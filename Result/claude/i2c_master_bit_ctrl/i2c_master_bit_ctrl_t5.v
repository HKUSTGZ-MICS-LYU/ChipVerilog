// ============================================================
//  i2c_master_bit_ctrl.v
//  Bit-level controller for the OpenCores I2C master core.
//
//  Responsibilities
//    - Clock divider and clk_en tick generation
//    - Two-stage input synchronisation + 3-sample majority filter
//    - Slave clock-stretching pause
//    - Multi-master SCL synchronisation
//    - START / STOP condition detection
//    - Bus-busy flag
//    - Arbitration-lost detection
//    - dout capture on filtered-SCL rising edge
//    - 4-command (START/STOP/READ/WRITE) FSM
//
//  Open-drain convention
//    scl_o / sda_o  are constant 0.
//    scl_oen = 1  →  release line (pull-up brings it high)
//    scl_oen = 0  →  drive line low
// ============================================================

module i2c_master_bit_ctrl (
    input             clk,       // system clock
    input             rst,       // synchronous active-high reset
    input             nReset,    // asynchronous active-low reset
    input             ena,       // core enable

    input      [15:0] clk_cnt,   // prescale value

    input      [ 3:0] cmd,       // bit command from byte controller
    output reg        cmd_ack,   // one-cycle command-complete pulse
    output reg        busy,      // bus busy
    output reg        al,        // arbitration lost

    input             din,       // data bit to write
    output reg        dout,      // data bit received

    input             scl_i,     // SCL pad input
    output            scl_o,     // SCL pad output (constant 0)
    output reg        scl_oen,   // SCL output-enable, active-low
    input             sda_i,     // SDA pad input
    output            sda_o,     // SDA pad output (constant 0)
    output reg        sda_oen    // SDA output-enable, active-low
);

// ---------------------------------------------------------------
//  Command encodings
// ---------------------------------------------------------------
localparam [3:0]
    I2C_CMD_NOP   = 4'b0000,
    I2C_CMD_START = 4'b0001,
    I2C_CMD_STOP  = 4'b0010,
    I2C_CMD_READ  = 4'b0100,
    I2C_CMD_WRITE = 4'b1000;

// ---------------------------------------------------------------
//  FSM state encoding
// ---------------------------------------------------------------
localparam [4:0]
    ST_IDLE    = 5'd0,
    ST_START_A = 5'd1,   // release SDA (ensure SDA free)
    ST_START_B = 5'd2,   // release SCL
    ST_START_C = 5'd3,   // wait SCL high / hold
    ST_START_D = 5'd4,   // pull SDA low  → START condition
    ST_START_E = 5'd5,   // pull SCL low  → ack
    ST_STOP_A  = 5'd6,   // ensure SDA low, SCL low
    ST_STOP_B  = 5'd7,   // release SCL
    ST_STOP_C  = 5'd8,   // hold SCL high
    ST_STOP_D  = 5'd9,   // release SDA   → STOP condition + ack
    ST_RD_A    = 5'd10,  // SCL low, release SDA
    ST_RD_B    = 5'd11,  // release SCL
    ST_RD_C    = 5'd12,  // hold SCL high (sample window)
    ST_RD_D    = 5'd13,  // pull SCL low + ack
    ST_WR_A    = 5'd14,  // SCL low, drive SDA per din
    ST_WR_B    = 5'd15,  // release SCL
    ST_WR_C    = 5'd16,  // hold SCL high, check arbitration
    ST_WR_D    = 5'd17;  // pull SCL low + ack

// ---------------------------------------------------------------
//  Open-drain: always output 0; OEN controls the line
// ---------------------------------------------------------------
assign scl_o = 1'b0;
assign sda_o = 1'b0;

// ---------------------------------------------------------------
//  Two-stage input synchronisers  (metastability reduction)
// ---------------------------------------------------------------
reg [1:0] cSCL, cSDA;   // cX[1] = stable synchronised value

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cSCL <= 2'b11;
        cSDA <= 2'b11;
    end else if (rst) begin
        cSCL <= 2'b11;
        cSDA <= 2'b11;
    end else begin
        cSCL <= {cSCL[0], scl_i};
        cSDA <= {cSDA[0], sda_i};
    end
end

