module fpu_addsub(
    clk,
    rst,
    enable,
    fpu_op,
    rmode,
    opa,
    opb,
    out,
    ready
);

input clk;
input rst;
input enable;
input fpu_op;
input [1:0] rmode;
input [63:0] opa;
input [63:0] opb;
output [63:0] out;
output ready;

reg [63:0] outfp;
reg [63:0] out;
reg [1:0] rm_1;
reg [1:0] rm_2;
reg [1:0] rm_3;
reg [1:0] rm_4;
reg [1:0] rm_5;
reg [1:0] rm_6;
reg [1:0] rm_7;
reg [1:0] rm_8;
reg [1:0] rm_9;
reg [1:0] rm_10;
reg [1:0] rm_11;
reg [1:0] rm_12;
reg [1:0] rm_13;
reg [1:0] rm_14;
reg [1:0] rm_15;
reg [1:0] rm_16;
reg sign;
reg sign_a;
reg sign_b;
reg fpu_op_1;
reg fpu_op_2;
reg fpu_op_3;
reg fpu_op_final;
reg fpuf_2;
reg fpuf_3;
reg fpuf_4;
reg fpuf_5;
reg fpuf_6;
reg fpuf_7;
reg fpuf_8;
reg fpuf_9;
reg fpuf_10;
reg fpuf_11;
reg fpuf_12;
reg fpuf_13;
reg fpuf_14;
reg fpuf_15;
reg fpuf_16;
reg fpuf_17;
reg fpuf_18;
reg fpuf_19;
reg fpuf_20;
reg fpuf_21;
reg sign_a2;
reg sign_a3;
reg sign_b2;
reg sign_b3;
reg sign_2;
reg sign_3;
reg sign_4;
reg sign_5;
reg sign_6;
reg sign_7;
reg sign_8;
reg sign_9;
reg sign_10;
reg sign_11;
reg sign_12;
reg sign_13;
reg sign_14;
reg sign_15;
reg sign_16;
reg sign_17;
reg sign_18;
reg sign_19;
reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg [10:0] expa_2;
reg [10:0] expb_2;
reg [10:0] expa_3;
reg [10:0] expb_3;
reg [51:0] mantissa_a;
reg [51:0] mantissa_b;
reg [51:0] mana_2;
reg [51:0] mana_3;
reg [51:0] manb_2;
reg [51:0] manb_3;
reg expa_et_inf;
reg expb_et_inf;
reg input_is_inf;
reg in_inf2;
reg in_inf3;
reg in_inf4;
reg in_inf5;
reg in_inf6;
reg in_inf7;
reg in_inf8;
reg in_inf9;
reg in_inf10;
reg in_inf11;
reg in_inf12;
reg in_inf13;
reg in_inf14;
reg in_inf15;
reg in_inf16;
reg in_inf17;
reg in_inf18;
reg in_inf19;
reg in_inf20;
reg in_inf21;
reg expa_gt_expb;
reg expa_et_expb;
reg mana_gtet_manb;
reg a_gtet_b;
reg [10:0] exponent_small;
reg [10:0] exponent_large;
reg [10:0] expl_2;
reg [10:0] expl_3;
reg [10:0] expl_4;
reg [10:0] expl_5;
reg [10:0] expl_6;
reg [10:0] expl_7;
reg [10:0] expl_8;
reg [10:0] expl_9;
reg [10:0] expl_10;
reg [10:0] expl_11;
reg [51:0] mantissa_small;
reg [51:0] mantissa_large;
reg [51:0] mantissa_small_2;
reg [51:0] mantissa_large_2;
reg [51:0] mantissa_small_3;
reg [51:0] mantissa_large_3;
reg exp_small_et0;
reg exp_large_et0;
reg exp_small_et0_2;
reg exp_large_et0_2;
reg [10:0] exponent_diff;
reg [10:0] exponent_diff_2;
reg [10:0] exponent_diff_3;
reg [107:0] bits_shifted_out;
reg [107:0] bits_shifted_out_2;
reg bits_shifted;
reg [55:0] large_add;
reg [55:0] large_add_2;
reg [55:0] large_add_3;
reg [55:0] small_add;
reg [55:0] small_shift;
reg [55:0] small_shift_2;
reg [55:0] small_shift_3;
reg [55:0] small_shift_4;
reg [55:0] large_add_4;
reg [55:0] large_add_5;
reg small_shift_nonzero;
reg small_is_nonzero;
reg small_is_nonzero_2;
reg small_is_nonzero_3;
reg small_fraction_enable;
wire [55:0] small_shift_LSB;
reg [55:0] sum;
reg [55:0] sum_2;
reg [55:0] sum_3;
reg [55:0] sum_4;
reg [55:0] sum_5;
reg [55:0] sum_6;
reg [55:0] sum_7;
reg [55:0] sum_8;
reg [55:0] sum_9;
reg [55:0] sum_10;
reg [55:0] sum_11;
reg sum_overflow;
reg sumround_overflow;
reg sum_lsb;
reg sum_lsb_2;
reg [10:0] exponent_add;
reg [10:0] exp_add_2;
reg [10:0] exponent_sub;
reg [10:0] exp_sub_2;
reg [10:0] exp_sub_3;
reg [10:0] exp_sub_4;
reg [10:0] exp_sub_5;
reg [10:0] exp_sub_6;
reg [10:0] exp_sub_7;
reg [10:0] exp_sub_8;
reg [10:0] exp_add_3;
reg [10:0] exp_add_4;
reg [10:0] exp_add_5;
reg [10:0] exp_add_6;
reg [10:0] exp_add_7;
reg [10:0] exp_add_8;
reg [10:0] exp_add_9;
reg [5:0] diff_shift;
reg [5:0] diff_shift_2;
reg [55:0] diff;
reg [55:0] diff_2;
reg [55:0] diff_3;
reg [55:0] diff_4;
reg [55:0] diff_5;
reg [55:0] diff_6;
reg [55:0] diff_7;
reg [55:0] diff_8;
reg [55:0] diff_9;
reg [55:0] diff_10;
reg [55:0] diff_11;
reg diffshift_gt_exponent;
reg diffshift_et_55;
reg diffround_overflow;
reg round_nearest_mode;
reg round_posinf_mode;
reg round_neginf_mode;
reg round_nearest_trigger;
reg round_nearest_exception;
reg round_nearest_enable;
reg round_posinf_trigger;
reg round_posinf_enable;
reg round_neginf_trigger;
reg round_neginf_enable;
reg round_enable;
reg ready;
reg count_ready;
reg count_ready_0;
reg [4:0] count;

