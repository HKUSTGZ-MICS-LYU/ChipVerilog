module i2c_master_bit_ctrl (
    input             clk,
    input             rst,
    input             nReset,
    input             ena,
    input      [15:0] clk_cnt,
    input      [ 3:0] cmd,
    output reg        cmd_ack,
    output reg        busy,
    output reg        al,
    input             din,
    output reg        dout,
    input             scl_i,
    output            scl_o,
    output reg        scl_oen,
    input             sda_i,
    output            sda_o,
    output reg        sda_oen
);

// --------------------------------------------------------------------------
// Parameters / Localparams
// --------------------------------------------------------------------------
localparam [3:0]
    IDLE    = 4'd0,
    START_A = 4'd1,
    START_B = 4'd2,
    START_C = 4'd3,
    STOP_A  = 4'd4,
    STOP_B  = 4'd5,
    STOP_C  = 4'd6,
    WRITE_A = 4'd7,
    WRITE_B = 4'd8,
    WRITE_C = 4'd9,
    READ_A  = 4'd10,
    READ_B  = 4'd11,
    READ_C  = 4'd12;

localparam [3:0]
    I2C_CMD_START = 4'd1,
    I2C_CMD_STOP  = 4'd2,
    I2C_CMD_WRITE = 4'd3,
    I2C_CMD_READ  = 4'd4;

// --------------------------------------------------------------------------
// Internal signals and registers
// --------------------------------------------------------------------------
reg [3:0] state;

reg [15:0] cnt;
reg clk_en;

reg [15:0] filter_cnt;
reg cSCL, cSDA;
reg [2:0] fSCL, fSDA;
reg sSCL, sSDA;
reg dSCL, dSDA;

reg sta_condition, sto_condition;
reg slave_wait;
reg scl_sync;

wire sda_chk = (state == WRITE_B);

// --------------------------------------------------------------------------
// Constant low drive outputs
// --------------------------------------------------------------------------
assign scl_o = 1'b0;
assign sda_o = 1'b0;

// --------------------------------------------------------------------------
// Combinational output enables (derived from current state)
// --------------------------------------------------------------------------
always @(*) begin
    case (state)
        IDLE:    begin scl_oen = 1'b1; sda_oen = 1'b1; end
        START_A: begin scl_oen = 1'b1; sda_oen = 1'b1; end
        START_B: begin scl_oen = 1'b1; sda_oen = 1'b0; end
        START_C: begin scl_oen = 1'b0; sda_oen = 1'b0; end
        STOP_A:  begin scl_oen = 1'b0; sda_oen = 1'b0; end
        STOP_B:  begin scl_oen = 1'b1; sda_oen = 1'b0; end
        STOP_C:  begin scl_oen = 1'b1; sda_oen = 1'b1; end
        WRITE_A: begin scl_oen = 1'b0; sda_oen = ~din; end
        WRITE_B: begin scl_oen = 1'b1; sda_oen = ~din; end
        WRITE_C: begin scl_oen = 1'b0; sda_oen = ~din; end
        READ_A:  begin scl_oen = 1'b0; sda_oen = 1'b1; end
        READ_B:  begin scl_oen = 1'b1; sda_oen = 1'b1; end
        READ_C:  begin scl_oen = 1'b0; sda_oen = 1'b1; end
        default: begin scl_oen = 1'b1; sda_oen = 1'b1; end
    endcase
end

