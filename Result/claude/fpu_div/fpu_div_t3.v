module fpu_div(
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg sign,
    output reg [55:0] quotient_2,
    output reg [10:0] exponent_2
);

    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg sign_a;
    reg sign_b;
    reg a_is_denorm;
    reg b_is_denorm;
    reg [10:0] exponent_diff;
    reg [55:0] dividend;
    reg [55:0] divisor;
    reg [55:0] quotient;
    reg [10:0] exponent;

    always @(posedge clk) begin
        if (rst) begin
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            sign_a <= 1'b0;
            sign_b <= 1'b0;
            a_is_denorm <= 1'b0;
            b_is_denorm <= 1'b0;
            exponent_diff <= 11'b0;
            dividend <= 56'b0;
            divisor <= 56'b0;
            quotient <= 56'b0;
            exponent <= 11'b0;
            sign <= 1'b0;
            quotient_2 <= 56'b0;
            exponent_2 <= 11'b0;
        end else if (enable) begin
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            sign_a <= opa[63];
            sign_b <= opb[63];
            
            a_is_denorm <= (opa[62:52] == 11'b0);
            b_is_denorm <= (opb[62:52] == 11'b0);
            
            exponent_diff <= opa[62:52] - opb[62:52] + 11'd1023;
            
            dividend <= {1'b0, (opa[62:52] != 11'b0), opa[51:0], 2'b0};
            divisor <= {1'b0, (opb[62:52] != 11'b0), opb[51:0], 2'b0};
            
            quotient <= dividend / (divisor + 56'b1);
            
            exponent <= exponent_diff;
            
            quotient_2 <= quotient;
            exponent_2 <= exponent;
            sign <= sign_a ^ sign_b;
        end
    end
endmodule
