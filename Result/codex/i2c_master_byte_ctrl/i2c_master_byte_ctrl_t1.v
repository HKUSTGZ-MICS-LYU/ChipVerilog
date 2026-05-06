module i2c_master_byte_ctrl (
    clk,
    rst,
    nReset,
    ena,
    clk_cnt,
    start,
    stop,
    read,
    write,
    ack_in,
    din,
    cmd_ack,
    ack_out,
    dout,
    i2c_busy,
    i2c_al,
    scl_i,
    scl_o,
    scl_oen,
    sda_i,
    sda_o,
    sda_oen
);

input         clk;
input         rst;
input         nReset;
input         ena;
input  [15:0] clk_cnt;
input         start;
input         stop;
input         read;
input         write;
input         ack_in;
input   [7:0] din;
input         scl_i;
input         sda_i;

output        cmd_ack;
output        ack_out;
output  [7:0] dout;
output        i2c_busy;
output        i2c_al;
output        scl_o;
output        scl_oen;
output        sda_o;
output        sda_oen;

reg           cmd_ack;
reg           ack_out;
reg     [7:0] sr;
reg     [2:0] dcnt;
reg     [2:0] state;
reg           op_read;

wire          go;
wire          cnt_done;
wire    [3:0] core_cmd;
wire          core_ack;
wire          core_txd;
wire          core_rxd;

localparam [2:0] ST_IDLE  = 3'b000;
localparam [2:0] ST_START = 3'b001;
localparam [2:0] ST_READ  = 3'b010;
localparam [2:0] ST_WRITE = 3'b011;
localparam [2:0] ST_ACK   = 3'b100;
localparam [2:0] ST_STOP  = 3'b101;

localparam [3:0] I2C_CMD_NOP   = 4'b0000;
localparam [3:0] I2C_CMD_START = 4'b0001;
localparam [3:0] I2C_CMD_STOP  = 4'b0010;
localparam [3:0] I2C_CMD_READ  = 4'b0100;
localparam [3:0] I2C_CMD_WRITE = 4'b1000;

assign go       = (read | write | stop) & ~cmd_ack;
assign cnt_done = (dcnt == 3'b000);
assign dout     = sr;
assign core_txd = (state == ST_ACK && op_read) ? ack_in : sr[7];
assign core_cmd = (state == ST_START) ? I2C_CMD_START :
                  (state == ST_READ)  ? I2C_CMD_READ  :
                  (state == ST_WRITE) ? I2C_CMD_WRITE :
                  (state == ST_ACK)   ? (op_read ? I2C_CMD_WRITE : I2C_CMD_READ) :
                  (state == ST_STOP)  ? I2C_CMD_STOP  :
                                        I2C_CMD_NOP;

always @(posedge clk or negedge nReset)
begin
    if (!nReset)
    begin
        sr      <= 8'h00;
        dcnt    <= 3'b000;
        state   <= ST_IDLE;
        op_read <= 1'b0;
        cmd_ack <= 1'b0;
        ack_out <= 1'b0;
    end
    else if (rst || i2c_al)
    begin
        sr      <= 8'h00;
        dcnt    <= 3'b000;
        state   <= ST_IDLE;
        op_read <= 1'b0;
        cmd_ack <= 1'b0;
        ack_out <= 1'b0;
    end
    else
    begin
        cmd_ack <= 1'b0;

        case (state)
            ST_IDLE:
            begin
                if (go)
                begin
                    sr   <= din;
                    dcnt <= 3'b111;

                    if (start)
                    begin
                        state <= ST_START;
                    end
                    else if (read)
                    begin
                        state   <= ST_READ;
                        op_read <= 1'b1;
                    end
                    else if (write)
                    begin
                        state   <= ST_WRITE;
                        op_read <= 1'b0;
                    end
                    else
                    begin
                        state   <= ST_STOP;
                        op_read <= 1'b0;
                    end
                end
            end

            ST_START:
            begin
                if (core_ack)
                begin
                    if (read)
                    begin
                        state   <= ST_READ;
                        op_read <= 1'b1;
                    end
                    else
                    begin
                        state   <= ST_WRITE;
                        op_read <= 1'b0;
                    end
                end
            end

            ST_WRITE:
            begin
                if (core_ack)
                begin
                    if (cnt_done)
                    begin
                        state <= ST_ACK;
                    end
                    else
                    begin
                        sr   <= {sr[6:0], core_rxd};
                        dcnt <= dcnt - 3'b001;
                    end
                end
            end

            ST_READ:
            begin
                if (core_ack)
                begin
                    sr   <= {sr[6:0], core_rxd};
                    dcnt <= dcnt - 3'b001;

                    if (cnt_done)
                        state <= ST_ACK;
                end
            end

            ST_ACK:
            begin
                if (core_ack)
                begin
                    if (!op_read)
                        ack_out <= core_rxd;

                    if (stop)
                    begin
                        state <= ST_STOP;
                    end
                    else
                    begin
                        state   <= ST_IDLE;
                        op_read <= 1'b0;
                        cmd_ack <= 1'b1;
                    end
                end
            end

            ST_STOP:
            begin
                if (core_ack)
                begin
                    state   <= ST_IDLE;
                    op_read <= 1'b0;
                    cmd_ack <= 1'b1;
                end
            end

            default:
            begin
                state   <= ST_IDLE;
                op_read <= 1'b0;
            end
        endcase
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