// ---------------------------------------------------------------
//  Digital glitch filter
//  Sampling interval = clk_cnt >> 2.
//  Three most-recent samples kept in fSCL / fSDA.
//  Majority vote gives sSCL / sSDA.
// ---------------------------------------------------------------
reg [15:0] filter_cnt;
reg  [2:0] fSCL, fSDA;
reg        sSCL, sSDA;  // filtered (stable) bus values
reg        dSCL, dSDA;  // one-cycle delayed filtered values

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        filter_cnt <= 16'd0;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
    end else if (rst) begin
        filter_cnt <= 16'd0;
        fSCL       <= 3'b111;
        fSDA       <= 3'b111;
    end else if (~ena) begin
        // While disabled, keep counter preloaded; do not shift samples
        filter_cnt <= clk_cnt >> 2;
    end else if (~|filter_cnt) begin
        // Counter expired: shift in new samples and reload
        filter_cnt <= clk_cnt >> 2;
        fSCL       <= {fSCL[1:0], cSCL[1]};
        fSDA       <= {fSDA[1:0], cSDA[1]};
    end else begin
        filter_cnt <= filter_cnt - 16'd1;
    end
end

// Majority vote + delayed copies
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        sSCL <= 1'b1; dSCL <= 1'b1;
        sSDA <= 1'b1; dSDA <= 1'b1;
    end else if (rst) begin
        sSCL <= 1'b1; dSCL <= 1'b1;
        sSDA <= 1'b1; dSDA <= 1'b1;
    end else begin
        dSCL <= sSCL;
        dSDA <= sSDA;
        sSCL <= (fSCL[2] & fSCL[1]) | (fSCL[2] & fSCL[0]) | (fSCL[1] & fSCL[0]);
        sSDA <= (fSDA[2] & fSDA[1]) | (fSDA[2] & fSDA[0]) | (fSDA[1] & fSDA[0]);
    end
end

// ---------------------------------------------------------------
//  START / STOP condition detectors
// ---------------------------------------------------------------
wire sta_condition =  dSDA & ~sSDA & sSCL;   // SDA fell while SCL high
wire sto_condition = ~dSDA &  sSDA & sSCL;   // SDA rose  while SCL high

// ---------------------------------------------------------------
//  Bus busy flag
// ---------------------------------------------------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset)    busy <= 1'b0;
    else if (rst)   busy <= 1'b0;
    else            busy <= (busy | sta_condition) & ~sto_condition;
end

// ---------------------------------------------------------------
//  Clock stretching and multi-master SCL sync
//
//  slave_wait : we released SCL (scl_oen=1) but bus is still low
//  scl_sync   : another master pulled SCL low while we released it
// ---------------------------------------------------------------
wire slave_wait = scl_oen & ~sSCL;
wire scl_sync   = scl_oen &  dSCL & ~sSCL;   // falling edge on sSCL while OEN=1

// ---------------------------------------------------------------
//  Clock divider and clk_en tick
// ---------------------------------------------------------------
reg [15:0] cnt;
reg        clk_en;

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        cnt    <= 16'd0;
        clk_en <= 1'b1;
    end else if (rst) begin
        cnt    <= 16'd0;
        clk_en <= 1'b1;
    end else if (~ena | scl_sync) begin
        // Disabled or SCL sync event: reload counter, assert tick
        cnt    <= clk_cnt;
        clk_en <= 1'b1;
    end else if (slave_wait) begin
        // Pause counting while slave stretches SCL
        clk_en <= 1'b0;
    end else if (~|cnt) begin
        // Counter expired normally
        cnt    <= clk_cnt;
        clk_en <= 1'b1;
    end else begin
        cnt    <= cnt - 16'd1;
        clk_en <= 1'b0;
    end
end

// ---------------------------------------------------------------
//  dout: capture filtered SDA on filtered SCL rising edge
// ---------------------------------------------------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset)            dout <= 1'b0;
    else if (rst)           dout <= 1'b0;
    else if (sSCL & ~dSCL)  dout <= sSDA;  // rising edge of filtered SCL
end

// ---------------------------------------------------------------
//  FSM state register + output registers
// ---------------------------------------------------------------
reg [4:0] c_state;
reg       sda_chk;   // 1 → check SDA for arbitration this cycle

// ---------------------------------------------------------------
//  Arbitration-lost flag
//
//  Case 1: we released SDA (sda_oen=1, expecting high) but
//          filtered SDA is low — another master won.
//  Case 2: unexpected STOP while FSM is executing a non-STOP cmd.
// ---------------------------------------------------------------
wire in_stop_seq = (c_state == ST_STOP_A) | (c_state == ST_STOP_B) |
                   (c_state == ST_STOP_C) | (c_state == ST_STOP_D);

always @(posedge clk or negedge nReset) begin
    if (!nReset)  al <= 1'b0;
    else if (rst) al <= 1'b0;
    else begin
        al <= (sda_chk & ~sSDA & sda_oen) |         // arb check failed
              (sto_condition & busy &                // unexpected STOP
               (c_state != ST_IDLE) & ~in_stop_seq);
    end