reg [63:0] result_4;
reg [63:0] result_5;
reg [63:0] result_6;
reg [63:0] result_7;
reg [63:0] result_8;
reg [63:0] result_9;
reg [63:0] result_10;
reg [63:0] result_11;
reg [63:0] result_12;
reg [63:0] result_13;
reg [63:0] result_14;
reg [63:0] result_15;
reg [63:0] result_16;
reg [63:0] result_17;
reg [63:0] result_18;
reg [63:0] result_19;
reg [63:0] result_20;
reg [63:0] result_21;
reg [63:0] result_22;

reg [56:0] temp_sum_ext;
reg [72:0] temp_norm_pack;
reg [55:0] temp_sig;
reg [55:0] temp_diff_sig;
reg [10:0] temp_exp;
reg [63:0] temp_result;
reg temp_effop;
reg temp_is_nan_a;
reg temp_is_nan_b;
reg temp_is_inf_a;
reg temp_is_inf_b;
reg temp_inexact;

assign small_shift_LSB = {55'b0, 1'b1};

function [55:0] shift_right_sticky;
    input [55:0] value;
    input [10:0] shamt;
    integer j;
    reg sticky_bit;
    reg [55:0] tmp;
    begin
        if (shamt == 11'd0) begin
            shift_right_sticky = value;
        end else if (shamt >= 11'd56) begin
            shift_right_sticky = {55'b0, |value};
        end else begin
            tmp = value >> shamt;
            sticky_bit = 1'b0;
            for (j = 0; j < 56; j = j + 1) begin
                if (j < shamt) begin
                    sticky_bit = sticky_bit | value[j];
                end
            end
            tmp[0] = tmp[0] | sticky_bit;
            shift_right_sticky = tmp;
        end
    end
endfunction

function [5:0] leading_zero_count56;
    input [55:0] value;
    integer j;
    reg found;
    begin
        leading_zero_count56 = 6'd56;
        found = 1'b0;
        for (j = 55; j >= 0; j = j - 1) begin
            if (!found && value[j]) begin
                leading_zero_count56 = 6'd55 - j[5:0];
                found = 1'b1;
            end
        end
    end
endfunction

function [72:0] normalize_sub;
    input [55:0] diff_in;
    input [10:0] exp_in;
    reg [5:0] lz;
    reg [5:0] sh;
    reg [10:0] exp_out;
    reg [55:0] sig_out;
    begin
        if (diff_in == 56'd0) begin
            normalize_sub = {11'd0, 6'd55, 56'd0};
        end else begin
            lz = leading_zero_count56(diff_in);
            if (exp_in > {5'd0, lz}) begin
                sh = lz;
                exp_out = exp_in - {5'd0, lz};
                sig_out = diff_in << lz;
            end else if (exp_in > 11'd0) begin
                sh = exp_in[5:0] - 6'd1;
                exp_out = 11'd0;
                sig_out = diff_in << sh;
            end else begin
                sh = 6'd0;
                exp_out = 11'd0;
                sig_out = diff_in;
            end
            normalize_sub = {exp_out, sh, sig_out};
        end
    end
endfunction

function [63:0] round_pack;
    input sign_in;
    input [10:0] exp_in;
    input [55:0] sig_in;
    input [1:0] rm_in;
    reg [52:0] main_sig;
    reg [53:0] rounded_sig;
    reg [10:0] exp_tmp;
    reg [51:0] frac_tmp;
    reg inc;
    reg inexact;
    begin
        if (sig_in == 56'd0) begin
            round_pack = {sign_in, 63'd0};
        end else begin
            main_sig = sig_in[55:3];
            inexact = |sig_in[2:0];
            case (rm_in)
                2'b00: inc = sig_in[2] & (sig_in[1] | sig_in[0] | sig_in[3]);
                2'b01: inc = 1'b0;
                2'b10: inc = (~sign_in) & inexact;
                default: inc = sign_in & inexact;
            endcase

            rounded_sig = {1'b0, main_sig} + inc;
            exp_tmp = exp_in;
            frac_tmp = rounded_sig[51:0];

            if (exp_in == 11'd0) begin
                if (rounded_sig[52]) begin
                    exp_tmp = 11'd1;
                    frac_tmp = rounded_sig[51:0];
                end
            end else if (rounded_sig[53]) begin
                exp_tmp = exp_in + 11'd1;
                frac_tmp = rounded_sig[52:1];
            end

            if (exp_tmp >= 11'h7ff) begin
                round_pack = {sign_in, 11'h7ff, 52'd0};
            end else begin
                round_pack = {sign_in, exp_tmp, frac_tmp};
            end
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        outfp <= 64'd0;
        out <= 64'd0;
        {rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8,
         rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15, rm_16} <= 0;
        {sign, sign_a, sign_b, fpu_op_1, fpu_op_2, fpu_op_3, fpu_op_final,
         fpuf_2, fpuf_3, fpuf_4, fpuf_5, fpuf_6, fpuf_7, fpuf_8, fpuf_9,
         fpuf_10, fpuf_11, fpuf_12, fpuf_13, fpuf_14, fpuf_15, fpuf_16,
         fpuf_17, fpuf_18, fpuf_19, fpuf_20, fpuf_21, sign_a2, sign_a3,
         sign_b2, sign_b3, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7,
         sign_8, sign_9, sign_10, sign_11, sign_12, sign_13, sign_14,
         sign_15, sign_16, sign_17, sign_18, sign_19, expa_et_inf,
         expb_et_inf, input_is_inf, in_inf2, in_inf3, in_inf4, in_inf5,
         in_inf6, in_inf7, in_inf8, in_inf9, in_inf10, in_inf11, in_inf12,
         in_inf13, in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19,
         in_inf20, in_inf21, expa_gt_expb, expa_et_expb, mana_gtet_manb,
         a_gtet_b, exp_small_et0, exp_large_et0, exp_small_et0_2,
         exp_large_et0_2, bits_shifted, small_shift_nonzero, small_is_nonzero,
         small_is_nonzero_2, small_is_nonzero_3, small_fraction_enable,
         sum_overflow, sumround_overflow, sum_lsb, sum_lsb_2,
         diffshift_gt_exponent, diffshift_et_55, diffround_overflow,
         round_nearest_mode, round_posinf_mode, round_neginf_mode,
         round_nearest_trigger, round_nearest_exception, round_nearest_enable,
         round_posinf_trigger, round_posinf_enable, round_neginf_trigger,
         round_neginf_enable, round_enable, ready, count_ready, count_ready_0,
         temp_effop, temp_is_nan_a, temp_is_nan_b, temp_is_inf_a,
         temp_is_inf_b, temp_inexact} <= 0;
        {exponent_a, exponent_b, expa_2, expb_2, expa_3, expb_3,
         exponent_small, exponent_large, expl_2, expl_3, expl_4, expl_5,
         expl_6, expl_7, expl_8, expl_9, expl_10, expl_11, exponent_diff,
         exponent_diff_2, exponent_diff_3, exponent_add, exp_add_2, exp_add_3,
         exp_add_4, exp_add_5, exp_add_6, exp_add_7, exp_add_8, exp_add_9,
         exponent_sub, exp_sub_2, exp_sub_3, exp_sub_4, exp_sub_5, exp_sub_6,
         exp_sub_7, exp_sub_8, temp_exp} <= 0;
        {mantissa_a, mantissa_b, mana_2, mana_3, manb_2, manb_3,
         mantissa_small, mantissa_large, mantissa_small_2, mantissa_large_2,
         mantissa_small_3, mantissa_large_3} <= 0;
        {bits_shifted_out, bits_shifted_out_2} <= 0;
        {large_add, large_add_2, large_add_3, large_add_4, large_add_5,
         small_add, small_shift, small_shift_2, small_shift_3, small_shift_4,
         sum, sum_2, sum_3, sum_4, sum_5, sum_6, sum_7, sum_8, sum_9, sum_10,
         sum_11, diff, diff_2, diff_3, diff_4, diff_5, diff_6, diff_7, diff_8,
         diff_9, diff_10, diff_11, temp_sig, temp_diff_sig} <= 0;
        {diff_shift, diff_shift_2} <= 0;
        {result_4, result_5, result_6, result_7, result_8, result_9, result_10,
         result_11, result_12, result_13, result_14, result_15, result_16,
         result_17, result_18, result_19, result_20, result_21, result_22,
         temp_result} <= 0;
        {temp_sum_ext, temp_norm_pack} <= 0;
        count <= 5'd0;
    end else if (enable) begin
        rm_16 <= rm_15;
        rm_15 <= rm_14;
        rm_14 <= rm_13;
        rm_13 <= rm_12;
        rm_12 <= rm_11;
        rm_11 <= rm_10;
        rm_10 <= rm_9;
        rm_9 <= rm_8;
        rm_8 <= rm_7;
        rm_7 <= rm_6;
        rm_6 <= rm_5;
        rm_5 <= rm_4;
        rm_4 <= rm_3;
        rm_3 <= rm_2;
        rm_2 <= rm_1;
        rm_1 <= rmode;

        fpu_op_3 <= fpu_op_2;
        fpu_op_2 <= fpu_op_1;
        fpu_op_1 <= fpu_op;
        fpu_op_final <= fpu_op ^ (opa[63] ^ opb[63]);

        fpuf_21 <= fpuf_20;
        fpuf_20 <= fpuf_19;
        fpuf_19 <= fpuf_18;
        fpuf_18 <= fpuf_17;
        fpuf_17 <= fpuf_16;
        fpuf_16 <= fpuf_15;
        fpuf_15 <= fpuf_14;
        fpuf_14 <= fpuf_13;
        fpuf_13 <= fpuf_12;
        fpuf_12 <= fpuf_11;
        fpuf_11 <= fpuf_10;
        fpuf_10 <= fpuf_9;
        fpuf_9 <= fpuf_8;
        fpuf_8 <= fpuf_7;
        fpuf_7 <= fpuf_6;
        fpuf_6 <= fpuf_5;
        fpuf_5 <= fpuf_4;
        fpuf_4 <= fpuf_3;
        fpuf_3 <= fpuf_2;
        fpuf_2 <= 1'b1;

        sign_19 <= sign_18;
        sign_18 <= sign_17;
        sign_17 <= sign_16;
        sign_16 <= sign_15;
        sign_15 <= sign_14;
        sign_14 <= sign_13;
        sign_13 <= sign_12;
        sign_12 <= sign_11;
        sign_11 <= sign_10;
        sign_10 <= sign_9;
        sign_9 <= sign_8;
        sign_8 <= sign_7;
        sign_7 <= sign_6;
        sign_6 <= sign_5;
        sign_5 <= sign_4;
        sign_4 <= sign_3;
        sign_3 <= sign_2;
        sign_2 <= sign;
        sign_a3 <= sign_a2;
        sign_a2 <= sign_a;
        sign_b3 <= sign_b2;
        sign_b2 <= sign_b;
        sign_a <= opa[63];
        sign_b <= opb[63];

        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        expa_3 <= expa_2;
        expb_3 <= expb_2;
        expa_2 <= exponent_a;
        expb_2 <= exponent_b;

        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        mana_3 <= mana_2;
        manb_3 <= manb_2;
        mana_2 <= mantissa_a;
        manb_2 <= mantissa_b;

        expa_et_inf <= (opa[62:52] == 11'h7ff) && (opa[51:0] == 52'd0);
        expb_et_inf <= (opb[62:52] == 11'h7ff) && (opb[51:0] == 52'd0);
        input_is_inf <= ((opa[62:52] == 11'h7ff) && (opa[51:0] == 52'd0)) ||
                        ((opb[62:52] == 11'h7ff) && (opb[51:0] == 52'd0));
        in_inf21 <= in_inf20;
        in_inf20 <= in_inf19;
        in_inf19 <= in_inf18;
        in_inf18 <= in_inf17;
        in_inf17 <= in_inf16;
        in_inf16 <= in_inf15;
        in_inf15 <= in_inf14;
        in_inf14 <= in_inf13;
        in_inf13 <= in_inf12;
        in_inf12 <= in_inf11;
        in_inf11 <= in_inf10;
        in_inf10 <= in_inf9;
        in_inf9 <= in_inf8;
        in_inf8 <= in_inf7;
        in_inf7 <= in_inf6;
        in_inf6 <= in_inf5;
        in_inf5 <= in_inf4;
        in_inf4 <= in_inf3;
        in_inf3 <= in_inf2;
        in_inf2 <= input_is_inf;

        expa_gt_expb <= (opa[62:52] > opb[62:52]);
        expa_et_expb <= (opa[62:52] == opb[62:52]);
        mana_gtet_manb <= (opa[51:0] >= opb[51:0]);
        a_gtet_b <= (opa[62:52] > opb[62:52]) ||
                    ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]));

        if ((opa[62:52] > opb[62:52]) ||
            ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) begin
            exponent_large <= opa[62:52];
            exponent_small <= opb[62:52];
            mantissa_large <= opa[51:0];
            mantissa_small <= opb[51:0];
            if ((fpu_op ^ (opa[63] ^ opb[63])) == 1'b0) begin
                sign <= opa[63];
            end else begin
                sign <= opa[63];
            end
        end else begin
            exponent_large <= opb[62:52];
            exponent_small <= opa[62:52];
            mantissa_large <= opb[51:0];
            mantissa_small <= opa[51:0];
            if ((fpu_op ^ (opa[63] ^ opb[63])) == 1'b0) begin
                sign <= opa[63];
            end else begin
                sign <= opb[63] ^ fpu_op;
            end
        end

        expl_11 <= expl_10;
        expl_10 <= expl_9;
        expl_9 <= expl_8;
        expl_8 <= expl_7;
        expl_7 <= expl_6;
        expl_6 <= expl_5;
        expl_5 <= expl_4;
        expl_4 <= expl_3;
        expl_3 <= expl_2;
        expl_2 <= exponent_large;

        mantissa_small_3 <= mantissa_small_2;
        mantissa_small_2 <= mantissa_small;
        mantissa_large_3 <= mantissa_large_2;
        mantissa_large_2 <= mantissa_large;

        exp_small_et0 <= (exponent_small == 11'd0);
        exp_large_et0 <= (exponent_large == 11'd0);
        exp_small_et0_2 <= exp_small_et0;
        exp_large_et0_2 <= exp_large_et0;

        if (opa[62:52] >= opb[62:52]) begin
            exponent_diff <= opa[62:52] - opb[62:52];
        end else begin
            exponent_diff <= opb[62:52] - opa[62:52];
        end
        exponent_diff_3 <= exponent_diff_2;
        exponent_diff_2 <= exponent_diff;

        large_add <= {(exponent_large != 11'd0), mantissa_large, 3'b000};
        large_add_5 <= large_add_4;
        large_add_4 <= large_add_3;
        large_add_3 <= large_add_2;
        large_add_2 <= {(exponent_large != 11'd0), mantissa_large, 3'b000};

        small_add <= {(exponent_small != 11'd0), mantissa_small, 3'b000};
        small_shift_nonzero <= |shift_right_sticky({(exponent_small != 11'd0), mantissa_small, 3'b000}, exponent_diff);
        small_is_nonzero <= |{(exponent_small != 11'd0), mantissa_small, 3'b000};
        small_is_nonzero_3 <= small_is_nonzero_2;
        small_is_nonzero_2 <= small_is_nonzero;
        // Verilog-2005/Icarus does not permit selecting bits directly from a
        // function-call expression.  Masking is equivalent to reducing [2:0].
        small_fraction_enable <= |(shift_right_sticky({(exponent_small != 11'd0), mantissa_small, 3'b000}, exponent_diff) & 56'h7);
        small_shift <= shift_right_sticky({(exponent_small != 11'd0), mantissa_small, 3'b000}, exponent_diff);
        small_shift_4 <= small_shift_3;
        small_shift_3 <= small_shift_2;
        small_shift_2 <= shift_right_sticky({(exponent_small != 11'd0), mantissa_small, 3'b000}, exponent_diff);

        bits_shifted_out <= {52'd0, {(exponent_small != 11'd0), mantissa_small, 3'b000}};
        bits_shifted_out_2 <= bits_shifted_out;
        bits_shifted <= |bits_shifted_out_2;

        temp_effop = fpu_op_2 ^ (sign_a2 ^ sign_b2);
        temp_is_nan_a = (expa_2 == 11'h7ff) && (mana_2 != 52'd0);
        temp_is_nan_b = (expb_2 == 11'h7ff) && (manb_2 != 52'd0);
        temp_is_inf_a = (expa_2 == 11'h7ff) && (mana_2 == 52'd0);
        temp_is_inf_b = (expb_2 == 11'h7ff) && (manb_2 == 52'd0);
        temp_sig = 56'd0;
        temp_exp = 11'd0;
        temp_result = 64'd0;
        temp_diff_sig = 56'd0;
        temp_sum_ext = 57'd0;
        temp_norm_pack = 73'd0;

        if (temp_is_nan_a || temp_is_nan_b) begin
            temp_result = 64'h7ff8000000000000;
        end else if (temp_is_inf_a || temp_is_inf_b) begin
            if (temp_is_inf_a && temp_is_inf_b && (sign_a2 != (sign_b2 ^ fpu_op_2))) begin
                temp_result = 64'h7ff8000000000000;
            end else if (temp_is_inf_a) begin
                temp_result = {sign_a2, 11'h7ff, 52'd0};
            end else begin
                temp_result = {sign_b2 ^ fpu_op_2, 11'h7ff, 52'd0};
            end
        end else if (temp_effop == 1'b0) begin
            temp_sum_ext = {1'b0, large_add_2} + {1'b0, small_shift_2};
            if (temp_sum_ext[56]) begin
                temp_sig = temp_sum_ext[56:1];
                temp_sig[0] = temp_sum_ext[1] | temp_sum_ext[0];
                temp_exp = expl_2 + 11'd1;
            end else begin
                temp_sig = temp_sum_ext[55:0];
                temp_exp = expl_2;
            end
            temp_result = round_pack(sign_2, temp_exp, temp_sig, rm_2);
        end else begin
            temp_diff_sig = large_add_2 - small_shift_2;
            temp_norm_pack = normalize_sub(temp_diff_sig, expl_2);
            temp_exp = temp_norm_pack[72:62];
            temp_sig = temp_norm_pack[55:0];
            temp_result = round_pack(sign_2, temp_exp, temp_sig, rm_2);
        end

        round_nearest_mode <= (rm_2 == 2'b00);
        round_posinf_mode <= (rm_2 == 2'b10);
        round_neginf_mode <= (rm_2 == 2'b11);
        temp_inexact = |temp_sig[2:0];
        round_nearest_trigger <= temp_sig[2] & (temp_sig[1] | temp_sig[0] | temp_sig[3]);
        round_nearest_exception <= temp_sig[2] & ~(temp_sig[1] | temp_sig[0]) & ~temp_sig[3];
        round_nearest_enable <= (rm_2 == 2'b00) &&
                                (temp_sig[2] & (temp_sig[1] | temp_sig[0] | temp_sig[3]));
        round_posinf_trigger <= (~sign_2) & temp_inexact;
        round_posinf_enable <= (rm_2 == 2'b10) && ((~sign_2) & temp_inexact);
        round_neginf_trigger <= sign_2 & temp_inexact;
        round_neginf_enable <= (rm_2 == 2'b11) && (sign_2 & temp_inexact);
        round_enable <= ((rm_2 == 2'b00) &&
                        (temp_sig[2] & (temp_sig[1] | temp_sig[0] | temp_sig[3]))) ||
                        ((rm_2 == 2'b10) && ((~sign_2) & temp_inexact)) ||
                        ((rm_2 == 2'b11) && (sign_2 & temp_inexact));

        sum_overflow <= (temp_effop == 1'b0) && temp_sum_ext[56];
        sumround_overflow <= (temp_effop == 1'b0) && (temp_result[62:52] == 11'h7ff) && (temp_sig != 56'd0);
        sum_lsb <= temp_sig[3];
        sum_lsb_2 <= sum_lsb;

        exponent_add <= temp_exp;
        exp_add_9 <= exp_add_8;
        exp_add_8 <= exp_add_7;
        exp_add_7 <= exp_add_6;
        exp_add_6 <= exp_add_5;
        exp_add_5 <= exp_add_4;
        exp_add_4 <= exp_add_3;
        exp_add_3 <= exp_add_2;
        exp_add_2 <= (temp_effop == 1'b0) ? temp_exp : 11'd0;

        exponent_sub <= temp_exp;
        exp_sub_8 <= exp_sub_7;
        exp_sub_7 <= exp_sub_6;
        exp_sub_6 <= exp_sub_5;
        exp_sub_5 <= exp_sub_4;
        exp_sub_4 <= exp_sub_3;
        exp_sub_3 <= exp_sub_2;
        exp_sub_2 <= (temp_effop == 1'b1) ? temp_exp : 11'd0;

        diff_shift <= temp_norm_pack[61:56];
        diff_shift_2 <= diff_shift;
        diffshift_gt_exponent <= (temp_norm_pack[61:56] > expl_2[5:0]);
        diffshift_et_55 <= (temp_norm_pack[61:56] == 6'd55);
        diffround_overflow <= (temp_effop == 1'b1) && (temp_result[62:52] == 11'h7ff) && (temp_sig != 56'd0);

        sum <= (temp_effop == 1'b0) ? temp_sig : 56'd0;
        sum_11 <= sum_10;
        sum_10 <= sum_9;
        sum_9 <= sum_8;
        sum_8 <= sum_7;
        sum_7 <= sum_6;
        sum_6 <= sum_5;
        sum_5 <= sum_4;
        sum_4 <= sum_3;
        sum_3 <= sum_2;
        sum_2 <= (temp_effop == 1'b0) ? temp_sig : 56'd0;

        diff <= (temp_effop == 1'b1) ? temp_sig : 56'd0;
        diff_11 <= diff_10;
        diff_10 <= diff_9;
        diff_9 <= diff_8;
        diff_8 <= diff_7;
        diff_7 <= diff_6;
        diff_6 <= diff_5;
        diff_5 <= diff_4;
        diff_4 <= diff_3;
        diff_3 <= diff_2;
        diff_2 <= (temp_effop == 1'b1) ? temp_sig : 56'd0;

        result_22 <= result_21;
        result_21 <= result_20;
        result_20 <= result_19;
        result_19 <= result_18;
        result_18 <= result_17;
        result_17 <= result_16;
        result_16 <= result_15;
        result_15 <= result_14;
        result_14 <= result_13;
        result_13 <= result_12;
        result_12 <= result_11;
        result_11 <= result_10;
        result_10 <= result_9;
        result_9 <= result_8;
        result_8 <= result_7;
        result_7 <= result_6;
        result_6 <= result_5;
        result_5 <= result_4;
        result_4 <= temp_result;

        count_ready <= fpuf_20;
        count_ready_0 <= count_ready;
        if (!fpuf_2) begin
            count <= 5'd0;
        end else if (count != 5'd21) begin
            count <= count + 5'd1;
        end else begin
            count <= count;
        end

        outfp <= result_22;
        out <= result_22;
        ready <= fpuf_21;
    end
end

endmodule
