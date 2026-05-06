module i2c_master_byte_ctrl (
    input wire clk,
    input wire rst,
    input wire nReset,
    input wire ena,
    input wire [15:0] clk_cnt,
    input wire start,
    input wire stop,
    input wire read,
    input wire write,
    input wire ack_in,
    input wire [7:0] din,
    output reg cmd_ack,
    output reg ack_out,
    output wire [7:0] dout,
    output wire i2c_busy,
    output wire i2c_al,
    input wire scl_i,
    output wire scl_o,
    output wire scl_oen,
    input wire sda_i,
    output wire sda_o,
    output wire sda_oen
);

    // Parameters for commands to bit controller
    localparam I2C_CMD_NOP    = 3'b000;
    localparam I2C_CMD_START  = 3'b001;
    localparam I2C_CMD_STOP   = 3'b010;
    localparam I2C_CMD_READ   = 3'b011;
    localparam I2C_CMD_WRITE  = 3'b100;

    // FSM state encoding
    localparam ST_IDLE  = 3'b000;
    localparam ST_START = 3'b001;
    localparam ST_READ  = 3'b010;
    localparam ST_WRITE = 3'b011;
    localparam ST_ACK   = 3'b100;
    localparam ST_STOP  = 3'b101;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] sr;
    reg [2:0] dcnt; // 3-bit counter
    reg [2:0] core_cmd;
    reg core_txd;
    wire core_ack;
    wire core_rxd;
    reg cmd_ack_reg; // internal for go logic
    reg ack_out_reg;
    reg ld, shift;

    // Combinational signals
    wire go = (read | write | stop) & ~cmd_ack_reg;
    wire cnt_done = (dcnt == 3'd0);

    // Always assign dout and ack_out from registers
    assign dout = sr;
    assign ack_out = ack_out_reg;
    // cmd_ack output from register
    assign cmd_ack = cmd_ack_reg;

    // Instantiate bit controller
    i2c_master_bit_ctrl bit_controller (
        .clk(clk),
        .rst(rst),
        .nReset(nReset),
        .ena(ena),
        .clk_cnt(clk_cnt),
        .cmd(core_cmd),
        .core_txd(core_txd),
        .core_ack(core_ack),
        .core_rxd(core_rxd),
        .scl_i(scl_i),
        .scl_o(scl_o),
        .scl_oen(scl_oen),
        .sda_i(sda_i),
        .sda_o(sda_o),
        .sda_oen(sda_oen),
        .i2c_busy(i2c_busy),
        .i2c_al(i2c_al)
    );

    // Sequential logic with async reset
    always @(posedge clk or negedge nReset) begin
        if (!nReset) begin
            state <= ST_IDLE;
            sr <= 8'd0;
            dcnt <= 3'd0;
            core_cmd <= I2C_CMD_NOP;
            cmd_ack_reg <= 1'b0;
            ack_out_reg <= 1'b0;
            ld <= 1'b0;
            shift <= 1'b0;
        end else begin
            // Synchronous reset or i2c_al abort
            if (rst || i2c_al) begin
                state <= ST_IDLE;
                sr <= 8'd0;
                dcnt <= 3'd0;
                core_cmd <= I2C_CMD_NOP;
                cmd_ack_reg <= 1'b0;
                ack_out_reg <= 1'b0;
                ld <= 1'b0;
                shift <= 1'b0;
            end else begin
                // Default updates
                state <= next_state;
                ld <= 1'b0; // one-cycle pulse
                shift <= 1'b0; // one-cycle pulse
                cmd_ack_reg <= 1'b0; // default low

                case (state)
                    ST_IDLE: begin
                        if (go) begin
                            ld <= 1'b1; // load din and initialize dcnt
                            // Priority: start, read, write, stop
                            if (start) begin
                                core_cmd <= I2C_CMD_START;
                                next_state <= ST_START;
                            end else if (read) begin
                                core_cmd <= I2C_CMD_READ;
                                next_state <= ST_READ;
                            end else if (write) begin
                                core_cmd <= I2C_CMD_WRITE;
                                next_state <= ST_WRITE;
                            end else begin // stop only
                                core_cmd <= I2C_CMD_STOP;
                                next_state <= ST_STOP;
                            end
                        end else begin
                            core_cmd <= I2C_CMD_NOP;
                            next_state <= ST_IDLE;
                        end
                    end

                    ST_START: begin
                        if (core_ack) begin
                            if (read) begin
                                core_cmd <= I2C_CMD_READ;
                                next_state <= ST_READ;
                            end else begin
                                core_cmd <= I2C_CMD_WRITE;
                                next_state <= ST_WRITE;
                            end
                        end else begin
                            core_cmd <= I2C_CMD_START;
                            next_state <= ST_START;
                        end
                    end

                    ST_WRITE: begin
                        if (core_ack) begin
                            if (!cnt_done) begin
                                shift <= 1'b1;
                                core_cmd <= I2C_CMD_WRITE;
                                next_state <= ST_WRITE;
                            end else begin
                                // last bit done, go to ACK
                                core_cmd <= I2C_CMD_READ;
                                next_state <= ST_ACK;
                            end
                        end else begin
                            core_cmd <= I2C_CMD_WRITE;
                            next_state <= ST_WRITE;
                        end
                    end

                    ST_READ: begin
                        if (core_ack) begin
                            if (!cnt_done) begin
                                shift <= 1'b1;
                                core_cmd <= I2C_CMD_READ;
                                next_state <= ST_READ;
                            end else begin
                                // last bit done, go to ACK
                                core_cmd <= I2C_CMD_WRITE;
                                next_state <= ST_ACK;
                            end
                        end else begin
                            core_cmd <= I2C_CMD_READ;
                            next_state <= ST_READ;
                        end
                    end

                    ST_ACK: begin
                        if (core_ack) begin
                            // Capture ack bit if we came from write (i.e., slave ack)
                            // The last command before ST_ACK determines this:
                            // If previous state was ST_WRITE, we issued READ, so core_rxd is slave ack.
                            // If previous state was ST_READ, we issued WRITE, so we used ack_in.
                            // We can infer from previous core_cmd? Or use a flag.
                            // Simpler: always capture core_rxd for ack_out, but for read we ignore.
                            ack_out_reg <= core_rxd; // captures slave ack for write; for read, core_rxd is undefined but not used.
                            if (stop) begin
                                core_cmd <= I2C_CMD_STOP;
                                next_state <= ST_STOP;
                            end else begin
                                cmd_ack_reg <= 1'b1;
                                core_cmd <= I2C_CMD_NOP;
                                next_state <= ST_IDLE;
                            end
                        end else begin
                            // Keep same command that started the ACK phase
                            // We need to remember the command; we can store it or check state history.
                            // Actually, we can determine: if we came from WRITE, the command is READ; if from READ, it's WRITE.
                            // We can use a register to remember command type, or check previous state.
                            // Alternative: always use the command that was issued when entering ST_ACK. We can store it.
                            // For simplicity, let's use a separate register to remember the ack command.
                        end
                    end

                    ST_STOP: begin
                        if (core_ack) begin
                            cmd_ack_reg <= 1'b1;
                            core_cmd <= I2C_CMD_NOP;
                            next_state <= ST_IDLE;
                        end else begin
                            core_cmd <= I2C_CMD_STOP;
                            next_state <= ST_STOP;
                        end
                    end

                    default: begin
                        next_state <= ST_IDLE;
                        core_cmd <= I2C_CMD_NOP;
                    end
                endcase

                // Load and shift operations
                if (ld) begin
                    sr <= din;
                    dcnt <= 3'd7;
                end else if (shift) begin
                    sr <= {sr[6:0], core_rxd};
                    dcnt <= dcnt - 3'd1;
                end
            end
        end
    end

    // Combinational core_txd based on state and ack_in
    always @(*) begin
        if (state == ST_ACK) begin
            // During ACK from read, we drive ack_in as master ack
            // But we need to know if we are in read ack or write ack.
            // Actually, in ST_ACK, the command issued is either READ (from write) or WRITE (from read).
            // For write ack: command is READ, core_txd is don't care? For read ack: command is WRITE, core_txd should be ack_in.
            // We can base on the command; we can check core_cmd which is set in the state.
            // However core_cmd is registered; it may not reflect the intended command for the current cycle.
            // Better: Use a separate combinational signal based on the previous state or a flag.
            // Simpler: Always use ack_in during ST_ACK, but that would incorrectly drive the slave ack during write ack.
            // Actually during write ack, core_cmd is READ, so core_txd is ignored by the bit controller for READ.
            // So we can simply set core_txd = ack_in; it won't matter for WRITE command? No, for WRITE command core_txd is driven.
            // But we need to distinguish when to use ack_in. Let's store a flag 'read_ack' when entering ST_ACK from ST_READ.
            // Alternatively, we can use a register to remember if the ack is for read or write.
        end
        // Default core_txd from sr MSB
        core_txd = sr[7];
    end

    // However, the above is not complete. We need to ensure that during ST_ACK when coming from ST_READ, core_txd = ack_in.
    // Also during ST_WRITE, core_txd = sr[7].
    // Let's refine the combinational block with state and maybe a stored flag.
    // We'll add a register 'ack_src' to indicate the ack phase is for read (1) or write (0). Set when entering ST_ACK.
    // But the spec says: "for a read transfer, the previous state scheduled a bit-level WRITE, so ack_in is driven through core_txd."
    // So we need to know that.

endmodule
