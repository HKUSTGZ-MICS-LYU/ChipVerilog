module fpu_addsub (
    input clk,
    input rst,
    input enable,
    input fpu_op,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output reg [63:0] out,
    output reg ready
);

    reg [63:0] outfp;

    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10,
              rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;

    reg sign, sign_a, sign_b;
    reg fpu_op_1, fpu_op_2, fpu_op_3, fpu_op_final;
    reg fpuf_2, fpuf_3, fpuf_4, fpuf_5, fpuf_6, fpuf_7, fpuf_8, fpuf_9, fpuf_10,
        fpuf_11, fpuf_12, fpuf_13, fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18,
        fpuf_19, fpuf_20, fpuf_21;

    reg sign_a2, sign_a3, sign_b2, sign_b3;
    reg sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10,
        sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19;

    reg [10:0] exponent_a, exponent_b;
    reg [10:0] expa_2, expb_2, expa_3, expb_3;
    reg [51:0] mantissa_a, mantissa_b;
    reg [51:0] mana_2, mana_3, manb_2, manb_3;

    reg expa_et_inf, expb_et_inf, input_is_inf;
    reg in_inf2, in_inf3, in_inf4, in_inf5, in_inf6, in_inf7, in_inf8, in_inf9,
        in_inf10, in_inf11, in_inf12, in_inf13, in_inf14, in_inf15, in_inf16,
        in_inf17, in_inf18, in_inf19, in_inf20, in_inf21;

    reg expa_gt_expb, expa_et_expb, mana_gtet_manb, a_gtet_b;
    reg [10:0] exponent_small, exponent_large;
    reg [10:0] expl_2, expl_3, expl_4, expl_5, expl_6, expl_7, expl_8, expl_9,
               expl_10, expl_11;
    reg [51:0] mantissa_small, mantissa_large;
    reg [51:0] mantissa_small_2, mantissa_large_2, mantissa_small_3, mantissa_large_3;
    reg exp_small_et0, exp_large_et0;
    reg exp_small_et0_2, exp_large_et0_2;
    reg [10:0] exponent_diff;
    reg [10:0] exponent_diff_2, exponent_diff_3;
    reg [107:0] bits_shifted_out;
    reg [107:0] bits_shifted_out_2;
    reg bits_shifted;
    reg [55:0] large_add, large_add_2, large_add_3, large_add_4, large_add_5;
    reg [55:0] small_add, small_shift, small_shift_2, small_shift_3, small_shift_4;
    reg small_shift_nonzero, small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
    reg small_fraction_enable;
    wire [55:0] small_shift_LSB = {55'b0, 1'b1};
    reg [55:0] sum, sum_2, sum_3, sum_4, sum_5, sum_6, sum_7, sum_8, sum_9,
               sum_10, sum_11;
    reg sum_overflow, sumround_overflow, sum_lsb, sum_lsb_2;
    reg [10:0] exponent_add, exp_add_2, exponent_sub, exp_sub_2, exp_sub_3,
               exp_sub_4, exp_sub_5, exp_sub_6, exp_sub_7, exp_sub_8,
               exp_add_3, exp_add_4, exp_add_5, exp_add_6, exp_add_7, exp_add_8, exp_add_9;
    reg [5:0] diff_shift, diff_shift_2;
    reg [55:0] diff, diff_2, diff_3, diff_4, diff_5, diff_6, diff_7, diff_8,
               diff_9, diff_10, diff_11;
    reg diffshift_gt_exponent, diffshift_et_55, diffround_overflow;
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;
    reg count_ready, count_ready_0;
    reg [4:0] count;

    // Pipeline valid propagation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_2 <= 1'b0; fpuf_3 <= 1'b0; fpuf_4 <= 1'b0; fpuf_5 <= 1'b0;
            fpuf_6 <= 1'b0; fpuf_7 <= 1'b0; fpuf_8 <= 1'b0; fpuf_9 <= 1'b0;
            fpuf_10 <= 1'b0; fpuf_11 <= 1'b0; fpuf_12 <= 1'b0; fpuf_13 <= 1'b0;
            fpuf_14 <= 1'b0; fpuf_15 <= 1'b0; fpuf_16 <= 1'b0; fpuf_17 <= 1'b0;
            fpuf_18 <= 1'b0; fpuf_19 <= 1'b0; fpuf_20 <= 1'b0; fpuf_21 <= 1'b0;
            count <= 5'd0;
            count_ready <= 1'b0;
            ready <= 1'b0;
        end else if (enable) begin
            fpuf_2 <= 1'b1;  // Assume valid from stage1
            fpuf_3 <= fpuf_2; fpuf_4 <= fpuf_3; fpuf_5 <= fpuf_4;
            fpuf_6 <= fpuf_5; fpuf_7 <= fpuf_6; fpuf_8 <= fpuf_7;
            fpuf_9 <= fpuf_8; fpuf_10 <= fpuf_9; fpuf_11 <= fpuf_10;
            fpuf_12 <= fpuf_11; fpuf_13 <= fpuf_12; fpuf_14 <= fpuf_13;
            fpuf_15 <= fpuf_14; fpuf_16 <= fpuf_15; fpuf_17 <= fpuf_16;
            fpuf_18 <= fpuf_17; fpuf_19 <= fpuf_18; fpuf_20 <= fpuf_19;
            fpuf_21 <= fpuf_20;
            // ready delay
            count <= count + 5'd1;
            if (count == 5'd21)
                count_ready <= 1'b1;
            ready <= count_ready;
        end else begin
            fpuf_2 <= 1'b0; fpuf_3 <= 1'b0; fpuf_4 <= 1'b0; fpuf_5 <= 1'b0;
            fpuf_6 <= 1'b0; fpuf_7 <= 1'b0; fpuf_8 <= 1'b0; fpuf_9 <= 1'b0;
            fpuf_10 <= 1'b0; fpuf_11 <= 1'b0; fpuf_12 <= 1'b0; fpuf_13 <= 1'b0;
            fpuf_14 <= 1'b0; fpuf_15 <= 1'b0; fpuf_16 <= 1'b0; fpuf_17 <= 1'b0;
            fpuf_18 <= 1'b0; fpuf_19 <= 1'b0; fpuf_20 <= 1'b0; fpuf_21 <= 1'b0;
            count <= 5'd0;
            count_ready <= 1'b0;
            ready <= 1'b0;
        end
    end

    // Stage 0: Input decode
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_a <= 1'b0; sign_b <= 1'b0;
            exponent_a <= 11'd0; exponent_b <= 11'd0;
            mantissa_a <= 52'd0; mantissa_b <= 52'd0;
            rm_1 <= 2'b00; fpu_op_1 <= 1'b0;
            expa_et_inf <= 1'b0; expb_et_inf <= 1'b0; input_is_inf <= 1'b0;
            in_inf2 <= 1'b0;
        end else if (enable) begin
            sign_a <= opa[63];
            sign_b <= opb[63];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            rm_1 <= rmode;
            fpu_op_1 <= fpu_op;
            expa_et_inf <= (opa[62:52] == 11'h7FF);
            expb_et_inf <= (opb[62:52] == 11'h7FF);
            input_is_inf <= (opa[62:52] == 11'h7FF && opa[51:0] == 52'b0) ||
                            (opb[62:52] == 11'h7FF && opb[51:0] == 52'b0);
            in_inf2 <= input_is_inf;
        end
    end

    // Stage 1: Effective operation, exponent comparison
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpu_op_final <= 1'b0;
            fpu_op_2 <= 1'b0; fpu_op_3 <= 1'b0;
            expa_2 <= 11'd0; expb_2 <= 11'd0;
            mana_2 <= 52'd0; manb_2 <= 52'd0;
            sign_2 <= 1'b0; sign_a2 <= 1'b0; sign_b2 <= 1'b0;
            in_inf3 <= 1'b0;
            expa_gt_expb <= 1'b0; expa_et_expb <= 1'b0;
            exponent_small <= 11'd0; exponent_large <= 11'd0;
            mantissa_small <= 52'd0; mantissa_large <= 52'd0;
            a_gtet_b <= 1'b0;
            exp_small_et0 <= 1'b0; exp_large_et0 <= 1'b0;
        end else if (enable) begin
            fpu_op_final <= fpu_op_1 ^ (sign_a ^ sign_b);
            fpu_op_2 <= fpu_op_1;
            fpu_op_3 <= fpu_op_2;
            expa_2 <= exponent_a;
            expb_2 <= exponent_b;
            mana_2 <= mantissa_a;
            manb_2 <= mantissa_b;
            sign_2 <= sign;
            sign_a2 <= sign_a;
            sign_b2 <= sign_b;
            in_inf3 <= in_inf2;
            expa_gt_expb <= (exponent_a > exponent_b);
            expa_et_expb <= (exponent_a == exponent_b);
            {exponent_small, exponent_large, mantissa_small, mantissa_large, a_gtet_b} <= 
                (exponent_a > exponent_b || (exponent_a == exponent_b && mantissa_a >= mantissa_b)) ?
                {exponent_b, exponent_a, mantissa_b, mantissa_a, 1'b1} :
                {exponent_a, exponent_b, mantissa_a, mantissa_b, 1'b0};
            exp_small_et0 <= (exponent_small == 11'd0);
            exp_large_et0 <= (exponent_large == 11'd0);
        end
    end

    // Stage 2: Exponent difference, shift small mantissa
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent_diff <= 11'd0;
            exponent_diff_2 <= 11'd0;
            expa_3 <= 11'd0; expb_3 <= 11'd0;
            mana_3 <= 52'd0; manb_3 <= 52'd0;
            sign_3 <= 1'b0; sign_a3 <= 1'b0; sign_b3 <= 1'b0;
            in_inf4 <= 1'b0;
            mantissa_small_2 <= 52'd0; mantissa_large_2 <= 52'd0;
            exp_small_et0_2 <= 1'b0; exp_large_et0_2 <= 1'b0;
            large_add <= 56'd0;
            small_shift <= 56'd0;
            bits_shifted_out <= 108'd0;
            small_shift_nonzero <= 1'b0;
            small_is_nonzero <= 1'b0;
            small_fraction_enable <= 1'b0;
            diff_shift <= 6'd0;
        end else if (enable) begin
            exponent_diff <= exponent_large - exponent_small;
            exponent_diff_2 <= exponent_diff;
            expa_3 <= expa_2;
            expb_3 <= expb_2;
            mana_3 <= mana_2;
            manb_3 <= manb_2;
            sign_3 <= sign_2;
            sign_a3 <= sign_a2;
            sign_b3 <= sign_b2;
            in_inf4 <= in_inf3;
            mantissa_small_2 <= mantissa_small;
            mantissa_large_2 <= mantissa_large;
            exp_small_et0_2 <= exp_small_et0;
            exp_large_et0_2 <= exp_large_et0;
            // Build significands with implicit bit and guard bits
            large_add <= {1'b1, mantissa_large, 3'b0};
            // Align small: shift right by exponent_diff (max 55 bits for double)
            if (exponent_diff <= 55)
                small_shift <= {1'b1, mantissa_small, 3'b0} >> exponent_diff;
            else
                small_shift <= 56'd0;
            // Shifted out bits for sticky
            bits_shifted_out <= { {108-56{1'b0}}, small_shift[55:0] }; // placeholder
            small_shift_nonzero <= (small_shift != 56'd0);
            small_is_nonzero <= (mantissa_small != 52'd0) || exponent_small != 11'd0;
            small_fraction_enable <= (exponent_diff <= 54);
            diff_shift <= (exponent_diff > 55) ? 6'd55 : exponent_diff[5:0];
        end
    end

    // Stage 3: Add/subtract significands
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum <= 56'd0;
            sum_2 <= 56'd0;
            large_add_2 <= 56'd0;
            small_shift_2 <= 56'd0;
            sign_4 <= 1'b0;
            in_inf5 <= 1'b0;
            bits_shifted_out_2 <= 108'd0;
            diff <= 56'd0;
            diff_shift_2 <= 6'd0;
            small_is_nonzero_2 <= 1'b0;
            exp_sub_2 <= 11'd0; exp_add_2 <= 11'd0;
            sum_lsb <= 1'b0;
        end else if (enable) begin
            large_add_2 <= large_add;
            small_shift_2 <= small_shift;
            sign_4 <= sign_3;
            in_inf5 <= in_inf4;
            bits_shifted_out_2 <= bits_shifted_out;
            small_is_nonzero_2 <= small_is_nonzero;
            diff_shift_2 <= diff_shift;
            sum_lsb <= sum[0]; // before update
            if (fpu_op_final == 1'b0) begin // Add
                sum <= large_add + small_shift;
                exp_add_2 <= exponent_large;
                exp_sub_2 <= 11'd0;
                diff <= 56'd0;
            end else begin // Subtract
                if (a_gtet_b) begin
                    sum <= large_add - small_shift;
                    exp_sub_2 <= exponent_large;
                    exp_add_2 <= 11'd0;
                    diff <= large_add - small_shift;
                end else begin
                    sum <= small_shift - large_add;
                    exp_sub_2 <= exponent_small;
                    exp_add_2 <= 11'd0;
                    diff <= small_shift - large_add;
                    sign_4 <= ~sign_3;
                end
            end
            sum_2 <= sum;
        end
    end

    // Stage 4: Normalization (leading zero count)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_3 <= 56'd0; sum_4 <= 56'd0; sum_5 <= 56'd0;
            exp_add_3 <= 11'd0; exp_add_4 <= 11'd0; exp_add_5 <= 11'd0;
            exp_sub_3 <= 11'd0; exp_sub_4 <= 11'd0; exp_sub_5 <= 11'd0;
            sign_5 <= 1'b0; sign_6 <= 1'b0; sign_7 <= 1'b0;
            in_inf6 <= 1'b0; in_inf7 <= 1'b0; in_inf8 <= 1'b0;
            large_add_3 <= 56'd0; large_add_4 <= 56'd0; large_add_5 <= 56'd0;
            small_shift_3 <= 56'd0; small_shift_4 <= 56'd0;
            sum_overflow <= 1'b0;
            sum_lsb_2 <= 1'b0;
            exp_sub_6 <= 11'd0; exp_add_6 <= 11'd0;
            diff_2 <= 56'd0; diff_3 <= 56'd0;
            bits_shifted <= 1'b0;
        end else if (enable) begin
            sum_3 <= sum_2;
            sum_4 <= sum_3;
            sum_5 <= sum_4;
            exp_add_3 <= exp_add_2; exp_add_4 <= exp_add_3; exp_add_5 <= exp_add_4;
            exp_sub_3 <= exp_sub_2; exp_sub_4 <= exp_sub_3; exp_sub_5 <= exp_sub_4;
            sign_5 <= sign_4; sign_6 <= sign_5; sign_7 <= sign_6;
            in_inf6 <= in_inf5; in_inf7 <= in_inf6; in_inf8 <= in_inf7;
            large_add_3 <= large_add_2; large_add_4 <= large_add_3; large_add_5 <= large_add_4;
            small_shift_3 <= small_shift_2; small_shift_4 <= small_shift_3;
            sum_lsb_2 <= sum_lsb;
            exp_sub_6 <= exp_sub_5;
            exp_add_6 <= exp_add_5;
            diff_2 <= diff; diff_3 <= diff_2;
            // Detect overflow after add: if sum[55] == 1 (considering 56 bits)
            sum_overflow <= (sum_2[55] == 1'b1 && fpu_op_final == 1'b0);
            // Bits shifted out sticky flag
            bits_shifted <= (bits_shifted_out_2 != 108'd0) || small_is_nonzero_2;
        end
    end

    // Stage 5,6,7: More normalization and rounding
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_6 <= 56'd0; sum_7 <= 56'd0; sum_8 <= 56'd0; sum_9 <= 56'd0;
            sum_10 <= 56'd0; sum_11 <= 56'd0;
            exp_add_7 <= 11'd0; exp_add_8 <= 11'd0; exp_add_9 <= 11'd0;
            exp_sub_7 <= 11'd0; exp_sub_8 <= 11'd0;
            sign_8 <= 1'b0; sign_9 <= 1'b0; sign_10 <= 1'b0; sign_11 <= 1'b0;
            sign_12 <= 1'b0; sign_13 <= 1'b0; sign_14 <= 1'b0; sign_15 <= 1'b0;
            sign_16 <= 1'b0; sign_17 <= 1'b0; sign_18 <= 1'b0; sign_19 <= 1'b0;
            in_inf9 <= 1'b0; in_inf10 <= 1'b0; in_inf11 <= 1'b0; in_inf12 <= 1'b0;
            in_inf13 <= 1'b0; in_inf14 <= 1'b0; in_inf15 <= 1'b0; in_inf16 <= 1'b0;
            in_inf17 <= 1'b0; in_inf18 <= 1'b0; in_inf19 <= 1'b0; in_inf20 <= 1'b0;
            in_inf21 <= 1'b0;
            rm_2 <= 2'b00; rm_3 <= 2'b00; rm_4 <= 2'b00; rm_5 <= 2'b00;
            rm_6 <= 2'b00; rm_7 <= 2'b00; rm_8 <= 2'b00; rm_9 <= 2'b00;
            rm_10 <= 2'b00; rm_11 <= 2'b00; rm_12 <= 2'b00; rm_13 <= 2'b00;
            rm_14 <= 2'b00; rm_15 <= 2'b00; rm_16 <= 2'b00;
            diff_4 <= 56'd0; diff_5 <= 56'd0; diff_6 <= 56'd0; diff_7 <= 56'd0;
            diff_8 <= 56'd0; diff_9 <= 56'd0; diff_10 <= 56'd0; diff_11 <= 56'd0;
            difference_overflow <= 1'b0;
            round_nearest_mode <= 1'b0; round_posinf_mode <= 1'b0; round_neginf_mode <= 1'b0;
            round_nearest_trigger <= 1'b0; round_nearest_exception <= 1'b0; round_nearest_enable <= 1'b0;
            round_posinf_trigger <= 1'b0; round_posinf_enable <= 1'b0;
            round_neginf_trigger <= 1'b0; round_neginf_enable <= 1'b0;
            round_enable <= 1'b0;
        end else if (enable) begin
            sum_6 <= sum_5; sum_7 <= sum_6; sum_8 <= sum_7; sum_9 <= sum_8;
            sum_10 <= sum_9; sum_11 <= sum_10;
            exp_add_7 <= exp_add_6; exp_add_8 <= exp_add_7; exp_add_9 <= exp_add_8;
            exp_sub_7 <= exp_sub_6; exp_sub_8 <= exp_sub_7;
            sign_8 <= sign_7; sign_9 <= sign_8; sign_10 <= sign_9; sign_11 <= sign_10;
            sign_12 <= sign_11; sign_13 <= sign_12; sign_14 <= sign_13; sign_15 <= sign_14;
            sign_16 <= sign_15; sign_17 <= sign_16; sign_18 <= sign_17; sign_19 <= sign_18;
            in_inf9 <= in_inf8; in_inf10 <= in_inf9; in_inf11 <= in_inf10; in_inf12 <= in_inf11;
            in_inf13 <= in_inf12; in_inf14 <= in_inf13; in_inf15 <= in_inf14; in_inf16 <= in_inf15;
            in_inf17 <= in_inf16; in_inf18 <= in_inf17; in_inf19 <= in_inf18; in_inf20 <= in_inf19;
            in_inf21 <= in_inf20;
            rm_2 <= rm_1; rm_3 <= rm_2; rm_4 <= rm_3; rm_5 <= rm_4; rm_6 <= rm_5;
            rm_7 <= rm_6; rm_8 <= rm_7; rm_9 <= rm_8; rm_10 <= rm_9; rm_11 <= rm_10;
            rm_12 <= rm_11; rm_13 <= rm_12; rm_14 <= rm_13; rm_15 <= rm_14; rm_16 <= rm_15;
            diff_4 <= diff_3; diff_5 <= diff_4; diff_6 <= diff_5; diff_7 <= diff_6;
            diff_8 <= diff_7; diff_9 <= diff_8; diff_10 <= diff_9; diff_11 <= diff_10;

            // Rounding mode decoding
            round_nearest_mode <= (rm_1 == 2'b00);
            round_posinf_mode <= (rm_1 == 2'b10);
            round_neginf_mode <= (rm_1 == 2'b11);
            // Round trigger based on sum LSB and guard/round/sticky
            // Simplified: trigger when LSB=1 and guard=1
            round_nearest_trigger <= (sum_5[1] & sum_5[0]) || (sum_5[1] & bits_shifted);
            round_nearest_exception <= 1'b0; // Placeholder
            round_nearest_enable <= round_nearest_mode & round_nearest_trigger;
            round_posinf_trigger <= (sign_7 == 1'b0) & (sum_5[1] | bits_shifted);
            round_posinf_enable <= round_posinf_mode & round_posinf_trigger;
            round_neginf_trigger <= (sign_7 == 1'b1) & (sum_5[1] | bits_shifted);
            round_neginf_enable <= round_neginf_mode & round_neginf_trigger;
            round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;
        end
    end

    // Final stage: Result generation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            outfp <= 64'd0;
            out <= 64'd0;
        end else if (enable && fpuf_21) begin
            // Combine sign, exponent, mantissa
            outfp[63] <= sign_19;
            // Normalized exponent: either from add path or sub path
            if (exp_add_9 != 11'd0) begin
                outfp[62:52] <= exp_add_9 + sum_overflow;
                outfp[51:0] <= sum_11[54:3]; // drop guard bits
            end else begin
                outfp[62:52] <= exp_sub_8 - (diff_11[55] ? 1 : 0); // adjust for normalization
                outfp[51:0] <= diff_11[54:3];
            end
            // Infinity handling
            if (in_inf21) begin
                outfp[62:52] <= 11'h7FF;
                outfp[51:0] <= 52'b0;
            end
            out <= outfp;
        end
    end

endmodule
