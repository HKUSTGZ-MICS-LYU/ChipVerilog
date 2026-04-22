`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_mult_mac_gen_from_original_desc(
        // Clock and reset
        clk, rst,

        // Multiplier/MAC interface
        ex_freeze, id_macrc_op, macrc_op, a, b, mac_op, alu_op, result, mac_stall_r,

        // SPR interface
        spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o
);

input                   clk;
input                   rst;

// Multiplier/MAC interface
input                   ex_freeze;
input                   id_macrc_op;
input                   macrc_op;
input   [31:0]          a;
input   [31:0]          b;
input   [1:0]           mac_op;
input   [3:0]           alu_op;
output  [31:0]          result;
output                  mac_stall_r;

// SPR interface
input                   spr_cs;
input                   spr_write;
input   [31:0]          spr_addr;
input   [31:0]          spr_dat_i;
output  [31:0]          spr_dat_o;

reg     [31:0]          result;
reg                     mac_stall_r;
reg     [63:0]          mac_r;
reg     [1:0]           mac_op_r1;
reg     [1:0]           mac_op_r2;
reg     [1:0]           mac_op_r3;

wire    [63:0]          mul_prod;
wire    [31:0]          div_result;
wire                    spr_maclo_we;
wire                    spr_machi_we;
wire                    alu_op_mul;
wire                    alu_op_div;
wire                    alu_op_divu;

assign alu_op_mul  = (alu_op == `OR1200_ALUOP_MUL);
assign alu_op_div  = (alu_op == `OR1200_ALUOP_DIV);
assign alu_op_divu = (alu_op == `OR1200_ALUOP_DIVU);

assign mul_prod = $signed(a) * $signed(b);

`ifdef OR1200_IMPL_DIV
assign div_result = alu_op_div  ? ($signed(b) != 0 ? $signed(a) / $signed(b) : 32'h0) :
                    alu_op_divu ? (b != 0 ? a / b : 32'h0) :
                    32'h0;
`else
assign div_result = 32'h0;
`endif

`ifdef OR1200_MAC_IMPLEMENTED
assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];
assign spr_dat_o    = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
`else
assign spr_maclo_we = 1'b0;
assign spr_machi_we = 1'b0;
assign spr_dat_o    = 32'h0000_0000;
`endif

// result selection
always @(*) begin
    if (alu_op_div || alu_op_divu)
        result = div_result;
    else if (alu_op_mul)
        result = mul_prod[31:0];
    else
        result = mac_r[31:0];
end

`ifdef OR1200_MAC_IMPLEMENTED
// pipeline MAC opcode
always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r1 <= 2'b00;
    else
        mac_op_r1 <= mac_op;

always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r2 <= 2'b00;
    else
        mac_op_r2 <= mac_op_r1;

always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r3 <= 2'b00;
    else
        mac_op_r3 <= mac_op_r2;

// MAC accumulator
always @(posedge clk or posedge rst)
    if (rst)
        mac_r <= 64'h0000_0000_0000_0000;
    else if (mac_op_r3 == `OR1200_MACOP_MAC)
        mac_r <= mac_r + mul_prod;
    else if (mac_op_r3 == `OR1200_MACOP_MSB)
        mac_r <= mac_r - mul_prod;
    else if (spr_maclo_we)
        mac_r[31:0] <= spr_dat_i;
    else if (spr_machi_we)
        mac_r[63:32] <= spr_dat_i;
    else if (macrc_op & !ex_freeze)
        mac_r <= 64'h0000_0000_0000_0000;

// simplified stall
always @(posedge clk or posedge rst)
    if (rst)
        mac_stall_r <= 1'b0;
    else
        mac_stall_r <= (id_macrc_op & (|mac_op | |mac_op_r1 | |mac_op_r2));
`else
always @(*) begin
    mac_stall_r = 1'b0;
end
`endif

endmodule
