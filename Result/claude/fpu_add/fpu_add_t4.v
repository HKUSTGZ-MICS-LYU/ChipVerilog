module fpu_add(
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
    
    wire small_shift_nonzero = |small_shift;
    wire small_is_nonzero = (exponent_small > 0) | |mantissa_small;
    wire small_fraction_enable = small_is_nonzero & !small_shift_nonzero;
    wire sum_overflow = sum[55];
    wire sum_leading_one = sum_2[54];

    always @(posedge clk) begin
        if (rst) begin
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            expa_gt_expb <= 1'b0;
            exponent_small <= 11'b0;
            exponent_large <= 11'b0;
            mantissa_small <= 52'b0;
            mantissa_large <= 52'b0;
            small_is_denorm <= 1'b0;
            large_is_denorm <= 1'b0;
            large_norm_small_denorm <= 1'b0;
            exponent_diff <= 11'b0;
            large_add <= 56'b0;
            small_add <= 56'b0;
            small_shift <= 56'b0;
            small_shift_3 <= 56'b0;
            sum <= 56'b0;
            exponent <= 11'b0;
            denorm_to_norm <= 1'b0;
            sign <= 1'b0;
            sum_2 <= 56'b0;
            exponent_2 <= 11'b0;
        end else if (enable) begin
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            
            if (opa[62:52] > opb[62:52]) begin
                exponent_large <= opa[62:52];
                exponent_small <= opb[62:52];
                mantissa_large <= opa[51:0];
                mantissa_small <= opb[51:0];
            end else begin
                exponent_large <= opb[62:52];
                exponent_small <= opa[62:52];
                mantissa_large <= opb[51:0];
                mantissa_small <= opa[51:0];
            end
            
            small_is_denorm <= (exponent_small == 11'b0);
            large_is_denorm <= (exponent_large == 11'b0);
            large_norm_small_denorm <= (exponent_large != 11'b0) & (exponent_small == 11'b0);
            exponent_diff <= exponent_large - exponent_small - ((exponent_large != 11'b0) & (exponent_small == 11'b0) ? 11'b1 : 11'b0);
            
            large_add <= {1'b0, (exponent_large != 11'b0), mantissa_large, 2'b0};
            small_add <= {1'b0, (exponent_small != 11'b0), mantissa_small, 2'b0};
            
            small_shift <= small_add >> (exponent_diff > 11'd55 ? 11'd55 : exponent_diff);
            small_shift_3 <= small_fraction_enable ? {55'b0, 1'b1} : small_shift;
            
            sum <= large_add + small_shift_3;
            exponent <= sum_overflow ? (exponent_large + 11'b1) : exponent_large;
            sum_2 <= sum_overflow ? (sum >> 1) : sum;
            denorm_to_norm <= large_is_denorm & sum_leading_one;
            exponent_2 <= denorm_to_norm ? (exponent + 11'b1) : exponent;
            sign <= opa[63];
        end
    end
endmodule
