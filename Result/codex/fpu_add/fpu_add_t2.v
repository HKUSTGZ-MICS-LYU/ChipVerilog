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

    // ------------------------------------------------------------
    // Field extraction
    // ------------------------------------------------------------
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;

    reg [51:0] fraction_a;
    reg [51:0] fraction_b;

    // ------------------------------------------------------------
    // Exponent comparison and operand selection
    // ------------------------------------------------------------
    reg expa_gt_expb;

    reg [10:0] exponent_large;
    reg [10:0] exponent_small;

    reg [51:0] fraction_large;
    reg [51:0] fraction_small;

    // ------------------------------------------------------------
    // Denormal detection
    // ------------------------------------------------------------
    reg large_is_denorm;
    reg small_is_denorm;

    reg large_norm_small_denorm;

    // ------------------------------------------------------------
    // Extended significands
    //
    // Layout:
    // [55]    : carry / overflow guard
    // [54]    : hidden / integer bit
    // [53:2]  : 52-bit fraction
    // [1:0]   : low-order rounding remainder bits
    // ------------------------------------------------------------
    reg [55:0] large_fraction;
    reg [55:0] small_fraction;

    // ------------------------------------------------------------
    // Alignment
    // ------------------------------------------------------------
    reg [10:0] exponent_diff;
    reg [55:0] small_shift;
    reg [55:0] small_shift_2;
    reg [55:0] small_shift_3;

    reg small_is_nonzero;
    reg small_shift_nonzero;
    reg small_fraction_enable;

    // ------------------------------------------------------------
    // Addition and normalization
    // ------------------------------------------------------------
    reg [55:0] sum;
    reg [10:0] exponent;

    reg sum_overflow;
    reg sum_leading_one;
    reg denorm_to_norm;

    always @(posedge clk) begin
        if (rst) begin
            sign                    <= 1'b0;
            sum_2                   <= 56'd0;
            exponent_2              <= 11'd0;

            exponent_a              <= 11'd0;
            exponent_b              <= 11'd0;
            fraction_a              <= 52'd0;
            fraction_b              <= 52'd0;

            expa_gt_expb            <= 1'b0;

            exponent_large          <= 11'd0;
            exponent_small          <= 11'd0;
            fraction_large          <= 52'd0;
            fraction_small          <= 52'd0;

            large_is_denorm         <= 1'b0;
            small_is_denorm         <= 1'b0;
            large_norm_small_denorm <= 1'b0;

            large_fraction          <= 56'd0;
            small_fraction          <= 56'd0;

            exponent_diff           <= 11'd0;
            small_shift             <= 56'd0;
            small_shift_2           <= 56'd0;
            small_shift_3           <= 56'd0;

            small_is_nonzero        <= 1'b0;
            small_shift_nonzero     <= 1'b0;
            small_fraction_enable   <= 1'b0;

            sum                     <= 56'd0;
            exponent                <= 11'd0;

            sum_overflow            <= 1'b0;
            sum_leading_one         <= 1'b0;
            denorm_to_norm          <= 1'b0;
        end else if (enable) begin
            // ----------------------------------------------------
            // 1. Extract sign, exponent and fraction fields
            // ----------------------------------------------------
            sign       <= opa[63];

            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];

            fraction_a <= opa[51:0];
            fraction_b <= opb[51:0];

            // ----------------------------------------------------
            // 2. Compare exponents
            //
            // If exponents are equal, opb is selected as large side.
            // ----------------------------------------------------
            expa_gt_expb <= exponent_a > exponent_b;

            exponent_large <= expa_gt_expb ? exponent_a : exponent_b;
            exponent_small <= expa_gt_expb ? exponent_b : exponent_a;

            fraction_large <= expa_gt_expb ? fraction_a : fraction_b;
            fraction_small <= expa_gt_expb ? fraction_b : fraction_a;

            // ----------------------------------------------------
            // 3. Denormal detection
            // ----------------------------------------------------
            large_is_denorm <= exponent_large == 11'd0;
            small_is_denorm <= exponent_small == 11'd0;

            large_norm_small_denorm <=
                (exponent_large != 11'd0) && (exponent_small == 11'd0);

            // ----------------------------------------------------
            // 4. Insert hidden bit for normalized operands
            //
            // Normalized:
            //   0_1_fraction_00
            //
            // Denormalized:
            //   0_0_fraction_00
            // ----------------------------------------------------
            large_fraction <= {
                1'b0,
                ~large_is_denorm,
                fraction_large,
                2'b00
            };

            small_fraction <= {
                1'b0,
                ~small_is_denorm,
                fraction_small,
                2'b00
            };

            // ----------------------------------------------------
            // 5. Compute exponent difference and align smaller side
            //
            // If large is normalized and small is denormalized,
            // reduce shift distance by 1.
            // ----------------------------------------------------
            exponent_diff <=
                exponent_large - exponent_small - large_norm_small_denorm;

            if (exponent_diff >= 11'd56) begin
                small_shift <= 56'd0;
            end else begin
                small_shift <= small_fraction >> exponent_diff;
            end

            // ----------------------------------------------------
            // 6. Limited sticky handling
            //
            // If the smaller operand is nonzero but completely shifted out,
            // force bit 0 to 1.
            // ----------------------------------------------------
            small_is_nonzero <= small_fraction != 56'd0;
            small_shift_nonzero <= small_shift != 56'd0;

            small_fraction_enable <= small_is_nonzero && !small_shift_nonzero;

            small_shift_2 <= 56'd1;

            small_shift_3 <= small_fraction_enable ? small_shift_2
                                                    : small_shift;

            // ----------------------------------------------------
            // 7. Add aligned significands
            // ----------------------------------------------------
            sum <= large_fraction + small_shift_3;

            exponent <= exponent_large;

            // ----------------------------------------------------
            // 8. Carry-out normalization
            //
            // If sum[55] is set, shift right by 1 and increment exponent.
            // ----------------------------------------------------
            sum_overflow <= sum[55];

            if (sum_overflow) begin
                sum_2    <= sum >> 1;
                exponent <= exponent + 11'd1;
            end else begin
                sum_2    <= sum;
                exponent <= exponent;
            end

            // ----------------------------------------------------
            // 9. Denormal-to-normal correction
            //
            // If the large operand was denormalized and the result now has
            // a leading one, increment exponent by 1.
            // ----------------------------------------------------
            sum_leading_one <= sum_2[54];

            denorm_to_norm <= sum_leading_one && large_is_denorm;

            exponent_2 <= denorm_to_norm ? exponent + 11'd1
                                          : exponent;
        end
    end

endmodule