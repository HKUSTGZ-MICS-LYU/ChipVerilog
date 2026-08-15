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

localparam [63:0] QNAN = 64'h7ff8000000000000;

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
reg op_final_2;
reg op_final_3;
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
// The generated datapath produces result_pipe[0] four clocks later than the
// testbench-facing 22-cycle contract assumed by the original 16-entry delay.
// Preserve the datapath and align only the output transport latency.
reg [63:0] result_pipe [0:19];

integer i;

function [55:0] make_sig56;
    input exp_is_zero;
    input [51:0] mant;
    begin
        // Match the bundled OpenCores-derived reference: exponent-zero inputs
        // are flushed to zero rather than treated as IEEE subnormals.
        make_sig56 = exp_is_zero ? 56'd0 : {1'b1, mant, 3'b000};
    end
endfunction

function [55:0] sticky_rshift56;
    input [55:0] value;
    input [10:0] shamt;
    reg [55:0] tmp;
    reg sticky;
    integer idx;
    begin
        tmp = 56'd0;
        sticky = 1'b0;
        if (shamt == 11'd0) begin
            tmp = value;
        end else if (shamt >= 11'd56) begin
            tmp = 56'd0;
            tmp[0] = |value;
        end else begin
            tmp = value >> shamt;
            for (idx = 0; idx < 56; idx = idx + 1) begin
                if ((idx < shamt) && value[idx]) begin
                    sticky = 1'b1;
                end
            end
            tmp[0] = tmp[0] | sticky;
        end
        sticky_rshift56 = tmp;
    end
endfunction

function [5:0] leadzero56;
    input [55:0] value;
    reg found;
    integer idx;
    begin
        leadzero56 = 6'd56;
        found = 1'b0;
        for (idx = 55; idx >= 0; idx = idx - 1) begin
            if (!found && value[idx]) begin
                leadzero56 = 6'd55 - idx;
                found = 1'b1;
            end
        end
    end
endfunction

function [55:0] add56_lo;
    input [55:0] a;
    input [55:0] b;
    reg [56:0] tmp;
    begin
        tmp = {1'b0, a} + {1'b0, b};
        add56_lo = tmp[55:0];
    end
endfunction

function add56_hi;
    input [55:0] a;
    input [55:0] b;
    reg [56:0] tmp;
    begin
        tmp = {1'b0, a} + {1'b0, b};
        add56_hi = tmp[56];
    end
endfunction

function [10:0] norm_sub_exp;
    input [10:0] exp_in;
    input [55:0] diff_in;
    reg [5:0] shamt;
    begin
        if (diff_in == 56'd0) begin
            norm_sub_exp = 11'd0;
        end else begin
            shamt = leadzero56(diff_in);
            if (exp_in > shamt) begin
                norm_sub_exp = exp_in - shamt;
            end else begin
                norm_sub_exp = 11'd0;
            end
        end
    end
endfunction

function [55:0] norm_sub_sig;
    input [10:0] exp_in;
    input [55:0] diff_in;
    reg [5:0] shamt;
    begin
        if (diff_in == 56'd0) begin
            norm_sub_sig = 56'd0;
        end else begin
            shamt = leadzero56(diff_in);
            if (exp_in > shamt) begin
                norm_sub_sig = diff_in << shamt;
            end else if (exp_in != 11'd0) begin
                norm_sub_sig = diff_in << (exp_in - 11'd1);
            end else begin
                norm_sub_sig = diff_in;
            end
        end
    end
endfunction

function [63:0] round_pack;
    input sign_in;
    input [10:0] exp_in;
    input [55:0] sig_in;
    input [1:0] rm_in;
    reg guardb;
    reg roundb;
    reg stickyb;
    reg lsb;
    reg inc;
    reg [53:0] rounded;
    reg [52:0] sig_main;
    reg [10:0] exp_work;
    begin
        guardb = sig_in[2];
        roundb = sig_in[1];
        stickyb = sig_in[0];
        lsb = sig_in[3];
        case (rm_in)
            2'b00: inc = guardb && (roundb || stickyb || lsb);
            2'b10: inc = (~sign_in) && (guardb || roundb || stickyb);
            2'b11: inc = sign_in && (guardb || roundb || stickyb);
            default: inc = 1'b0;
        endcase
        rounded = {1'b0, sig_in[55:3]} + inc;
        exp_work = exp_in;
        if (rounded[53]) begin
            sig_main = rounded[53:1];
            if (exp_work != 11'h7ff) begin
                exp_work = exp_work + 11'd1;
            end
        end else begin
            sig_main = rounded[52:0];
        end
        if (sig_main == 53'd0) begin
            round_pack = {sign_in, 11'd0, 52'd0};
        end else if (exp_work >= 11'h7ff) begin
            case (rm_in)
                2'b01: round_pack = {sign_in, 11'h7fe, 52'hfffffffffffff};
                2'b10: round_pack = sign_in ? {1'b1, 11'h7fe, 52'hfffffffffffff} : {1'b0, 11'h7ff, 52'd0};
                2'b11: round_pack = sign_in ? {1'b1, 11'h7ff, 52'd0} : {1'b0, 11'h7fe, 52'hfffffffffffff};
                default: round_pack = {sign_in, 11'h7ff, 52'd0};
            endcase
        end else if (exp_work == 11'd0) begin
            round_pack = {sign_in, 11'd0, sig_main[51:0]};
        end else begin
            round_pack = {sign_in, exp_work, sig_main[51:0]};
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        outfp <= 64'd0;
        out <= 64'd0;
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
        op_final_2 <= 1'b0;
        op_final_3 <= 1'b0;
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
        for (i = 0; i < 20; i = i + 1) begin
            result_pipe[i] <= 64'd0;
        end
    end else if (enable) begin
        outfp <= result_pipe[19];
        out <= result_pipe[19];
        ready <= fpuf_21;

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

        count_ready <= count_ready_0;
        count_ready_0 <= 1'b1;
        if (fpuf_21) begin
            count <= 5'd0;
        end else if (count_ready) begin
            count <= count + 5'd1;
        end

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
        op_final_3 <= op_final_2;
        op_final_2 <= fpu_op_final;
        fpu_op_final <= fpu_op ^ (opa[63] ^ opb[63]);

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

        expa_3 <= expa_2;
        expb_3 <= expb_2;
        expa_2 <= exponent_a;
        expb_2 <= exponent_b;
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];

        mana_3 <= mana_2;
        manb_3 <= manb_2;
        mana_2 <= mantissa_a;
        manb_2 <= mantissa_b;
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];

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
        input_is_inf <= ((opa[62:52] == 11'h7ff) || (opb[62:52] == 11'h7ff));

        expa_et_inf <= (opa[62:52] == 11'h7ff);
        expb_et_inf <= (opb[62:52] == 11'h7ff);
        expa_gt_expb <= (opa[62:52] > opb[62:52]);
        expa_et_expb <= (opa[62:52] == opb[62:52]);
        mana_gtet_manb <= (opa[51:0] >= opb[51:0]);
        a_gtet_b <= (opa[62:52] > opb[62:52]) || ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]));

        if ((opa[62:52] > opb[62:52]) || ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) begin
            exponent_large <= (opa[62:52] == 11'd0) ? 11'd1 : opa[62:52];
            exponent_small <= (opb[62:52] == 11'd0) ? 11'd1 : opb[62:52];
            mantissa_large <= opa[51:0];
            mantissa_small <= opb[51:0];
            exp_large_et0 <= (opa[62:52] == 11'd0);
            exp_small_et0 <= (opb[62:52] == 11'd0);
            exponent_diff <= ((opa[62:52] == 11'd0) ? 11'd1 : opa[62:52]) - ((opb[62:52] == 11'd0) ? 11'd1 : opb[62:52]);
        end else begin
            exponent_large <= (opb[62:52] == 11'd0) ? 11'd1 : opb[62:52];
            exponent_small <= (opa[62:52] == 11'd0) ? 11'd1 : opa[62:52];
            mantissa_large <= opb[51:0];
            mantissa_small <= opa[51:0];
            exp_large_et0 <= (opb[62:52] == 11'd0);
            exp_small_et0 <= (opa[62:52] == 11'd0);
            exponent_diff <= ((opb[62:52] == 11'd0) ? 11'd1 : opb[62:52]) - ((opa[62:52] == 11'd0) ? 11'd1 : opa[62:52]);
        end

        if ((fpu_op ^ (opa[63] ^ opb[63])) == 1'b0) begin
            sign <= opa[63];
        end else if ((opa[62:52] > opb[62:52]) || ((opa[62:52] == opb[62:52]) && (opa[51:0] >= opb[51:0]))) begin
            sign <= opa[63];
        end else begin
            sign <= opb[63] ^ fpu_op;
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
        mantissa_large_3 <= mantissa_large_2;
        mantissa_small_2 <= mantissa_small;
        mantissa_large_2 <= mantissa_large;

        exp_small_et0_2 <= exp_small_et0;
        exp_large_et0_2 <= exp_large_et0;
        exponent_diff_3 <= exponent_diff_2;
        exponent_diff_2 <= exponent_diff;

        bits_shifted_out_2 <= bits_shifted_out;
        bits_shifted_out <= 108'd0;
        bits_shifted <= 1'b0;

        large_add_5 <= large_add_4;
        large_add_4 <= large_add_3;
        large_add_3 <= large_add_2;
        large_add_2 <= large_add;
        large_add <= make_sig56(exp_large_et0, mantissa_large);

        small_add <= make_sig56(exp_small_et0, mantissa_small);
        small_shift_4 <= small_shift_3;
        small_shift_3 <= small_shift_2;
        small_shift_2 <= small_shift;
        small_shift <= sticky_rshift56(make_sig56(exp_small_et0, mantissa_small), exponent_diff);

        small_shift_nonzero <= |sticky_rshift56(make_sig56(exp_small_et0, mantissa_small), exponent_diff);
        small_is_nonzero_3 <= small_is_nonzero_2;
        small_is_nonzero_2 <= small_is_nonzero;
        small_is_nonzero <= |make_sig56(exp_small_et0, mantissa_small);
        small_fraction_enable <= 1'b0;

        sum_11 <= sum_10;
        sum_10 <= sum_9;
        sum_9 <= sum_8;
        sum_8 <= sum_7;
        sum_7 <= sum_6;
        sum_6 <= sum_5;
        sum_5 <= sum_4;
        sum_4 <= sum_3;
        sum_3 <= sum_2;
        sum_2 <= sum_overflow ? {1'b1, sum[55:1]} : sum;
        sum <= add56_lo(make_sig56(exp_large_et0, mantissa_large), sticky_rshift56(make_sig56(exp_small_et0, mantissa_small), exponent_diff));
        sum_overflow <= add56_hi(make_sig56(exp_large_et0, mantissa_large), sticky_rshift56(make_sig56(exp_small_et0, mantissa_small), exponent_diff));
        sumround_overflow <= 1'b0;
        sum_lsb_2 <= sum_lsb;
        sum_lsb <= 1'b0;

        exponent_add <= exponent_large;
        exp_add_9 <= exp_add_8;
        exp_add_8 <= exp_add_7;
        exp_add_7 <= exp_add_6;
        exp_add_6 <= exp_add_5;
        exp_add_5 <= exp_add_4;
        exp_add_4 <= exp_add_3;
        exp_add_3 <= sum_overflow ? (exp_add_2 + 11'd1) : exp_add_2;
        exp_add_2 <= exponent_large;

        exponent_sub <= exponent_large;
        exp_sub_8 <= exp_sub_7;
        exp_sub_7 <= exp_sub_6;
        exp_sub_6 <= exp_sub_5;
        exp_sub_5 <= exp_sub_4;
        exp_sub_4 <= exp_sub_3;
        exp_sub_3 <= exp_sub_2;
        exp_sub_2 <= exponent_large;

        diff_11 <= diff_10;
        diff_10 <= diff_9;
        diff_9 <= diff_8;
        diff_8 <= diff_7;
        diff_7 <= diff_6;
        diff_6 <= diff_5;
        diff_5 <= diff_4;
        diff_4 <= diff_3;
        diff_3 <= diff_2;
        diff_2 <= diff;
        diff <= make_sig56(exp_large_et0, mantissa_large) - sticky_rshift56(make_sig56(exp_small_et0, mantissa_small), exponent_diff);
        diff_shift <= leadzero56(diff);
        diff_shift_2 <= diff_shift;
        diffshift_gt_exponent <= (leadzero56(diff) >= exponent_large);
        diffshift_et_55 <= (leadzero56(diff) == 6'd55);
        diffround_overflow <= 1'b0;

        round_nearest_mode <= (rm_3 == 2'b00);
        round_posinf_mode <= (rm_3 == 2'b10);
        round_neginf_mode <= (rm_3 == 2'b11);
        round_nearest_trigger <= 1'b0;
        round_nearest_exception <= 1'b0;
        round_nearest_enable <= 1'b0;
        round_posinf_trigger <= 1'b0;
        round_posinf_enable <= 1'b0;
        round_neginf_trigger <= 1'b0;
        round_neginf_enable <= 1'b0;
        round_enable <= 1'b1;

        for (i = 19; i > 0; i = i - 1) begin
            result_pipe[i] <= result_pipe[i-1];
        end

        if (((expa_3 == 11'h7ff) && (mana_3 != 52'd0)) || ((expb_3 == 11'h7ff) && (manb_3 != 52'd0))) begin
            result_pipe[0] <= QNAN;
        end else if (in_inf3 && (expa_3 == 11'h7ff) && (expb_3 == 11'h7ff) && op_final_3) begin
            result_pipe[0] <= QNAN;
        end else if (in_inf3) begin
            if ((expa_3 == 11'h7ff) && (expb_3 == 11'h7ff)) begin
                result_pipe[0] <= {sign_a3, 11'h7ff, 52'd0};
            end else if (expa_3 == 11'h7ff) begin
                result_pipe[0] <= {sign_a3, 11'h7ff, 52'd0};
            end else begin
                result_pipe[0] <= {sign_b3 ^ fpu_op_3, 11'h7ff, 52'd0};
            end
        end else if (op_final_3 == 1'b0) begin
            result_pipe[0] <= round_pack(sign_3, exp_add_3, sum_2, rm_3);
        end else if (diff_2 == 56'd0) begin
            result_pipe[0] <= 64'd0;
        end else begin
            result_pipe[0] <= round_pack(sign_3, norm_sub_exp(exp_sub_3, diff_2), norm_sub_sig(exp_sub_3, diff_2), rm_3);
        end
    end
end

endmodule
