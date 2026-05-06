`timescale 1ns / 1ps

module fpu_round(
    input clk,
    input rst,
    input enable,
    input sign,
    input [55:0] mantissa_term,
    input [10:0] exponent_term,
    output reg [63:0] result
);

    reg [10:0] exponent;
    reg [55:0] mantissa;
    reg result_sign;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent <= 11'b0;
            mantissa <= 56'b0;
            result_sign <= 1'b0;
            result <= 64'b0;
        end else if (enable) begin
            exponent <= exponent_term;
            mantissa <= mantissa_term;
            result_sign <= sign;
            
            result <= {result_sign, exponent, mantissa[51:0]};
        end
    end

endmodule
