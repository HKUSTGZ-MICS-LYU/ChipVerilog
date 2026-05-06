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
    reg [2:0] op_reg;
    reg [1:0] rmode_reg;
    reg [6:0] cnt, target;
    reg busy;
    wire add_en = busy && (((op_reg == 3'b000) && !(opa_reg[63]^opb_reg[63])) || ((op_reg == 3'b001) && (opa_reg[63]^opb_reg[63])));
    wire sub_en = busy && (((op_reg == 3'b000) &&  (opa_reg[63]^opb_reg[63])) || ((op_reg == 3'b001) && !(opa_reg[63]^opb_reg[63])));
    wire mul_en = busy && (op_reg == 3'b010);
    wire div_en = busy && (op_reg == 3'b011);
    wire add_s, sub_s, mul_s, div_s;
    wire [55:0] add_m, sub_m, mul_m, div_m;
    wire [10:0] add_e, sub_e;
    wire [11:0] mul_e, div_e;
    reg sel_s; reg [55:0] sel_m; reg [11:0] sel_e;
    wire [63:0] rnd; wire [11:0] rnd_e;
    wire [63:0] ex_o; wire ex_en, uf, of, ix, exc, inv;
    fpu_add u_add(clk,rst,add_en,opa_reg,opb_reg,add_s,add_m,add_e);
    fpu_sub u_sub(clk,rst,sub_en,opa_reg,opb_reg,op_reg,sub_s,sub_m,sub_e);
    fpu_mul u_mul(clk,rst,mul_en,opa_reg,opb_reg,mul_s,mul_m,mul_e);
    fpu_div u_div(clk,rst,div_en,opa_reg,opb_reg,div_s,div_m,div_e);
    fpu_round u_round(clk,rst,1'b1,rmode_reg,sel_s,sel_m,sel_e,rnd,rnd_e);
    fpu_exceptions u_exc(clk,rst,1'b1,rmode_reg,opa_reg,opb_reg,rnd,rnd_e,sel_m[1:0],op_reg,ex_o,ex_en,uf,of,ix,exc,inv);
    always @(*) begin
        case (op_reg)
            3'b000: begin if (opa_reg[63]^opb_reg[63]) begin sel_s=sub_s; sel_m=sub_m; sel_e={1'b0,sub_e}; end else begin sel_s=add_s; sel_m=add_m; sel_e={1'b0,add_e}; end end
            3'b001: begin if (opa_reg[63]^opb_reg[63]) begin sel_s=add_s; sel_m=add_m; sel_e={1'b0,add_e}; end else begin sel_s=sub_s; sel_m=sub_m; sel_e={1'b0,sub_e}; end end
            3'b010: begin sel_s=mul_s; sel_m=mul_m; sel_e=mul_e; end
            3'b011: begin sel_s=div_s; sel_m=div_m; sel_e=div_e; end
            default: begin sel_s=0; sel_m=0; sel_e=0; end
        endcase
    end
    always @(*) begin
        case (op_reg)
            3'b000: target = 7'd20;
            3'b001: target = 7'd21;
            3'b010: target = 7'd24;
            3'b011: target = 7'd71;
            default: target = 7'd2;
        endcase
    end
    always @(posedge clk) begin
        if (rst) begin
            opa_reg <= 0; opb_reg <= 0; op_reg <= 0; rmode_reg <= 0; cnt <= 0; busy <= 0; ready <= 0; out <= 0;
            underflow <= 0; overflow <= 0; inexact <= 0; exception <= 0; invalid <= 0;
        end else begin
            ready <= 0;
            if (enable && !busy) begin
                opa_reg <= opa; opb_reg <= opb; op_reg <= fpu_op; rmode_reg <= rmode; cnt <= 0; busy <= 1;
            end else if (busy) begin
                cnt <= cnt + 1'b1;
                if (cnt >= target) begin
                    busy <= 0; ready <= 1; out <= ex_en ? ex_o : rnd;
                    underflow <= uf; overflow <= of; inexact <= ix; exception <= exc; invalid <= inv;
                end
            end
        end
    end
endmodule
