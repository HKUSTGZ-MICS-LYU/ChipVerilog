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

    // Stage 0 signals
    reg sign_a, sign_b;
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg expa_et_inf, expb_et_inf;
    reg input_is_inf;
    reg fpu_op_1;
    reg [1:0] rm_1;
    reg [4:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_a <= 0;
            sign_b <= 0;
            exponent_a <= 0;
            exponent_b <= 0;
            mantissa_a <= 0;
            mantissa_b <= 0;
            expa_et_inf <= 0;
            expb_et_inf <= 0;
            input_is_inf <= 0;
            fpu_op_1 <= 0;
            rm_1 <= 0;
            count <= 0;
        end else if (enable) begin
            sign_a <= opa[63];
            sign_b <= opb[63];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            expa_et_inf <= (opa[62:52] == 11'h7FF);
            expb_et_inf <= (opb[62:52] == 11'h7FF);
            input_is_inf <= (opa[62:52] == 11'h7FF) || (opb[62:52] == 11'h7FF);
            fpu_op_1 <= fpu_op;
            rm_1 <= rmode;
            count <= count + 1;
        end
    end

    // Stage 1
    reg fpu_op_2;
    reg fpuf_2;
    reg sign_a2, sign_b2;
    reg sign_2;
    reg [10:0] expa_2, expb_2;
    reg [51:0] mana_2, manb_2;
    reg in_inf2;
    reg [1:0] rm_2;
    reg fpu_op_final;
    reg expa_gt_expb;
    reg expa_et_expb;
    reg mana_gtet_manb;
    reg a_gtet_b;
    reg [10:0] exponent_small, exponent_large;
    reg [51:0] mantissa_small, mantissa_large;
    reg exp_small_et0, exp_large_et0;
    reg [10:0] exponent_diff;
    reg sign;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpu_op_2 <= 0;
            fpuf_2 <= 0;
            sign_a2 <= 0;
            sign_b2 <= 0;
            sign_2 <= 0;
            expa_2 <= 0;
            expb_2 <= 0;
            mana_2 <= 0;
            manb_2 <= 0;
            in_inf2 <= 0;
            rm_2 <= 0;
            fpu_op_final <= 0;
            expa_gt_expb <= 0;
            expa_et_expb <= 0;
            mana_gtet_manb <= 0;
            a_gtet_b <= 0;
            exponent_small <= 0;
            exponent_large <= 0;
            mantissa_small <= 0;
            mantissa_large <= 0;
            exp_small_et0 <= 0;
            exp_large_et0 <= 0;
            exponent_diff <= 0;
            sign <= 0;
        end else if (enable) begin
            fpu_op_2 <= fpu_op_1;
            fpuf_2 <= 1;
            sign_a2 <= sign_a;
            sign_b2 <= sign_b;
            sign_2 <= sign_a; // will be updated later
            expa_2 <= exponent_a;
            expb_2 <= exponent_b;
            mana_2 <= mantissa_a;
            manb_2 <= mantissa_b;
            in_inf2 <= input_is_inf;
            rm_2 <= rm_1;

            fpu_op_final <= fpu_op_1 ^ (sign_a ^ sign_b);

            // Compare exponents and mantissas for effective subtraction ordering
            expa_gt_expb <= (exponent_a > exponent_b);
            expa_et_expb <= (exponent_a == exponent_b);
            mana_gtet_manb <= (mantissa_a >= mantissa_b);
            a_gtet_b <= (exponent_a > exponent_b) || ((exponent_a == exponent_b) && (mantissa_a >= mantissa_b));

            // Swap operands so large is always a_gtet_b
            if ((exponent_a > exponent_b) || ((exponent_a == exponent_b) && (mantissa_a >= mantissa_b))) begin
                exponent_large <= exponent_a;
                exponent_small <= exponent_b;
                mantissa_large <= mantissa_a;
                mantissa_small <= mantissa_b;
                sign <= sign_a;
            end else begin
                exponent_large <= exponent_b;
                exponent_small <= exponent_a;
                mantissa_large <= mantissa_b;
                mantissa_small <= mantissa_a;
                sign <= sign_b;
            end

            exp_small_et0 <= (exponent_small == 0);
            exp_large_et0 <= (exponent_large == 0);
            exponent_diff <= exponent_large - exponent_small;
        end
    end

    // Stage 2
    reg fpu_op_3;
    reg fpuf_3;
    reg sign_a3, sign_b3;
    reg sign_3;
    reg [10:0] expa_3, expb_3;
    reg [51:0] mana_3, manb_3;
    reg in_inf3;
    reg [1:0] rm_3;
    reg [10:0] expl_2;
    reg [51:0] mantissa_small_2, mantissa_large_2;
    reg exp_small_et0_2, exp_large_et0_2;
    reg [10:0] exponent_diff_2;
    reg [107:0] bits_shifted_out;
    reg bits_shifted;
    reg [55:0] large_add;
    reg [55:0] small_add;
    reg [55:0] small_shift;
    reg small_shift_nonzero;
    reg small_is_nonzero;
    reg small_fraction_enable;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpu_op_3 <= 0;
            fpuf_3 <= 0;
            sign_a3 <= 0;
            sign_b3 <= 0;
            sign_3 <= 0;
            expa_3 <= 0;
            expb_3 <= 0;
            mana_3 <= 0;
            manb_3 <= 0;
            in_inf3 <= 0;
            rm_3 <= 0;
            expl_2 <= 0;
            mantissa_small_2 <= 0;
            mantissa_large_2 <= 0;
            exp_small_et0_2 <= 0;
            exp_large_et0_2 <= 0;
            exponent_diff_2 <= 0;
            bits_shifted_out <= 0;
            bits_shifted <= 0;
            large_add <= 0;
            small_add <= 0;
            small_shift <= 0;
            small_shift_nonzero <= 0;
            small_is_nonzero <= 0;
            small_fraction_enable <= 0;
        end else if (enable) begin
            fpu_op_3 <= fpu_op_2;
            fpuf_3 <= fpuf_2;
            sign_a3 <= sign_a2;
            sign_b3 <= sign_b2;
            sign_3 <= sign;
            expa_3 <= expa_2;
            expb_3 <= expb_2;
            mana_3 <= mana_2;
            manb_3 <= manb_2;
            in_inf3 <= in_inf2;
            rm_3 <= rm_2;
            expl_2 <= exponent_large;
            mantissa_small_2 <= mantissa_small;
            mantissa_large_2 <= mantissa_large;
            exp_small_et0_2 <= exp_small_et0;
            exp_large_et0_2 <= exp_large_et0;
            exponent_diff_2 <= exponent_diff;

            // Build significands with implicit bits
            large_add <= { (exp_large_et0 ? 1'b0 : 1'b1), mantissa_large, 3'b0 };
            small_add <= { (exp_small_et0 ? 1'b0 : 1'b1), mantissa_small, 3'b0 };

            // Shift small operand
            small_shift <= small_add >> exponent_diff;
            bits_shifted_out <= { {52{1'b0}}, small_add } << (56 - exponent_diff);
            bits_shifted <= |bits_shifted_out;
            small_shift_nonzero <= |small_shift;
            small_is_nonzero <= (|small_add) && (exponent_diff < 56);
            small_fraction_enable <= (exponent_diff == 0);
        end
    end

    // Stage 3
    reg fpuf_4;
    reg sign_4;
    reg in_inf4;
    reg [1:0] rm_4;
    reg [10:0] expl_3;
    reg [51:0] mantissa_small_3, mantissa_large_3;
    reg [10:0] exponent_diff_3;
    reg [55:0] large_add_2;
    reg [55:0] small_shift_2;
    reg small_is_nonzero_2;
    reg [10:0] exponent_add, exponent_sub;
    reg [55:0] sum;
    reg sum_overflow;
    reg sum_lsb;
    reg [5:0] diff_shift;
    reg [55:0] diff;
    reg diffshift_gt_exponent;
    reg diffshift_et_55;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_4 <= 0;
            sign_4 <= 0;
            in_inf4 <= 0;
            rm_4 <= 0;
            expl_3 <= 0;
            mantissa_small_3 <= 0;
            mantissa_large_3 <= 0;
            exponent_diff_3 <= 0;
            large_add_2 <= 0;
            small_shift_2 <= 0;
            small_is_nonzero_2 <= 0;
            exponent_add <= 0;
            exponent_sub <= 0;
            sum <= 0;
            sum_overflow <= 0;
            sum_lsb <= 0;
            diff_shift <= 0;
            diff <= 0;
            diffshift_gt_exponent <= 0;
            diffshift_et_55 <= 0;
        end else if (enable) begin
            fpuf_4 <= fpuf_3;
            sign_4 <= sign_3;
            in_inf4 <= in_inf3;
            rm_4 <= rm_3;
            expl_3 <= expl_2;
            mantissa_small_3 <= mantissa_small_2;
            mantissa_large_3 <= mantissa_large_2;
            exponent_diff_3 <= exponent_diff_2;
            large_add_2 <= large_add;
            small_shift_2 <= small_shift;
            small_is_nonzero_2 <= small_is_nonzero;

            exponent_add <= expl_2;
            exponent_sub <= expl_2;

            if (fpu_op_3) begin
                // Effective subtraction
                {sum_overflow, sum} <= large_add - small_shift;
                sum_lsb <= sum[0];
                diff_shift <= (large_add[55] ? 6'b0 : 
                               large_add[54] ? 6'd1 : 
                               large_add[53] ? 6'd2 : 
                               large_add[52] ? 6'd3 : 
                               large_add[51] ? 6'd4 : 
                               large_add[50] ? 6'd5 : 
                               large_add[49] ? 6'd6 : 
                               large_add[48] ? 6'd7 :
                               large_add[47] ? 6'd8 :
                               large_add[46] ? 6'd9 :
                               large_add[45] ? 6'd10 :
                               large_add[44] ? 6'd11 :
                               large_add[43] ? 6'd12 :
                               large_add[42] ? 6'd13 :
                               large_add[41] ? 6'd14 :
                               large_add[40] ? 6'd15 :
                               large_add[39] ? 6'd16 :
                               large_add[38] ? 6'd17 :
                               large_add[37] ? 6'd18 :
                               large_add[36] ? 6'd19 :
                               large_add[35] ? 6'd20 :
                               large_add[34] ? 6'd21 :
                               large_add[33] ? 6'd22 :
                               large_add[32] ? 6'd23 :
                               large_add[31] ? 6'd24 :
                               large_add[30] ? 6'd25 :
                               large_add[29] ? 6'd26 :
                               large_add[28] ? 6'd27 :
                               large_add[27] ? 6'd28 :
                               large_add[26] ? 6'd29 :
                               large_add[25] ? 6'd30 :
                               large_add[24] ? 6'd31 :
                               large_add[23] ? 6'd32 :
                               large_add[22] ? 6'd33 :
                               large_add[21] ? 6'd34 :
                               large_add[20] ? 6'd35 :
                               large_add[19] ? 6'd36 :
                               large_add[18] ? 6'd37 :
                               large_add[17] ? 6'd38 :
                               large_add[16] ? 6'd39 :
                               large_add[15] ? 6'd40 :
                               large_add[14] ? 6'd41 :
                               large_add[13] ? 6'd42 :
                               large_add[12] ? 6'd43 :
                               large_add[11] ? 6'd44 :
                               large_add[10] ? 6'd45 :
                               large_add[9] ? 6'd46 :
                               large_add[8] ? 6'd47 :
                               large_add[7] ? 6'd48 :
                               large_add[6] ? 6'd49 :
                               large_add[5] ? 6'd50 :
                               large_add[4] ? 6'd51 :
                               large_add[3] ? 6'd52 :
                               large_add[2] ? 6'd53 :
                               large_add[1] ? 6'd54 :
                               large_add[0] ? 6'd55 : 6'd56);
                diff <= large_add - small_shift;
                diffshift_gt_exponent <= (diff_shift > expl_2);
                diffshift_et_55 <= (diff_shift == 6'd55);
            end else begin
                // Effective addition
                {sum_overflow, sum} <= large_add + small_shift;
                sum_lsb <= sum[0];
                diff_shift <= 0;
                diff <= 0;
                diffshift_gt_exponent <= 0;
                diffshift_et_55 <= 0;
            end
        end
    end

    // Stage 4
    reg fpuf_5;
    reg sign_5;
    reg in_inf5;
    reg [1:0] rm_5;
    reg [10:0] expl_4;
    reg [55:0] large_add_3;
    reg [55:0] small_shift_3;
    reg small_is_nonzero_3;
    reg [10:0] exp_add_2, exp_sub_2;
    reg [55:0] sum_2;
    reg sum_lsb_2;
    reg sumround_overflow;
    reg [5:0] diff_shift_2;
    reg [55:0] diff_2;
    reg diffround_overflow;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_5 <= 0;
            sign_5 <= 0;
            in_inf5 <= 0;
            rm_5 <= 0;
            expl_4 <= 0;
            large_add_3 <= 0;
            small_shift_3 <= 0;
            small_is_nonzero_3 <= 0;
            exp_add_2 <= 0;
            exp_sub_2 <= 0;
            sum_2 <= 0;
            sum_lsb_2 <= 0;
            sumround_overflow <= 0;
            diff_shift_2 <= 0;
            diff_2 <= 0;
            diffround_overflow <= 0;
        end else if (enable) begin
            fpuf_5 <= fpuf_4;
            sign_5 <= sign_4;
            in_inf5 <= in_inf4;
            rm_5 <= rm_4;
            expl_4 <= expl_3;
            large_add_3 <= large_add_2;
            small_shift_3 <= small_shift_2;
            small_is_nonzero_3 <= small_is_nonzero_2;
            exp_add_2 <= exponent_add;
            exp_sub_2 <= exponent_sub;
            sum_2 <= sum;
            sum_lsb_2 <= sum_lsb;

            if (fpu_op_3) begin
                // Subtraction rounding
                sumround_overflow <= 0; // handled later in normalization
                diff_shift_2 <= diff_shift;
                diff_2 <= diff;
                diffround_overflow <= (diff_shift == 0) && diff[55];
            end else begin
                // Addition rounding
                sumround_overflow <= sum_overflow;
                diff_shift_2 <= 0;
                diff_2 <= 0;
                diffround_overflow <= 0;
            end
        end
    end

    // Stage 5
    reg fpuf_6;
    reg sign_6;
    reg in_inf6;
    reg [1:0] rm_6;
    reg [10:0] expl_5;
    reg [55:0] large_add_4;
    reg [55:0] small_shift_4;
    reg [10:0] exp_add_3, exp_sub_3;
    reg [55:0] sum_3;
    reg [55:0] diff_3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_6 <= 0;
            sign_6 <= 0;
            in_inf6 <= 0;
            rm_6 <= 0;
            expl_5 <= 0;
            large_add_4 <= 0;
            small_shift_4 <= 0;
            exp_add_3 <= 0;
            exp_sub_3 <= 0;
            sum_3 <= 0;
            diff_3 <= 0;
        end else if (enable) begin
            fpuf_6 <= fpuf_5;
            sign_6 <= sign_5;
            in_inf6 <= in_inf5;
            rm_6 <= rm_5;
            expl_5 <= expl_4;
            large_add_4 <= large_add_3;
            small_shift_4 <= small_shift_3;
            exp_add_3 <= exp_add_2;
            exp_sub_3 <= exp_sub_2;
            sum_3 <= sum_2;
            diff_3 <= diff_2;
        end
    end

    // Stage 6
    reg fpuf_7;
    reg sign_7;
    reg in_inf7;
    reg [1:0] rm_7;
    reg [10:0] expl_6;
    reg [55:0] large_add_5;
    reg [10:0] exp_add_4, exp_sub_4;
    reg [55:0] sum_4;
    reg [55:0] diff_4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_7 <= 0;
            sign_7 <= 0;
            in_inf7 <= 0;
            rm_7 <= 0;
            expl_6 <= 0;
            large_add_5 <= 0;
            exp_add_4 <= 0;
            exp_sub_4 <= 0;
            sum_4 <= 0;
            diff_4 <= 0;
        end else if (enable) begin
            fpuf_7 <= fpuf_6;
            sign_7 <= sign_6;
            in_inf7 <= in_inf6;
            rm_7 <= rm_6;
            expl_6 <= expl_5;
            large_add_5 <= large_add_4;
            exp_add_4 <= exp_add_3;
            exp_sub_4 <= exp_sub_3;
            sum_4 <= sum_3;
            diff_4 <= diff_3;
        end
    end

    // Stage 7
    reg fpuf_8;
    reg sign_8;
    reg in_inf8;
    reg [1:0] rm_8;
    reg [10:0] expl_7;
    reg [10:0] exp_add_5, exp_sub_5;
    reg [55:0] sum_5;
    reg [55:0] diff_5;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_8 <= 0;
            sign_8 <= 0;
            in_inf8 <= 0;
            rm_8 <= 0;
            expl_7 <= 0;
            exp_add_5 <= 0;
            exp_sub_5 <= 0;
            sum_5 <= 0;
            diff_5 <= 0;
        end else if (enable) begin
            fpuf_8 <= fpuf_7;
            sign_8 <= sign_7;
            in_inf8 <= in_inf7;
            rm_8 <= rm_7;
            expl_7 <= expl_6;
            exp_add_5 <= exp_add_4;
            exp_sub_5 <= exp_sub_4;
            sum_5 <= sum_4;
            diff_5 <= diff_4;
        end
    end

    // Stage 8
    reg fpuf_9;
    reg sign_9;
    reg in_inf9;
    reg [1:0] rm_9;
    reg [10:0] expl_8;
    reg [10:0] exp_add_6, exp_sub_6;
    reg [55:0] sum_6;
    reg [55:0] diff_6;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_9 <= 0;
            sign_9 <= 0;
            in_inf9 <= 0;
            rm_9 <= 0;
            expl_8 <= 0;
            exp_add_6 <= 0;
            exp_sub_6 <= 0;
            sum_6 <= 0;
            diff_6 <= 0;
        end else if (enable) begin
            fpuf_9 <= fpuf_8;
            sign_9 <= sign_8;
            in_inf9 <= in_inf8;
            rm_9 <= rm_8;
            expl_8 <= expl_7;
            exp_add_6 <= exp_add_5;
            exp_sub_6 <= exp_sub_5;
            sum_6 <= sum_5;
            diff_6 <= diff_5;
        end
    end

    // Stage 9
    reg fpuf_10;
    reg sign_10;
    reg in_inf10;
    reg [1:0] rm_10;
    reg [10:0] expl_9;
    reg [10:0] exp_add_7, exp_sub_7;
    reg [55:0] sum_7;
    reg [55:0] diff_7;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_10 <= 0;
            sign_10 <= 0;
            in_inf10 <= 0;
            rm_10 <= 0;
            expl_9 <= 0;
            exp_add_7 <= 0;
            exp_sub_7 <= 0;
            sum_7 <= 0;
            diff_7 <= 0;
        end else if (enable) begin
            fpuf_10 <= fpuf_9;
            sign_10 <= sign_9;
            in_inf10 <= in_inf9;
            rm_10 <= rm_9;
            expl_9 <= expl_8;
            exp_add_7 <= exp_add_6;
            exp_sub_7 <= exp_sub_6;
            sum_7 <= sum_6;
            diff_7 <= diff_6;
        end
    end

    // Stage 10
    reg fpuf_11;
    reg sign_11;
    reg in_inf11;
    reg [1:0] rm_11;
    reg [10:0] expl_10;
    reg [10:0] exp_add_8, exp_sub_8;
    reg [55:0] sum_8;
    reg [55:0] diff_8;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_11 <= 0;
            sign_11 <= 0;
            in_inf11 <= 0;
            rm_11 <= 0;
            expl_10 <= 0;
            exp_add_8 <= 0;
            exp_sub_8 <= 0;
            sum_8 <= 0;
            diff_8 <= 0;
        end else if (enable) begin
            fpuf_11 <= fpuf_10;
            sign_11 <= sign_10;
            in_inf11 <= in_inf10;
            rm_11 <= rm_10;
            expl_10 <= expl_9;
            exp_add_8 <= exp_add_7;
            exp_sub_8 <= exp_sub_7;
            sum_8 <= sum_7;
            diff_8 <= diff_7;
        end
    end

    // Stage 11
    reg fpuf_12;
    reg sign_12;
    reg in_inf12;
    reg [1:0] rm_12;
    reg [10:0] expl_11;
    reg [10:0] exp_add_9;
    reg [55:0] sum_9;
    reg [55:0] diff_9;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_12 <= 0;
            sign_12 <= 0;
            in_inf12 <= 0;
            rm_12 <= 0;
            expl_11 <= 0;
            exp_add_9 <= 0;
            sum_9 <= 0;
            diff_9 <= 0;
        end else if (enable) begin
            fpuf_12 <= fpuf_11;
            sign_12 <= sign_11;
            in_inf12 <= in_inf11;
            rm_12 <= rm_11;
            expl_11 <= expl_10;
            exp_add_9 <= exp_add_8;
            sum_9 <= sum_8;
            diff_9 <= diff_8;
        end
    end

    // Stage 12
    reg fpuf_13;
    reg sign_13;
    reg in_inf13;
    reg [1:0] rm_13;
    reg [55:0] sum_10;
    reg [55:0] diff_10;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_13 <= 0;
            sign_13 <= 0;
            in_inf13 <= 0;
            rm_13 <= 0;
            sum_10 <= 0;
            diff_10 <= 0;
        end else if (enable) begin
            fpuf_13 <= fpuf_12;
            sign_13 <= sign_12;
            in_inf13 <= in_inf12;
            rm_13 <= rm_12;
            sum_10 <= sum_9;
            diff_10 <= diff_9;
        end
    end

    // Stage 13
    reg fpuf_14;
    reg sign_14;
    reg in_inf14;
    reg [1:0] rm_14;
    reg [55:0] sum_11;
    reg [55:0] diff_11;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_14 <= 0;
            sign_14 <= 0;
            in_inf14 <= 0;
            rm_14 <= 0;
            sum_11 <= 0;
            diff_11 <= 0;
        end else if (enable) begin
            fpuf_14 <= fpuf_13;
            sign_14 <= sign_13;
            in_inf14 <= in_inf13;
            rm_14 <= rm_13;
            sum_11 <= sum_10;
            diff_11 <= diff_10;
        end
    end

    // Stage 14
    reg fpuf_15;
    reg sign_15;
    reg in_inf15;
    reg [1:0] rm_15;
    reg [63:0] outfp;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_15 <= 0;
            sign_15 <= 0;
            in_inf15 <= 0;
            rm_15 <= 0;
            outfp <= 0;
        end else if (enable) begin
            fpuf_15 <= fpuf_14;
            sign_15 <= sign_14;
            in_inf15 <= in_inf14;
            rm_15 <= rm_14;
            outfp <= 0; // placeholder for later normalization
        end
    end

    // Stage 15
    reg fpuf_16;
    reg sign_16;
    reg in_inf16;
    reg [1:0] rm_16;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_16 <= 0;
            sign_16 <= 0;
            in_inf16 <= 0;
            rm_16 <= 0;
        end else if (enable) begin
            fpuf_16 <= fpuf_15;
            sign_16 <= sign_15;
            in_inf16 <= in_inf15;
            rm_16 <= rm_15;
        end
    end

    // Stage 16
    reg fpuf_17;
    reg sign_17;
    reg in_inf17;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_17 <= 0;
            sign_17 <= 0;
            in_inf17 <= 0;
        end else if (enable) begin
            fpuf_17 <= fpuf_16;
            sign_17 <= sign_16;
            in_inf17 <= in_inf16;
        end
    end

    // Stage 17
    reg fpuf_18;
    reg sign_18;
    reg in_inf18;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_18 <= 0;
            sign_18 <= 0;
            in_inf18 <= 0;
        end else if (enable) begin
            fpuf_18 <= fpuf_17;
            sign_18 <= sign_17;
            in_inf18 <= in_inf17;
        end
    end

    // Stage 18
    reg fpuf_19;
    reg sign_19;
    reg in_inf19;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_19 <= 0;
            sign_19 <= 0;
            in_inf19 <= 0;
        end else if (enable) begin
            fpuf_19 <= fpuf_18;
            sign_19 <= sign_18;
            in_inf19 <= in_inf18;
        end
    end

    // Stage 19
    reg fpuf_20;
    reg in_inf20;
    reg [63:0] out_reg;
    reg ready_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_20 <= 0;
            in_inf20 <= 0;
            out_reg <= 0;
            ready_reg <= 0;
        end else if (enable) begin
            fpuf_20 <= fpuf_19;
            in_inf20 <= in_inf19;
            out_reg <= outfp; // placeholder
            ready_reg <= fpuf_19;
        end
    end

    // Stage 20
    reg fpuf_21;
    reg in_inf21;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpuf_21 <= 0;
            in_inf21 <= 0;
            out <= 0;
            ready <= 0;
        end else if (enable) begin
            fpuf_21 <= fpuf_20;
            in_inf21 <= in_inf20;
            out <= out_reg;
            ready <= fpuf_20;
        end
    end

endmodule
