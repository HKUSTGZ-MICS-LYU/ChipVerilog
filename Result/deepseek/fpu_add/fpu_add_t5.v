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

reg expa_gt_expb;
reg [10:0] exponent_large, exponent_small;
reg [51:0] fraction_large, fraction_small;
reg large_is_norm, large_is_denorm, small_is_norm, small_is_denorm;
reg large_norm_small_denorm;
reg [10:0] exponent_diff;
reg [55:0] large_frac_extended, small_frac_extended;
reg [55:0] small_shift;
reg [55:0] small_shift_2;
reg [55:0] small_shift_3;
reg small_shift_nonzero;
reg small_is_nonzero;
reg small_fraction_enable;
reg [56:0] sum_full;
reg carry;
reg [55:0] sum_norm;
reg exponent_inc;
reg sum_leading_one;
reg denorm_to_norm;
reg [10:0] exponent_final;

always @(posedge clk) begin
    if (rst) begin
        sign <= 0;
        sum_2 <= 0;
        exponent_2 <= 0;
        expa_gt_expb <= 0;
        exponent_large <= 0;
        exponent_small <= 0;
        fraction_large <= 0;
        fraction_small <= 0;
        large_is_norm <= 0;
        large_is_denorm <= 0;
        small_is_norm <= 0;
        small_is_denorm <= 0;
        large_norm_small_denorm <= 0;
        exponent_diff <= 0;
        large_frac_extended <= 0;
        small_frac_extended <= 0;
        small_shift <= 0;
        small_shift_2 <= 0;
        small_shift_3 <= 0;
        small_shift_nonzero <= 0;
        small_is_nonzero <= 0;
        small_fraction_enable <= 0;
        sum_full <= 0;
        carry <= 0;
        sum_norm <= 0;
        exponent_inc <= 0;
        sum_leading_one <= 0;
        denorm_to_norm <= 0;
        exponent_final <= 0;
    end else if (enable) begin
        // Compare exponents
        expa_gt_expb <= (opa[62:52] > opb[62:52]);
        
        // Select large/small based on previous comparison
        exponent_large <= expa_gt_expb ? opa[62:52] : opb[62:52];
        exponent_small <= expa_gt_expb ? opb[62:52] : opa[62:52];
        fraction_large <= expa_gt_expb ? opa[51:0] : opb[51:0];
        fraction_small <= expa_gt_expb ? opb[51:0] : opa[51:0];
        
        // Denorm flags
        large_is_norm <= (exponent_large != 0);
        large_is_denorm <= (exponent_large == 0);
        small_is_norm <= (exponent_small != 0);
        small_is_denorm <= (exponent_small == 0);
        
        // Insert hidden bits (56-bit representation: [55:53] = 0, [54] = integer, [53:2] = fraction, [1:0]=0)
        large_frac_extended <= large_is_norm ? {3'b0, 1'b1, fraction_large} : {3'b0, 1'b0, fraction_large};
        small_frac_extended <= small_is_norm ? {3'b0, 1'b1, fraction_small} : {3'b0, 1'b0, fraction_small};
        
        // Large norm small denorm flag
        large_norm_small_denorm <= large_is_norm & small_is_denorm;
        
        // Exponent difference (alignment shift amount)
        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;
        
        // Align smaller significand; saturate shift to 0 if >55
        if (exponent_diff > 55)
            small_shift <= 0;
        else
            small_shift <= small_frac_extended >> exponent_diff;
        
        // Sticky detection
        small_shift_nonzero <= (small_shift != 0);
        small_is_nonzero <= (small_frac_extended != 0);
        small_fraction_enable <= small_is_nonzero & ~small_shift_nonzero;
        
        // Pipeline for shift
        small_shift_2 <= small_shift;
        small_shift_3 <= small_fraction_enable ? (small_shift_2 | 56'd1) : small_shift;
        
        // 57-bit addition (guard for overflow)
        sum_full <= {1'b0, large_frac_extended} + {1'b0, small_shift_3};
        
        // Carry out (overflow guard)
        carry <= sum_full[56];
        
        // Normalize: if carry, shift right and increment exponent
        sum_norm <= carry ? {1'b1, sum_full[55:1]} : sum_full[55:0];
        exponent_inc <= carry ? 1 : 0;
        
        // Leading integer bit after normalization
        sum_leading_one <= sum_norm[54];
        
        // Denormal-to-normal exponent correction
        denorm_to_norm <= sum_leading_one & large_is_denorm;
        
        // Final exponent
        exponent_final <= exponent_large + exponent_inc + (denorm_to_norm ? 1 : 0);
        
        // Output assignments
        sign <= opa[63];
        sum_2 <= sum_norm;
        exponent_2 <= exponent_final[10:0];
    end
end

endmodule
