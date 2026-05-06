// FPU Division Module for Double-Precision Operands
// Implements iterative long-division quotient generation

module fpu_div(clk, rst, enable, opa, opb, sign, mantissa_7, exponent_out);
    input clk;
    input rst;
    input enable;
    input [63:0] opa;
    input [63:0] opb;
    output reg sign;
    output reg [55:0] mantissa_7;
    output reg [10:0] exponent_out;
    
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg sign_a;
    reg [55:0] dividend, divisor;
    reg [55:0] quotient;
    reg [10:0] exponent_result;
    integer shift_count;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            sign_a <= 1'b0;
            dividend <= 56'b0;
            divisor <= 56'b0;
            quotient <= 56'b0;
            exponent_result <= 11'b0;
            shift_count <= 0;
            mantissa_7 <= 56'b0;
            exponent_out <= 11'b0;
            sign <= 1'b0;
        end else if (enable) begin
            // Extract fields
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            sign_a <= opa[63];
            
            // Prepare normalized dividend and divisor
            dividend <= {(exponent_a != 11'b0), mantissa_a, 3'b0};
            divisor <= {(exponent_b != 11'b0), mantissa_b, 3'b0};
            
            // Compute exponent
            exponent_result <= exponent_a - exponent_b + 11'd1023;
            
            // Simple iterative division (generates bits sequentially)
            quotient <= dividend / (divisor + 56'b1);
            
            // Output
            mantissa_7 <= quotient;
            exponent_out <= exponent_result;
            sign <= sign_a ^ opb[63];
        end
    end
endmodule
