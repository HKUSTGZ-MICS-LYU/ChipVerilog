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

    // Internal pipeline registers
    reg sign_reg;
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] fraction_a, fraction_b;
    reg expa_gt_expb;
    reg [10:0] exponent_large, exponent_small;
    reg [51:0] fraction_large, fraction_small;
    reg large_is_denorm, small_is_denorm;
    reg [52:0] large_ext, small_ext;
    reg large_norm_small_denorm;
    reg [10:0] exponent_diff;
    reg [55:0] small_shift;
    reg small_is_nonzero;
    reg small_shift_nonzero;
    reg small_fraction_enable;
    reg [55:0] small_shift_2, small_shift_3;
    reg [55:0] large_ext_aligned;
    reg [55:0] sum;
    reg sum_leading_one;
    reg denorm_to_norm;
    reg [10:0] exponent;
    reg [55:0] sum_reg;

    always @(posedge clk) begin
        if (rst) begin
            sign <= 1'b0;
            sum_2 <= 56'b0;
            exponent_2 <= 11'b0;
            sign_reg <= 1'b0;
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            fraction_a <= 52'b0;
            fraction_b <= 52'b0;
            expa_gt_expb <= 1'b0;
            exponent_large <= 11'b0;
            exponent_small <= 11'b0;
            fraction_large <= 52'b0;
            fraction_small <= 52'b0;
            large_is_denorm <= 1'b0;
            small_is_denorm <= 1'b0;
            large_ext <= 53'b0;
            small_ext <= 53'b0;
            large_norm_small_denorm <= 1'b0;
            exponent_diff <= 11'b0;
            small_shift <= 56'b0;
            small_is_nonzero <= 1'b0;
            small_shift_nonzero <= 1'b0;
            small_fraction_enable <= 1'b0;
            small_shift_2 <= 56'b0;
            small_shift_3 <= 56'b0;
            large_ext_aligned <= 56'b0;
            sum <= 56'b0;
            sum_leading_one <= 1'b0;
            denorm_to_norm <= 1'b0;
            exponent <= 11'b0;
            sum_reg <= 56'b0;
        end else if (enable) begin
            // Stage 1: Extract fields
            sign_reg <= opa[63];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            fraction_a <= opa[51:0];
            fraction_b <= opb[51:0];
            
            // Stage 2: Compare exponents and select large/small
            expa_gt_expb <= exponent_a > exponent_b;
            exponent_large <= expa_gt_expb ? exponent_a : exponent_b;
            exponent_small <= expa_gt_expb ? exponent_b : exponent_a;
            fraction_large <= expa_gt_expb ? fraction_a : fraction_b;
            fraction_small <= expa_gt_expb ? fraction_b : fraction_a;
            
            // Stage 3: Denormal detection
            large_is_denorm <= (exponent_large == 11'b0);
            small_is_denorm <= (exponent_small == 11'b0);
            
            // Stage 4: Extend significands with hidden bit
            large_ext <= large_is_denorm ? {1'b0, fraction_large} : {1'b1, fraction_large};
            small_ext <= small_is_denorm ? {1'b0, fraction_small} : {1'b1, fraction_small};
            
            // Stage 5: Alignment control
            large_norm_small_denorm <= !large_is_denorm && small_is_denorm;
            exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;
            
            // Stage 6: Align smaller significand
            small_shift <= {small_ext, 3'b0} >> exponent_diff;
            small_is_nonzero <= (small_ext != 53'b0);
            small_shift_nonzero <= (small_shift != 56'b0);
            small_fraction_enable <= small_is_nonzero && !small_shift_nonzero;
            small_shift_2 <= small_shift;
            small_shift_3 <= small_fraction_enable ? (small_shift_2 | 56'b1) : small_shift_2;
            
            // Stage 7: Prepare large operand and add
            large_ext_aligned <= {large_ext, 3'b0};
            sum <= large_ext_aligned + small_shift_3;
            
            // Stage 8: Post-addition normalization
            sum_leading_one <= sum[55];
            exponent <= exponent_large;
            denorm_to_norm <= sum_leading_one && large_is_denorm;
            
            // Stage 9: Final output registers
            sum_reg <= sum_leading_one ? (sum >> 1) : sum;
            sign <= sign_reg;
            sum_2 <= sum_reg;
            exponent_2 <= denorm_to_norm ? (exponent + 11'b1) : 
                          (sum_leading_one ? (exponent + 11'b1) : exponent);
        end
    end

endmodule
