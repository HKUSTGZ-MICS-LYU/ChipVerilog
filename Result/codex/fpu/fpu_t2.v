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

localparam [63:0] QNAN = 64'h7ff8_0000_0000_0000;
localparam [2:0] OP_ADD = 3'b000;
localparam [2:0] OP_SUB = 3'b001;
localparam [2:0] OP_MUL = 3'b010;
localparam [2:0] OP_DIV = 3'b011;
localparam [2:0] LATENCY = 3'd4;

reg [63:0] opa_r;
reg [63:0] opb_r;
reg [2:0] fpu_op_r;
reg [1:0] rmode_r;
reg enable_d;
reg busy;
reg [2:0] latency_cnt;

reg [63:0] calc_out;
reg calc_underflow;
reg calc_overflow;
reg calc_inexact;
reg calc_exception;
reg calc_invalid;

reg sign_a;
reg sign_b;
reg sign_b_eff;
reg sign_res;
reg force_sign;
reg [10:0] exp_a;
reg [10:0] exp_b;
reg [10:0] exp_a_eff;
reg [10:0] exp_b_eff;
reg [51:0] frac_a;
reg [51:0] frac_b;
reg [52:0] mant_a;
reg [52:0] mant_b;
reg is_nan_a;
reg is_nan_b;
reg is_inf_a;
reg is_inf_b;
reg is_zero_a;
reg is_zero_b;
reg [55:0] mant_ext_res;
reg [55:0] ext_a;
reg [55:0] ext_b;
reg [55:0] ext_hi;
reg [55:0] ext_lo;
reg [56:0] sum57;
reg [56:0] diff57;
reg [105:0] prod106;
reg [105:0] div_num;
reg [53:0] div_quo;
reg [52:0] div_rem;
reg [5:0] msb_idx;
reg [52:0] mant_main;
reg [53:0] mant_round_ext;
reg [55:0] mant_shifted;
reg guard_bit;
reg round_bit;
reg sticky_bit;
reg round_inc;
reg op_force_nan;
reg op_force_inf;
reg op_force_zero;
reg base_invalid;
reg base_exception;
reg extra_inexact;
reg a_ge_b_mag;
reg [10:0] shift_u11;
integer exp_res_i;
integer exp_round_i;
integer shift_i;
integer sub_shift_i;

wire start_pulse;
assign start_pulse = enable & ~enable_d;

function [55:0] shr_sticky56;
    input [55:0] val;
    input [10:0] sh;
    integer i;
    reg [55:0] tmp;
    reg sticky;
