`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_mult_mac_gen_from_fixed_desc(
        // Clock and reset
        clk, rst,

        // Multiplier/MAC interface
        ex_freeze, id_macrc_op, macrc_op, a, b, mac_op, alu_op, result, mac_stall_r,

        // SPR interface
        spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o
);

input                           clk;
input                           rst;

// Multiplier/MAC interface
input                           ex_freeze;
input                           id_macrc_op;
input                           macrc_op;
input   [31:0]                  a;
input   [31:0]                  b;
input   [1:0]                   mac_op;
input   [3:0]                   alu_op;
output  [31:0]                  result;
output                          mac_stall_r;

// SPR interface
input                           spr_cs;
input                           spr_write;
input   [31:0]                  spr_addr;
input   [31:0]                  spr_dat_i;
output  [31:0]                  spr_dat_o;

`ifdef OR1200_MULT_IMPLEMENTED
reg     [31:0]                  result;
reg     [63:0]                  mul_prod_r;
`else
wire    [31:0]                  result;
wire    [63:0]                  mul_prod_r;
`endif

wire    [63:0]                  mul_prod;

`ifdef OR1200_MAC_IMPLEMENTED
reg     [1:0]                   mac_op_r1;
reg     [1:0]                   mac_op_r2;
reg     [1:0]                   mac_op_r3;
reg                             mac_stall_r;
reg     [63:0]                  mac_r;
`else
wire    [1:0]                   mac_op_r1;
wire    [1:0]                   mac_op_r2;
wire    [1:0]                   mac_op_r3;
wire                            mac_stall_r;
wire    [63:0]                  mac_r;
`endif

wire    [31:0]                  x;
wire    [31:0]                  y;
wire                            spr_maclo_we;
wire                            spr_machi_we;
wire                            alu_op_div_divu;
wire                            alu_op_div;
reg                             div_free;

`ifdef OR1200_IMPL_DIV
wire    [31:0]                  div_tmp;
reg     [5:0]                   div_cntr;
`endif

//
// SPR / accumulator access
//
`ifdef OR1200_MAC_IMPLEMENTED
assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];
assign spr_dat_o    = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
`else
assign spr_maclo_we = 1'b0;
assign spr_machi_we = 1'b0;
assign spr_dat_o    = 32'h0000_0000;
`endif

//
// Operand preprocess
//
`ifdef OR1200_LOWPWR_MULT
assign x = (alu_op_div & a[31]) ? (~a + 32'b1) :
           (alu_op_div_divu | (alu_op == `OR1200_ALUOP_MUL) | (|mac_op)) ? a : 32'h0000_0000;

