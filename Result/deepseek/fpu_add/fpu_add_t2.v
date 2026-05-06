module fpu_add (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg sign,
    output reg [55:0] sum_2,
    output reg [10:0] exponent_2
);

    // Internal registers
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] fraction_a, fraction_b;
    reg expa_gt_expb;
    reg [10:0] exponent_large, exponent_small;
    reg [52:0] mantissa_large, mantissa_small;
    reg [52:0] mantissa_large_next, mantissa_small_next;
    reg large_is_denorm, small_is_denorm;
    reg large_is_denorm_next, small_is_denorm_next;
    reg large_norm_small_denorm;
    reg [10:0] exponent_diff;
    reg [55:0] small_shift;
    reg small_is_nonzero;
    reg small_shift_nonzero;
    reg small_fraction_enable;
    reg [55:0] small_shift_2, small_shift_3;
    reg [55:0] sum;
    reg sum_leading_one;
    reg denorm_to_norm;
    reg [10:0] exponent;
    reg [10:0] exponent_next;

    always @(posedge clk) begin
        if (rst) begin
            sign <= 1'b0;
            sum_2 <= 56'd0;
            exponent_2 <= 11'd0;
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            fraction_a <= 52'd0;
            fraction_b <= 52'd0;
            expa_gt_expb <= 1'b0;
            exponent_large <= 11'd0;
            exponent_small <= 11'd0;
            mantissa_large <= 53'd0;
            mantissa_small <= 53'd0;
            mantissa_large_next <= 53'd0;
            mantissa_small_next <= 53'd0;
            large_is_denorm <= 1'b0;
            small_is_denorm <= 1'b0;
            large_is_denorm_next <= 1'b0;
            small_is_denorm_next <= 1'b0;
            large_norm_small_denorm <= 1'b0;
            exponent_diff <= 11'd0;
            small_shift <= 56'd0;
            small_is_nonzero <= 1'b0;
            small_shift_nonzero <= 1'b0;
            small_fraction_enable <= 1'b0;
            small_shift_2 <= 56'd0;
            small_shift_3 <= 56'd0;
            sum <= 56'd0;
            sum_leading_one <= 1'b0;
            denorm_to_norm <= 1'b0;
            exponent <= 11'd0;
            exponent_next <= 11'd0;
        end else if (enable) begin
            // Stage 1: Extract fields
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            fraction_a <= opa[51:0];
            fraction_b <= opb[51:0];

            // Stage 2: Compare exponents and swap
            expa_gt_expb <= exponent_a > exponent_b;
            exponent_large <= expa_gt_expb ? exponent_a : exponent_b;
            exponent_small <= expa_gt_expb ? exponent_b : exponent_a;
            mantissa_large_next <= expa_gt_expb ? {1'b0, fraction_a} : {1'b0, fraction_b};
            mantissa_small_next <= expa_gt_expb ? {1'b0, fraction_b} : {1'b0, fraction_a};
            large_is_denorm_next <= expa_gt_expb ? (exponent_a == 11'd0) : (exponent_b == 11'd0);
            small_is_denorm_next <= expa_gt_expb ? (exponent_b == 11'd0) : (exponent_a == 11'd0);

            // Stage 3: Insert hidden bit
            mantissa_large <= large_is_denorm_next ? mantissa_large_next : {1'b1, mantissa_large_next[51:0]};
            mantissa_small <= small_is_denorm_next ? mantissa_small_next : {1'b1, mantissa_small_next[51:0]};
            large_is_denorm <= large_is_denorm_next;
            small_is_denorm <= small_is_denorm_next;

            // Stage 4: Compute exponent difference and alignment control
            large_norm_small_denorm <= !large_is_denorm && small_is_denorm;
            exponent_diff <= exponent_large - exponent_small - (large_norm_small_denorm ? 11'd1 : 11'd0);

            // Stage 5: Shift small significand
            // small_shift is the aligned small mantissa extended to 56 bits
            small_shift <= (exponent_diff >= 56) ? 56'd0 : {1'b0, mantissa_small, 2'b00} >> exponent_diff;
            small_is_nonzero <= (mantissa_small != 53'd0);
            small_shift_nonzero <= (small_shift != 56'd0);

            // Stage 6: Sticky bit injection
            small_fraction_enable <= small_is_nonzero && !small_shift_nonzero;
            small_shift_2 <= small_shift;
            small_shift_3 <= small_fraction_enable ? {small_shift_2[55:1], 1'b1} : small_shift_2;

            // Stage 7: Add
            sum <= {1'b0, mantissa_large, 2'b00} + small_shift_3;

            // Stage 8: Normalization and exponent update
            sum_leading_one <= sum[55];
            denorm_to_norm <= sum_leading_one && large_is_denorm;
            exponent_next <= exponent_large;
            exponent <= denorm_to_norm ? (exponent_next + 11'd1) : exponent_next;
            // Handle carry-out
            if (sum[55]) begin
                sum_2 <= {1'b0, sum[55:1]};
                exponent_2 <= exponent + 11'd1;
            end else begin
                sum_2 <= sum;
                exponent_2 <= exponent;
            end
            sign <= opa[63];
        end
    end

endmodule
