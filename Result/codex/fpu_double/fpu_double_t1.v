module fpu (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [2:0] fpu_op,
    input [63:0] opa,
    input [63:0] opb,
    output reg [63:0] out,
    output reg ready,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg exception,
    output reg invalid
);

localparam [2:0] OP_ADD = 3'b000;
localparam [2:0] OP_SUB = 3'b001;
localparam [2:0] OP_MUL = 3'b010;
localparam [2:0] OP_DIV = 3'b011;
localparam integer LATENCY = 4;
localparam [63:0] QNAN = 64'h7ff8_0000_0000_0000;
localparam [63:0] POS_INF = 64'h7ff0_0000_0000_0000;
localparam [63:0] NEG_INF = 64'hfff0_0000_0000_0000;
localparam [63:0] POS_MAX = 64'h7fef_ffff_ffff_ffff;
localparam [63:0] NEG_MAX = 64'hffef_ffff_ffff_ffff;

reg enable_d;
reg busy;
reg [2:0] latency_cnt;

reg [63:0] opa_reg;
reg [63:0] opb_reg;
reg [2:0] fpu_op_reg;
reg [1:0] rmode_reg;

reg [63:0] pending_out;
reg pending_underflow;
reg pending_overflow;
reg pending_inexact;
reg pending_exception;
reg pending_invalid;

reg [63:0] calc_out;
reg calc_underflow;
reg calc_overflow;
reg calc_inexact;
reg calc_exception;
reg calc_invalid;

