module fpu_mul(
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg sign,
    output reg [55:0] product_7,
    output reg [11:0] exponent_5
);

    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg a_is_norm;
    reg b_is_norm;
    reg a_is_zero;
    reg b_is_zero;
    reg [11:0] exponent_1;
    reg [11:0] exponent_2;
    reg [11:0] exponent_3;
    reg [11:0] exponent_4;
    reg [105:0] product;
    reg [105:0] product_1;
    reg [105:0] product_2;
    reg [105:0] product_3;
    reg [105:0] product_4;
    reg [105:0] product_5;
    reg [105:0] product_6;
    reg product_lsb;
    reg [52:0] mul_a;
    reg [52:0] mul_b;

    wire [10:0] exp_a = opa[62:52];
    wire [10:0] exp_b = opb[62:52];
    wire [51:0] mant_a = opa[51:0];
    wire [51:0] mant_b = opb[51:0];
    
    wire a_normalized = |exp_a;
    wire b_normalized = |exp_b;
    wire a_zero = !(|opa[62:0]);
    wire b_zero = !(|opb[62:0]);
    
    wire [11:0] exp_a_ext = {1'b0, exp_a};
    wire [11:0] exp_b_ext = {1'b0, exp_b};
    wire [11:0] exp_sum = exp_a_ext + exp_b_ext;
    wire [11:0] exp_adjust = a_normalized && b_normalized ? (exp_sum - 12'd1023) : 12'd0;

    always @(posedge clk) begin
        if (rst) begin
            sign <= 0;
            product_7 <= 0;
            exponent_5 <= 0;
            mantissa_a <= 0;
            mantissa_b <= 0;
            exponent_a <= 0;
            exponent_b <= 0;
            a_is_norm <= 0;
            b_is_norm <= 0;
            a_is_zero <= 0;
            b_is_zero <= 0;
            exponent_1 <= 0;
            exponent_2 <= 0;
            exponent_3 <= 0;
            exponent_4 <= 0;
            product <= 0;
            product_1 <= 0;
            product_2 <= 0;
            product_3 <= 0;
            product_4 <= 0;
            product_5 <= 0;
            product_6 <= 0;
            product_lsb <= 0;
            mul_a <= 0;
            mul_b <= 0;
        end else if (enable) begin
            sign <= opa[63] ^ opb[63];
            
            mantissa_a <= mant_a;
            mantissa_b <= mant_b;
            exponent_a <= exp_a;
            exponent_b <= exp_b;
            
            a_is_norm <= a_normalized;
            b_is_norm <= b_normalized;
            a_is_zero <= a_zero;
            b_is_zero <= b_zero;
            
            mul_a <= a_normalized ? {1'b1, mant_a} : {1'b0, mant_a};
            mul_b <= b_normalized ? {1'b1, mant_b} : {1'b0, mant_b};
            
            exponent_1 <= exp_adjust;
            exponent_2 <= exponent_1;
            exponent_3 <= exponent_2;
            exponent_4 <= exponent_3;
            
            product <= mul_a * mul_b;
            product_1 <= product;
            product_2 <= product_1;
            product_3 <= product_2;
            product_4 <= product_3;
            product_5 <= product_4;
            product_6 <= product_5;
            
            product_lsb <= |product_6[51:0];
            
            exponent_5 <= (a_is_zero || b_is_zero) ? 12'd0 : exponent_4;
            
            product_7 <= {1'b0, product_6[105:52], product_lsb};
        end
    end

endmodule