assign y = (alu_op_div & b[31]) ? (~b + 32'b1) :
           (alu_op_div_divu | (alu_op == `OR1200_ALUOP_MUL) | (|mac_op)) ? b : 32'h0000_0000;
`else
assign x = (alu_op_div & a[31]) ? (~a + 32'b1) : a;
assign y = (alu_op_div & b[31]) ? (~b + 32'b1) : b;
`endif

`ifdef OR1200_IMPL_DIV
assign alu_op_div       = (alu_op == `OR1200_ALUOP_DIV);
assign alu_op_div_divu  = alu_op_div | (alu_op == `OR1200_ALUOP_DIVU);
assign div_tmp          = mul_prod_r[63:32] - y;
`else
assign alu_op_div       = 1'b0;
assign alu_op_div_divu  = 1'b0;
`endif

`ifdef OR1200_MULT_IMPLEMENTED

//
// Result selection
//
always @(*) begin
    casex (alu_op)
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV:
            result = a[31] ^ b[31] ? (~mul_prod_r[31:0] + 32'b1) : mul_prod_r[31:0];
        `OR1200_ALUOP_DIVU:
            result = mul_prod_r[31:0];
`endif
        `OR1200_ALUOP_MUL:
            result = mul_prod_r[31:0];
        default:
            result = mac_r[31:0];
    endcase
end

//
// Multiplier instance
//
`ifdef OR1200_ASIC_MULTP2_32X32
or1200_amultp2_32x32 u_mult (
        .X   (x),
        .Y   (y),
        .RST (rst),
        .CLK (clk),
        .P   (mul_prod)
);
`else
or1200_gmultp2_32x32 u_mult (
        .X   (x),
        .Y   (y),
        .RST (rst),
        .CLK (clk),
        .P   (mul_prod)
);
`endif

//
// Shared mul/div working register
//
always @(posedge rst or posedge clk)
    if (rst) begin
        mul_prod_r <= 64'h0000_0000_0000_0000;
        div_free   <= 1'b1;
`ifdef OR1200_IMPL_DIV
        div_cntr   <= 6'b00_0000;
`endif
    end
`ifdef OR1200_IMPL_DIV
    else if (|div_cntr) begin
        if (div_tmp[31])
            mul_prod_r <= {mul_prod_r[62:0], 1'b0};
        else
            mul_prod_r <= {div_tmp[30:0], mul_prod_r[31:0], 1'b1};
        div_cntr <= div_cntr - 6'd1;
    end
    else if (alu_op_div_divu && div_free) begin
        mul_prod_r <= {31'b0, x[31:0], 1'b0};
        div_cntr   <= 6'b10_0000;
        div_free   <= 1'b0;
    end
`endif
    else if (div_free | !ex_freeze) begin
        mul_prod_r <= mul_prod[63:0];
        div_free   <= 1'b1;
    end

`else
assign result     = {`OR1200_OPERAND_WIDTH{1'b0}};
assign mul_prod   = {2*`OR1200_OPERAND_WIDTH{1'b0}};
assign mul_prod_r = {2*`OR1200_OPERAND_WIDTH{1'b0}};
`endif

`ifdef OR1200_MAC_IMPLEMENTED

//
// MAC op pipeline
//
always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r1 <= `OR1200_MACOP_WIDTH'b0;
    else
        mac_op_r1 <= mac_op;

always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r2 <= `OR1200_MACOP_WIDTH'b0;
    else
        mac_op_r2 <= mac_op_r1;

always @(posedge clk or posedge rst)
    if (rst)
        mac_op_r3 <= `OR1200_MACOP_WIDTH'b0;
    else
        mac_op_r3 <= mac_op_r2;

//
// MAC accumulator
// SPR writes have priority over accumulate/subtract.
//
always @(posedge rst or posedge clk)
    if (rst)
        mac_r <= 64'h0000_0000_0000_0000;
`ifdef OR1200_MAC_SPR_WE
    else if (spr_maclo_we)
        mac_r[31:0] <= spr_dat_i;
    else if (spr_machi_we)
        mac_r[63:32] <= spr_dat_i;
`endif
    else if (mac_op_r3 == `OR1200_MACOP_MAC)
        mac_r <= mac_r + mul_prod_r;
    else if (mac_op_r3 == `OR1200_MACOP_MSB)
        mac_r <= mac_r - mul_prod_r;
    else if (macrc_op & !ex_freeze)
        mac_r <= 64'h0000_0000_0000_0000;

//
// Stall generation
//
always @(posedge rst or posedge clk)
    if (rst)
        mac_stall_r <= 1'b0;
    else
        mac_stall_r <= ((|mac_op) | (((|mac_op_r1) | (|mac_op_r2)) & id_macrc_op)
`ifdef OR1200_IMPL_DIV
                        | (|div_cntr)
`endif
                        );

`else
assign mac_stall_r = 1'b0;
assign mac_r       = {2*`OR1200_OPERAND_WIDTH{1'b0}};
assign mac_op_r1   = `OR1200_MACOP_WIDTH'b0;
assign mac_op_r2   = `OR1200_MACOP_WIDTH'b0;
assign mac_op_r3   = `OR1200_MACOP_WIDTH'b0;
`endif

endmodule
