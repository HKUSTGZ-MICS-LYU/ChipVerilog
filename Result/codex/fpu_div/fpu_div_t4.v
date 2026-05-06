`timescale 1ns/1ps
module fpu_div (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output sign,
    output reg [55:0] mantissa_7,
    output reg [11:0] exponent_out
);
    assign sign = opa[63] ^ opb[63];
    reg [52:0] sa, sb;
    reg [11:0] exp;
    reg [109:0] num;
    reg [56:0] q;
    reg [52:0] r;
    reg [55:0] mant;
    reg zero;
    always @(*) begin
        zero = (opa[62:0] == 0) || (opb[62:0] == 0);
        sa = {|opa[62:52], opa[51:0]};
        sb = {|opb[62:52], opb[51:0]};
        exp = {1'b0,opa[62:52]} + 12'd1023 - {1'b0,opb[62:52]};
        num = {57'd0, sa} << 54;
        q = (sb == 0) ? 57'd0 : (num / sb);
        r = (sb == 0) ? 53'd0 : (num % sb);
        if (zero) begin exp = 0; mant = 0; end
        else if (q[54]) begin
            mant = {1'b0, 1'b1, q[53:2], q[1], q[0] | (|r)};
        end else begin
            exp = exp - 12'd1;
            q = q << 1;
            mant = {1'b0, 1'b1, q[53:2], q[1], q[0] | (|r)};
        end
    end
    always @(posedge clk) begin
        if (rst) begin mantissa_7 <= 0; exponent_out <= 0; end
        else if (enable) begin mantissa_7 <= mant; exponent_out <= exp; end
    end
endmodule
