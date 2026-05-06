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

    // Pipeline registers
    reg [10:0] s1_exp_a, s1_exp_b;
    reg [51:0] s1_frac_a, s1_frac_b;
    reg s1_sign;
    reg s1_denorm_a, s1_denorm_b;
    reg s1_expa_gt_expb;

    reg [10:0] s2_large_exp, s2_small_exp;
    reg [51:0] s2_large_frac, s2_small_frac;
    reg s2_large_denorm, s2_small_denorm;
    reg s2_sign;

    reg s3_large_hidden, s3_small_hidden;
    reg [55:0] s3_large_ext, s3_small_ext;
    reg [10:0] s3_exp_diff;
    reg [10:0] s3_large_exp;
    reg s3_large_denorm;
    reg s3_sign;

    reg [55:0] s4_small_shift;
    reg s4_small_nonzero;
    reg s4_small_shift_nonzero;
    reg s4_small_fraction_enable;
    reg [55:0] s4_large_ext;
    reg [10:0] s4_large_exp;
    reg s4_large_denorm;
    reg s4_sign;

    reg [55:0] s5_small_shift_3;
    reg [55:0] s5_large_ext;
    reg [10:0] s5_large_exp;
    reg s5_large_denorm;
    reg s5_sign;

    reg [55:0] s6_sum;
    reg [10:0] s6_large_exp;
    reg s6_large_denorm;
    reg s6_sign;

    reg [55:0] s7_sum_1;
    reg [10:0] s7_exponent_1;
    reg s7_large_denorm;
    reg s7_sign;

    reg s8_denorm_to_norm;
    reg [55:0] s8_sum_2;
    reg [10:0] s8_exponent_2;
    reg s8_sign;

    always @(posedge clk) begin
        if (rst) begin
            s1_exp_a <= 0; s1_exp_b <= 0;
            s1_frac_a <= 0; s1_frac_b <= 0;
            s1_sign <= 0;
            s1_denorm_a <= 0; s1_denorm_b <= 0;
            s1_expa_gt_expb <= 0;

            s2_large_exp <= 0; s2_small_exp <= 0;
            s2_large_frac <= 0; s2_small_frac <= 0;
            s2_large_denorm <= 0; s2_small_denorm <= 0;
            s2_sign <= 0;

            s3_large_hidden <= 0; s3_small_hidden <= 0;
            s3_large_ext <= 0; s3_small_ext <= 0;
            s3_exp_diff <= 0;
            s3_large_exp <= 0;
            s3_large_denorm <= 0;
            s3_sign <= 0;

            s4_small_shift <= 0;
            s4_small_nonzero <= 0; s4_small_shift_nonzero <= 0;
            s4_small_fraction_enable <= 0;
            s4_large_ext <= 0;
            s4_large_exp <= 0;
            s4_large_denorm <= 0;
            s4_sign <= 0;

            s5_small_shift_3 <= 0;
            s5_large_ext <= 0;
            s5_large_exp <= 0;
            s5_large_denorm <= 0;
            s5_sign <= 0;

            s6_sum <= 0;
            s6_large_exp <= 0;
            s6_large_denorm <= 0;
            s6_sign <= 0;

            s7_sum_1 <= 0;
            s7_exponent_1 <= 0;
            s7_large_denorm <= 0;
            s7_sign <= 0;

            s8_denorm_to_norm <= 0;
            s8_sum_2 <= 0;
            s8_exponent_2 <= 0;
            s8_sign <= 0;

            sign <= 0;
            sum_2 <= 0;
            exponent_2 <= 0;
        end else if (enable) begin
            // Stage 1: Extract and compare exponents
            s1_exp_a <= opa[62:52];
            s1_exp_b <= opb[62:52];
            s1_frac_a <= opa[51:0];
            s1_frac_b <= opb[51:0];
            s1_sign <= opa[63];
            s1_denorm_a <= (opa[62:52] == 11'h0);
            s1_denorm_b <= (opb[62:52] == 11'h0);
            s1_expa_gt_expb <= (opa[62:52] > opb[62:52]);

            // Stage 2: Select large and small operands
            s2_large_exp <= s1_expa_gt_expb ? s1_exp_a : s1_exp_b;
            s2_small_exp <= s1_expa_gt_expb ? s1_exp_b : s1_exp_a;
            s2_large_frac <= s1_expa_gt_expb ? s1_frac_a : s1_frac_b;
            s2_small_frac <= s1_expa_gt_expb ? s1_frac_b : s1_frac_a;
            s2_large_denorm <= s1_expa_gt_expb ? s1_denorm_a : s1_denorm_b;
            s2_small_denorm <= s1_expa_gt_expb ? s1_denorm_b : s1_denorm_a;
            s2_sign <= s1_sign;

            // Stage 3: Hidden bits, extended significands, exponent difference
            s3_large_hidden <= !s2_large_denorm;
            s3_small_hidden <= !s2_small_denorm;
            s3_large_ext <= {1'b0, s3_large_hidden, s2_large_frac, 2'b00};
            s3_small_ext <= {1'b0, s3_small_hidden, s2_small_frac, 2'b00};
            s3_exp_diff <= s2_large_exp - s2_small_exp - ((!s2_large_denorm) & s2_small_denorm);
            s3_large_exp <= s2_large_exp;
            s3_large_denorm <= s2_large_denorm;
            s3_sign <= s2_sign;

            // Stage 4: Shift smaller operand
            if (s3_exp_diff >= 56)
                s4_small_shift <= 56'h0;
            else
                s4_small_shift <= s3_small_ext >> s3_exp_diff;
            s4_small_nonzero <= (s3_small_ext != 56'h0);
            s4_small_shift_nonzero <= ((s3_small_ext >> s3_exp_diff) != 56'h0);
            s4_small_fraction_enable <= s4_small_nonzero & !s4_small_shift_nonzero;
            s4_large_ext <= s3_large_ext;
            s4_large_exp <= s3_large_exp;
            s4_large_denorm <= s3_large_denorm;
            s4_sign <= s3_sign;

            // Stage 5: Force LSB if entire significand shifted out
            s5_small_shift_3 <= s4_small_fraction_enable ? {s4_small_shift[55:1], 1'b1} : s4_small_shift;
            s5_large_ext <= s4_large_ext;
            s5_large_exp <= s4_large_exp;
            s5_large_denorm <= s4_large_denorm;
            s5_sign <= s4_sign;

            // Stage 6: Add aligned significands
            s6_sum <= s5_large_ext + s5_small_shift_3;
            s6_large_exp <= s5_large_exp;
            s6_large_denorm <= s5_large_denorm;
            s6_sign <= s5_sign;

            // Stage 7: Normalize if overflow carry
            s7_sum_1 <= s6_sum[55] ? (s6_sum >> 1) : s6_sum;
            s7_exponent_1 <= s6_sum[55] ? (s6_large_exp + 1) : s6_large_exp;
            s7_large_denorm <= s6_large_denorm;
            s7_sign <= s6_sign;

            // Stage 8: Denormal-to-normal exponent correction
            s8_denorm_to_norm <= s7_sum_1[54] & s7_large_denorm;
            s8_exponent_2 <= s8_denorm_to_norm ? (s7_exponent_1 + 1) : s7_exponent_1;
            s8_sum_2 <= s7_sum_1;
            s8_sign <= s7_sign;

            // Outputs
            sign <= s8_sign;
            sum_2 <= s8_sum_2;
            exponent_2 <= s8_exponent_2;
        end
    end
endmodule
