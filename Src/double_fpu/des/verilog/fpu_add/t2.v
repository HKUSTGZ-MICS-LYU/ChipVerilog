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

    // Stage registers - cycle 1: extract fields
    reg        expa_gt_expb;
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] fraction_a, fraction_b;

    // Stage registers - cycle 2: large/small assignment
    reg [10:0] exponent_large, exponent_small;
    reg [54:0] large_frac, small_frac;   // 55-bit: hidden bit + 52-bit fraction + 2 guard bits
    reg        large_is_denorm, small_is_denorm;
    reg        large_norm_small_denorm;
    reg        sign_r1;

    // Stage registers - cycle 3: alignment
    reg [10:0] exponent_diff;
    reg [54:0] small_shift;
    reg [54:0] large_frac_r;
    reg [10:0] exponent_r;
    reg        small_is_nonzero;
    reg        sign_r2;

    // Stage registers - cycle 4: sticky
    reg        small_fraction_enable;
    reg        small_shift_nonzero;
    reg [54:0] small_shift_3;
    reg [54:0] large_frac_r2;
    reg [10:0] exponent_r2;
    reg        sign_r3;
    reg        large_is_denorm_r;

    // Stage registers - cycle 5: addition result
    reg [55:0] sum;
    reg [10:0] exponent_r3;
    reg        sign_r4;
    reg        large_is_denorm_r2;

    always @(posedge clk) begin
        if (rst) begin
            expa_gt_expb        <= 0;
            exponent_a          <= 0;
            exponent_b          <= 0;
            fraction_a          <= 0;
            fraction_b          <= 0;
            exponent_large      <= 0;
            exponent_small      <= 0;
            large_frac          <= 0;
            small_frac          <= 0;
            large_is_denorm     <= 0;
            small_is_denorm     <= 0;
            large_norm_small_denorm <= 0;
            sign_r1             <= 0;
            exponent_diff       <= 0;
            small_shift         <= 0;
            large_frac_r        <= 0;
            exponent_r          <= 0;
            small_is_nonzero    <= 0;
            sign_r2             <= 0;
            small_fraction_enable <= 0;
            small_shift_nonzero <= 0;
            small_shift_3       <= 0;
            large_frac_r2       <= 0;
            exponent_r2         <= 0;
            sign_r3             <= 0;
            large_is_denorm_r   <= 0;
            sum                 <= 0;
            exponent_r3         <= 0;
            sign_r4             <= 0;
            large_is_denorm_r2  <= 0;
            sign                <= 0;
            sum_2               <= 0;
            exponent_2          <= 0;
        end else if (enable) begin

            // Cycle 1: Extract fields
            exponent_a   <= opa[62:52];
            exponent_b   <= opb[62:52];
            fraction_a   <= opa[51:0];
            fraction_b   <= opb[51:0];
            expa_gt_expb <= (opa[62:52] > opb[62:52]);
            sign_r1      <= opa[63];

            // Cycle 2: Large/small assignment (uses prev expa_gt_expb)
            if (expa_gt_expb) begin
                exponent_large <= exponent_a;
                exponent_small <= exponent_b;
                large_frac     <= (exponent_a != 0) ? {1'b1, fraction_a, 2'b00}
                                                    : {1'b0, fraction_a, 2'b00};
                small_frac     <= (exponent_b != 0) ? {1'b1, fraction_b, 2'b00}
                                                    : {1'b0, fraction_b, 2'b00};
                large_is_denorm <= (exponent_a == 0);
                small_is_denorm <= (exponent_b == 0);
                large_norm_small_denorm <= (exponent_a != 0) & (exponent_b == 0);
            end else begin
                exponent_large <= exponent_b;
                exponent_small <= exponent_a;
                large_frac     <= (exponent_b != 0) ? {1'b1, fraction_b, 2'b00}
                                                    : {1'b0, fraction_b, 2'b00};
                small_frac     <= (exponent_a != 0) ? {1'b1, fraction_a, 2'b00}
                                                    : {1'b0, fraction_a, 2'b00};
                large_is_denorm <= (exponent_b == 0);
                small_is_denorm <= (exponent_a == 0);
                large_norm_small_denorm <= (exponent_b != 0) & (exponent_a == 0);
            end
            sign_r2 <= sign_r1;

            // Cycle 3: Exponent diff and alignment shift
            exponent_diff    <= exponent_large - exponent_small - large_norm_small_denorm;
            large_frac_r     <= large_frac;
            exponent_r       <= exponent_large;
            small_is_nonzero <= (small_frac != 0);
            if (exponent_diff > 55)
                small_shift <= 0;
            else
                small_shift <= small_frac >> exponent_diff;
            sign_r3 <= sign_r2;

            // Cycle 4: Sticky bit preservation
            small_shift_nonzero   <= (small_shift != 0);
            small_fraction_enable <= small_is_nonzero & (small_shift == 0);
            if (small_is_nonzero & (small_shift == 0))
                small_shift_3 <= {54'b0, 1'b1};
            else
                small_shift_3 <= small_shift;
            large_frac_r2     <= large_frac_r;
            exponent_r2       <= exponent_r;
            large_is_denorm_r <= large_is_denorm;
            sign_r4           <= sign_r3;

            // Cycle 5: Addition
            sum              <= {1'b0, large_frac_r2} + {1'b0, small_shift_3};
            exponent_r3      <= exponent_r2;
            large_is_denorm_r2 <= large_is_denorm_r;
            sign             <= sign_r4;

            // Cycle 6: Carry normalisation + denorm-to-norm correction
            begin
                reg [55:0] sum_norm;
                reg [10:0] exp_norm;
                reg        sum_leading_one;
                reg        denorm_to_norm;
                reg [10:0] exponent;

                if (sum[55]) begin
                    sum_norm = sum >> 1;
                    exp_norm = exponent_r3 + 1;
                end else begin
                    sum_norm = sum;
                    exp_norm = exponent_r3;
                end

                sum_leading_one = sum_norm[54];
                denorm_to_norm  = sum_leading_one & large_is_denorm_r2;
                exponent        = denorm_to_norm ? exp_norm + 1 : exp_norm;

                sum_2      <= sum_norm;
                exponent_2 <= exponent;
            end

        end
    end

endmodule
