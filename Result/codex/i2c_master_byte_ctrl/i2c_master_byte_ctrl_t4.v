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

parameter [2:0] ST_IDLE  = 3'b000;
parameter [2:0] ST_START = 3'b001;
parameter [2:0] ST_READ  = 3'b010;
parameter [2:0] ST_WRITE = 3'b011;
parameter [2:0] ST_ACK   = 3'b100;
parameter [2:0] ST_STOP  = 3'b101;

parameter [3:0] I2C_CMD_NOP   = 4'b0000;
parameter [3:0] I2C_CMD_START = 4'b0001;
parameter [3:0] I2C_CMD_STOP  = 4'b0010;
parameter [3:0] I2C_CMD_READ  = 4'b0100;
parameter [3:0] I2C_CMD_WRITE = 4'b1000;

reg  [7:0] sr;
reg  [2:0] dcnt;
reg  [2:0] c_state;
reg  [3:0] core_cmd;
reg        core_txd;
reg        shift;
reg        ld;
reg        cmd_ack;
reg        ack_out;
wire       core_ack;
wire       core_rxd;
wire       go;
wire       cnt_done;

assign dout     = sr;
assign go       = (read | write | stop) & ~cmd_ack;
assign cnt_done = (dcnt == 3'b000);

always @(posedge clk or negedge nReset)
  if (!nReset)
    sr <= 8'h00;
  else if (rst)
    sr <= 8'h00;
  else if (ld)
    sr <= din;
  else if (shift)
    sr <= {sr[6:0], core_rxd};

always @(posedge clk or negedge nReset)
  if (!nReset)
    dcnt <= 3'b000;
  else if (rst)
    dcnt <= 3'b000;
  else if (ld)
    dcnt <= 3'b111;
  else if (shift)
    dcnt <= dcnt - 3'b001;

always @(posedge clk or negedge nReset)
begin
  if (!nReset)
  begin
    c_state <= ST_IDLE;
    core_cmd <= I2C_CMD_NOP;
    core_txd <= 1'b0;
    shift <= 1'b0;
    ld <= 1'b0;
    cmd_ack <= 1'b0;
    ack_out <= 1'b0;
  end
  else if (rst | i2c_al)
  begin
    c_state <= ST_IDLE;
    core_cmd <= I2C_CMD_NOP;
    core_txd <= 1'b0;
    shift <= 1'b0;
    ld <= 1'b0;
    cmd_ack <= 1'b0;
    ack_out <= 1'b0;
  end
  else
  begin
    shift <= 1'b0;
    ld <= 1'b0;
    cmd_ack <= 1'b0;
    core_txd <= sr[7];

    case (c_state)
      ST_IDLE:
        if (go)
        begin
          ld <= 1'b1;
          if (start)
          begin
            c_state <= ST_START;
            core_cmd <= I2C_CMD_START;
          end
          else if (read)
          begin
            c_state <= ST_READ;
            core_cmd <= I2C_CMD_READ;
          end
          else if (write)
          begin
            c_state <= ST_WRITE;
            core_cmd <= I2C_CMD_WRITE;
          end
          else
          begin
            c_state <= ST_STOP;
            core_cmd <= I2C_CMD_STOP;
          end
        end

      ST_START:
        if (core_ack)
          if (read)
          begin
            c_state <= ST_READ;
            core_cmd <= I2C_CMD_READ;
          end
          else
          begin
            c_state <= ST_WRITE;
            core_cmd <= I2C_CMD_WRITE;
          end

      ST_WRITE:
        if (core_ack)
          if (cnt_done)
          begin
            c_state <= ST_ACK;
            core_cmd <= I2C_CMD_READ;
          end
          else
            shift <= 1'b1;

      ST_READ:
        if (core_ack)
        begin
          shift <= 1'b1;
          if (cnt_done)
          begin
            c_state <= ST_ACK;
            core_cmd <= I2C_CMD_WRITE;
            core_txd <= ack_in;
          end
        end

      ST_ACK:
        if (core_ack)
        begin
          if (core_cmd == I2C_CMD_READ)
            ack_out <= core_rxd;

          if (stop)
          begin
            c_state <= ST_STOP;
            core_cmd <= I2C_CMD_STOP;
          end
          else
          begin
            c_state <= ST_IDLE;
            core_cmd <= I2C_CMD_NOP;
            cmd_ack <= 1'b1;
          end
        end
        else if (core_cmd == I2C_CMD_WRITE)
          core_txd <= ack_in;

      ST_STOP:
        if (core_ack)
        begin
          c_state <= ST_IDLE;
          core_cmd <= I2C_CMD_NOP;
          cmd_ack <= 1'b1;
        end

      default:
      begin
        c_state <= ST_IDLE;
        core_cmd <= I2C_CMD_NOP;
      end
    endcase
  end
end

i2c_master_bit_ctrl bit_controller (
    clk,
    rst,
    nReset,
    ena,
    clk_cnt,
    core_cmd,
    core_ack,
    i2c_busy,
    i2c_al,
    core_txd,
    core_rxd,
    scl_i,
    scl_o,
    scl_oen,
    sda_i,
    sda_o,
    sda_oen
);

endmodule
