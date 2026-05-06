`include "or1200_defines.v"

module or1200_mult_mac(
    input               clk,
    input               rst,
    input               ex_freeze,
    input               id_macrc_op,
    input               macrc_op,
    input  [31:0]       a,
    input  [31:0]       b,
    input  [1:0]        mac_op,
    input  [3:0]        alu_op,
    output [31:0]       result,
    output              mac_stall_r,
    input               spr_cs,
    input               spr_write,
    input  [31:0]       spr_addr,
    input  [31:0]       spr_dat_i,
    output [31:0]       spr_dat_o
);

reg [63:0] mul_prod_r;
reg [63:0] mac_r;
reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
reg div_free;
reg [5:0] div_cntr;
reg [31:0] div_quot_r;
wire signed [31:0] a_s = a;
wire signed [31:0] b_s = b;
wire [63:0] mul_prod = $signed(a_s) * $signed(b_s);
wire [63:0] umul_prod = a * b;
wire div_start = ((alu_op == `OR1200_ALUOP_DIV) || (alu_op == `OR1200_ALUOP_DIVU)) && div_free && !ex_freeze;
wire div_busy = !div_free;
wire [31:0] div_quot = (alu_op == `OR1200_ALUOP_DIV) ? ((b != 0) ? ($signed(a_s) / $signed(b_s)) : 32'b0)
                                                     : ((b != 0) ? (a / b) : 32'b0);
wire spr_mac_hi = spr_addr[`OR1200_MAC_ADDR] == 1'b0;
wire spr_mac_lo = spr_addr[`OR1200_MAC_ADDR] == 1'b1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
        mac_r <= 64'b0;
        mac_op_r1 <= `OR1200_MACOP_NOP;
        mac_op_r2 <= `OR1200_MACOP_NOP;
        mac_op_r3 <= `OR1200_MACOP_NOP;
        div_free <= 1'b1;
        div_cntr <= 6'd0;
        div_quot_r <= 32'b0;
    end else begin
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;

        if (div_busy) begin
            if (div_cntr != 0)
                div_cntr <= div_cntr - 1'b1;
            else
                div_free <= 1'b1;
        end else if (div_start) begin
            div_free <= 1'b0;
            div_cntr <= 6'd32;
            div_quot_r <= div_quot;
        end else if (!ex_freeze) begin
            mul_prod_r <= ((alu_op == `OR1200_ALUOP_MUL) ? mul_prod : umul_prod);
        end

        if (spr_cs && spr_write && spr_mac_hi)
            mac_r[63:32] <= spr_dat_i;
        else if (spr_cs && spr_write && spr_mac_lo)
            mac_r[31:0] <= spr_dat_i;
        else if (mac_op_r3 == `OR1200_MACOP_MAC)
            mac_r <= mac_r + mul_prod_r;
        else if (mac_op_r3 == `OR1200_MACOP_MSB)
            mac_r <= mac_r - mul_prod_r;
    end
end

assign result = ((alu_op == `OR1200_ALUOP_DIV) || (alu_op == `OR1200_ALUOP_DIVU)) ? div_quot_r :
                (alu_op == `OR1200_ALUOP_MUL) ? mul_prod_r[31:0] :
                mac_r[`OR1200_MAC_SHIFTBY + 31:`OR1200_MAC_SHIFTBY];
assign spr_dat_o = spr_mac_hi ? mac_r[63:32] : mac_r[31:0];
assign mac_stall_r = div_busy | id_macrc_op | macrc_op | (mac_op_r1 != `OR1200_MACOP_NOP) |
                     (mac_op_r2 != `OR1200_MACOP_NOP) | (mac_op_r3 != `OR1200_MACOP_NOP);

endmodule
