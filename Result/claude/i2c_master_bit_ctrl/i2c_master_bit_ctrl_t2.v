// =============================================================================
// Module  : i2c_master_bit_ctrl
// Purpose : Bit-level controller for the OpenCores I2C master core.
//           Translates START / STOP / READ / WRITE bit commands from the byte
//           controller into timed SCL / SDA open-drain sequences.
//
// Features
//   - START and STOP condition generation
//   - Single-bit READ and WRITE cycles
//   - Bus-busy detection
//   - Arbitration-lost detection
//   - Slave clock-stretching support
//   - Multi-master SCL synchronisation
//   - Two-stage metastability synchronisation on SCL / SDA inputs
//   - Three-sample majority-vote glitch filter on SCL / SDA
// =============================================================================

`timescale 1ns / 1ps

module i2c_master_bit_ctrl (
    // System
    input             clk,       // system clock (rising-edge sensitive)
    input             rst,       // synchronous  active-high reset
    input             nReset,    // asynchronous active-low  reset

    // Control
    input             ena,       // core enable
    input      [15:0] clk_cnt,   // clock prescale value (bit-period / 4 - 1)

    // Byte-controller interface
    input      [ 3:0] cmd,       // bit command
    output reg        cmd_ack,   // one-cycle command-complete pulse
    output reg        busy,      // bus busy flag
    output reg        al,        // arbitration-lost flag

    // Data
    input             din,       // bit to transmit (WRITE)
    output reg        dout,      // bit received    (READ)

    // I2C SCL open-drain interface
    input             scl_i,     // SCL line input  (from pad)
    output            scl_o,     // SCL line output – constant low
    output reg        scl_oen,   // SCL output-enable, active-low
                                 //   0 = drive low, 1 = release (pull-up wins)
    // I2C SDA open-drain interface
    input             sda_i,     // SDA line input  (from pad)
    output            sda_o,     // SDA line output – constant low
    output reg        sda_oen    // SDA output-enable, active-low
                                 //   0 = drive low, 1 = release (pull-up wins)
);

// =============================================================================
// Parameters
// =============================================================================

    // Bit-command encodings
    localparam I2C_CMD_NOP   = 4'b0000;
    localparam I2C_CMD_START = 4'b0001;
    localparam I2C_CMD_STOP  = 4'b0010;
    localparam I2C_CMD_READ  = 4'b0100;
    localparam I2C_CMD_WRITE = 4'b1000;

    // FSM states (5-bit to fit 17 states)
    localparam ST_IDLE    = 5'd0;
    localparam ST_START_A = 5'd1;
    localparam ST_START_B = 5'd2;
    localparam ST_START_C = 5'd3;
    localparam ST_START_D = 5'd4;
    localparam ST_STOP_A  = 5'd5;
    localparam ST_STOP_B  = 5'd6;
    localparam ST_STOP_C  = 5'd7;
    localparam ST_STOP_D  = 5'd8;
    localparam ST_RD_A    = 5'd9;
    localparam ST_RD_B    = 5'd10;
    localparam ST_RD_C    = 5'd11;
    localparam ST_RD_D    = 5'd12;
    localparam ST_WR_A    = 5'd13;
    localparam ST_WR_B    = 5'd14;
    localparam ST_WR_C    = 5'd15;
    localparam ST_WR_D    = 5'd16;

// =============================================================================
// Open-drain output assignments
// scl_o / sda_o are tied low; the OEN signals control the actual line level.
// =============================================================================

    assign scl_o = 1'b0;
    assign sda_o = 1'b0;

// =============================================================================
// Two-stage input synchronisation (metastability reduction)
// =============================================================================

    reg [1:0] cSCL, cSDA;   // capture shift-registers

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

// =============================================================================
// Filter counter
// Sampling interval = clk_cnt >> 2  (one quarter of the bit-period counter)
// =============================================================================

    reg [15:0] filter_cnt;

    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            filter_cnt <= 16'd0;
        end else if (rst) begin
            filter_cnt <= 16'd0;
        end else if (!ena) begin
            // Core disabled: reload the filter counter but do not sample
            filter_cnt <= clk_cnt >> 2;
        end else if (filter_cnt == 16'd0) begin
            filter_cnt <= clk_cnt >> 2;
        end else begin
            filter_cnt <= filter_cnt - 16'd1;
        end
    end

// =============================================================================
// Three-sample glitch filter + majority-vote
// =============================================================================

    reg [2:0] fSCL, fSDA;  // 3-sample history shift-registers
    reg       sSCL, sSDA;  // filtered (stable) SCL / SDA
    reg       dSCL, dSDA;  // one-cycle delayed filtered values

    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end else if (rst) begin
            fSCL <= 3'b111;
            fSDA <= 3'b111;
            sSCL <= 1'b1;
            sSDA <= 1'b1;
            dSCL <= 1'b1;
            dSDA <= 1'b1;
        end else begin
            // Delay registers for edge detection
            dSCL <= sSCL;
            dSDA <= sSDA;

            // Shift a new sample into the history when the filter interval expires
            if (filter_cnt == 16'd0) begin
                fSCL <= {fSCL[1:0], cSCL[1]};
                fSDA <= {fSDA[1:0], cSDA[1]};
            end

            // Majority vote over the 3-sample history
            sSCL <= (fSCL[2] & fSCL[1]) | (fSCL[2] & fSCL[0]) | (fSCL[1] & fSCL[0]);
            sSDA <= (fSDA[2] & fSDA[1]) | (fSDA[2] & fSDA[0]) | (fSDA[1] & fSDA[0]);
        end
    end

// =============================================================================
// START / STOP condition detection
// =============================================================================

    wire sta_condition = ~sSDA & dSDA & sSCL;  // SDA falling while SCL high
    wire sto_condition =  sSDA & ~dSDA & sSCL; // SDA rising  while SCL high

// =============================================================================
// Bus busy flag
// =============================================================================

    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            busy <= 1'b0;
        else if (rst)
            busy <= 1'b0;
        else
            busy <= (sta_condition | busy) & ~sto_condition;
    end

// =============================================================================
// Clock divider and clk_en generation
// =============================================================================

    reg        clk_en;     // timing enable pulse for the FSM
    reg [15:0] cnt;        // bit-period down-counter

    // Slave clock-stretching: we released SCL (scl_oen=1) but the line is still low
    wire slave_wait = scl_oen & ~sSCL;

    // Multi-master synchronisation: SCL fell externally while we released it
    wire scl_sync   = dSCL & ~sSCL & scl_oen;

    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            cnt    <= 16'd0;
            clk_en <= 1'b1;   // allow FSM to start from idle after reset
        end else if (rst) begin
            cnt    <= 16'd0;
            clk_en <= 1'b1;
        end else begin
            clk_en <= 1'b0;   // default: de-asserted

            if (!ena) begin
                // Core disabled: reload counter, suppress clk_en
                cnt <= clk_cnt;
            end else if (scl_sync) begin
                // Re-sync to external SCL low: restart low-phase timing
                cnt <= clk_cnt;
            end else if (slave_wait) begin
                // Clock-stretching: freeze counter, do not assert clk_en
                /* hold */
            end else if (cnt == 16'd0) begin
                cnt    <= clk_cnt;
                clk_en <= 1'b1;   // tick the FSM
            end else begin
                cnt <= cnt - 16'd1;
            end
        end
    end

// =============================================================================
// Read data capture
// Sample filtered SDA on every rising edge of filtered SCL
// =============================================================================

    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            dout <= 1'b0;
        else if (rst)
            dout <= 1'b0;
        else if (sSCL & ~dSCL)    // rising edge of filtered SCL
            dout <= sSDA;
    end

// =============================================================================
// Arbitration-lost detection
//
// Case 1 – SDA check failure:
//   We enabled the SDA checker (sda_chk=1) and released SDA (sda_oen=1)
//   expecting it to be high, but the filtered SDA is observed low.
//
// Case 2 – Unexpected STOP:
//   A STOP condition is detected while the FSM is active AND we are not the
//   ones generating that STOP (i.e. we are not in the STOP command sequence).
// =============================================================================

    reg [4:0] c_state;   // forward declaration needed for al combinational
    reg       sda_chk;   // enable SDA arbitration check

    wire in_stop_seq = (c_state == ST_STOP_A) | (c_state == ST_STOP_B) |
                       (c_state == ST_STOP_C) | (c_state == ST_STOP_D);

    wire al_next = (sda_chk & sda_oen & ~sSDA) |
                   (sto_condition & (c_state != ST_IDLE) & ~in_stop_seq);

    always @(posedge clk or negedge nReset) begin
        if (!nReset)
            al <= 1'b0;
        else if (rst)
            al <= 1'b0;
        else
            al <= al_next;
    end

// =============================================================================
// Command FSM
// Advances only when clk_en is asserted.
// If arbitration is lost the FSM returns to idle immediately (not gated by clk_en).
// =============================================================================

    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            c_state <= ST_IDLE;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end else if (rst) begin
            c_state <= ST_IDLE;
            cmd_ack <= 1'b0;
            scl_oen <= 1'b1;
            sda_oen <= 1'b1;
            sda_chk <= 1'b0;
        end else begin
            cmd_ack <= 1'b0;   // default: de-asserted

            if (al) begin
                // --------------------------------------------------------
                // Arbitration lost: abort, release both lines, go to idle
                // --------------------------------------------------------
                c_state <= ST_IDLE;
                scl_oen <= 1'b1;
                sda_oen <= 1'b1;
                sda_chk <= 1'b0;

            end else if (clk_en) begin
                case (c_state)

                    // -------------------------------------------------------
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

                    // -------------------------------------------------------
                    // START sequence
                    //
                    //  A : keep SCL as-is (low if repeated-start, high if
                    //      first-start); release SDA high
                    //  B : release SCL high; SDA stays high
                    //  C : SCL high, pull SDA low  →  START condition
                    //  D : pull SCL low            →  cmd_ack
                    // -------------------------------------------------------
                    ST_START_A: begin
                        scl_oen <= scl_oen;   // preserve existing SCL drive
                        sda_oen <= 1'b1;      // release SDA high
                        sda_chk <= 1'b0;
                        c_state <= ST_START_B;
                    end
                    ST_START_B: begin
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                        c_state <= ST_START_C;
                    end
                    ST_START_C: begin
                        scl_oen <= 1'b1;      // SCL remains high
                        sda_oen <= 1'b0;      // pull SDA low → START condition
                        sda_chk <= 1'b0;
                        c_state <= ST_START_D;
                    end
                    ST_START_D: begin
                        scl_oen <= 1'b0;      // pull SCL low
                        sda_oen <= 1'b0;
                        sda_chk <= 1'b0;
                        c_state <= ST_IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // -------------------------------------------------------
                    // STOP sequence
                    //
                    //  A : SCL low, SDA low  (setup)
                    //  B : release SCL high; SDA stays low
                    //  C : SCL high, release SDA high  →  STOP condition
                    //  D : hold (bus now idle)         →  cmd_ack
                    // -------------------------------------------------------
                    ST_STOP_A: begin
                        scl_oen <= 1'b0;      // drive SCL low
                        sda_oen <= 1'b0;      // drive SDA low
                        sda_chk <= 1'b0;
                        c_state <= ST_STOP_B;
                    end
                    ST_STOP_B: begin
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b0;      // SDA still low
                        sda_chk <= 1'b0;
                        c_state <= ST_STOP_C;
                    end
                    ST_STOP_C: begin
                        scl_oen <= 1'b1;      // SCL remains high
                        sda_oen <= 1'b1;      // release SDA high → STOP condition
                        sda_chk <= 1'b0;
                        c_state <= ST_STOP_D;
                    end
                    ST_STOP_D: begin
                        scl_oen <= 1'b1;
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                        c_state <= ST_IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // -------------------------------------------------------
                    // READ sequence
                    //
                    //  A : SCL low, release SDA (slave drives the bit)
                    //  B : release SCL high (sample window opens)
                    //  C : SCL still high  (dout captured by SCL-edge logic)
                    //  D : pull SCL low    →  cmd_ack
                    // -------------------------------------------------------
                    ST_RD_A: begin
                        scl_oen <= 1'b0;      // drive SCL low
                        sda_oen <= 1'b1;      // release SDA → slave can drive
                        sda_chk <= 1'b0;
                        c_state <= ST_RD_B;
                    end
                    ST_RD_B: begin
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                        c_state <= ST_RD_C;
                    end
                    ST_RD_C: begin
                        scl_oen <= 1'b1;      // SCL remains high
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                        c_state <= ST_RD_D;
                    end
                    ST_RD_D: begin
                        scl_oen <= 1'b0;      // pull SCL low
                        sda_oen <= 1'b1;
                        sda_chk <= 1'b0;
                        c_state <= ST_IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // -------------------------------------------------------
                    // WRITE sequence
                    //
                    // SDA open-drain semantics:
                    //   din = 1 → sda_oen = 1 (release, pull-up wins → high)
                    //   din = 0 → sda_oen = 0 (drive low)
                    //
                    //  A : SCL low; drive SDA per din
                    //  B : release SCL high
                    //  C : SCL high; enable arbitration check (sda_chk)
                    //  D : pull SCL low  →  cmd_ack
                    // -------------------------------------------------------
                    ST_WR_A: begin
                        scl_oen <= 1'b0;
                        sda_oen <= din;       // din maps directly to oen polarity
                        sda_chk <= 1'b0;
                        c_state <= ST_WR_B;
                    end
                    ST_WR_B: begin
                        scl_oen <= 1'b1;      // release SCL high
                        sda_oen <= din;
                        sda_chk <= 1'b0;
                        c_state <= ST_WR_C;
                    end
                    ST_WR_C: begin
                        scl_oen <= 1'b1;      // SCL remains high
                        sda_oen <= din;
                        sda_chk <= 1'b1;      // check arbitration during stable high
                        c_state <= ST_WR_D;
                    end
                    ST_WR_D: begin
                        scl_oen <= 1'b0;      // pull SCL low
                        sda_oen <= din;
                        sda_chk <= 1'b0;
                        c_state <= ST_IDLE;
                        cmd_ack <= 1'b1;
                    end

                    default: c_state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
