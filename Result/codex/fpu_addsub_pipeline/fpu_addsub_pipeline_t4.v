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
reg ready;
reg count_ready;
reg count_ready_0;
reg [4:0] count;

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

reg [56:0] add_tmp;
reg [56:0] round_tmp;
reg [55:0] selected_sig;
reg [10:0] selected_exp;
reg [5:0] lzc_tmp;

function [55:0] shift_right_jam56;
    input [55:0] value;
    input [10:0] shamt;
    integer i;
    reg sticky_local;
    begin
        if (shamt == 0) begin
            shift_right_jam56 = value;
        end else if (shamt >= 56) begin
            shift_right_jam56 = {55'b0, |value};
        end else begin
            shift_right_jam56 = value >> shamt;
            sticky_local = 1'b0;
            for (i = 0; i < 56; i = i + 1) begin
                if ((i < shamt) && value[i]) begin
                    sticky_local = 1'b1;
                end
            end
            shift_right_jam56[0] = shift_right_jam56[0] | sticky_local;
        end
    end
endfunction

function [5:0] leading_zero_count56;
    input [55:0] value;
    integer i;
    reg found_local;
    begin
        leading_zero_count56 = 6'd55;
        found_local = 1'b0;
        for (i = 55; i >= 0; i = i - 1) begin
            if (!found_local && value[i]) begin
                leading_zero_count56 = 6'd55 - i[5:0];
                found_local = 1'b1;
            end
        end
    end
endfunction

function round_increment;
    input [1:0] rm_in;
    input sign_in;
    input [55:0] sig_in;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg lsb_bit;
    begin
        guard_bit = sig_in[2];
        round_bit = sig_in[1];
        sticky_bit = sig_in[0];
        lsb_bit = sig_in[3];
        case (rm_in)
            2'b00: round_increment = guard_bit & (round_bit | sticky_bit | lsb_bit);
            2'b01: round_increment = 1'b0;
            2'b10: round_increment = (~sign_in) & (guard_bit | round_bit | sticky_bit);
            default: round_increment = sign_in & (guard_bit | round_bit | sticky_bit);
        endcase
    end
endfunction

always @(posedge clk) begin
    if (rst) begin
        outfp <= 64'b0;
        out <= 64'b0;
        rm_1 <= 2'b0;
        rm_2 <= 2'b0;
        rm_3 <= 2'b0;
        rm_4 <= 2'b0;
        rm_5 <= 2'b0;
        rm_6 <= 2'b0;
        rm_7 <= 2'b0;
        rm_8 <= 2'b0;
        rm_9 <= 2'b0;
        rm_10 <= 2'b0;
        rm_11 <= 2'b0;
        rm_12 <= 2'b0;
        rm_13 <= 2'b0;
        rm_14 <= 2'b0;
        rm_15 <= 2'b0;
        rm_16 <= 2'b0;
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
        exponent_a <= 11'b0;
        exponent_b <= 11'b0;
        expa_2 <= 11'b0;
        expb_2 <= 11'b0;
        expa_3 <= 11'b0;
        expb_3 <= 11'b0;
        mantissa_a <= 52'b0;
        mantissa_b <= 52'b0;
        mana_2 <= 52'b0;
        mana_3 <= 52'b0;
        manb_2 <= 52'b0;
        manb_3 <= 52'b0;
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
        exponent_small <= 11'b0;
        exponent_large <= 11'b0;
        expl_2 <= 11'b0;
        expl_3 <= 11'b0;
        expl_4 <= 11'b0;
        expl_5 <= 11'b0;
        expl_6 <= 11'b0;
        expl_7 <= 11'b0;
        expl_8 <= 11'b0;
        expl_9 <= 11'b0;
        expl_10 <= 11'b0;
        expl_11 <= 11'b0;
        mantissa_small <= 52'b0;
        mantissa_large <= 52'b0;
        mantissa_small_2 <= 52'b0;
        mantissa_large_2 <= 52'b0;
        mantissa_small_3 <= 52'b0;
        mantissa_large_3 <= 52'b0;
        exp_small_et0 <= 1'b0;
        exp_large_et0 <= 1'b0;
        exp_small_et0_2 <= 1'b0;
        exp_large_et0_2 <= 1'b0;
        exponent_diff <= 11'b0;
        exponent_diff_2 <= 11'b0;
        exponent_diff_3 <= 11'b0;
        bits_shifted_out <= 108'b0;
        bits_shifted_out_2 <= 108'b0;
        bits_shifted <= 1'b0;
        large_add <= 56'b0;
        large_add_2 <= 56'b0;
        large_add_3 <= 56'b0;
        small_add <= 56'b0;
        small_shift <= 56'b0;
        small_shift_2 <= 56'b0;
        small_shift_3 <= 56'b0;
        small_shift_4 <= 56'b0;
        large_add_4 <= 56'b0;
        large_add_5 <= 56'b0;
        small_shift_nonzero <= 1'b0;
        small_is_nonzero <= 1'b0;
        small_is_nonzero_2 <= 1'b0;
        small_is_nonzero_3 <= 1'b0;
        small_fraction_enable <= 1'b0;
        sum <= 56'b0;
        sum_2 <= 56'b0;
        sum_3 <= 56'b0;
        sum_4 <= 56'b0;
        sum_5 <= 56'b0;
        sum_6 <= 56'b0;
        sum_7 <= 56'b0;
        sum_8 <= 56'b0;
        sum_9 <= 56'b0;
        sum_10 <= 56'b0;
        sum_11 <= 56'b0;
        sum_overflow <= 1'b0;
        sumround_overflow <= 1'b0;
        sum_lsb <= 1'b0;
        sum_lsb_2 <= 1'b0;
        exponent_add <= 11'b0;
        exp_add_2 <= 11'b0;
        exponent_sub <= 11'b0;
        exp_sub_2 <= 11'b0;
        exp_sub_3 <= 11'b0;
        exp_sub_4 <= 11'b0;
        exp_sub_5 <= 11'b0;
        exp_sub_6 <= 11'b0;
        exp_sub_7 <= 11'b0;
        exp_sub_8 <= 11'b0;
        exp_add_3 <= 11'b0;
        exp_add_4 <= 11'b0;
        exp_add_5 <= 11'b0;
        exp_add_6 <= 11'b0;
        exp_add_7 <= 11'b0;
        exp_add_8 <= 11'b0;
        exp_add_9 <= 11'b0;
        diff_shift <= 6'b0;
        diff_shift_2 <= 6'b0;
        diff <= 56'b0;
        diff_2 <= 56'b0;
        diff_3 <= 56'b0;
        diff_4 <= 56'b0;
        diff_5 <= 56'b0;
        diff_6 <= 56'b0;
        diff_7 <= 56'b0;
        diff_8 <= 56'b0;
        diff_9 <= 56'b0;
        diff_10 <= 56'b0;
        diff_11 <= 56'b0;
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
        ready <= 1'b0;
        count_ready <= 1'b0;
        count_ready_0 <= 1'b0;
        count <= 5'b0;
        result_6 <= 64'b0;
        result_7 <= 64'b0;
        result_8 <= 64'b0;
        result_9 <= 64'b0;
        result_10 <= 64'b0;
        result_11 <= 64'b0;
        result_12 <= 64'b0;
        result_13 <= 64'b0;
        result_14 <= 64'b0;
        result_15 <= 64'b0;
        result_16 <= 64'b0;
        result_17 <= 64'b0;
        result_18 <= 64'b0;
        result_19 <= 64'b0;
        result_20 <= 64'b0;
        add_tmp <= 57'b0;
        round_tmp <= 57'b0;
        selected_sig <= 56'b0;
        selected_exp <= 11'b0;
        lzc_tmp <= 6'b0;
    end else if (enable) begin
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

        sign_a <= opa[63];
        sign_b <= opb[63];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        fpu_op_1 <= fpu_op;
        fpu_op_2 <= fpu_op_1;
        fpu_op_3 <= fpu_op_2;

        expa_et_inf <= (opa[62:52] == 11'h7ff);
        expb_et_inf <= (opb[62:52] == 11'h7ff);
        input_is_inf <= (opa[62:52] == 11'h7ff) | (opb[62:52] == 11'h7ff);
        expa_gt_expb <= (opa[62:52] > opb[62:52]);
        expa_et_expb <= (opa[62:52] == opb[62:52]);
        mana_gtet_manb <= (opa[51:0] >= opb[51:0]);
        a_gtet_b <= (opa[62:52] > opb[62:52]) |
                    ((opa[62:52] == opb[62:52]) & (opa[51:0] >= opb[51:0]));
        fpu_op_final <= fpu_op ^ (opa[63] ^ opb[63]);

        if ((opa[62:52] > opb[62:52]) ||
            ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) begin
            exponent_large <= opa[62:52];
            exponent_small <= opb[62:52];
            mantissa_large <= opa[51:0];
            mantissa_small <= opb[51:0];
            sign <= (fpu_op ^ (opa[63] ^ opb[63])) ? opa[63] : opa[63];
        end else begin
            exponent_large <= opb[62:52];
            exponent_small <= opa[62:52];
            mantissa_large <= opb[51:0];
            mantissa_small <= opa[51:0];
            sign <= (fpu_op ^ (opa[63] ^ opb[63])) ? (opb[63] ^ fpu_op) : opa[63];
        end

        exp_large_et0 <= (((opa[62:52] > opb[62:52]) ||
                          ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) ?
                          (opa[62:52] == 11'b0) : (opb[62:52] == 11'b0));
        exp_small_et0 <= (((opa[62:52] > opb[62:52]) ||
                          ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) ?
                          (opb[62:52] == 11'b0) : (opa[62:52] == 11'b0));

        exponent_diff <= (((opa[62:52] > opb[62:52]) ||
                          ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) ?
                          (opa[62:52] - opb[62:52]) : (opb[62:52] - opa[62:52]));

        // The generated nested ternaries had unmatched parentheses.  Express
        // the same magnitude ordering explicitly so the concatenations are
        // unambiguous to Verilog-2005 parsers.
        if (((opa[62:52] > opb[62:52]) ||
            ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0])))) begin
            large_add <= {(opa[62:52] != 11'b0), opa[51:0], 3'b000};
            small_add <= {(opb[62:52] != 11'b0), opb[51:0], 3'b000};
        end else begin
            large_add <= {(opb[62:52] != 11'b0), opb[51:0], 3'b000};
            small_add <= {(opa[62:52] != 11'b0), opa[51:0], 3'b000};
        end

        if (((opa[62:52] > opb[62:52]) ||
            ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0])))) begin
            small_shift <= shift_right_jam56({(opb[62:52] != 11'b0), opb[51:0], 3'b000},
                                             (opa[62:52] - opb[62:52]));
            bits_shifted <= |({(opb[62:52] != 11'b0), opb[51:0], 3'b000} &
                             ~({56{1'b1}} << (opa[62:52] - opb[62:52])));
        end else begin
            small_shift <= shift_right_jam56({(opa[62:52] != 11'b0), opa[51:0], 3'b000},
                                             (opb[62:52] - opa[62:52]));
            bits_shifted <= |({(opa[62:52] != 11'b0), opa[51:0], 3'b000} &
                             ~({56{1'b1}} << (opb[62:52] - opa[62:52])));
        end

        bits_shifted_out <= 108'b0;
        small_shift_nonzero <= |small_shift;
        small_is_nonzero <= |small_add;
        small_fraction_enable <= |small_add[54:0];

        sign_a2 <= sign_a;
        sign_b2 <= sign_b;
        sign_a3 <= sign_a2;
        sign_b3 <= sign_b2;
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

        expa_2 <= exponent_a;
        expb_2 <= exponent_b;
        expa_3 <= expa_2;
        expb_3 <= expb_2;
        mana_2 <= mantissa_a;
        manb_2 <= mantissa_b;
        mana_3 <= mana_2;
        manb_3 <= manb_2;

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
        exp_small_et0_2 <= exp_small_et0;
        exp_large_et0_2 <= exp_large_et0;
        exponent_diff_2 <= exponent_diff;
        exponent_diff_3 <= exponent_diff_2;
        bits_shifted_out_2 <= bits_shifted_out;
        large_add_2 <= large_add;
        large_add_3 <= large_add_2;
        small_shift_2 <= small_shift;
        small_shift_3 <= small_shift_2;
        small_shift_4 <= small_shift_3;
        large_add_4 <= large_add_3;
        large_add_5 <= large_add_4;
        small_is_nonzero_2 <= small_is_nonzero;
        small_is_nonzero_3 <= small_is_nonzero_2;

        add_tmp = {1'b0, large_add_2} + {1'b0, small_shift_2};
        sum <= add_tmp[55:0];
        sum_2 <= add_tmp[55:0];
        sum_3 <= sum_2;
        sum_overflow <= add_tmp[56];
        sum_lsb <= add_tmp[0];
        sum_lsb_2 <= sum_lsb;
        exponent_add <= expl_2;
        exp_add_2 <= exponent_add;

        diff <= large_add_2 - small_shift_2;
        diff_2 <= diff;
        diff_3 <= diff_2;
        exponent_sub <= expl_2;
        exp_sub_2 <= exponent_sub;

        if (!fpu_op_3) begin
            if (sum_overflow) begin
                sum_4 <= {sum_overflow, sum_3[55:4], sum_3[3], sum_3[2], (sum_3[1] | sum_3[0])};
                exp_add_3 <= exp_add_2 + 11'd1;
            end else begin
                sum_4 <= sum_3;
                exp_add_3 <= exp_add_2;
            end
            diff_4 <= 56'b0;
            exp_sub_3 <= 11'b0;
            diff_shift <= 6'b0;
            diff_shift_2 <= 6'b0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
        end else begin
            lzc_tmp = leading_zero_count56(diff_3);
            diff_shift <= lzc_tmp;
            diff_shift_2 <= diff_shift;
            if (diff_3 == 56'b0) begin
                diff_4 <= 56'b0;
                exp_sub_3 <= 11'b0;
                diffshift_gt_exponent <= 1'b1;
                diffshift_et_55 <= 1'b1;
            end else begin
                diff_4 <= diff_3 << lzc_tmp;
                if (exp_sub_2 > lzc_tmp) begin
                    exp_sub_3 <= exp_sub_2 - lzc_tmp;
                end else begin
                    exp_sub_3 <= 11'b0;
                end
                diffshift_gt_exponent <= (lzc_tmp >= exp_sub_2);
                diffshift_et_55 <= (lzc_tmp == 6'd55);
            end
            sum_4 <= 56'b0;
            exp_add_3 <= 11'b0;
        end

        if (fpu_op_3) begin
            selected_sig <= diff_4;
            selected_exp <= exp_sub_3;
        end else begin
            selected_sig <= sum_4;
            selected_exp <= exp_add_3;
        end

        sum_5 <= selected_sig;
        diff_5 <= diff_4;
        exp_add_4 <= selected_exp;
        exp_sub_4 <= exp_sub_3;
        sum_6 <= sum_5;
        sum_7 <= sum_6;
        sum_8 <= sum_7;
        sum_9 <= sum_8;
        sum_10 <= sum_9;
        sum_11 <= sum_10;
        diff_6 <= diff_5;
        diff_7 <= diff_6;
        diff_8 <= diff_7;
        diff_9 <= diff_8;
        diff_10 <= diff_9;
        diff_11 <= diff_10;
        exp_sub_5 <= exp_sub_4;
        exp_sub_6 <= exp_sub_5;
        exp_sub_7 <= exp_sub_6;
        exp_sub_8 <= exp_sub_7;
        exp_add_5 <= exp_add_4;
        exp_add_6 <= exp_add_5;
        exp_add_7 <= exp_add_6;
        exp_add_8 <= exp_add_7;
        exp_add_9 <= exp_add_8;

        round_nearest_mode <= (rm_5 == 2'b00);
        round_posinf_mode <= (rm_5 == 2'b10);
        round_neginf_mode <= (rm_5 == 2'b11);
        round_nearest_trigger <= sum_5[2] & (sum_5[1] | sum_5[0] | sum_5[3]);
        round_nearest_exception <= |sum_5[2:0];
        round_nearest_enable <= (rm_5 == 2'b00) & round_nearest_trigger;
        round_posinf_trigger <= (~sign_5) & (|sum_5[2:0]);
        round_posinf_enable <= (rm_5 == 2'b10) & round_posinf_trigger;
        round_neginf_trigger <= sign_5 & (|sum_5[2:0]);
        round_neginf_enable <= (rm_5 == 2'b11) & round_neginf_trigger;
        round_enable <= round_increment(rm_5, sign_5, sum_5);

        round_tmp = {1'b0, sum_5} + (round_increment(rm_5, sign_5, sum_5) ? 57'd8 : 57'd0);
        sumround_overflow <= round_tmp[56] & ~fpu_op_3;
        diffround_overflow <= round_tmp[56] & fpu_op_3;

        if (in_inf5) begin
            result_6 <= {sign_5, 11'h7ff, 52'b0};
        end else if (sum_5 == 56'b0) begin
            result_6 <= {sign_5, 63'b0};
        end else begin
            if (round_tmp[56]) begin
                exp_add_5 <= exp_add_4 + 11'd1;
                if ((exp_add_4 + 11'd1) >= 11'h7ff) begin
                    result_6 <= {sign_5, 11'h7ff, 52'b0};
                end else begin
                    result_6 <= {sign_5, exp_add_4 + 11'd1, round_tmp[55:4]};
                end
            end else begin
                if (exp_add_4 >= 11'h7ff) begin
                    result_6 <= {sign_5, 11'h7ff, 52'b0};
                end else if (exp_add_4 == 11'b0) begin
                    result_6 <= {sign_5, 11'b0, round_tmp[54:3]};
                end else begin
                    result_6 <= {sign_5, exp_add_4, round_tmp[54:3]};
                end
            end
        end

        result_7 <= result_6;
        result_8 <= result_7;
        result_9 <= result_8;
        result_10 <= result_9;
        result_11 <= result_10;
        result_12 <= result_11;
        result_13 <= result_12;
        result_14 <= result_13;
        result_15 <= result_14;
        result_16 <= result_15;
        result_17 <= result_16;
        result_18 <= result_17;
        result_19 <= result_18;
        result_20 <= result_19;
        outfp <= result_20;
        out <= outfp;

        ready <= fpuf_21;
        count_ready_0 <= 1'b1;
        count_ready <= fpuf_21;
        if (fpuf_21) begin
            count <= 5'b0;
        end else if (count_ready_0) begin
            count <= count + 5'd1;
        end else begin
            count <= 5'd1;
        end
    end
end

endmodule