// --------------------------------------------------------------------------
// Sequential: System Clock Domain
// --------------------------------------------------------------------------
always @(posedge clk or negedge nReset) begin
    if (~nReset) begin
        // Asynchronous reset
        state <= IDLE;
        cmd_ack <= 1'b0;
        busy <= 1'b0;
        al <= 1'b0;
        dout <= 1'b0;

        cnt <= clk_cnt;
        clk_en <= 1'b0;

        filter_cnt <= clk_cnt >> 2;  // clk_cnt[15:2]
        cSCL <= 1'b1;
        cSDA <= 1'b1;
        fSCL <= 3'b111;
        fSDA <= 3'b111;
        sSCL <= 1'b1;
        sSDA <= 1'b1;
        dSCL <= 1'b1;
        dSDA <= 1'b1;

        slave_wait <= 1'b0;
        scl_sync <= 1'b0;
        sta_condition <= 1'b0;
        sto_condition <= 1'b0;
    end else if (rst) begin
        // Synchronous reset
        state <= IDLE;
        cmd_ack <= 1'b0;
        busy <= 1'b0;
        al <= 1'b0;
        dout <= 1'b0;

        cnt <= clk_cnt;
        clk_en <= 1'b0;

        filter_cnt <= clk_cnt >> 2;
        cSCL <= 1'b1;
        cSDA <= 1'b1;
        fSCL <= 3'b111;
        fSDA <= 3'b111;
        sSCL <= 1'b1;
        sSDA <= 1'b1;
        dSCL <= 1'b1;
        dSDA <= 1'b1;

        slave_wait <= 1'b0;
        scl_sync <= 1'b0;
        sta_condition <= 1'b0;
        sto_condition <= 1'b0;
    end else begin
        // ------------------------------------------------------------------
        // 1. Input capture (synchronization stage)
        // ------------------------------------------------------------------
        cSCL <= scl_i;
        cSDA <= sda_i;

        // ------------------------------------------------------------------
        // 2. Input filter (sampling at clk_cnt/4 rate)
        // ------------------------------------------------------------------
        if (~ena) begin
            filter_cnt <= clk_cnt >> 2;
        end else if (filter_cnt == 16'd0) begin
            filter_cnt <= clk_cnt >> 2;
            fSCL <= {fSCL[1:0], cSCL};
            fSDA <= {fSDA[1:0], cSDA};
        end else begin
            filter_cnt <= filter_cnt - 1'b1;
        end

        // ------------------------------------------------------------------
        // 3. Majority function → filtered signals
        // ------------------------------------------------------------------
        sSCL <= (fSCL[0] & fSCL[1]) | (fSCL[1] & fSCL[2]) | (fSCL[0] & fSCL[2]);
        sSDA <= (fSDA[0] & fSDA[1]) | (fSDA[1] & fSDA[2]) | (fSDA[0] & fSDA[2]);

        // ------------------------------------------------------------------
        // 4. Delayed versions for edge detection
        // ------------------------------------------------------------------
        dSCL <= sSCL;
        dSDA <= sSDA;

        // ------------------------------------------------------------------
        // 5. START and STOP condition detection
        // ------------------------------------------------------------------
        sta_condition <= (~sSDA & dSDA & sSCL);
        sto_condition <= ( sSDA & ~dSDA & sSCL);

        // ------------------------------------------------------------------
        // 6. Slave clock stretching (hold when master releases SCL but sSCL low)
        // ------------------------------------------------------------------
        slave_wait <= (scl_oen == 1'b1) & (~sSCL);

        // ------------------------------------------------------------------
        // 7. Multi-master clock synchronisation (falling edge on sSCL while released)
        // ------------------------------------------------------------------
        scl_sync <= (scl_oen == 1'b1) & (dSCL & ~sSCL);

        // ------------------------------------------------------------------
        // 8. Clock divider & clk_en generation
        // ------------------------------------------------------------------
        if (~ena) begin
            // Core disabled: reload counter, no tick
            cnt <= clk_cnt;
            clk_en <= 1'b0;
        end else if (scl_sync) begin
            // Another master drove SCL low while we released it
            cnt <= clk_cnt;
            // Do not assert clk_en – the FSM shall not advance on sync
            clk_en <= 1'b0;
        end else if (slave_wait) begin
            // Hold counter while slave is stretching
            cnt <= cnt;
            clk_en <= 1'b0;
        end else if (cnt == 16'd0) begin
            // Counter expired: generate timing tick and reload
            cnt <= clk_cnt;
            clk_en <= 1'b1;
        end else begin
            cnt <= cnt - 1'b1;
            clk_en <= 1'b0;
        end

        // ------------------------------------------------------------------
        // 9. Bus busy flag
        // ------------------------------------------------------------------
        if (sta_condition) begin
            busy <= 1'b1;
        end else if (sto_condition) begin
            busy <= 1'b0;
        end

        // ------------------------------------------------------------------
        // 10. Arbitration lost detection
        // ------------------------------------------------------------------
        if ( (sda_chk && (sda_oen == 1'b1) && (sSDA == 1'b0)) |
             (sto_condition && (state != IDLE) &&
              (state != STOP_A) && (state != STOP_B) && (state != STOP_C) ) ) begin
            al <= 1'b1;
        end else if (state == IDLE) begin
            // Clear arbitration lost when returning to idle
            al <= 1'b0;
        end

        // ------------------------------------------------------------------
        // 11. Read data sampling (on rising edge of filtered SCL)
        // ------------------------------------------------------------------
        if (sSCL & ~dSCL) begin
            dout <= sSDA;
        end

        // ------------------------------------------------------------------
        // 12. Command FSM (only advances on clk_en if not arbitration lost)
        // ------------------------------------------------------------------
        if (clk_en) begin
            if (al) begin
                // Arbitration lost forces idle
                state <= IDLE;
                cmd_ack <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        cmd_ack <= 1'b0;
                        case (cmd)
                            I2C_CMD_START: state <= START_A;
                            I2C_CMD_STOP:  state <= STOP_A;
                            I2C_CMD_WRITE: state <= WRITE_A;
                            I2C_CMD_READ:  state <= READ_A;
                            default:       state <= IDLE;
                        endcase
                    end

                    // ---- START sequence ----
                    START_A: state <= START_B;
                    START_B: state <= START_C;
                    START_C: begin
                        state <= IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // ---- STOP sequence ----
                    STOP_A: state <= STOP_B;
                    STOP_B: state <= STOP_C;
                    STOP_C: begin
                        state <= IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // ---- WRITE sequence ----
                    WRITE_A: state <= WRITE_B;
                    WRITE_B: state <= WRITE_C;
                    WRITE_C: begin
                        state <= IDLE;
                        cmd_ack <= 1'b1;
                    end

                    // ---- READ sequence ----
                    READ_A: state <= READ_B;
                    READ_B: state <= READ_C;
                    READ_C: begin
                        state <= IDLE;
                        cmd_ack <= 1'b1;
                    end

                    default: begin
                        state <= IDLE;
                        cmd_ack <= 1'b0;
                    end
                endcase
            end // else: !al
        end else begin
            // No clk_en – keep state and clear cmd_ack if idle
            if (state == IDLE) begin
                cmd_ack <= 1'b0;
            end
        end // clk_en

    end // else: no reset
end

endmodule
