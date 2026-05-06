// FPU Addition Module for Double-Precision Operands
// Implements aligned mantissa addition with carry normalization

module fpu_add(clk, rst, enable, opa, opb, sign, sum_2, exponent_2);
    input clk;
    input rst;
    input enable;
    input [63:0] opa;
    input [63:0] opb;
    output reg sign;
    output reg [55:0] sum_2;
    output reg [10:0] exponent_2;
    
    // Stage 1: Extract fields
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg sign_a;
    
    // Stage 2: Compare and select large/small
    reg [10:0] exponent_small, exponent_large;
    reg [51:0] mantissa_small, mantissa_large;
    reg small_is_denorm, large_is_denorm;
    
    // Stage 3: Alignment computation
    reg [10:0] exponent_diff;
    reg large_norm_small_denorm;
    reg [55:0] large_add, small_add, small_shift;
    
    // Stage 4: Addition
    reg [55:0] small_shift_3;
    reg [55:0] sum;
    wire sum_overflow;
    
    // Stage 5: Normalization
    wire small_shift_nonzero;
    wire small_is_nonzero;
    wire small_fraction_enable;
    wire [55:0] normalized_sum;
    reg denorm_to_norm;
    reg [10:0] exponent;
    
    assign sum_overflow = sum[55];
    assign small_shift_nonzero = |small_shift[55:0];
    assign small_is_nonzero = (exponent_small > 0) | |mantissa_small[51:0];
    assign small_fraction_enable = small_is_nonzero & ~small_shift_nonzero;
    assign normalized_sum = sum_overflow ? (sum >> 1) : sum;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            sign_a <= 1'b0;
            exponent_small <= 11'b0;
            exponent_large <= 11'b0;
            mantissa_small <= 52'b0;
            mantissa_large <= 52'b0;
            small_is_denorm <= 1'b0;
            large_is_denorm <= 1'b0;
            exponent_diff <= 11'b0;
            large_norm_small_denorm <= 1'b0;
            large_add <= 56'b0;
            small_add <= 56'b0;
            small_shift <= 56'b0;
            small_shift_3 <= 56'b0;
            sum <= 56'b0;
            denorm_to_norm <= 1'b0;
            exponent <= 11'b0;
            sign <= 1'b0;
            sum_2 <= 56'b0;
            exponent_2 <= 11'b0;
        end else if (enable) begin
            // Stage 1: Extract fields
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            sign_a <= opa[63];
            
            // Stage 2: Compare and select
            if (exponent_a > exponent_b) begin
                exponent_large <= exponent_a;
                exponent_small <= exponent_b;
                mantissa_large <= mantissa_a;
                mantissa_small <= mantissa_b;
            end else begin
                exponent_large <= exponent_b;
                exponent_small <= exponent_a;
                mantissa_large <= mantissa_b;
                mantissa_small <= mantissa_a;
            end
            large_is_denorm <= (exponent_a > exponent_b) ? (exponent_a == 11'b0) : (exponent_b == 11'b0);
            small_is_denorm <= (exponent_a > exponent_b) ? (exponent_b == 11'b0) : (exponent_a == 11'b0);
            
            // Stage 3: Alignment
            large_norm_small_denorm <= ((exponent_a > exponent_b) ? (exponent_a != 11'b0) : (exponent_b != 11'b0)) & 
                                       ((exponent_a > exponent_b) ? (exponent_b == 11'b0) : (exponent_a == 11'b0));
            exponent_diff <= (exponent_a > exponent_b) ? (exponent_a - exponent_b) : (exponent_b - exponent_a);
            large_add <= {1'b0, (exponent_a > exponent_b) ? (exponent_a != 11'b0) : (exponent_b != 11'b0), 
                          (exponent_a > exponent_b) ? mantissa_a : mantissa_b, 2'b0};
            small_add <= {1'b0, (exponent_a > exponent_b) ? (exponent_b != 11'b0) : (exponent_a != 11'b0), 
                          (exponent_a > exponent_b) ? mantissa_b : mantissa_a, 2'b0};
            
            // Stage 4: Shift and add
            small_shift <= small_add >> exponent_diff;
            small_shift_3 <= small_fraction_enable ? 56'h1 : (small_add >> exponent_diff);
            sum <= large_add + small_shift_3;
            
            // Stage 5: Normalize
            sum_2 <= normalized_sum;
            exponent <= sum_overflow ? (exponent_large + 11'b1) : exponent_large;
            denorm_to_norm <= large_is_denorm & normalized_sum[54];
            exponent_2 <= denorm_to_norm ? (exponent + 11'b1) : exponent;
            sign <= sign_a;
        end
    end
endmodule
