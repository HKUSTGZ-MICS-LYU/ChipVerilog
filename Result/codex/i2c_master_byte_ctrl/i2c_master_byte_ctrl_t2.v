module i2c_master_byte_ctrl (
    clk, rst, nReset, ena, clk_cnt, start, stop, read, write, ack_in, din,
    cmd_ack, ack_out, dout, i2c_busy, i2c_al, scl_i, scl_o, scl_oen, sda_i, sda_o, sda_oen
);

input        clk;
input        rst;
input        nReset;
input        ena;
input [15:0] clk_cnt;
input        start;
input        stop;
input        read;
input        write;
input        ack_in;
input  [7:0] din;
input        scl_i;
input        sda_i;

output       cmd_ack;
output       ack_out;
output [7:0] dout;
output       i2c_busy;
output       i2c_al;
output       scl_o;
output       scl_oen;
output       sda_o;
output       sda_oen;

reg          cmd_ack;
reg          ack_out;
reg  [7:0]   sr;
reg  [2:0]   dcnt;
reg  [2:0]   c_state;
reg  [2:0]   state_n;
reg  [3:0]   core_cmd;
reg  [3:0]   core_cmd_n;
reg          ack_out_n;
reg          cmd_ack_n;
reg          ld;
reg          shift;

wire         core_ack;
wire         core_rxd;
wire         core_txd;
wire         cnt_done;
wire         go;

localparam [2:0] ST_IDLE  = 3'd0,
                 ST_START = 3'd1,
                 ST_READ  = 3'd2,
                 ST_WRITE = 3'd3,
                 ST_ACK   = 3'd4,
                 ST_STOP  = 3'd5;

localparam [3:0] I2C_CMD_NOP   = 4'b0000,
                 I2C_CMD_START = 4'b0001,
                 I2C_CMD_STOP  = 4'b0010,
                 I2C_CMD_READ  = 4'b0100,
                 I2C_CMD_WRITE = 4'b1000;

assign go       = (read | write | stop) & ~cmd_ack;
assign cnt_done = (dcnt == 3'd0);
assign dout     = sr;
assign core_txd = (c_state == ST_ACK) ? ack_in : sr[7];

always @* begin
    state_n    = c_state;
    core_cmd_n = core_cmd;
    cmd_ack_n  = 1'b0;
    ack_out_n  = ack_out;
    ld         = 1'b0;
    shift      = 1'b0;

    case (c_state)
        ST_IDLE: begin
            core_cmd_n = I2C_CMD_NOP;
            if (go) begin
                ld = 1'b1;
                if (start) begin
                    state_n    = ST_START;
                    core_cmd_n = I2C_CMD_START;
                end else if (read) begin
                    state_n    = ST_READ;
                    core_cmd_n = I2C_CMD_READ;
                end else if (write) begin
                    state_n    = ST_WRITE;
                    core_cmd_n = I2C_CMD_WRITE;
                end else begin
                    state_n    = ST_STOP;
                    core_cmd_n = I2C_CMD_STOP;
                end
            end
        end

        ST_START: begin
            if (core_ack) begin
                if (read) begin
                    state_n    = ST_READ;
                    core_cmd_n = I2C_CMD_READ;
                end else begin
                    state_n    = ST_WRITE;
                    core_cmd_n = I2C_CMD_WRITE;
                end
            end
        end

        ST_WRITE: begin
            if (core_ack) begin
                if (cnt_done) begin
                    state_n    = ST_ACK;
                    core_cmd_n = I2C_CMD_READ;
                end else begin
                    shift      = 1'b1;
                    state_n    = ST_WRITE;
                    core_cmd_n = I2C_CMD_WRITE;
                end
            end
        end

        ST_READ: begin
            if (core_ack) begin
                shift = 1'b1;
                if (cnt_done) begin
                    state_n    = ST_ACK;
                    core_cmd_n = I2C_CMD_WRITE;
                end else begin
                    state_n    = ST_READ;
                    core_cmd_n = I2C_CMD_READ;
                end
            end
        end

        ST_ACK: begin
            if (core_ack) begin
                if (core_cmd == I2C_CMD_READ)
                    ack_out_n = core_rxd;

                if (stop) begin
                    state_n    = ST_STOP;
                    core_cmd_n = I2C_CMD_STOP;
                end else begin
                    state_n    = ST_IDLE;
                    core_cmd_n = I2C_CMD_NOP;
                    cmd_ack_n  = 1'b1;
                end
            end
        end

        ST_STOP: begin
            if (core_ack) begin
                state_n    = ST_IDLE;
                core_cmd_n = I2C_CMD_NOP;
                cmd_ack_n  = 1'b1;
            end
        end

        default: begin
            state_n    = ST_IDLE;
            core_cmd_n = I2C_CMD_NOP;
        end
    endcase
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        sr   <= 8'h00;
        dcnt <= 3'd0;
    end else if (rst) begin
        sr   <= 8'h00;
        dcnt <= 3'd0;
    end else if (ld) begin
        sr   <= din;
        dcnt <= 3'd7;
    end else if (shift) begin
        sr   <= {sr[6:0], core_rxd};
        dcnt <= dcnt - 3'd1;
    end
end

always @(posedge clk or negedge nReset) begin
    if (!nReset) begin
        c_state  <= ST_IDLE;
        core_cmd <= I2C_CMD_NOP;
        cmd_ack  <= 1'b0;
        ack_out  <= 1'b0;
    end else if (rst | i2c_al) begin
        c_state  <= ST_IDLE;
        core_cmd <= I2C_CMD_NOP;
        cmd_ack  <= 1'b0;
        ack_out  <= 1'b0;
    end else begin
        c_state  <= state_n;
        core_cmd <= core_cmd_n;
        cmd_ack  <= cmd_ack_n;
        ack_out  <= ack_out_n;
    end
end

i2c_master_bit_ctrl bit_controller (
    .clk     (clk),
    .rst     (rst),
    .nReset  (nReset),
    .ena     (ena),
    .clk_cnt (clk_cnt),
    .cmd     (core_cmd),
    .cmd_ack (core_ack),
    .busy    (i2c_busy),
    .al      (i2c_al),
    .din     (core_txd),
    .dout    (core_rxd),
    .scl_i   (scl_i),
    .scl_o   (scl_o),
    .scl_oen (scl_oen),
    .sda_i   (sda_i),
    .sda_o   (sda_o),
    .sda_oen (sda_oen)
);

endmodule