module fpu_addsub (
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

reg [63:0] out_pipe_5;
reg [63:0] out_pipe_6;
reg [63:0] out_pipe_7;
reg [63:0] out_pipe_8;
reg [63:0] out_pipe_9;
reg [63:0] out_pipe_10;
reg [63:0] out_pipe_11;
reg [63:0] out_pipe_12;
reg [63:0] out_pipe_13;
reg [63:0] out_pipe_14;
reg [63:0] out_pipe_15;
reg [63:0] out_pipe_16;
reg [63:0] out_pipe_17;
reg [63:0] out_pipe_18;
reg [63:0] out_pipe_19;
reg [63:0] out_pipe_20;
reg [56:0] add_temp;
reg [55:0] diff_temp;
reg [5:0] lz_temp;

wire sign_a_in;
wire sign_b_in;
wire [10:0] exponent_a_in;
wire [10:0] exponent_b_in;
wire [51:0] mantissa_a_in;
wire [51:0] mantissa_b_in;
wire expa_et_inf_in;
wire expb_et_inf_in;
wire expa_gt_expb_in;
wire expa_et_expb_in;
wire mana_gtet_manb_in;
wire a_gtet_b_in;
wire [10:0] exponent_large_in;
wire [10:0] exponent_small_in;
wire [51:0] mantissa_large_in;
wire [51:0] mantissa_small_in;
wire exp_small_et0_in;
wire exp_large_et0_in;
wire [10:0] exponent_diff_in;
wire fpu_op_final_in;
wire sign_result_in;
wire [55:0] large_add_in;
wire [55:0] small_add_in;

assign sign_a_in = opa[63];
assign sign_b_in = opb[63];
assign exponent_a_in = opa[62:52];
assign exponent_b_in = opb[62:52];
assign mantissa_a_in = opa[51:0];
assign mantissa_b_in = opb[51:0];
assign expa_et_inf_in = (exponent_a_in == 11'h7ff) && (mantissa_a_in == 52'b0);
assign expb_et_inf_in = (exponent_b_in == 11'h7ff) && (mantissa_b_in == 52'b0);
assign expa_gt_expb_in = (exponent_a_in > exponent_b_in);
assign expa_et_expb_in = (exponent_a_in == exponent_b_in);
assign mana_gtet_manb_in = (mantissa_a_in >= mantissa_b_in);
assign a_gtet_b_in = expa_gt_expb_in | (expa_et_expb_in & mana_gtet_manb_in);
assign exponent_large_in = a_gtet_b_in ? exponent_a_in : exponent_b_in;
assign exponent_small_in = a_gtet_b_in ? exponent_b_in : exponent_a_in;
assign mantissa_large_in = a_gtet_b_in ? mantissa_a_in : mantissa_b_in;
assign mantissa_small_in = a_gtet_b_in ? mantissa_b_in : mantissa_a_in;
assign exp_small_et0_in = (exponent_small_in == 11'b0);
assign exp_large_et0_in = (exponent_large_in == 11'b0);
assign exponent_diff_in = exponent_large_in - exponent_small_in;
assign fpu_op_final_in = fpu_op ^ (sign_a_in ^ sign_b_in);
assign sign_result_in = fpu_op_final_in ? (a_gtet_b_in ? sign_a_in : (sign_b_in ^ fpu_op)) : sign_a_in;
assign large_add_in = {(exponent_large_in != 11'b0), mantissa_large_in, 3'b000};
assign small_add_in = {(exponent_small_in != 11'b0), mantissa_small_in, 3'b000};

function [55:0] shift_right_jam56;
    input [55:0] value;
    input [10:0] shift;
    integer i;
    reg sticky;
    reg [55:0] temp;
begin
    if (shift == 0) begin
        shift_right_jam56 = value;
    end else if (shift >= 56) begin
        shift_right_jam56 = (|value) ? 56'b1 : 56'b0;
    end else begin
        temp = value >> shift;
        sticky = 1'b0;
        for (i = 0; i < 56; i = i + 1) begin
            if (i < shift) begin
                sticky = sticky | value[i];
            end
        end
        temp[0] = temp[0] | sticky;
        shift_right_jam56 = temp;
    end
end
endfunction

function [5:0] leading_zero56;
    input [55:0] value;
    integer i;
begin
    leading_zero56 = 6'd56;
    for (i = 55; i >= 0; i = i - 1) begin
        if (value[i] && (leading_zero56 == 6'd56)) begin
            leading_zero56 = 6'd55 - i[5:0];
        end
    end
end
endfunction

function [63:0] pack_fp64;
    input sign_in_f;
    input [10:0] exp_in_f;
    input [55:0] sig_in_f;
    input [1:0] rm_in_f;
    input inf_in_f;
    reg round_inc;
    reg [56:0] sig_ext;
    reg [55:0] sig_round;
    reg [10:0] exp_round;
    reg discarded;
begin
    if (inf_in_f) begin
        pack_fp64 = {sign_in_f, 11'h7ff, 52'b0};
    end else if (sig_in_f == 56'b0) begin
        pack_fp64 = 64'b0;
    end else begin
        discarded = |sig_in_f[2:0];
        case (rm_in_f)
            2'b00: round_inc = sig_in_f[2] & (sig_in_f[1] | sig_in_f[0] | sig_in_f[3]);
            2'b01: round_inc = 1'b0;
            2'b10: round_inc = (~sign_in_f) & discarded;
            default: round_inc = sign_in_f & discarded;
        endcase
        sig_ext = {1'b0, sig_in_f} + (round_inc ? 57'd8 : 57'd0);
        sig_round = sig_ext[55:0];
        exp_round = exp_in_f;
        if (sig_ext[56]) begin
            sig_round = sig_ext[56:1];
            if (exp_in_f == 11'h7fe) begin
                exp_round = 11'h7ff;
            end else if (exp_in_f != 11'h7ff) begin
                exp_round = exp_in_f + 11'd1;
            end
        end else if ((exp_in_f == 11'b0) && sig_round[55]) begin
            exp_round = 11'd1;
        end
        if (exp_round >= 11'h7ff) begin
            pack_fp64 = {sign_in_f, 11'h7ff, 52'b0};
        end else begin
            pack_fp64 = {sign_in_f, exp_round, sig_round[54:3]};
        end
    end
end
endfunction

always @(posedge clk or posedge rst) begin
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
        out_pipe_5 <= 64'b0;
        out_pipe_6 <= 64'b0;
        out_pipe_7 <= 64'b0;
        out_pipe_8 <= 64'b0;
        out_pipe_9 <= 64'b0;
        out_pipe_10 <= 64'b0;
        out_pipe_11 <= 64'b0;
        out_pipe_12 <= 64'b0;
        out_pipe_13 <= 64'b0;
        out_pipe_14 <= 64'b0;
        out_pipe_15 <= 64'b0;
        out_pipe_16 <= 64'b0;
        out_pipe_17 <= 64'b0;
        out_pipe_18 <= 64'b0;
        out_pipe_19 <= 64'b0;
        out_pipe_20 <= 64'b0;
        add_temp <= 57'b0;
        diff_temp <= 56'b0;
        lz_temp <= 6'b0;
    end else if (enable) begin
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
        ready <= fpuf_21;
        count_ready_0 <= 1'b1;
        count_ready <= fpuf_21;
        if (count != 5'd31) begin
            count <= count + 5'd1;
        end

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

        sign_a <= sign_a_in;
        sign_b <= sign_b_in;
        sign_a2 <= sign_a;
        sign_a3 <= sign_a2;
        sign_b2 <= sign_b;
        sign_b3 <= sign_b2;
        sign <= sign_result_in;
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

        fpu_op_1 <= fpu_op;
        fpu_op_final <= fpu_op_final_in;
        fpu_op_2 <= fpu_op_final;
        fpu_op_3 <= fpu_op_2;

        exponent_a <= exponent_a_in;
        exponent_b <= exponent_b_in;
        expa_2 <= exponent_a;
        expb_2 <= exponent_b;
        expa_3 <= expa_2;
        expb_3 <= expb_2;

        mantissa_a <= mantissa_a_in;
        mantissa_b <= mantissa_b_in;
        mana_2 <= mantissa_a;
        mana_3 <= mana_2;
        manb_2 <= mantissa_b;
        manb_3 <= manb_2;

        expa_et_inf <= expa_et_inf_in;
        expb_et_inf <= expb_et_inf_in;
        input_is_inf <= expa_et_inf_in | expb_et_inf_in;
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

        expa_gt_expb <= expa_gt_expb_in;
        expa_et_expb <= expa_et_expb_in;
        mana_gtet_manb <= mana_gtet_manb_in;
        a_gtet_b <= a_gtet_b_in;

        exponent_small <= exponent_small_in;
        exponent_large <= exponent_large_in;
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

        mantissa_small <= mantissa_small_in;
        mantissa_large <= mantissa_large_in;
        mantissa_small_2 <= mantissa_small;
        mantissa_large_2 <= mantissa_large;
        mantissa_small_3 <= mantissa_small_2;
        mantissa_large_3 <= mantissa_large_2;

        exp_small_et0 <= exp_small_et0_in;
        exp_large_et0 <= exp_large_et0_in;
        exp_small_et0_2 <= exp_small_et0;
        exp_large_et0_2 <= exp_large_et0;

        exponent_diff <= exponent_diff_in;
        exponent_diff_2 <= exponent_diff;
        exponent_diff_3 <= exponent_diff_2;

        bits_shifted_out <= {small_add_in, 52'b0};
        bits_shifted_out_2 <= bits_shifted_out;
        bits_shifted <= |small_shift[2:0];

        large_add <= large_add_in;
        small_add <= small_add_in;
        small_shift <= shift_right_jam56(small_add, exponent_diff);
        large_add_2 <= large_add;
        large_add_3 <= large_add_2;
        large_add_4 <= large_add_3;
        large_add_5 <= large_add_4;
        small_shift_2 <= small_shift;
        small_shift_3 <= small_shift_2;
        small_shift_4 <= small_shift_3;
        small_shift_nonzero <= |small_shift;
        small_is_nonzero <= |small_add;
        small_is_nonzero_2 <= small_is_nonzero;
        small_is_nonzero_3 <= small_is_nonzero_2;
        small_fraction_enable <= |small_shift[2:0];

        add_temp = {1'b0, large_add_2} + {1'b0, small_shift_2};
        diff_temp = large_add_2 - small_shift_2;
        lz_temp = leading_zero56(diff_temp);

        if (fpu_op_2) begin
            diff <= diff_temp;
            if (diff_temp == 56'b0) begin
                diff_2 <= 56'b0;
                exponent_sub <= 11'b0;
            end else if (expl_2 > {5'b0, lz_temp}) begin
                diff_2 <= diff_temp << lz_temp;
                exponent_sub <= expl_2 - {5'b0, lz_temp};
            end else begin
                if (expl_2 > 11'd1) begin
                    diff_2 <= diff_temp << (expl_2 - 11'd1);
                end else begin
                    diff_2 <= diff_temp;
                end
                exponent_sub <= 11'b0;
            end
            diff_shift <= lz_temp;
            diff_shift_2 <= diff_shift;
            diffshift_gt_exponent <= (lz_temp > expl_2[5:0]);
            diffshift_et_55 <= (lz_temp == 6'd55);
            exponent_add <= 11'b0;
            sum <= 56'b0;
            sum_overflow <= 1'b0;
        end else begin
            if (add_temp[56]) begin
                sum <= add_temp[56:1];
                exponent_add <= expl_2 + 11'd1;
                sum_overflow <= 1'b1;
            end else begin
                sum <= add_temp[55:0];
                exponent_add <= expl_2;
                sum_overflow <= 1'b0;
            end
            sum_lsb <= add_temp[3];
            diff <= 56'b0;
            diff_2 <= 56'b0;
            diff_shift <= 6'b0;
            diff_shift_2 <= 6'b0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
            exponent_sub <= 11'b0;
        end

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
        sum_lsb_2 <= sum_lsb;

        exp_add_2 <= exponent_add;
        exp_add_3 <= exp_add_2;
        exp_add_4 <= exp_add_3;
        exp_add_5 <= exp_add_4;
        exp_add_6 <= exp_add_5;
        exp_add_7 <= exp_add_6;
        exp_add_8 <= exp_add_7;
        exp_add_9 <= exp_add_8;

        exp_sub_2 <= exponent_sub;
        exp_sub_3 <= exp_sub_2;
        exp_sub_4 <= exp_sub_3;
        exp_sub_5 <= exp_sub_4;
        exp_sub_6 <= exp_sub_5;
        exp_sub_7 <= exp_sub_6;
        exp_sub_8 <= exp_sub_7;

        diff_3 <= diff_2;
        diff_4 <= diff_3;
        diff_5 <= diff_4;
        diff_6 <= diff_5;
        diff_7 <= diff_6;
        diff_8 <= diff_7;
        diff_9 <= diff_8;
        diff_10 <= diff_9;
        diff_11 <= diff_10;

        round_nearest_mode <= (rm_3 == 2'b00);
        round_posinf_mode <= (rm_3 == 2'b10);
        round_neginf_mode <= (rm_3 == 2'b11);
        round_nearest_trigger <= fpu_op_3 ? diff_2[2] & (diff_2[1] | diff_2[0] | diff_2[3]) : sum[2] & (sum[1] | sum[0] | sum[3]);
        round_nearest_exception <= fpu_op_3 ? |diff_2[2:0] : |sum[2:0];
        round_nearest_enable <= round_nearest_mode & round_nearest_trigger;
        round_posinf_trigger <= (~sign_3) & (fpu_op_3 ? |diff_2[2:0] : |sum[2:0]);
        round_posinf_enable <= round_posinf_mode & round_posinf_trigger;
        round_neginf_trigger <= sign_3 & (fpu_op_3 ? |diff_2[2:0] : |sum[2:0]);
        round_neginf_enable <= round_neginf_mode & round_neginf_trigger;
        round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;
        sumround_overflow <= 1'b0;
        diffround_overflow <= 1'b0;

        if (in_inf3) begin
            outfp <= pack_fp64(sign_3, 11'h7ff, 56'b0, rm_3, 1'b1);
        end else if (fpu_op_3) begin
            outfp <= pack_fp64(sign_3, exponent_sub, diff_2, rm_3, 1'b0);
        end else begin
            outfp <= pack_fp64(sign_3, exponent_add, sum, rm_3, 1'b0);
        end

        out_pipe_5 <= outfp;
        out_pipe_6 <= out_pipe_5;
        out_pipe_7 <= out_pipe_6;
        out_pipe_8 <= out_pipe_7;
        out_pipe_9 <= out_pipe_8;
        out_pipe_10 <= out_pipe_9;
        out_pipe_11 <= out_pipe_10;
        out_pipe_12 <= out_pipe_11;
        out_pipe_13 <= out_pipe_12;
        out_pipe_14 <= out_pipe_13;
        out_pipe_15 <= out_pipe_14;
        out_pipe_16 <= out_pipe_15;
        out_pipe_17 <= out_pipe_16;
        out_pipe_18 <= out_pipe_17;
        out_pipe_19 <= out_pipe_18;
        out_pipe_20 <= out_pipe_19;
        out <= out_pipe_20;
    end else begin
        fpuf_2 <= 1'b0;
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
        ready <= fpuf_21;
        count_ready_0 <= 1'b0;
        count_ready <= 1'b0;
        count <= 5'b0;
        out_pipe_5 <= outfp;
        out_pipe_6 <= out_pipe_5;
        out_pipe_7 <= out_pipe_6;
        out_pipe_8 <= out_pipe_7;
        out_pipe_9 <= out_pipe_8;
        out_pipe_10 <= out_pipe_9;
        out_pipe_11 <= out_pipe_10;
        out_pipe_12 <= out_pipe_11;
        out_pipe_13 <= out_pipe_12;
        out_pipe_14 <= out_pipe_13;
        out_pipe_15 <= out_pipe_14;
        out_pipe_16 <= out_pipe_15;
        out_pipe_17 <= out_pipe_16;
        out_pipe_18 <= out_pipe_17;
        out_pipe_19 <= out_pipe_18;
        out_pipe_20 <= out_pipe_19;
        out <= out_pipe_20;
    end
end

endmodule
