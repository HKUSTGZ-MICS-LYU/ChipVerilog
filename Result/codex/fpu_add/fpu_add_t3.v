module fpu_add( clk, rst, enable, opa, opb, sign, sum_2, exponent_2);

input clk;
input rst;
input enable;
input [63:0] opa;
input [63:0] opb;
output reg sign;
output reg [55:0] sum_2;
output reg [10:0] exponent_2;

reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg [51:0] mantissa_a;
reg [51:0] mantissa_b;
reg expa_gt_expb;
reg [10:0] exponent_small;
reg [10:0] exponent_large;
reg [51:0] mantissa_small;
reg [51:0] mantissa_large;
reg small_is_denorm;
reg large_is_denorm;
reg large_norm_small_denorm;
reg [10:0] exponent_diff;
reg [55:0] large_add;
reg [55:0] small_add;
reg [55:0] small_shift;
reg [55:0] small_shift_3;
reg [55:0] sum;
reg [10:0] exponent;
reg denorm_to_norm;

wire small_shift_nonzero;
wire small_is_nonzero;
wire small_fraction_enable;
wire [55:0] small_shift_2;
wire sum_overflow;
wire sum_leading_one;

assign small_shift_nonzero = |small_shift[55:0];
assign small_is_nonzero = (exponent_small > 11'd0) | (|mantissa_small[51:0]);
assign small_fraction_enable = small_is_nonzero & !small_shift_nonzero;
assign small_shift_2 = {55'b0, 1'b1};
assign sum_overflow = sum[55];
assign sum_leading_one = sum_2[54];

always @(posedge clk) begin
    if (rst) begin
        sign <= 1'b0;
        sum_2 <= 56'd0;
        exponent_2 <= 11'd0;
        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        mantissa_a <= 52'd0;
        mantissa_b <= 52'd0;
        expa_gt_expb <= 1'b0;
        exponent_small <= 11'd0;
        exponent_large <= 11'd0;
        mantissa_small <= 52'd0;
        mantissa_large <= 52'd0;
        small_is_denorm <= 1'b0;
        large_is_denorm <= 1'b0;
        large_norm_small_denorm <= 1'b0;
        exponent_diff <= 11'd0;
        large_add <= 56'd0;
        small_add <= 56'd0;
        small_shift <= 56'd0;
        small_shift_3 <= 56'd0;
        sum <= 56'd0;
        exponent <= 11'd0;
        denorm_to_norm <= 1'b0;
    end else if (enable) begin
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        expa_gt_expb <= exponent_a > exponent_b;

        if (expa_gt_expb) begin
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

        small_is_denorm <= exponent_small == 11'd0;
        large_is_denorm <= exponent_large == 11'd0;
        large_norm_small_denorm <= (exponent_large != 11'd0) & (exponent_small == 11'd0);
        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;

        large_add <= {1'b0, !large_is_denorm, mantissa_large, 2'b0};
        small_add <= {1'b0, !small_is_denorm, mantissa_small, 2'b0};
        small_shift <= small_add >> exponent_diff;
        small_shift_3 <= small_fraction_enable ? small_shift_2 : small_shift;

        sum <= large_add + small_shift_3;
        sum_2 <= sum_overflow ? (sum >> 1) : sum;
        exponent <= sum_overflow ? (exponent_large + 11'd1) : exponent_large;
        denorm_to_norm <= large_is_denorm & sum_leading_one;
        exponent_2 <= denorm_to_norm ? (exponent + 11'd1) : exponent;
        sign <= opa[63];
    end
end

endmodule