begin
    if (sh == 0) begin
        tmp = val;
    end else if (sh >= 56) begin
        tmp = {55'd0, |val};
    end else begin
        tmp = val >> sh;
        sticky = 1'b0;
        for (i = 0; i < 56; i = i + 1) begin
            if (i < sh) begin
                sticky = sticky | val[i];
            end
        end
        tmp[0] = tmp[0] | sticky;
    end
    shr_sticky56 = tmp;
end
endfunction

function [5:0] msb_index56;
    input [55:0] val;
    integer i;
    reg [5:0] idx;
begin
    idx = 6'd0;
    for (i = 0; i < 56; i = i + 1) begin
        if (val[i]) begin
            idx = i[5:0];
        end
    end
    msb_index56 = idx;
end
endfunction

always @* begin
    calc_out = 64'd0;
    calc_underflow = 1'b0;
    calc_overflow = 1'b0;
    calc_inexact = 1'b0;
    calc_exception = 1'b0;
    calc_invalid = 1'b0;

    sign_a = opa_r[63];
    sign_b = opb_r[63];
    exp_a = opa_r[62:52];
    exp_b = opb_r[62:52];
    frac_a = opa_r[51:0];
    frac_b = opb_r[51:0];
    exp_a_eff = (exp_a == 11'd0) ? 11'd1 : exp_a;
    exp_b_eff = (exp_b == 11'd0) ? 11'd1 : exp_b;
    mant_a = (exp_a == 11'd0) ? {1'b0, frac_a} : {1'b1, frac_a};
    mant_b = (exp_b == 11'd0) ? {1'b0, frac_b} : {1'b1, frac_b};
    is_nan_a = (exp_a == 11'h7ff) && (frac_a != 0);
    is_nan_b = (exp_b == 11'h7ff) && (frac_b != 0);
    is_inf_a = (exp_a == 11'h7ff) && (frac_a == 0);
    is_inf_b = (exp_b == 11'h7ff) && (frac_b == 0);
    is_zero_a = (exp_a == 11'd0) && (frac_a == 0);
    is_zero_b = (exp_b == 11'd0) && (frac_b == 0);

    sign_b_eff = sign_b;
    sign_res = 1'b0;
    force_sign = 1'b0;
    mant_ext_res = 56'd0;
    ext_a = 56'd0;
    ext_b = 56'd0;
    ext_hi = 56'd0;
    ext_lo = 56'd0;
    sum57 = 57'd0;
    diff57 = 57'd0;
    prod106 = 106'd0;
    div_num = 106'd0;
    div_quo = 54'd0;
    div_rem = 53'd0;
    msb_idx = 6'd0;
    mant_main = 53'd0;
    mant_round_ext = 54'd0;
    mant_shifted = 56'd0;
    guard_bit = 1'b0;
    round_bit = 1'b0;
    sticky_bit = 1'b0;
    round_inc = 1'b0;
    op_force_nan = 1'b0;
    op_force_inf = 1'b0;
    op_force_zero = 1'b0;
    base_invalid = 1'b0;
    base_exception = 1'b0;
    extra_inexact = 1'b0;
    a_ge_b_mag = 1'b0;
    shift_u11 = 11'd0;
    exp_res_i = 0;
    exp_round_i = 0;
    shift_i = 0;
    sub_shift_i = 0;

    case (fpu_op_r)
        OP_ADD, OP_SUB: begin
            sign_b_eff = sign_b ^ (fpu_op_r == OP_SUB);
            if (is_nan_a || is_nan_b) begin
                op_force_nan = 1'b1;
                base_exception = 1'b1;
            end else if (is_inf_a && is_inf_b && (sign_a != sign_b_eff)) begin
                op_force_nan = 1'b1;
                base_invalid = 1'b1;
                base_exception = 1'b1;
            end else if (is_inf_a) begin
                op_force_inf = 1'b1;
                force_sign = sign_a;
            end else if (is_inf_b) begin
                op_force_inf = 1'b1;
                force_sign = sign_b_eff;
            end else if (is_zero_a && is_zero_b) begin
                op_force_zero = 1'b1;
                force_sign = (rmode_r == 2'b11);
            end else begin
                a_ge_b_mag = (exp_a_eff > exp_b_eff) || ((exp_a_eff == exp_b_eff) && (mant_a >= mant_b));
                if (sign_a == sign_b_eff) begin
                    if (exp_a_eff >= exp_b_eff) begin
                        exp_res_i = exp_a_eff;
                        ext_a = {mant_a, 3'b000};
                        shift_u11 = exp_a_eff - exp_b_eff;
                        ext_b = shr_sticky56({mant_b, 3'b000}, shift_u11);
                    end else begin
                        exp_res_i = exp_b_eff;
                        ext_a = {mant_b, 3'b000};
                        shift_u11 = exp_b_eff - exp_a_eff;
                        ext_b = shr_sticky56({mant_a, 3'b000}, shift_u11);
                    end
                    sum57 = {1'b0, ext_a} + {1'b0, ext_b};
                    sign_res = sign_a;
                    if (sum57[56]) begin
                        mant_ext_res = sum57[56:1];
                        mant_ext_res[0] = mant_ext_res[0] | sum57[0];
                        exp_res_i = exp_res_i + 1;
                    end else begin
                        mant_ext_res = sum57[55:0];
                    end
                end else begin
                    if (a_ge_b_mag) begin
                        sign_res = sign_a;
                        exp_res_i = exp_a_eff;
                        ext_hi = {mant_a, 3'b000};
                        shift_u11 = exp_a_eff - exp_b_eff;
                        ext_lo = shr_sticky56({mant_b, 3'b000}, shift_u11);
                    end else begin
                        sign_res = sign_b_eff;
                        exp_res_i = exp_b_eff;
                        ext_hi = {mant_b, 3'b000};
                        shift_u11 = exp_b_eff - exp_a_eff;
                        ext_lo = shr_sticky56({mant_a, 3'b000}, shift_u11);
                    end
                    diff57 = {1'b0, ext_hi} - {1'b0, ext_lo};
                    if (diff57[55:0] == 56'd0) begin
                        op_force_zero = 1'b1;
                        force_sign = (rmode_r == 2'b11);
                    end else begin
                        mant_ext_res = diff57[55:0];
                        msb_idx = msb_index56(mant_ext_res);
                        shift_i = 55 - msb_idx;
                        if (shift_i > 0) begin
                            mant_ext_res = mant_ext_res << shift_i;
                            exp_res_i = exp_res_i - shift_i;
                        end
                    end
                end
            end
        end

        OP_MUL: begin
            if (is_nan_a || is_nan_b) begin
                op_force_nan = 1'b1;
                base_exception = 1'b1;
            end else if ((is_inf_a && is_zero_b) || (is_inf_b && is_zero_a)) begin
                op_force_nan = 1'b1;
                base_invalid = 1'b1;
                base_exception = 1'b1;
            end else if (is_inf_a || is_inf_b) begin
                op_force_inf = 1'b1;
                force_sign = sign_a ^ sign_b;
            end else if (is_zero_a || is_zero_b) begin
                op_force_zero = 1'b1;
                force_sign = sign_a ^ sign_b;
            end else begin
                prod106 = mant_a * mant_b;
                sign_res = sign_a ^ sign_b;
                exp_res_i = exp_a_eff + exp_b_eff - 1023;
                if (prod106[105]) begin
                    mant_ext_res[55:3] = prod106[105:53];
                    mant_ext_res[2] = prod106[52];
                    mant_ext_res[1] = prod106[51];
                    mant_ext_res[0] = |prod106[50:0];
                    exp_res_i = exp_res_i + 1;
                end else begin
                    mant_ext_res[55:3] = prod106[104:52];
                    mant_ext_res[2] = prod106[51];
                    mant_ext_res[1] = prod106[50];
                    mant_ext_res[0] = |prod106[49:0];
                end
            end
        end

        OP_DIV: begin
            if (is_nan_a || is_nan_b) begin
                op_force_nan = 1'b1;
                base_exception = 1'b1;
            end else if ((is_zero_a && is_zero_b) || (is_inf_a && is_inf_b)) begin
                op_force_nan = 1'b1;
                base_invalid = 1'b1;
                base_exception = 1'b1;
            end else if (is_inf_a) begin
                op_force_inf = 1'b1;
                force_sign = sign_a ^ sign_b;
            end else if (is_inf_b) begin
                op_force_zero = 1'b1;
                force_sign = sign_a ^ sign_b;
            end else if (is_zero_b) begin
                op_force_inf = 1'b1;
                force_sign = sign_a ^ sign_b;
                base_exception = 1'b1;
            end else if (is_zero_a) begin
                op_force_zero = 1'b1;
                force_sign = sign_a ^ sign_b;
            end else begin
                div_num = {mant_a, 53'd0};
                div_quo = div_num / mant_b;
                div_rem = div_num % mant_b;
                sign_res = sign_a ^ sign_b;
                exp_res_i = exp_a_eff - exp_b_eff + 1023;
                guard_bit = 1'b0;
                round_bit = 1'b0;
                sticky_bit = 1'b0;
                if (div_quo[53]) begin
                    mant_main = div_quo[53:1];
                    guard_bit = div_quo[0];
                    sticky_bit = (div_rem != 0);
                    exp_res_i = exp_res_i + 1;
                end else begin
                    mant_main = div_quo[52:0];
                    sticky_bit = (div_rem != 0);
                    if ((mant_main[52] == 1'b0) && (mant_main != 0)) begin
                        mant_main = mant_main << 1;
                        exp_res_i = exp_res_i - 1;
                    end
                end
                mant_ext_res = {mant_main, guard_bit, round_bit, sticky_bit};
                extra_inexact = (div_rem != 0);
            end
        end

        default: begin
            op_force_zero = 1'b1;
            force_sign = 1'b0;
        end
    endcase

    if (op_force_nan) begin
        calc_out = QNAN;
        calc_invalid = base_invalid;
        calc_exception = 1'b1;
    end else if (op_force_inf) begin
        calc_out = {force_sign, 11'h7ff, 52'd0};
        calc_invalid = base_invalid;
        calc_exception = base_exception | base_invalid;
    end else if (op_force_zero) begin
        calc_out = {force_sign, 11'd0, 52'd0};
        calc_invalid = base_invalid;
        calc_exception = base_exception | base_invalid;
    end else begin
        exp_round_i = exp_res_i;
        mant_main = mant_ext_res[55:3];
        guard_bit = mant_ext_res[2];
        round_bit = mant_ext_res[1];
        sticky_bit = mant_ext_res[0];
        round_inc = 1'b0;

        case (rmode_r)
            2'b00: round_inc = guard_bit & (round_bit | sticky_bit | mant_main[0]);
            2'b01: round_inc = 1'b0;
            2'b10: round_inc = ~sign_res & (guard_bit | round_bit | sticky_bit);
            default: round_inc = sign_res & (guard_bit | round_bit | sticky_bit);
        endcase

        mant_round_ext = {1'b0, mant_main};
        if (round_inc) begin
            mant_round_ext = mant_round_ext + 1'b1;
        end

        if (mant_round_ext[53]) begin
            mant_main = mant_round_ext[53:1];
            exp_round_i = exp_round_i + 1;
        end else begin
            mant_main = mant_round_ext[52:0];
        end

        calc_inexact = guard_bit | round_bit | sticky_bit | extra_inexact;

        if (mant_main == 0) begin
            calc_out = {sign_res, 11'd0, 52'd0};
            calc_exception = base_exception | base_invalid;
            calc_invalid = base_invalid;
        end else if (exp_round_i >= 2047) begin
            calc_out = {sign_res, 11'h7ff, 52'd0};
            calc_overflow = 1'b1;
            calc_inexact = 1'b1;
            calc_exception = 1'b1;
            calc_invalid = base_invalid;
        end else if (exp_round_i <= 0) begin
            calc_underflow = 1'b1;
            sub_shift_i = 1 - exp_round_i;
            if (sub_shift_i >= 56) begin
                calc_out = {sign_res, 11'd0, 52'd0};
                calc_inexact = calc_inexact | (mant_main != 0);
            end else begin
                shift_u11 = sub_shift_i[10:0];
                mant_shifted = shr_sticky56({mant_main, 3'b000}, shift_u11);

                mant_main = mant_shifted[55:3];
                guard_bit = mant_shifted[2];
                round_bit = mant_shifted[1];
                sticky_bit = mant_shifted[0];

                case (rmode_r)
                    2'b00: round_inc = guard_bit & (round_bit | sticky_bit | mant_main[0]);
                    2'b01: round_inc = 1'b0;
                    2'b10: round_inc = ~sign_res & (guard_bit | round_bit | sticky_bit);
                    default: round_inc = sign_res & (guard_bit | round_bit | sticky_bit);
                endcase

                mant_round_ext = {1'b0, mant_main};
                if (round_inc) begin
                    mant_round_ext = mant_round_ext + 1'b1;
                end

                if (mant_round_ext[53]) begin
                    calc_out = {sign_res, 11'd1, mant_round_ext[51:0]};
                    calc_underflow = 1'b0;
                end else begin
                    calc_out = {sign_res, 11'd0, mant_round_ext[51:0]};
                end
                calc_inexact = calc_inexact | guard_bit | round_bit | sticky_bit;
            end
            calc_exception = 1'b1;
            calc_invalid = base_invalid;
        end else begin
            calc_out = {sign_res, exp_round_i[10:0], mant_main[51:0]};
            calc_exception = base_exception | base_invalid | calc_inexact;
            calc_invalid = base_invalid;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        opa_r <= 64'd0;
        opb_r <= 64'd0;
        fpu_op_r <= 3'd0;
        rmode_r <= 2'd0;
        enable_d <= 1'b0;
        busy <= 1'b0;
        latency_cnt <= 3'd0;
        out <= 64'd0;
        ready <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else begin
        enable_d <= enable;
        ready <= 1'b0;

        if (start_pulse && !busy) begin
            opa_r <= opa;
            opb_r <= opb;
            fpu_op_r <= fpu_op;
            rmode_r <= rmode;
            busy <= 1'b1;
            latency_cnt <= LATENCY;
            underflow <= 1'b0;
            overflow <= 1'b0;
            inexact <= 1'b0;
            exception <= 1'b0;
            invalid <= 1'b0;
        end else if (busy) begin
            if (latency_cnt > 3'd1) begin
                latency_cnt <= latency_cnt - 3'd1;
            end else begin
                busy <= 1'b0;
                latency_cnt <= 3'd0;
                out <= calc_out;
                ready <= 1'b1;
                underflow <= calc_underflow;
                overflow <= calc_overflow;
                inexact <= calc_inexact;
                exception <= calc_exception;
                invalid <= calc_invalid;
            end
        end
    end
end

endmodule
