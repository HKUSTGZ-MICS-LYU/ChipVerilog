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

reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg [51:0] fraction_a;
reg [51:0] fraction_b;

reg expa_gt_expb;
reg [10:0] exponent_large;
reg [10:0] exponent_small;
reg [51:0] fraction_large;
reg [51:0] fraction_small;

reg large_is_denorm;
reg small_is_denorm;
reg large_norm_small_denorm;

reg [55:0] significand_large;
reg [55:0] significand_small;

reg [10:0] exponent_diff;
reg [55:0] small_shift;
reg [55:0] small_shift_2;
reg [55:0] small_shift_3;

reg small_is_nonzero;
reg small_shift_nonzero;
reg small_fraction_enable;

reg [55:0] sum;
reg sum_overflow;
reg [55:0] sum_shift;
reg sum_leading_one;

reg [10:0] exponent;
reg denorm_to_norm;

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
        fraction_large <= 52'd0;
        fraction_small <= 52'd0;

        large_is_denorm <= 1'b0;
        small_is_denorm <= 1'b0;
        large_norm_small_denorm <= 1'b0;

        significand_large <= 56'd0;
        significand_small <= 56'd0;

        exponent_diff <= 11'd0;
        small_shift <= 56'd0;
        small_shift_2 <= 56'd0;
        small_shift_3 <= 56'd0;

        small_is_nonzero <= 1'b0;
        small_shift_nonzero <= 1'b0;
        small_fraction_enable <= 1'b0;

        sum <= 56'd0;
        sum_overflow <= 1'b0;
        sum_shift <= 56'd0;
        sum_leading_one <= 1'b0;

        exponent <= 11'd0;
        denorm_to_norm <= 1'b0;
    end else if (enable) begin
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        fraction_a <= opa[51:0];
        fraction_b <= opb[51:0];

        expa_gt_expb <= (exponent_a > exponent_b);
        exponent_large <= expa_gt_expb ? exponent_a : exponent_b;
        exponent_small <= expa_gt_expb ? exponent_b : exponent_a;
        fraction_large <= expa_gt_expb ? fraction_a : fraction_b;
        fraction_small <= expa_gt_expb ? fraction_b : fraction_a;

        large_is_denorm <= (exponent_large == 11'd0);
        small_is_denorm <= (exponent_small == 11'd0);
        large_norm_small_denorm <= (~large_is_denorm) & small_is_denorm;

        significand_large <= {1'b0, (~large_is_denorm), fraction_large, 2'b00};
        significand_small <= {1'b0, (~small_is_denorm), fraction_small, 2'b00};

        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;
        small_shift <= significand_small >> exponent_diff;

        small_is_nonzero <= (exponent_small != 11'd0) | (fraction_small != 52'd0);
        small_shift_nonzero <= |small_shift;
        small_fraction_enable <= small_is_nonzero & (~small_shift_nonzero);
        small_shift_2 <= {small_shift[55:1], 1'b1};
        small_shift_3 <= small_fraction_enable ? small_shift_2 : small_shift;

        sum <= significand_large + small_shift_3;
        sum_overflow <= sum[55];
        sum_shift <= sum_overflow ? (sum >> 1) : sum;
        sum_leading_one <= sum_shift[54];

        exponent <= sum_overflow ? (exponent_large + 11'd1) : exponent_large;
        denorm_to_norm <= sum_leading_one & large_is_denorm;
        exponent_2 <= denorm_to_norm ? (exponent + 11'd1) : exponent;
        sum_2 <= sum_shift;
        sign <= opa[63];
    end
end

endmodule