function [55:0] shift_right_sticky56;
    input [55:0] value;
    input integer sh;
    integer j;
    reg sticky_bit;
    begin
        if (sh <= 0) begin
            shift_right_sticky56 = value;
        end else if (sh >= 56) begin
            shift_right_sticky56 = {55'd0, |value};
        end else begin
            sticky_bit = 1'b0;
            for (j = 0; j < sh; j = j + 1) begin
                sticky_bit = sticky_bit | value[j];
            end
            shift_right_sticky56 = value >> sh;
            shift_right_sticky56[0] = shift_right_sticky56[0] | sticky_bit;
        end
    end
endfunction

function [63:0] overflow_value;
    input sign;
    input [1:0] mode;
    begin
        case (mode)
            2'b01: overflow_value = sign ? NEG_MAX : POS_MAX;
            2'b10: overflow_value = sign ? NEG_MAX : POS_INF;
            2'b11: overflow_value = sign ? NEG_INF : POS_MAX;
            default: overflow_value = sign ? NEG_INF : POS_INF;
        endcase
    end
endfunction

task automatic round_pack;
    input sign;
    input integer exp_in;
    input [55:0] full_in;
    input [1:0] mode;
    output [63:0] result;
    output uf;
    output of;
    output ix;
    integer exp_adj;
    integer shift_amt;
    reg [55:0] shifted;
    reg [52:0] mant_main;
    reg [51:0] frac_main;
    reg [53:0] mant_round;
    reg [52:0] frac_round;
    reg [10:0] exp_field;
    reg round_inc;
    reg any_round;
    begin
        result = {sign, 63'd0};
        uf = 1'b0;
        of = 1'b0;
        ix = 1'b0;
        exp_adj = exp_in;

        if (full_in[55:3] == 53'd0) begin
            result = {sign, 63'd0};
        end else if (exp_adj > 1023) begin
            of = 1'b1;
            ix = 1'b1;
            result = overflow_value(sign, mode);
        end else if (exp_adj >= -1022) begin
            any_round = |full_in[2:0];
            mant_main = full_in[55:3];
            case (mode)
                2'b00: round_inc = full_in[2] & (full_in[1] | full_in[0] | mant_main[0]);
                2'b10: round_inc = (~sign) & any_round;
                2'b11: round_inc = sign & any_round;
                default: round_inc = 1'b0;
            endcase
            mant_round = {1'b0, mant_main} + round_inc;
            if (mant_round[53]) begin
                exp_adj = exp_adj + 1;
                mant_main = mant_round[53:1];
            end else begin
                mant_main = mant_round[52:0];
            end
            if (exp_adj > 1023) begin
                of = 1'b1;
                ix = 1'b1;
                result = overflow_value(sign, mode);
            end else begin
                ix = any_round;
                exp_field = exp_adj + 1023;
                result = {sign, exp_field, mant_main[51:0]};
            end
        end else begin
            shift_amt = -1022 - exp_adj;
            shifted = shift_right_sticky56(full_in, shift_amt);
            uf = 1'b1;
            any_round = |shifted[2:0];
            frac_main = shifted[54:3];
            case (mode)
                2'b00: round_inc = shifted[2] & (shifted[1] | shifted[0] | frac_main[0]);
                2'b10: round_inc = (~sign) & any_round;
                2'b11: round_inc = sign & any_round;
                default: round_inc = 1'b0;
            endcase
            frac_round = {1'b0, frac_main} + round_inc;
            ix = any_round;
            if (frac_round[52]) begin
                result = {sign, 11'd1, 52'd0};
            end else begin
                result = {sign, 11'd0, frac_round[51:0]};
            end
        end
    end
endtask

task automatic compute_fpu;
    input [63:0] a;
    input [63:0] b;
    input [2:0] op;
    input [1:0] mode;
    output [63:0] result;
    output uf;
    output of;
    output ix;
    output ex;
    output inv;
    reg sign_a;
    reg sign_b;
    reg sign_b_eff;
    reg sign_large;
    reg sign_small;
    reg sign_res;
    reg [10:0] exp_a;
    reg [10:0] exp_b;
    reg [51:0] frac_a;
    reg [51:0] frac_b;
    reg a_nan;
    reg b_nan;
    reg a_inf;
    reg b_inf;
    reg a_zero;
    reg b_zero;
    reg [52:0] sig_a;
    reg [52:0] sig_b;
    reg [52:0] sig_large;
    reg [52:0] sig_small;
    reg [55:0] ext_large;
    reg [55:0] ext_small;
    reg [55:0] full_sig;
    reg [56:0] add_sum;
    reg [55:0] sub_diff;
    reg [105:0] prod;
    reg [107:0] dividend;
    reg [107:0] quotient_wide;
    reg [52:0] remainder;
    reg div_zero;
    reg same_sign;
    integer ea;
    integer eb;
    integer e_large;
    integer e_small;
    integer er;
    integer shift_amt;
    integer i;
    reg tmp_uf;
    reg tmp_of;
    reg tmp_ix;
    reg special_zero_sign;
    begin
        result = 64'd0;
        uf = 1'b0;
        of = 1'b0;
        ix = 1'b0;
        ex = 1'b0;
        inv = 1'b0;
        div_zero = 1'b0;

        sign_a = a[63];
        sign_b = b[63];
        exp_a = a[62:52];
        exp_b = b[62:52];
        frac_a = a[51:0];
        frac_b = b[51:0];

        a_nan = (exp_a == 11'h7ff) && (frac_a != 52'd0);
        b_nan = (exp_b == 11'h7ff) && (frac_b != 52'd0);
        a_inf = (exp_a == 11'h7ff) && (frac_a == 52'd0);
        b_inf = (exp_b == 11'h7ff) && (frac_b == 52'd0);
        a_zero = (exp_a == 11'd0) && (frac_a == 52'd0);
        b_zero = (exp_b == 11'd0) && (frac_b == 52'd0);

        sig_a = 53'd0;
        sig_b = 53'd0;
        ea = -1022;
        eb = -1022;

        if (!a_inf && !a_nan && !a_zero) begin
            if (exp_a == 11'd0) begin
                sig_a = {1'b0, frac_a};
                ea = -1022;
                for (i = 0; i < 52; i = i + 1) begin
                    if (!sig_a[52]) begin
                        sig_a = sig_a << 1;
                        ea = ea - 1;
                    end
                end
            end else begin
                sig_a = {1'b1, frac_a};
                ea = exp_a - 1023;
            end
        end

        if (!b_inf && !b_nan && !b_zero) begin
            if (exp_b == 11'd0) begin
                sig_b = {1'b0, frac_b};
                eb = -1022;
                for (i = 0; i < 52; i = i + 1) begin
                    if (!sig_b[52]) begin
                        sig_b = sig_b << 1;
                        eb = eb - 1;
                    end
                end
            end else begin
                sig_b = {1'b1, frac_b};
                eb = exp_b - 1023;
            end
        end

        if (a_nan || b_nan) begin
            result = QNAN;
            inv = 1'b1;
            ex = 1'b1;
        end else begin
            case (op)
                OP_ADD,
                OP_SUB: begin
                    sign_b_eff = sign_b ^ (op == OP_SUB);
                    if (a_inf && b_inf && (sign_a != sign_b_eff)) begin
                        result = QNAN;
                        inv = 1'b1;
                    end else if (a_inf) begin
                        result = sign_a ? NEG_INF : POS_INF;
                    end else if (b_inf) begin
                        result = sign_b_eff ? NEG_INF : POS_INF;
                    end else if (a_zero && b_zero) begin
                        if (sign_a == sign_b_eff) begin
                            special_zero_sign = sign_a;
                        end else begin
                            special_zero_sign = (mode == 2'b11);
                        end
                        result = {special_zero_sign, 63'd0};
                    end else if (a_zero) begin
                        result = {sign_b_eff, exp_b, frac_b};
                    end else if (b_zero) begin
                        result = {sign_a, exp_a, frac_a};
                    end else begin
                        if ((ea > eb) || ((ea == eb) && (sig_a >= sig_b))) begin
                            sig_large = sig_a;
                            sig_small = sig_b;
                            sign_large = sign_a;
                            sign_small = sign_b_eff;
                            e_large = ea;
                            e_small = eb;
                        end else begin
                            sig_large = sig_b;
                            sig_small = sig_a;
                            sign_large = sign_b_eff;
                            sign_small = sign_a;
                            e_large = eb;
                            e_small = ea;
                        end

                        shift_amt = e_large - e_small;
                        ext_large = {sig_large, 3'b000};
                        ext_small = shift_right_sticky56({sig_small, 3'b000}, shift_amt);
                        same_sign = (sign_large == sign_small);
                        er = e_large;

                        if (same_sign) begin
                            add_sum = {1'b0, ext_large} + {1'b0, ext_small};
                            sign_res = sign_large;
                            if (add_sum[56]) begin
                                full_sig = add_sum[56:1];
                                full_sig[0] = add_sum[1] | add_sum[0];
                                er = er + 1;
                            end else begin
                                full_sig = add_sum[55:0];
                            end
                            round_pack(sign_res, er, full_sig, mode, result, tmp_uf, tmp_of, tmp_ix);
                            uf = tmp_uf;
                            of = tmp_of;
                            ix = tmp_ix;
                        end else begin
                            sub_diff = ext_large - ext_small;
                            if (sub_diff == 56'd0) begin
                                result = {(mode == 2'b11), 63'd0};
                            end else begin
                                full_sig = sub_diff;
                                sign_res = sign_large;
                                for (i = 0; i < 55; i = i + 1) begin
                                    if (!full_sig[55] && (full_sig[54:0] != 55'd0) && (er > -1022)) begin
                                        full_sig = full_sig << 1;
                                        er = er - 1;
                                    end
                                end
                                round_pack(sign_res, er, full_sig, mode, result, tmp_uf, tmp_of, tmp_ix);
                                uf = tmp_uf;
                                of = tmp_of;
                                ix = tmp_ix;
                            end
                        end
                    end
                end

                OP_MUL: begin
                    sign_res = sign_a ^ sign_b;
                    if ((a_inf && b_zero) || (a_zero && b_inf)) begin
                        result = QNAN;
                        inv = 1'b1;
                    end else if (a_inf || b_inf) begin
                        result = sign_res ? NEG_INF : POS_INF;
                    end else if (a_zero || b_zero) begin
                        result = {sign_res, 63'd0};
                    end else begin
                        prod = sig_a * sig_b;
                        if (prod[105]) begin
                            er = ea + eb + 1;
                            full_sig = {prod[105:53], prod[52], prod[51], |prod[50:0]};
                        end else begin
                            er = ea + eb;
                            full_sig = {prod[104:52], prod[51], prod[50], |prod[49:0]};
                        end
                        round_pack(sign_res, er, full_sig, mode, result, tmp_uf, tmp_of, tmp_ix);
                        uf = tmp_uf;
                        of = tmp_of;
                        ix = tmp_ix;
                    end
                end

                OP_DIV: begin
                    sign_res = sign_a ^ sign_b;
                    if ((a_inf && b_inf) || (a_zero && b_zero)) begin
                        result = QNAN;
                        inv = 1'b1;
                    end else if (a_inf) begin
                        result = sign_res ? NEG_INF : POS_INF;
                    end else if (b_inf) begin
                        result = {sign_res, 63'd0};
                    end else if (b_zero) begin
                        div_zero = 1'b1;
                        result = sign_res ? NEG_INF : POS_INF;
                    end else if (a_zero) begin
                        result = {sign_res, 63'd0};
                    end else begin
                        dividend = {sig_a, 55'd0};
                        quotient_wide = dividend / sig_b;
                        remainder = dividend % sig_b;
                        if (quotient_wide[55]) begin
                            er = ea - eb;
                            full_sig = {quotient_wide[55:3], quotient_wide[2], quotient_wide[1], quotient_wide[0] | (remainder != 53'd0)};
                        end else begin
                            er = ea - eb - 1;
                            quotient_wide = quotient_wide << 1;
                            full_sig = {quotient_wide[55:3], quotient_wide[2], quotient_wide[1], quotient_wide[0] | (remainder != 53'd0)};
                        end
                        round_pack(sign_res, er, full_sig, mode, result, tmp_uf, tmp_of, tmp_ix);
                        uf = tmp_uf;
                        of = tmp_of;
                        ix = tmp_ix;
                    end
                end

                default: begin
                    result = QNAN;
                    inv = 1'b1;
                end
            endcase

            ex = inv | of | uf | ix | div_zero;
        end
    end
endtask

always @(posedge clk or posedge rst) begin
    if (rst) begin
        enable_d <= 1'b0;
        busy <= 1'b0;
        latency_cnt <= 3'd0;
        opa_reg <= 64'd0;
        opb_reg <= 64'd0;
        fpu_op_reg <= 3'd0;
        rmode_reg <= 2'd0;
        pending_out <= 64'd0;
        pending_underflow <= 1'b0;
        pending_overflow <= 1'b0;
        pending_inexact <= 1'b0;
        pending_exception <= 1'b0;
        pending_invalid <= 1'b0;
        out <= 64'd0;
        ready <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else begin
        ready <= 1'b0;
        enable_d <= enable;

        if (!busy && enable && !enable_d) begin
            opa_reg <= opa;
            opb_reg <= opb;
            fpu_op_reg <= fpu_op;
            rmode_reg <= rmode;
            compute_fpu(opa, opb, fpu_op, rmode, calc_out, calc_underflow, calc_overflow, calc_inexact, calc_exception, calc_invalid);
            pending_out <= calc_out;
            pending_underflow <= calc_underflow;
            pending_overflow <= calc_overflow;
            pending_inexact <= calc_inexact;
            pending_exception <= calc_exception;
            pending_invalid <= calc_invalid;
            busy <= 1'b1;
            latency_cnt <= LATENCY[2:0];
        end else if (busy) begin
            if (latency_cnt == 3'd1) begin
                out <= pending_out;
                ready <= 1'b1;
                underflow <= pending_underflow;
                overflow <= pending_overflow;
                inexact <= pending_inexact;
                exception <= pending_exception;
                invalid <= pending_invalid;
                busy <= 1'b0;
                latency_cnt <= 3'd0;
            end else begin
                latency_cnt <= latency_cnt - 3'd1;
            end
        end
    end
end

endmodule
