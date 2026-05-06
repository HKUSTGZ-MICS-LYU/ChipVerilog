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

    // Extract fields
    wire [10:0] expa = opa[62:52];
    wire [10:0] expb = opb[62:52];
    wire [51:0] fraca = opa[51:0];
    wire [51:0] fracb = opb[51:0];

    // Compare exponents and select large/small
    wire expa_gt_expb = (expa > expb);
    wire [10:0] exponent_large = expa_gt_expb ? expa : expb;
    wire [10:0] exponent_small = expa_gt_expb ? expb : expa;
    wire [51:0] fraction_large = expa_gt_expb ? fraca : fracb;
    wire [51:0] fraction_small = expa_gt_expb ? fracb : fraca;

    // Build extended significands (56-bit)
    // bit55: guard, bit54: integer, bits53:2: fraction, bits1:0: low
    wire [55:0] sig_large = {1'b0, (exponent_large != 0) ? 1'b1 : 1'b0, fraction_large, 2'b0};
    wire [55:0] sig_small = {1'b0, (exponent_small != 0) ? 1'b1 : 1'b0, fraction_small, 2'b0};

    // Compute effective exponent difference
    wire large_is_norm = (exponent_large != 0);
    wire small_is_denorm = (exponent_small == 0);
    wire large_norm_small_denorm = large_is_norm & small_is_denorm;
    wire [10:0] exponent_diff = exponent_large - exponent_small - large_norm_small_denorm;

    // Right-shift smaller significand, saturate at 55 bits
    wire [55:0] small_shifted = (exponent_diff > 55) ? 56'b0 : (sig_small >> exponent_diff);

    // Sticky injection when small operand entirely shifted out
    wire small_is_nonzero = (sig_small != 0);
    wire small_shift_nonzero = (small_shifted != 0);
    wire small_fraction_enable = small_is_nonzero & (~small_shift_nonzero);
    wire [55:0] small_shift_3 = small_fraction_enable ? (small_shifted | 56'b1) : small_shifted;

    // Addition
    wire [55:0] sum_tmp = sig_large + small_shift_3;
    wire carry_out = sum_tmp[55];
    // Carry normalization
    wire [55:0] sum_normalized = carry_out ? {1'b0, sum_tmp[55:1]} : sum_tmp;
    wire [10:0] exp_after_carry = exponent_large + carry_out;

    // Denormal-to-normal adjustment: if large operand was denormal and result now has leading 1
    wire large_is_denorm = (exponent_large == 0);
    wire sum_leading_one = sum_normalized[54];
    wire denorm_to_norm = sum_leading_one & large_is_denorm;
    wire [10:0] exponent_final = denorm_to_norm ? (exp_after_carry + 1) : exp_after_carry;

    // Output registers
    always @(posedge clk) begin
        if (rst) begin
            sign <= 0;
            sum_2 <= 0;
            exponent_2 <= 0;
        end else if (enable) begin
            sign <= opa[63];          // sign forwarded directly
            sum_2 <= sum_normalized;
            exponent_2 <= exponent_final;
        end
    end

endmodule