end

// ---------------------------------------------------------------
//  Main command FSM
// ---------------------------------------------------------------
always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        c_state <= ST_IDLE;
        cmd_ack <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else if (rst | al) begin
        // Synchronous reset or arbitration lost → back to idle, release bus
        c_state <= ST_IDLE;
        cmd_ack <= 1'b0;
        scl_oen <= 1'b1;
        sda_oen <= 1'b1;
        sda_chk <= 1'b0;
    end else begin
        // Default: deassert single-cycle pulse
        cmd_ack <= 1'b0;

        if (clk_en) begin
            case (c_state)

                // ------------------------------------------------
                //  IDLE: decode next command
                // ------------------------------------------------
                ST_IDLE: begin
                    sda_chk <= 1'b0;
                    case (cmd)
                        I2C_CMD_START: c_state <= ST_START_A;
                        I2C_CMD_STOP:  c_state <= ST_STOP_A;
                        I2C_CMD_READ:  c_state <= ST_RD_A;
                        I2C_CMD_WRITE: c_state <= ST_WR_A;
                        default:       c_state <= ST_IDLE;
                    endcase
                end

                // ------------------------------------------------
                //  START sequence
                //  Timing: release SDA → release SCL → hold →
                //          pull SDA low (START) → pull SCL low
                // ------------------------------------------------
                ST_START_A: begin
                    // Release SDA so both lines are free
                    scl_oen <= scl_oen;   // keep current SCL state
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_START_B;
                end
                ST_START_B: begin
                    // Release SCL
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_START_C;
                end
                ST_START_C: begin
                    // Hold both high (allow SCL to rise fully)
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_START_D;
                end
                ST_START_D: begin
                    // Pull SDA low while SCL is high → START condition
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    c_state <= ST_START_E;
                end
                ST_START_E: begin
                    // Pull SCL low; return to idle; signal done
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                    c_state <= ST_IDLE;
                end

                // ------------------------------------------------
                //  STOP sequence
                //  Timing: SCL low + SDA low → release SCL →
                //          hold → release SDA (STOP)
                // ------------------------------------------------
                ST_STOP_A: begin
                    // Ensure SCL and SDA are low
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    c_state <= ST_STOP_B;
                end
                ST_STOP_B: begin
                    // Release SCL
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    c_state <= ST_STOP_C;
                end
                ST_STOP_C: begin
                    // Hold SCL high, SDA still low
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b0;
                    sda_chk <= 1'b0;
                    c_state <= ST_STOP_D;
                end
                ST_STOP_D: begin
                    // Release SDA while SCL high → STOP condition; signal done
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                    c_state <= ST_IDLE;
                end

                // ------------------------------------------------
                //  READ sequence
                //  Timing: SCL low + release SDA → release SCL →
                //          hold (dout captured by SCL-edge logic) →
                //          pull SCL low
                // ------------------------------------------------
                ST_RD_A: begin
                    // SCL low; release SDA for slave to drive
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_RD_B;
                end
                ST_RD_B: begin
                    // Release SCL
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_RD_C;
                end
                ST_RD_C: begin
                    // Hold SCL high; dout captured by SCL rising-edge logic above
                    scl_oen <= 1'b1;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    c_state <= ST_RD_D;
                end
                ST_RD_D: begin
                    // Pull SCL low; signal done
                    scl_oen <= 1'b0;
                    sda_oen <= 1'b1;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                    c_state <= ST_IDLE;
                end

                // ------------------------------------------------
                //  WRITE sequence
                //  Timing: SCL low + drive SDA per din → release SCL →
                //          hold + arbitration check → pull SCL low
                //
                //  sda_oen = din:
                //    din=1 → sda_oen=1 → release SDA (line goes high)
                //    din=0 → sda_oen=0 → drive  SDA low
                // ------------------------------------------------
                ST_WR_A: begin
                    // SCL low; set SDA according to din
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    c_state <= ST_WR_B;
                end
                ST_WR_B: begin
                    // Release SCL
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    c_state <= ST_WR_C;
                end
                ST_WR_C: begin
                    // Hold SCL high; enable arbitration check
                    scl_oen <= 1'b1;
                    sda_oen <= din;
                    sda_chk <= 1'b1;
                    c_state <= ST_WR_D;
                end
                ST_WR_D: begin
                    // Pull SCL low; signal done
                    scl_oen <= 1'b0;
                    sda_oen <= din;
                    sda_chk <= 1'b0;
                    cmd_ack <= 1'b1;
                    c_state <= ST_IDLE;
                end

                default: c_state <= ST_IDLE;

            endcase
        end // clk_en
    end
end

endmodule