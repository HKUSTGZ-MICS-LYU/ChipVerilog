`timescale 1ns/1ps
module fpu (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [2:0] fpu_op,
    input [63:0] opa,
    input [63:0] opb,
    output reg [63:0] out,
    output reg ready,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg exception,
    output reg invalid
);
    reg [63:0] opa_reg, opb_reg;
    reg [2:0] fpu_op_reg;
    reg [1:0] rmode_reg;
    reg [6:0] count_cycles, count_ready;
    reg busy;

    wire route_add = ((fpu_op_reg == 3'b000) && !(opa_reg[63]^opb_reg[63])) ||
                     ((fpu_op_reg == 3'b001) &&  (opa_reg[63]^opb_reg[63]));
    wire route_sub = ((fpu_op_reg == 3'b000) &&  (opa_reg[63]^opb_reg[63])) ||
                     ((fpu_op_reg == 3'b001) && !(opa_reg[63]^opb_reg[63]));
    wire add_en = busy & route_add;
    wire sub_en = busy & route_sub;
    wire mul_en = busy & (fpu_op_reg == 3'b010);
    wire div_en = busy & (fpu_op_reg == 3'b011);

    wire add_sign, sub_sign, mul_sign, div_sign;
    wire [55:0] add_mant, sub_mant, mul_mant, div_mant;
    wire [10:0] add_exp, sub_exp;
    wire [11:0] mul_exp, div_exp;

    fpu_add u_add(.clk(clk),.rst(rst),.enable(add_en),.opa(opa_reg),.opb(opb_reg),.sign(add_sign),.sum_2(add_mant),.exponent_2(add_exp));
    fpu_sub u_sub(.clk(clk),.rst(rst),.enable(sub_en),.opa(opa_reg),.opb(opb_reg),.fpu_op(fpu_op_reg),.sign(sub_sign),.diff_2(sub_mant),.exponent_2(sub_exp));
    fpu_mul u_mul(.clk(clk),.rst(rst),.enable(mul_en),.opa(opa_reg),.opb(opb_reg),.sign(mul_sign),.product_7(mul_mant),.exponent_5(mul_exp));
    fpu_div u_div(.clk(clk),.rst(rst),.enable(div_en),.opa(opa_reg),.opb(opb_reg),.sign(div_sign),.mantissa_7(div_mant),.exponent_out(div_exp));

    reg sel_sign;
    reg [55:0] sel_mant;
    reg [11:0] sel_exp;
    always @* begin
        sel_sign = 1'b0; sel_mant = 56'd0; sel_exp = 12'd0;
        case (fpu_op_reg)
            3'b000,3'b001: begin
                if (route_add) begin sel_sign = add_sign; sel_mant = add_mant; sel_exp = {1'b0, add_exp}; end
                else begin sel_sign = sub_sign; sel_mant = sub_mant; sel_exp = {1'b0, sub_exp}; end
            end
            3'b010: begin sel_sign = mul_sign; sel_mant = mul_mant; sel_exp = mul_exp; end
            3'b011: begin sel_sign = div_sign; sel_mant = div_mant; sel_exp = div_exp; end
            default: begin sel_sign = 1'b0; sel_mant = 56'd0; sel_exp = 12'd0; end
        endcase
    end

    wire [63:0] round_out;
    wire [11:0] round_exp;
    fpu_round u_round(.clk(clk),.rst(rst),.enable(busy),.round_mode(rmode_reg),.sign_term(sel_sign),.mantissa_term(sel_mant),.exponent_term(sel_exp),.round_out(round_out),.exponent_final(round_exp));

    wire [63:0] ex_out;
    wire ex_en, uf0, of0, ix0, exc0, inv0;
    fpu_exceptions u_ex(.clk(clk),.rst(rst),.enable(busy),.rmode(rmode_reg),.opa(opa_reg),.opb(opb_reg),.in_except(round_out),.exponent_in(round_exp),.mantissa_in(sel_mant[1:0]),.fpu_op(fpu_op_reg),.out(ex_out),.ex_enable(ex_en),.underflow(uf0),.overflow(of0),.inexact(ix0),.exception(exc0),.invalid(inv0));

    always @(posedge clk) begin
        if (rst) begin
            opa_reg <= 0; opb_reg <= 0; fpu_op_reg <= 0; rmode_reg <= 0; count_cycles <= 0; count_ready <= 0; busy <= 0;
            out <= 0; ready <= 0; underflow <= 0; overflow <= 0; inexact <= 0; exception <= 0; invalid <= 0;
        end else begin
            ready <= 1'b0;
            if (enable && !busy) begin
                opa_reg <= opa; opb_reg <= opb; fpu_op_reg <= fpu_op; rmode_reg <= rmode;
                count_cycles <= 0; busy <= 1'b1;
                case (fpu_op)
                    3'b000: count_ready <= 7'd20;
                    3'b001: count_ready <= 7'd21;
                    3'b010: count_ready <= 7'd24;
                    3'b011: count_ready <= 7'd71;
                    default: count_ready <= 7'd2;
                endcase
            end else if (busy) begin
                count_cycles <= count_cycles + 7'd1;
                if (count_cycles >= count_ready) begin
                    busy <= 1'b0;
                    ready <= 1'b1;
                    out <= ex_en ? ex_out : round_out;
                    underflow <= uf0; overflow <= of0; inexact <= ix0; exception <= exc0; invalid <= inv0;
                end
            end
        end
    end
endmodule
