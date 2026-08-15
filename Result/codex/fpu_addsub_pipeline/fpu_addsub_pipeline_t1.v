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
wire [55:0] small_shift_LSB = {55'b0, 1'b1};
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
reg count_ready;
reg count_ready_0;
reg [4:0] count;

reg [63:0] result_pipe [0:20];

integer idx;

function [55:0] shift_right_sticky56;
    input [55:0] value;
    input [10:0] shamt;
    integer i;
    reg sticky_bit;
    begin
        if (shamt == 0) begin
            shift_right_sticky56 = value;
        end else if (shamt >= 56) begin
            shift_right_sticky56 = 56'd0;
            shift_right_sticky56[0] = |value;
        end else begin
            shift_right_sticky56 = value >> shamt;
            sticky_bit = 1'b0;
            for (i = 0; i < 56; i = i + 1) begin
                if ((i < shamt) && value[i]) begin
                    sticky_bit = 1'b1;
                end
            end
            shift_right_sticky56[0] = shift_right_sticky56[0] | sticky_bit;
        end
    end
endfunction

function [5:0] leading_zero56;
    input [55:0] value;
    integer i;
    begin
        leading_zero56 = 6'd56;
        for (i = 55; i >= 0; i = i - 1) begin
            if ((leading_zero56 == 6'd56) && value[i]) begin
                leading_zero56 = 6'd55 - i[5:0];
            end
        end
    end
endfunction

function [63:0] addsub_core;
    input fop;
    input [1:0] rm;
    input [63:0] a;
    input [63:0] b;
    reg sa;
    reg sb;
    reg sb_eff;
    reg sign_large;
    reg sign_small;
    reg sign_res;
    reg [10:0] ea;
    reg [10:0] eb;
    reg [10:0] e_large;
    reg [10:0] e_small;
    reg [10:0] e_res;
    reg [51:0] ma;
    reg [51:0] mb;
    reg [52:0] siga;
    reg [52:0] sigb;
    reg [55:0] sig_large;
    reg [55:0] sig_small;
    reg [55:0] shifted_small;
    reg [55:0] sig_work;
    reg [55:0] diff_work;
    reg [5:0] lz;
    reg effective_sub;
    reg guard_bit;
    reg sticky_bit;
    reg lsb_bit;
    reg inc_round;
    reg [53:0] rounded_main;
    reg [55:0] rounded_sig;
    reg nan_a;
    reg nan_b;
    reg inf_a;
    reg inf_b;
    begin
        sa = a[63];
        sb = b[63];
        ea = a[62:52];
        eb = b[62:52];
        ma = a[51:0];
        mb = b[51:0];
        sb_eff = sb ^ fop;
        nan_a = (ea == 11'h7ff) && (ma != 0);
        nan_b = (eb == 11'h7ff) && (mb != 0);
        inf_a = (ea == 11'h7ff) && (ma == 0);
        inf_b = (eb == 11'h7ff) && (mb == 0);

        if (nan_a || nan_b) begin
            addsub_core = 64'h7ff8_0000_0000_0000;
        end else if (inf_a && inf_b) begin
            if (sa ^ sb_eff) begin
                addsub_core = 64'h7ff8_0000_0000_0000;
            end else begin
                addsub_core = {sa, 11'h7ff, 52'd0};
            end
        end else if (inf_a) begin
            addsub_core = {sa, 11'h7ff, 52'd0};
        end else if (inf_b) begin
            addsub_core = {sb_eff, 11'h7ff, 52'd0};
        end else begin
            siga = (ea != 0) ? {1'b1, ma} : {1'b0, ma};
            sigb = (eb != 0) ? {1'b1, mb} : {1'b0, mb};

            if ((ea > eb) || ((ea == eb) && (siga >= sigb))) begin
                e_large = ea;
                e_small = eb;
                sig_large = {1'b0, siga, 2'b00};
                sig_small = {1'b0, sigb, 2'b00};
                sign_large = sa;
                sign_small = sb_eff;
            end else begin
                e_large = eb;
                e_small = ea;
                sig_large = {1'b0, sigb, 2'b00};
                sig_small = {1'b0, siga, 2'b00};
                sign_large = sb_eff;
                sign_small = sa;
            end

            effective_sub = sign_large ^ sign_small;
            sign_res = sign_large;
            shifted_small = shift_right_sticky56(sig_small, e_large - e_small);
            e_res = e_large;
            sig_work = 56'd0;

            if (effective_sub) begin
                diff_work = sig_large - shifted_small;
                if (diff_work == 0) begin
                    sig_work = 56'd0;
                    e_res = 11'd0;
                    sign_res = (rm == 2'b11);
                end else begin
                    lz = leading_zero56(diff_work);
                    if (e_large > lz) begin
                        sig_work = diff_work << lz;
                        e_res = e_large - lz;
                    end else begin
                        e_res = 11'd0;
                        if (e_large > 0) begin
                            sig_work = diff_work << (e_large - 1'b1);
                        end else begin
                            sig_work = diff_work;
                        end
                    end
                end
            end else begin
                sig_work = sig_large + shifted_small;
                if (sig_work[55]) begin
                    sig_work = sig_work >> 1;
                    e_res = e_large + 1'b1;
                end else if ((e_res == 0) && sig_work[54]) begin
                    e_res = 11'd1;
                end
            end

            guard_bit = sig_work[1];
            sticky_bit = sig_work[0];
            lsb_bit = sig_work[2];
            inc_round = 1'b0;

            case (rm)
                2'b00: inc_round = guard_bit && (sticky_bit || lsb_bit);
                2'b01: inc_round = 1'b0;
                2'b10: inc_round = (~sign_res) && (guard_bit || sticky_bit);
                2'b11: inc_round = sign_res && (guard_bit || sticky_bit);
                default: inc_round = 1'b0;
            endcase

            rounded_main = {1'b0, sig_work[54:2]} + inc_round;
            if (rounded_main[53]) begin
                rounded_sig = {1'b0, rounded_main[53:1], 2'b00};
                if (e_res == 0) begin
                    e_res = 11'd1;
                end else begin
                    e_res = e_res + 1'b1;
                end
            end else begin
                rounded_sig = {1'b0, rounded_main[52:0], 2'b00};
            end

            if (e_res >= 11'h7ff) begin
                addsub_core = {sign_res, 11'h7ff, 52'd0};
            end else if ((e_res == 0) && (rounded_sig[53:2] == 0)) begin
                addsub_core = {sign_res, 11'd0, 52'd0};
            end else begin
                addsub_core = {sign_res, e_res, rounded_sig[53:2]};
            end
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        out <= 64'd0;
        outfp <= 64'd0;
        ready <= 1'b0;
        rm_1 <= 2'd0;
        rm_2 <= 2'd0;
        rm_3 <= 2'd0;
        rm_4 <= 2'd0;
        rm_5 <= 2'd0;
        rm_6 <= 2'd0;
        rm_7 <= 2'd0;
        rm_8 <= 2'd0;
        rm_9 <= 2'd0;
        rm_10 <= 2'd0;
        rm_11 <= 2'd0;
        rm_12 <= 2'd0;
        rm_13 <= 2'd0;
        rm_14 <= 2'd0;
        rm_15 <= 2'd0;
        rm_16 <= 2'd0;
        sign <= 1'b0;
        sign_a <= 1'b0;
        sign_b <= 1'b0;
        fpu_op_1 <= 1'b0;
        fpu_op_2 <= 1'b0;
        fpu_op_3 <= 1'b0;
        fpu_op_final <= 1'b0;
        fpuf_2 <= 1'b0;
        fpuf_3 <= 1'b0;
        fpuf_4 <= 1'b0;
        fpuf_5 <= 1'b0;
        fpuf_6 <= 1'b0;
        fpuf_7 <= 1'b0;
        fpuf_8 <= 1'b0;
        fpuf_9 <= 1'b0;
        fpuf_10 <= 1'b0;
        fpuf_11 <= 1'b0;
        fpuf_12 <= 1'b0;
        fpuf_13 <= 1'b0;
        fpuf_14 <= 1'b0;
        fpuf_15 <= 1'b0;
        fpuf_16 <= 1'b0;
        fpuf_17 <= 1'b0;
        fpuf_18 <= 1'b0;
        fpuf_19 <= 1'b0;
        fpuf_20 <= 1'b0;
        fpuf_21 <= 1'b0;
        sign_a2 <= 1'b0;
        sign_a3 <= 1'b0;
        sign_b2 <= 1'b0;
        sign_b3 <= 1'b0;
        sign_2 <= 1'b0;
        sign_3 <= 1'b0;
        sign_4 <= 1'b0;
        sign_5 <= 1'b0;
        sign_6 <= 1'b0;
        sign_7 <= 1'b0;
        sign_8 <= 1'b0;
        sign_9 <= 1'b0;
        sign_10 <= 1'b0;
        sign_11 <= 1'b0;
        sign_12 <= 1'b0;
        sign_13 <= 1'b0;
        sign_14 <= 1'b0;
        sign_15 <= 1'b0;
        sign_16 <= 1'b0;
        sign_17 <= 1'b0;
        sign_18 <= 1'b0;
        sign_19 <= 1'b0;
        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        expa_2 <= 11'd0;
        expb_2 <= 11'd0;
        expa_3 <= 11'd0;
        expb_3 <= 11'd0;
        mantissa_a <= 52'd0;
        mantissa_b <= 52'd0;
        mana_2 <= 52'd0;
        mana_3 <= 52'd0;
        manb_2 <= 52'd0;
        manb_3 <= 52'd0;
        expa_et_inf <= 1'b0;
        expb_et_inf <= 1'b0;
        input_is_inf <= 1'b0;
        in_inf2 <= 1'b0;
        in_inf3 <= 1'b0;
        in_inf4 <= 1'b0;
        in_inf5 <= 1'b0;
        in_inf6 <= 1'b0;
        in_inf7 <= 1'b0;
        in_inf8 <= 1'b0;
        in_inf9 <= 1'b0;
        in_inf10 <= 1'b0;
        in_inf11 <= 1'b0;
        in_inf12 <= 1'b0;
        in_inf13 <= 1'b0;
        in_inf14 <= 1'b0;
        in_inf15 <= 1'b0;
        in_inf16 <= 1'b0;
        in_inf17 <= 1'b0;
        in_inf18 <= 1'b0;
        in_inf19 <= 1'b0;
        in_inf20 <= 1'b0;
        in_inf21 <= 1'b0;
        expa_gt_expb <= 1'b0;
        expa_et_expb <= 1'b0;
        mana_gtet_manb <= 1'b0;
        a_gtet_b <= 1'b0;
        exponent_small <= 11'd0;
        exponent_large <= 11'd0;
        expl_2 <= 11'd0;
        expl_3 <= 11'd0;
        expl_4 <= 11'd0;
        expl_5 <= 11'd0;
        expl_6 <= 11'd0;
        expl_7 <= 11'd0;
        expl_8 <= 11'd0;
        expl_9 <= 11'd0;
        expl_10 <= 11'd0;
        expl_11 <= 11'd0;
        mantissa_small <= 52'd0;
        mantissa_large <= 52'd0;
        mantissa_small_2 <= 52'd0;
        mantissa_large_2 <= 52'd0;
        mantissa_small_3 <= 52'd0;
        mantissa_large_3 <= 52'd0;
        exp_small_et0 <= 1'b0;
        exp_large_et0 <= 1'b0;
        exp_small_et0_2 <= 1'b0;
        exp_large_et0_2 <= 1'b0;
        exponent_diff <= 11'd0;
        exponent_diff_2 <= 11'd0;
        exponent_diff_3 <= 11'd0;
        bits_shifted_out <= 108'd0;
        bits_shifted_out_2 <= 108'd0;
        bits_shifted <= 1'b0;
        large_add <= 56'd0;
        large_add_2 <= 56'd0;
        large_add_3 <= 56'd0;
        small_add <= 56'd0;
        small_shift <= 56'd0;
        small_shift_2 <= 56'd0;
        small_shift_3 <= 56'd0;
        small_shift_4 <= 56'd0;
        large_add_4 <= 56'd0;
        large_add_5 <= 56'd0;
        small_shift_nonzero <= 1'b0;
        small_is_nonzero <= 1'b0;
        small_is_nonzero_2 <= 1'b0;
        small_is_nonzero_3 <= 1'b0;
        small_fraction_enable <= 1'b0;
        sum <= 56'd0;
        sum_2 <= 56'd0;
        sum_3 <= 56'd0;
        sum_4 <= 56'd0;
        sum_5 <= 56'd0;
        sum_6 <= 56'd0;
        sum_7 <= 56'd0;
        sum_8 <= 56'd0;
        sum_9 <= 56'd0;
        sum_10 <= 56'd0;
        sum_11 <= 56'd0;
        sum_overflow <= 1'b0;
        sumround_overflow <= 1'b0;
        sum_lsb <= 1'b0;
        sum_lsb_2 <= 1'b0;
        exponent_add <= 11'd0;
        exp_add_2 <= 11'd0;
        exponent_sub <= 11'd0;
        exp_sub_2 <= 11'd0;
        exp_sub_3 <= 11'd0;
        exp_sub_4 <= 11'd0;
        exp_sub_5 <= 11'd0;
        exp_sub_6 <= 11'd0;
        exp_sub_7 <= 11'd0;
        exp_sub_8 <= 11'd0;
        exp_add_3 <= 11'd0;
        exp_add_4 <= 11'd0;
        exp_add_5 <= 11'd0;
        exp_add_6 <= 11'd0;
        exp_add_7 <= 11'd0;
        exp_add_8 <= 11'd0;
        exp_add_9 <= 11'd0;
        diff_shift <= 6'd0;
        diff_shift_2 <= 6'd0;
        diff <= 56'd0;
        diff_2 <= 56'd0;
        diff_3 <= 56'd0;
        diff_4 <= 56'd0;
        diff_5 <= 56'd0;
        diff_6 <= 56'd0;
        diff_7 <= 56'd0;
        diff_8 <= 56'd0;
        diff_9 <= 56'd0;
        diff_10 <= 56'd0;
        diff_11 <= 56'd0;
        diffshift_gt_exponent <= 1'b0;
        diffshift_et_55 <= 1'b0;
        diffround_overflow <= 1'b0;
        round_nearest_mode <= 1'b0;
        round_posinf_mode <= 1'b0;
        round_neginf_mode <= 1'b0;
        round_nearest_trigger <= 1'b0;
        round_nearest_exception <= 1'b0;
        round_nearest_enable <= 1'b0;
        round_posinf_trigger <= 1'b0;
        round_posinf_enable <= 1'b0;
        round_neginf_trigger <= 1'b0;
        round_neginf_enable <= 1'b0;
        round_enable <= 1'b0;
        count_ready <= 1'b0;
        count_ready_0 <= 1'b0;
        count <= 5'd0;
        for (idx = 0; idx < 21; idx = idx + 1) begin
            result_pipe[idx] <= 64'd0;
        end
    end else if (enable) begin
        for (idx = 20; idx > 0; idx = idx - 1) begin
            result_pipe[idx] <= result_pipe[idx-1];
        end
        result_pipe[0] <= addsub_core(fpu_op, rmode, opa, opb);

        outfp <= result_pipe[19];
        out <= result_pipe[20];
        ready <= fpuf_21;

        rm_1 <= rmode;
        rm_2 <= rm_1;
        rm_3 <= rm_2;
        rm_4 <= rm_3;
        rm_5 <= rm_4;
        rm_6 <= rm_5;
        rm_7 <= rm_6;
        rm_8 <= rm_7;
        rm_9 <= rm_8;
        rm_10 <= rm_9;
        rm_11 <= rm_10;
        rm_12 <= rm_11;
        rm_13 <= rm_12;
        rm_14 <= rm_13;
        rm_15 <= rm_14;
        rm_16 <= rm_15;

        sign_a <= opa[63];
        sign_b <= opb[63];
        sign_a2 <= sign_a;
        sign_a3 <= sign_a2;
        sign_b2 <= sign_b;
        sign_b3 <= sign_b2;

        fpu_op_1 <= fpu_op;
        fpu_op_2 <= fpu_op_1;
        fpu_op_3 <= fpu_op_2;
        fpu_op_final <= fpu_op ^ (opa[63] ^ opb[63]);

        fpuf_2 <= 1'b1;
        fpuf_3 <= fpuf_2;
        fpuf_4 <= fpuf_3;
        fpuf_5 <= fpuf_4;
        fpuf_6 <= fpuf_5;
        fpuf_7 <= fpuf_6;
        fpuf_8 <= fpuf_7;
        fpuf_9 <= fpuf_8;
        fpuf_10 <= fpuf_9;
        fpuf_11 <= fpuf_10;
        fpuf_12 <= fpuf_11;
        fpuf_13 <= fpuf_12;
        fpuf_14 <= fpuf_13;
        fpuf_15 <= fpuf_14;
        fpuf_16 <= fpuf_15;
        fpuf_17 <= fpuf_16;
        fpuf_18 <= fpuf_17;
        fpuf_19 <= fpuf_18;
        fpuf_20 <= fpuf_19;
        fpuf_21 <= fpuf_20;

        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        expa_2 <= exponent_a;
        expb_2 <= exponent_b;
        expa_3 <= expa_2;
        expb_3 <= expb_2;

        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        mana_2 <= mantissa_a;
        mana_3 <= mana_2;
        manb_2 <= mantissa_b;
        manb_3 <= manb_2;

        expa_et_inf <= (opa[62:52] == 11'h7ff);
        expb_et_inf <= (opb[62:52] == 11'h7ff);
        input_is_inf <= ((opa[62:52] == 11'h7ff) || (opb[62:52] == 11'h7ff));
        in_inf2 <= input_is_inf;
        in_inf3 <= in_inf2;
        in_inf4 <= in_inf3;
        in_inf5 <= in_inf4;
        in_inf6 <= in_inf5;
        in_inf7 <= in_inf6;
        in_inf8 <= in_inf7;
        in_inf9 <= in_inf8;
        in_inf10 <= in_inf9;
        in_inf11 <= in_inf10;
        in_inf12 <= in_inf11;
        in_inf13 <= in_inf12;
        in_inf14 <= in_inf13;
        in_inf15 <= in_inf14;
        in_inf16 <= in_inf15;
        in_inf17 <= in_inf16;
        in_inf18 <= in_inf17;
        in_inf19 <= in_inf18;
        in_inf20 <= in_inf19;
        in_inf21 <= in_inf20;

        expa_gt_expb <= (opa[62:52] > opb[62:52]);
        expa_et_expb <= (opa[62:52] == opb[62:52]);
        mana_gtet_manb <= (opa[51:0] >= opb[51:0]);
        a_gtet_b <= ((opa[62:52] > opb[62:52]) || ((opa[62:52] == opb[62:52]) && ({(opa[62:52] != 0), opa[51:0]} >= {(opb[62:52] != 0), opb[51:0]})));

        if (((opa[62:52] > opb[62:52]) || ((opa[62:52] == opb[62:52]) && ({(opa[62:52] != 0), opa[51:0]} >= {(opb[62:52] != 0), opb[51:0]})))) begin
            exponent_large <= opa[62:52];
            exponent_small <= opb[62:52];
            mantissa_large <= opa[51:0];
            mantissa_small <= opb[51:0];
            sign <= opa[63];
        end else begin
            exponent_large <= opb[62:52];
            exponent_small <= opa[62:52];
            mantissa_large <= opb[51:0];
            mantissa_small <= opa[51:0];
            sign <= opb[63] ^ fpu_op;
        end

        sign_2 <= sign;
        sign_3 <= sign_2;
        sign_4 <= sign_3;
        sign_5 <= sign_4;
        sign_6 <= sign_5;
        sign_7 <= sign_6;
        sign_8 <= sign_7;
        sign_9 <= sign_8;
        sign_10 <= sign_9;
        sign_11 <= sign_10;
        sign_12 <= sign_11;
        sign_13 <= sign_12;
        sign_14 <= sign_13;
        sign_15 <= sign_14;
        sign_16 <= sign_15;
        sign_17 <= sign_16;
        sign_18 <= sign_17;
        sign_19 <= sign_18;

        expl_2 <= exponent_large;
        expl_3 <= expl_2;
        expl_4 <= expl_3;
        expl_5 <= expl_4;
        expl_6 <= expl_5;
        expl_7 <= expl_6;
        expl_8 <= expl_7;
        expl_9 <= expl_8;
        expl_10 <= expl_9;
        expl_11 <= expl_10;

        mantissa_small_2 <= mantissa_small;
        mantissa_large_2 <= mantissa_large;
        mantissa_small_3 <= mantissa_small_2;
        mantissa_large_3 <= mantissa_large_2;

        exp_small_et0 <= (exponent_small == 0);
        exp_large_et0 <= (exponent_large == 0);
        exp_small_et0_2 <= exp_small_et0;
        exp_large_et0_2 <= exp_large_et0;

        exponent_diff <= exponent_large - exponent_small;
        exponent_diff_2 <= exponent_diff;
        exponent_diff_3 <= exponent_diff_2;

        large_add <= {1'b0, ((exponent_large != 0) ? 1'b1 : 1'b0), mantissa_large, 2'b00};
        small_add <= {1'b0, ((exponent_small != 0) ? 1'b1 : 1'b0), mantissa_small, 2'b00};
        bits_shifted_out <= {52'd0, small_add};
        bits_shifted_out_2 <= bits_shifted_out;
        bits_shifted <= (exponent_diff != 0);
        large_add_2 <= large_add;
        large_add_3 <= large_add_2;
        large_add_4 <= large_add_3;
        large_add_5 <= large_add_4;

        small_shift <= shift_right_sticky56(small_add, exponent_diff);
        small_shift_2 <= small_shift;
        small_shift_3 <= small_shift_2;
        small_shift_4 <= small_shift_3;
        small_shift_nonzero <= (small_shift != 0);
        small_is_nonzero <= (small_add != 0);
        small_is_nonzero_2 <= small_is_nonzero;
        small_is_nonzero_3 <= small_is_nonzero_2;
        small_fraction_enable <= (|small_shift[1:0]);

        sum <= large_add + small_shift;
        sum_2 <= sum;
        sum_3 <= sum_2;
        sum_4 <= sum_3;
        sum_5 <= sum_4;
        sum_6 <= sum_5;
        sum_7 <= sum_6;
        sum_8 <= sum_7;
        sum_9 <= sum_8;
        sum_10 <= sum_9;
        sum_11 <= sum_10;
        sum_overflow <= sum[55];
        sumround_overflow <= sum_11[55];
        sum_lsb <= sum[2];
        sum_lsb_2 <= sum_lsb;

        exponent_add <= exponent_large + sum[55];
        exp_add_2 <= exponent_add;
        exp_add_3 <= exp_add_2;
        exp_add_4 <= exp_add_3;
        exp_add_5 <= exp_add_4;
        exp_add_6 <= exp_add_5;
        exp_add_7 <= exp_add_6;
        exp_add_8 <= exp_add_7;
        exp_add_9 <= exp_add_8;

        if (large_add >= small_shift) begin
            diff <= large_add - small_shift;
        end else begin
            diff <= small_shift - large_add;
        end
        diff_2 <= diff;
        diff_3 <= diff_2;
        diff_4 <= diff_3;
        diff_5 <= diff_4;
        diff_6 <= diff_5;
        diff_7 <= diff_6;
        diff_8 <= diff_7;
        diff_9 <= diff_8;
        diff_10 <= diff_9;
        diff_11 <= diff_10;

        diff_shift <= leading_zero56(diff);
        diff_shift_2 <= diff_shift;
        diffshift_gt_exponent <= (diff_shift_2 > exponent_large[5:0]);
        diffshift_et_55 <= (diff_shift_2 == 6'd55);

        exponent_sub <= (exponent_large > diff_shift) ? (exponent_large - diff_shift) : 11'd0;
        exp_sub_2 <= exponent_sub;
        exp_sub_3 <= exp_sub_2;
        exp_sub_4 <= exp_sub_3;
        exp_sub_5 <= exp_sub_4;
        exp_sub_6 <= exp_sub_5;
        exp_sub_7 <= exp_sub_6;
        exp_sub_8 <= exp_sub_7;
        diffround_overflow <= diff_11[55];

        round_nearest_mode <= (rmode == 2'b00);
        round_posinf_mode <= (rmode == 2'b10);
        round_neginf_mode <= (rmode == 2'b11);
        round_nearest_trigger <= sum[1] && (sum[0] || sum[2]);
        round_nearest_exception <= sum[1] || sum[0];
        round_nearest_enable <= round_nearest_mode && round_nearest_trigger;
        round_posinf_trigger <= (~sign) && (sum[1] || sum[0]);
        round_posinf_enable <= round_posinf_mode && round_posinf_trigger;
        round_neginf_trigger <= sign && (sum[1] || sum[0]);
        round_neginf_enable <= round_neginf_mode && round_neginf_trigger;
        round_enable <= round_nearest_enable || round_posinf_enable || round_neginf_enable;

        count_ready <= fpuf_21;
        count_ready_0 <= 1'b1;
        if (ready) begin
            count <= 5'd0;
        end else if (count_ready_0) begin
            count <= count + 1'b1;
        end
    end
end

endmodule
