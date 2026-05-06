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
    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10;
    reg [1:0] rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;
    reg sign;
    reg sign_a;
    reg sign_b;
    reg fpu_op_1, fpu_op_2, fpu_op_3;
    reg fpu_op_final;
    reg fpuf_2, fpuf_3, fpuf_4, fpuf_5, fpuf_6, fpuf_7, fpuf_8, fpuf_9, fpuf_10;
    reg fpuf_11, fpuf_12, fpuf_13, fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18, fpuf_19, fpuf_20, fpuf_21;
    reg sign_a2, sign_a3, sign_b2, sign_b3;
    reg sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10;
    reg sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19;
    reg [10:0] exponent_a, exponent_b;
    reg [10:0] expa_2, expb_2, expa_3, expb_3;
    reg [51:0] mantissa_a, mantissa_b;
    reg [51:0] mana_2, mana_3, manb_2, manb_3;
    reg expa_et_inf, expb_et_inf, input_is_inf;
    reg in_inf2, in_inf3, in_inf4, in_inf5, in_inf6, in_inf7, in_inf8, in_inf9, in_inf10;
    reg in_inf11, in_inf12, in_inf13, in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19, in_inf20, in_inf21;
    reg expa_gt_expb, expa_et_expb, mana_gtet_manb, a_gtet_b;
    reg [10:0] exponent_small, exponent_large;
    reg [10:0] expl_2, expl_3, expl_4, expl_5, expl_6, expl_7, expl_8, expl_9, expl_10, expl_11;
    reg [51:0] mantissa_small, mantissa_large;
    reg [51:0] mantissa_small_2, mantissa_large_2, mantissa_small_3, mantissa_large_3;
    reg exp_small_et0, exp_large_et0, exp_small_et0_2, exp_large_et0_2;
    reg [10:0] exponent_diff, exponent_diff_2, exponent_diff_3;
    reg [107:0] bits_shifted_out, bits_shifted_out_2;
    reg bits_shifted;
    reg [55:0] large_add, large_add_2, large_add_3, large_add_4, large_add_5;
    reg [55:0] small_add, small_shift, small_shift_2, small_shift_3, small_shift_4;
    reg small_shift_nonzero, small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
    reg small_fraction_enable;
    wire [55:0] small_shift_LSB = {55'b0, 1'b1};
    reg [55:0] sum, sum_2, sum_3, sum_4, sum_5, sum_6, sum_7, sum_8, sum_9, sum_10, sum_11;
    reg sum_overflow, sumround_overflow;
    reg sum_lsb, sum_lsb_2;
    reg [10:0] exponent_add, exp_add_2, exp_add_3, exp_add_4, exp_add_5, exp_add_6, exp_add_7, exp_add_8, exp_add_9;
    reg [10:0] exponent_sub, exp_sub_2, exp_sub_3, exp_sub_4, exp_sub_5, exp_sub_6, exp_sub_7, exp_sub_8;
    reg [5:0] diff_shift, diff_shift_2;
    reg [55:0] diff, diff_2, diff_3, diff_4, diff_5, diff_6, diff_7, diff_8, diff_9, diff_10, diff_11;
    reg diffshift_gt_exponent, diffshift_et_55, diffround_overflow;
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;
    reg count_ready, count_ready_0;
    reg [4:0] count;

    // Stage 1: unpack and prepare
    always @(posedge clk) begin
        if (rst) begin
            sign_a <= 1'b0;
            sign_b <= 1'b0;
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            mantissa_a <= 52'd0;
            mantissa_b <= 52'd0;
            fpu_op_1 <= 1'b0;
            rm_1 <= 2'b0;
            expa_et_inf <= 1'b0;
            expb_et_inf <= 1'b0;
            input_is_inf <= 1'b0;
            count_ready_0 <= 1'b0;
        end else if (enable) begin
            sign_a <= opa[63];
            sign_b <= opb[63];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            fpu_op_1 <= fpu_op;
            rm_1 <= rmode;
            expa_et_inf <= (opa[62:52] == 11'h7FF);
            expb_et_inf <= (opb[62:52] == 11'h7FF);
            input_is_inf <= (opa[62:52] == 11'h7FF) | (opb[62:52] == 11'h7FF);
            count_ready_0 <= 1'b1;
        end
    end

    // Stage 2: pipeline copies and initial compare
    always @(posedge clk) begin
        if (rst) begin
            sign_a2 <= 1'b0; sign_b2 <= 1'b0;
            expa_2 <= 11'd0; expb_2 <= 11'd0;
            mana_2 <= 52'd0; manb_2 <= 52'd0;
            fpu_op_2 <= 1'b0; rm_2 <= 2'b0;
            in_inf2 <= 1'b0;
            fpuf_2 <= 1'b0;
            expa_gt_expb <= 1'b0;
            expa_et_expb <= 1'b0;
            count_ready <= 1'b0;
        end else if (enable) begin
            sign_a2 <= sign_a; sign_b2 <= sign_b;
            expa_2 <= exponent_a; expb_2 <= exponent_b;
            mana_2 <= mantissa_a; manb_2 <= mantissa_b;
            fpu_op_2 <= fpu_op_1; rm_2 <= rm_1;
            in_inf2 <= input_is_inf;
            fpuf_2 <= count_ready_0;
            expa_gt_expb <= (exponent_a > exponent_b);
            expa_et_expb <= (exponent_a == exponent_b);
            count_ready <= count_ready_0;
        end
    end

    // Stage 3: effective operation, select large/small, compute diff
    always @(posedge clk) begin
        if (rst) begin
            fpu_op_final <= 1'b0;
            fpu_op_3 <= 1'b0;
            sign_a3 <= 1'b0; sign_b3 <= 1'b0;
            expa_3 <= 11'd0; expb_3 <= 11'd0;
            mana_3 <= 52'd0; manb_3 <= 52'd0;
            rm_3 <= 2'b0;
            in_inf3 <= 1'b0;
            fpuf_3 <= 1'b0;
            exponent_small <= 11'd0;
            exponent_large <= 11'd0;
            mantissa_small <= 52'd0;
            mantissa_large <= 52'd0;
            exponent_diff <= 11'd0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b <= 1'b0;
            sign <= 1'b0;
            exp_small_et0 <= 1'b0;
            exp_large_et0 <= 1'b0;
        end else if (enable) begin
            fpu_op_final <= fpu_op_2 ^ (sign_a2 ^ sign_b2);
            fpu_op_3 <= fpu_op_2;
            sign_a3 <= sign_a2; sign_b3 <= sign_b2;
            expa_3 <= expa_2; expb_3 <= expb_2;
            mana_3 <= mana_2; manb_3 <= manb_2;
            rm_3 <= rm_2;
            in_inf3 <= in_inf2;
            fpuf_3 <= fpuf_2;
            if (expa_gt_expb) begin
                exponent_small <= expb_2;
                exponent_large <= expa_2;
                mantissa_small <= manb_2;
                mantissa_large <= mana_2;
                exponent_diff <= expa_2 - expb_2;
            end else begin
                exponent_small <= expa_2;
                exponent_large <= expb_2;
                mantissa_small <= mana_2;
                mantissa_large <= manb_2;
                exponent_diff <= expb_2 - expa_2;
            end
            mana_gtet_manb <= (mana_2 >= manb_2);
            a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);
            sign <= (fpu_op_final) ? (~a_gtet_b) : sign_a2;
            exp_small_et0 <= (exponent_small == 11'd0);
            exp_large_et0 <= (exponent_large == 11'd0);
        end
    end

    // Stage 4: shift small mantissa, prepare large add
    always @(posedge clk) begin
        if (rst) begin
            small_add <= 56'd0; large_add <= 56'd0;
            small_shift_nonzero <= 1'b0;
            small_is_nonzero <= 1'b0;
            small_fraction_enable <= 1'b0;
            bits_shifted_out <= 108'd0;
            bits_shifted <= 1'b0;
            sign_2 <= 1'b0;
            rm_4 <= 2'b0; in_inf4 <= 1'b0; fpuf_4 <= 1'b0;
            expl_2 <= 11'd0;
            exp_small_et0_2 <= 1'b0; exp_large_et0_2 <= 1'b0;
            exponent_diff_2 <= 11'd0;
            mantissa_small_2 <= 52'd0; mantissa_large_2 <= 52'd0;
        end else if (enable) begin
            sign_2 <= sign;
            rm_4 <= rm_3;
            in_inf4 <= in_inf3;
            fpuf_4 <= fpuf_3;
            expl_2 <= exponent_large;
            exp_small_et0_2 <= exp_small_et0;
            exp_large_et0_2 <= exp_large_et0;
            exponent_diff_2 <= exponent_diff;
            mantissa_small_2 <= mantissa_small;
            mantissa_large_2 <= mantissa_large;

            // Build large_add: implicit 1 or 0
            if (exp_large_et0)
                large_add <= {1'b0, mantissa_large, 3'b0};
            else
                large_add <= {1'b1, mantissa_large, 3'b0};

            // Build small_add and shift
            if (exp_small_et0)
                small_add <= {1'b0, mantissa_small, 3'b0};
            else
                small_add <= {1'b1, mantissa_small, 3'b0};

            small_shift_nonzero <= (mantissa_small != 52'd0) | ~exp_small_et0;
            small_is_nonzero <= (mantissa_small != 52'd0) | ~exp_small_et0;
            small_fraction_enable <= (exponent_diff > 11'd55);

            if (exponent_diff > 11'd107) begin
                bits_shifted_out <= 108'd0;
                bits_shifted <= 1'b0;
            end else begin
                bits_shifted_out <= {small_add, 52'd0} >> exponent_diff;
                bits_shifted <= (small_add >> exponent_diff) != 56'd0;
            end
        end
    end

    // Stage 5: final small shift and pipeline
    always @(posedge clk) begin
        if (rst) begin
            small_shift <= 56'd0;
            small_shift_2 <= 56'd0;
            large_add_2 <= 56'd0;
            small_is_nonzero_2 <= 1'b0;
            bits_shifted_out_2 <= 108'd0;
            rm_5 <= 2'b0; in_inf5 <= 1'b0; fpuf_5 <= 1'b0;
            sign_3 <= 1'b0;
            expl_3 <= 11'd0;
            exponent_diff_3 <= 11'd0;
            mantissa_small_3 <= 52'd0; mantissa_large_3 <= 52'd0;
        end else if (enable) begin
            rm_5 <= rm_4; in_inf5 <= in_inf4; fpuf_5 <= fpuf_4;
            sign_3 <= sign_2;
            expl_3 <= expl_2;
            exponent_diff_3 <= exponent_diff_2;
            mantissa_small_3 <= mantissa_small_2;
            mantissa_large_3 <= mantissa_large_2;

            if (small_fraction_enable)
                small_shift <= 56'd0;
            else if (exponent_diff_2 > 11'd55)
                small_shift <= 56'd0;
            else
                small_shift <= small_add >> exponent_diff_2;

            small_shift_2 <= small_shift;
            large_add_2 <= large_add;
            small_is_nonzero_2 <= small_is_nonzero;
            bits_shifted_out_2 <= bits_shifted_out;
        end
    end

    // Stage 6: sum or diff
    always @(posedge clk) begin
        if (rst) begin
            sum <= 56'd0;
            diff <= 56'd0;
            exponent_add <= 11'd0;
            exponent_sub <= 11'd0;
            small_shift_3 <= 56'd0;
            large_add_3 <= 56'd0;
            small_is_nonzero_3 <= 1'b0;
            rm_6 <= 2'b0; in_inf6 <= 1'b0; fpuf_6 <= 1'b0;
            sign_4 <= 1'b0;
            expl_4 <= 11'd0;
        end else if (enable) begin
            rm_6 <= rm_5; in_inf6 <= in_inf5; fpuf_6 <= fpuf_5;
            sign_4 <= sign_3;
            expl_4 <= expl_3;
            small_shift_3 <= small_shift_2;
            large_add_3 <= large_add_2;
            small_is_nonzero_3 <= small_is_nonzero_2;

            if (~fpu_op_3) begin
                sum <= large_add_2 + small_shift_2;
                exponent_add <= expl_3;
                diff <= 56'd0;
                exponent_sub <= 11'd0;
            end else begin
                sum <= 56'd0;
                exponent_add <= 11'd0;
                if (a_gtet_b) begin
                    diff <= large_add_2 - small_shift_2;
                    exponent_sub <= expl_3;
                end else begin
                    diff <= small_shift_2 - large_add_2;
                    exponent_sub <= expl_3;
                end
            end
        end
    end

    // Stage 7: pipeline sum and diff
    always @(posedge clk) begin
        if (rst) begin
            sum_2 <= 56'd0; diff_2 <= 56'd0;
            exp_add_2 <= 11'd0; exp_sub_2 <= 11'd0;
            small_shift_4 <= 56'd0; large_add_4 <= 56'd0;
            rm_7 <= 2'b0; in_inf7 <= 1'b0; fpuf_7 <= 1'b0;
            sign_5 <= 1'b0;
            expl_5 <= 11'd0;
            sum_lsb <= 1'b0;
        end else if (enable) begin
            rm_7 <= rm_6; in_inf7 <= in_inf6; fpuf_7 <= fpuf_6;
            sign_5 <= sign_4;
            expl_5 <= expl_4;
            sum_2 <= sum;
            diff_2 <= diff;
            exp_add_2 <= exponent_add;
            exp_sub_2 <= exponent_sub;
            small_shift_4 <= small_shift_3;
            large_add_4 <= large_add_3;
            sum_lsb <= sum[0];
        end
    end

    // Stage 8: overflow and first normalization
    always @(posedge clk) begin
        if (rst) begin
            sum_3 <= 56'd0; diff_3 <= 56'd0;
            exp_add_3 <= 11'd0; exp_sub_3 <= 11'd0;
            sum_overflow <= 1'b0;
            rm_8 <= 2'b0; in_inf8 <= 1'b0; fpuf_8 <= 1'b0;
            sign_6 <= 1'b0;
            expl_6 <= 11'd0;
            sum_lsb_2 <= 1'b0;
            diff_shift <= 6'd0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
        end else if (enable) begin
            rm_8 <= rm_7; in_inf8 <= in_inf7; fpuf_8 <= fpuf_7;
            sign_6 <= sign_5;
            expl_6 <= expl_5;
            sum_3 <= sum_2;
            diff_3 <= diff_2;
            exp_add_3 <= exp_add_2;
            exp_sub_3 <= exp_sub_2;
            sum_lsb_2 <= sum_lsb;
            sum_overflow <= sum_2[55];

            if (diff_2[55]) diff_shift <= 6'd0;
            else if (diff_2[54]) diff_shift <= 6'd1;
            else if (diff_2[53]) diff_shift <= 6'd2;
            else if (diff_2[52]) diff_shift <= 6'd3;
            else if (diff_2[51]) diff_shift <= 6'd4;
            else if (diff_2[50]) diff_shift <= 6'd5;
            else if (diff_2[49]) diff_shift <= 6'd6;
            else if (diff_2[48]) diff_shift <= 6'd7;
            else if (diff_2[47]) diff_shift <= 6'd8;
            else if (diff_2[46]) diff_shift <= 6'd9;
            else if (diff_2[45]) diff_shift <= 6'd10;
            else if (diff_2[44]) diff_shift <= 6'd11;
            else if (diff_2[43]) diff_shift <= 6'd12;
            else if (diff_2[42]) diff_shift <= 6'd13;
            else if (diff_2[41]) diff_shift <= 6'd14;
            else if (diff_2[40]) diff_shift <= 6'd15;
            else if (diff_2[39]) diff_shift <= 6'd16;
            else if (diff_2[38]) diff_shift <= 6'd17;
            else if (diff_2[37]) diff_shift <= 6'd18;
            else if (diff_2[36]) diff_shift <= 6'd19;
            else if (diff_2[35]) diff_shift <= 6'd20;
            else if (diff_2[34]) diff_shift <= 6'd21;
            else if (diff_2[33]) diff_shift <= 6'd22;
            else if (diff_2[32]) diff_shift <= 6'd23;
            else if (diff_2[31]) diff_shift <= 6'd24;
            else if (diff_2[30]) diff_shift <= 6'd25;
            else if (diff_2[29]) diff_shift <= 6'd26;
            else if (diff_2[28]) diff_shift <= 6'd27;
            else if (diff_2[27]) diff_shift <= 6'd28;
            else if (diff_2[26]) diff_shift <= 6'd29;
            else if (diff_2[25]) diff_shift <= 6'd30;
            else if (diff_2[24]) diff_shift <= 6'd31;
            else if (diff_2[23]) diff_shift <= 6'd32;
            else if (diff_2[22]) diff_shift <= 6'd33;
            else if (diff_2[21]) diff_shift <= 6'd34;
            else if (diff_2[20]) diff_shift <= 6'd35;
            else if (diff_2[19]) diff_shift <= 6'd36;
            else if (diff_2[18]) diff_shift <= 6'd37;
            else if (diff_2[17]) diff_shift <= 6'd38;
            else if (diff_2[16]) diff_shift <= 6'd39;
            else if (diff_2[15]) diff_shift <= 6'd40;
            else if (diff_2[14]) diff_shift <= 6'd41;
            else if (diff_2[13]) diff_shift <= 6'd42;
            else if (diff_2[12]) diff_shift <= 6'd43;
            else if (diff_2[11]) diff_shift <= 6'd44;
            else if (diff_2[10]) diff_shift <= 6'd45;
            else if (diff_2[9])  diff_shift <= 6'd46;
            else if (diff_2[8])  diff_shift <= 6'd47;
            else if (diff_2[7])  diff_shift <= 6'd48;
            else if (diff_2[6])  diff_shift <= 6'd49;
            else if (diff_2[5])  diff_shift <= 6'd50;
            else if (diff_2[4])  diff_shift <= 6'd51;
            else if (diff_2[3])  diff_shift <= 6'd52;
            else if (diff_2[2])  diff_shift <= 6'd53;
            else if (diff_2[1])  diff_shift <= 6'd54;
            else diff_shift <= 6'd55;

            diffshift_gt_exponent <= (diff_shift > exp_sub_2);
            diffshift_et_55 <= (diff_shift == 6'd55);
        end
    end

    // Stage 9: normalize sum and diff
    always @(posedge clk) begin
        if (rst) begin
            sum_4 <= 56'd0; diff_4 <= 56'd0;
            exp_add_4 <= 11'd0; exp_sub_4 <= 11'd0;
            sumround_overflow <= 1'b0;
            rm_9 <= 2'b0; in_inf9 <= 1'b0; fpuf_9 <= 1'b0;
            sign_7 <= 1'b0;
            expl_7 <= 11'd0;
            diff_shift_2 <= 6'd0;
        end else if (enable) begin
            rm_9 <= rm_8; in_inf9 <= in_inf8; fpuf_9 <= fpuf_8;
            sign_7 <= sign_6;
            expl_7 <= expl_6;
            diff_shift_2 <= diff_shift;

            if (sum_overflow) begin
                sum_4 <= {1'b0, sum_3[55:1]};
                exp_add_4 <= exp_add_3 + 11'd1;
            end else begin
                sum_4 <= sum_3;
                exp_add_4 <= exp_add_3;
            end

            if (diffshift_gt_exponent) begin
                diff_4 <= 56'd0;
                exp_sub_4 <= 11'd0;
            end else begin
                diff_4 <= diff_3 << diff_shift;
                exp_sub_4 <= exp_sub_3 - diff_shift;
            end
            sumround_overflow <= (sum_4[2:0] >= 3'b100) ? 1'b1 : 1'b0;
        end
    end

    // Stage 10: rounding preparation
    always @(posedge clk) begin
        if (rst) begin
            sum_5 <= 56'd0; diff_5 <= 56'd0;
            exp_add_5 <= 11'd0; exp_sub_5 <= 11'd0;
            round_nearest_mode <= 1'b0; round_posinf_mode <= 1'b0; round_neginf_mode <= 1'b0;
            round_nearest_trigger <= 1'b0; round_nearest_exception <= 1'b0;
            round_posinf_trigger <= 1'b0; round_neginf_trigger <= 1'b0;
            rm_10 <= 2'b0; in_inf10 <= 1'b0; fpuf_10 <= 1'b0;
            sign_8 <= 1'b0;
            expl_8 <= 11'd0;
        end else if (enable) begin
            rm_10 <= rm_9; in_inf10 <= in_inf9; fpuf_10 <= fpuf_9;
            sign_8 <= sign_7;
            expl_8 <= expl_7;
            sum_5 <= sum_4;
            diff_5 <= diff_4;
            exp_add_5 <= exp_add_4;
            exp_sub_5 <= exp_sub_4;

            round_nearest_mode <= (rm_9 == 2'b00);
            round_posinf_mode <= (rm_9 == 2'b10);
            round_neginf_mode <= (rm_9 == 2'b11);

            round_nearest_trigger <= (sum_4[2] & (sum_4[1] | sum_4[0] | sum_lsb_2));
            round_nearest_exception <= (sum_4[2] & ~sum_4[1] & ~sum_4[0] & ~sum_lsb_2);
            round_posinf_trigger <= (sum_4[2] | sum_4[1] | sum_4[0]) & ~sign_7;
            round_neginf_trigger <= (sum_4[2] | sum_4[1] | sum_4[0]) & sign_7;
        end
    end

    // Stage 11: rounding and normalization
    always @(posedge clk) begin
        if (rst) begin
            sum_6 <= 56'd0; diff_6 <= 56'd0;
            exp_add_6 <= 11'd0; exp_sub_6 <= 11'd0;
            round_enable <= 1'b0;
            rm_11 <= 2'b0; in_inf11 <= 1'b0; fpuf_11 <= 1'b0;
            sign_9 <= 1'b0;
            expl_9 <= 11'd0;
        end else if (enable) begin
            rm_11 <= rm_10; in_inf11 <= in_inf10; fpuf_11 <= fpuf_10;
            sign_9 <= sign_8;
            expl_9 <= expl_8;
            diff_6 <= diff_5;
            exp_sub_6 <= exp_sub_5;

            round_nearest_enable <= round_nearest_mode & round_nearest_trigger;
            round_posinf_enable <= round_posinf_mode & round_posinf_trigger;
            round_neginf_enable <= round_neginf_mode & round_neginf_trigger;
            round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;

            if (round_enable) begin
                sum_6 <= sum_5 + 56'd4;
                exp_add_6 <= exp_add_5;
            end else begin
                sum_6 <= sum_5;
                exp_add_6 <= exp_add_5;
            end

            if (round_enable && sum_6[55]) begin
                exp_add_6 <= exp_add_6 + 11'd1;
                sum_6 <= {1'b0, sum_6[55:1]};
            end
        end
    end

    // Stage 12-15: additional pipeline stages
    always @(posedge clk) begin
        if (rst) begin
            sum_7 <= 56'd0; diff_7 <= 56'd0;
            exp_add_7 <= 11'd0; exp_sub_7 <= 11'd0;
            rm_12 <= 2'b0; in_inf12 <= 1'b0; fpuf_12 <= 1'b0;
            sign_10 <= 1'b0;
            expl_10 <= 11'd0;
        end else if (enable) begin
            rm_12 <= rm_11; in_inf12 <= in_inf11; fpuf_12 <= fpuf_11;
            sign_10 <= sign_9;
            expl_10 <= expl_9;
            sum_7 <= sum_6; diff_7 <= diff_6;
            exp_add_7 <= exp_add_6; exp_sub_7 <= exp_sub_6;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sum_8 <= 56'd0; diff_8 <= 56'd0;
            exp_add_8 <= 11'd0; exp_sub_8 <= 11'd0;
            rm_13 <= 2'b0; in_inf13 <= 1'b0; fpuf_13 <= 1'b0;
            sign_11 <= 1'b0;
            expl_11 <= 11'd0;
        end else if (enable) begin
            rm_13 <= rm_12; in_inf13 <= in_inf12; fpuf_13 <= fpuf_12;
            sign_11 <= sign_10;
            expl_11 <= expl_10;
            sum_8 <= sum_7; diff_8 <= diff_7;
            exp_add_8 <= exp_add_7; exp_sub_8 <= exp_sub_7;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sum_9 <= 56'd0; diff_9 <= 56'd0;
            exp_add_9 <= 11'd0;
            rm_14 <= 2'b0; in_inf14 <= 1'b0; fpuf_14 <= 1'b0;
            sign_12 <= 1'b0;
        end else if (enable) begin
            rm_14 <= rm_13; in_inf14 <= in_inf13; fpuf_14 <= fpuf_13;
            sign_12 <= sign_11;
            sum_9 <= sum_8; diff_9 <= diff_8;
            exp_add_9 <= exp_add_8;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sum_10 <= 56'd0; diff_10 <= 56'd0;
            rm_15 <= 2'b0; in_inf15 <= 1'b0; fpuf_15 <= 1'b0;
            sign_13 <= 1'b0;
        end else if (enable) begin
            rm_15 <= rm_14; in_inf15 <= in_inf14; fpuf_15 <= fpuf_14;
            sign_13 <= sign_12;
            sum_10 <= sum_9; diff_10 <= diff_9;
        end
    end

    // Stage 16: final result assembly
    always @(posedge clk) begin
        if (rst) begin
            sum_11 <= 56'd0; diff_11 <= 56'd0;
            rm_16 <= 2'b0; in_inf16 <= 1'b0; fpuf_16 <= 1'b0;
            sign_14 <= 1'b0;
        end else if (enable) begin
            rm_16 <= rm_15; in_inf16 <= in_inf15; fpuf_16 <= fpuf_15;
            sign_14 <= sign_13;
            sum_11 <= sum_10; diff_11 <= diff_10;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            in_inf17 <= 1'b0; fpuf_17 <= 1'b0;
            sign_15 <= 1'b0;
        end else if (enable) begin
            in_inf17 <= in_inf16; fpuf_17 <= fpuf_16;
            sign_15 <= sign_14;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            in_inf18 <= 1'b0; fpuf_18 <= 1'b0;
            sign_16 <= 1'b0;
        end else if (enable) begin
            in_inf18 <= in_inf17; fpuf_18 <= fpuf_17;
            sign_16 <= sign_15;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            in_inf19 <= 1'b0; fpuf_19 <= 1'b0;
            sign_17 <= 1'b0;
        end else if (enable) begin
            in_inf19 <= in_inf18; fpuf_19 <= fpuf_18;
            sign_17 <= sign_16;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            in_inf20 <= 1'b0; fpuf_20 <= 1'b0;
            sign_18 <= 1'b0;
        end else if (enable) begin
            in_inf20 <= in_inf19; fpuf_20 <= fpuf_19;
            sign_18 <= sign_17;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            in_inf21 <= 1'b0; fpuf_21 <= 1'b0;
            sign_19 <= 1'b0;
        end else if (enable) begin
            in_inf21 <= in_inf20; fpuf_21 <= fpuf_20;
            sign_19 <= sign_18;
        end
    end

    // Output
    always @(posedge clk) begin
        if (rst) begin
            out <= 64'd0;
            ready <= 1'b0;
        end else if (enable) begin
            out <= outfp;
            ready <= fpuf_21;
        end
    end

    // outfp combinational logic
    always @* begin
        outfp = 64'd0;
        if (in_inf21) begin
            outfp = {sign_19, 11'h7FF, 52'd0};
        end else if (~fpu_op_final) begin
            outfp = {sign_19, exp_add_9[10:0], sum_11[54:3]};
        end else begin
            outfp = {sign_19, exp_sub_8[10:0], diff_11[54:3]};
        end
    end

endmodule
