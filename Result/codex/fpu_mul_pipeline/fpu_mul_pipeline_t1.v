module fpu_mul(
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output reg ready,
    output reg [63:0] outfp
);

localparam [63:0] QNAN_VALUE = 64'h7ff8000000000000;
localparam [63:0] MAX_FINITE_POS = 64'h7fefffffffffffff;
localparam [63:0] MAX_FINITE_NEG = 64'hffefffffffffffff;

reg product_shift;
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
reg sign;
reg sign_1;
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
reg sign_20;
reg [51:0] mantissa_a1;
reg [51:0] mantissa_a2;
reg [51:0] mantissa_b1;
reg [51:0] mantissa_b2;
reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg count_ready;
reg count_ready_0;
reg [4:0] count;
reg a_is_zero;
reg b_is_zero;
reg a_is_inf;
reg b_is_inf;
reg in_inf_1;
reg in_inf_2;
reg in_zero_1;
reg [11:0] exponent_terms_1;
reg [11:0] exponent_terms_2;
reg [11:0] exponent_terms_3;
reg [11:0] exponent_terms_4;
reg [11:0] exponent_terms_5;
reg [11:0] exponent_terms_6;
reg [11:0] exponent_terms_7;
reg [11:0] exponent_terms_8;
reg [11:0] exponent_terms_9;
reg exponent_gt_expoffset;
reg [11:0] exponent_1;
wire [11:0] exponent;
reg [11:0] exponent_2;
reg [11:0] exponent_2_0;
reg [11:0] exponent_2_1;
reg exponent_gt_prodshift;
reg exponent_is_infinity;
reg [11:0] exponent_3;
reg [11:0] exponent_4;
reg set_mantissa_zero;
reg set_mz_1;
reg [52:0] mul_a;
reg [52:0] mul_a1;
reg [52:0] mul_a2;
reg [52:0] mul_a3;
reg [52:0] mul_a4;
reg [52:0] mul_a5;
reg [52:0] mul_a6;
reg [52:0] mul_a7;
reg [52:0] mul_a8;
reg [52:0] mul_b;
reg [52:0] mul_b1;
reg [52:0] mul_b2;
reg [52:0] mul_b3;
reg [52:0] mul_b4;
reg [52:0] mul_b5;
reg [52:0] mul_b6;
reg [52:0] mul_b7;
reg [52:0] mul_b8;
reg [105:0] product;
reg [105:0] product_1;
reg [52:0] product_2;
reg [52:0] product_3;
reg [53:0] product_4;
reg [53:0] product_5;
reg [53:0] product_6;
reg [53:0] product_7;
reg product_overflow;
reg [11:0] exponent_5;
reg [11:0] exponent_6;
reg [11:0] exponent_7;
reg [11:0] exponent_8;
reg [11:0] exponent_9;
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

reg [63:0] result_pipe [0:19];
reg [19:0] valid_pipe;
integer i;

wire [10:0] opa_exp_w;
wire [10:0] opb_exp_w;
wire [51:0] opa_frac_w;
wire [51:0] opb_frac_w;
wire input_sign_w;
wire a_is_nan_w;
wire b_is_nan_w;
wire a_is_inf_w;
wire b_is_inf_w;
wire a_is_zero_w;
wire b_is_zero_w;
wire [52:0] mul_a_w;
wire [52:0] mul_b_w;
wire [105:0] product_w;
wire product_shift_w;
wire [11:0] exponent_terms_w;
wire [11:0] exponent_sum_w;
wire [52:0] mant_main_w;
wire guard_w;
wire round_bit_w;
wire sticky_w;
wire [63:0] result_next_w;

assign exponent = 12'd0;
assign opa_exp_w = opa[62:52];
assign opb_exp_w = opb[62:52];
assign opa_frac_w = opa[51:0];
assign opb_frac_w = opb[51:0];
assign input_sign_w = opa[63] ^ opb[63];
assign a_is_nan_w = (opa_exp_w == 11'h7ff) && (opa_frac_w != 52'd0);
assign b_is_nan_w = (opb_exp_w == 11'h7ff) && (opb_frac_w != 52'd0);
assign a_is_inf_w = (opa_exp_w == 11'h7ff) && (opa_frac_w == 52'd0);
assign b_is_inf_w = (opb_exp_w == 11'h7ff) && (opb_frac_w == 52'd0);
assign a_is_zero_w = (opa_exp_w == 11'd0) && (opa_frac_w == 52'd0);
assign b_is_zero_w = (opb_exp_w == 11'd0) && (opb_frac_w == 52'd0);
assign mul_a_w = (opa_exp_w == 11'd0) ? {1'b0, opa_frac_w} : {1'b1, opa_frac_w};
assign mul_b_w = (opb_exp_w == 11'd0) ? {1'b0, opb_frac_w} : {1'b1, opb_frac_w};
assign product_w = mul_a_w * mul_b_w;
assign product_shift_w = product_w[105];
assign exponent_terms_w = ((opa_exp_w == 11'd0) ? 12'd1 : {1'b0, opa_exp_w}) +
                          ((opb_exp_w == 11'd0) ? 12'd1 : {1'b0, opb_exp_w}) -
                          12'd1023;
assign exponent_sum_w = exponent_terms_w + (product_shift_w ? 12'd1 : 12'd0);
assign mant_main_w = product_shift_w ? product_w[105:53] : product_w[104:52];
assign guard_w = product_shift_w ? product_w[52] : product_w[51];
assign round_bit_w = product_shift_w ? product_w[51] : product_w[50];
assign sticky_w = product_shift_w ? |product_w[50:0] : |product_w[49:0];
assign result_next_w = fp_mul_core(opa, opb, rmode);

function [63:0] fp_mul_core;
    input [63:0] a;
    input [63:0] b;
    input [1:0] rm;
    reg sign_f;
    reg [10:0] exp_a_raw;
    reg [10:0] exp_b_raw;
    reg [51:0] frac_a;
    reg [51:0] frac_b;
    reg a_zero;
    reg b_zero;
    reg a_inf;
    reg b_inf;
    reg a_nan;
    reg b_nan;
    reg [52:0] mant_a;
    reg [52:0] mant_b;
    reg [105:0] prod;
    reg prod_shift_f;
    reg [52:0] mant_main;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg inexact;
    reg round_inc;
    reg [53:0] mant_ext;
    reg [55:0] sub_ext;
    reg [55:0] sub_shifted;
    reg [55:0] lost_mask;
    reg [55:0] guard_mask;
    reg guard_sub;
    reg sticky_sub;
    integer exp_int;
    integer shift_amt;
    begin
        sign_f = a[63] ^ b[63];
        exp_a_raw = a[62:52];
        exp_b_raw = b[62:52];
        frac_a = a[51:0];
        frac_b = b[51:0];
        a_zero = (exp_a_raw == 11'd0) && (frac_a == 52'd0);
        b_zero = (exp_b_raw == 11'd0) && (frac_b == 52'd0);
        a_inf = (exp_a_raw == 11'h7ff) && (frac_a == 52'd0);
        b_inf = (exp_b_raw == 11'h7ff) && (frac_b == 52'd0);
        a_nan = (exp_a_raw == 11'h7ff) && (frac_a != 52'd0);
        b_nan = (exp_b_raw == 11'h7ff) && (frac_b != 52'd0);
        fp_mul_core = 64'd0;

        if (a_nan || b_nan || ((a_inf || b_inf) && (a_zero || b_zero))) begin
            fp_mul_core = QNAN_VALUE;
        end else if (a_inf || b_inf) begin
            fp_mul_core = {sign_f, 11'h7ff, 52'd0};
        end else if (a_zero || b_zero) begin
            fp_mul_core = {sign_f, 11'd0, 52'd0};
        end else begin
            mant_a = (exp_a_raw == 11'd0) ? {1'b0, frac_a} : {1'b1, frac_a};
            mant_b = (exp_b_raw == 11'd0) ? {1'b0, frac_b} : {1'b1, frac_b};
            prod = mant_a * mant_b;

            if (prod[105]) begin
                prod_shift_f = 1'b1;
                mant_main = prod[105:53];
                guard_bit = prod[52];
                round_bit = prod[51];
                sticky_bit = |prod[50:0];
            end else begin
                prod_shift_f = 1'b0;
                mant_main = prod[104:52];
                guard_bit = prod[51];
                round_bit = prod[50];
                sticky_bit = |prod[49:0];
            end

            exp_int = ((exp_a_raw == 11'd0) ? 1 : exp_a_raw) +
                      ((exp_b_raw == 11'd0) ? 1 : exp_b_raw) -
                      1023 +
                      (prod_shift_f ? 1 : 0);

            inexact = guard_bit | round_bit | sticky_bit;
            round_inc = 1'b0;
            case (rm)
                2'b00: round_inc = guard_bit && (round_bit || sticky_bit || mant_main[0]);
                2'b01: round_inc = 1'b0;
                2'b10: round_inc = (~sign_f) && inexact;
                default: round_inc = sign_f && inexact;
            endcase

            mant_ext = {1'b0, mant_main} + (round_inc ? 54'd1 : 54'd0);
            if (mant_ext[53]) begin
                mant_main = mant_ext[53:1];
                exp_int = exp_int + 1;
            end else begin
                mant_main = mant_ext[52:0];
            end

            if (exp_int >= 2047) begin
                if ((rm == 2'b00) ||
                    ((rm == 2'b10) && !sign_f) ||
                    ((rm == 2'b11) && sign_f)) begin
                    fp_mul_core = {sign_f, 11'h7ff, 52'd0};
                end else begin
                    fp_mul_core = sign_f ? MAX_FINITE_NEG : MAX_FINITE_POS;
                end
            end else if (exp_int <= 0) begin
                shift_amt = 1 - exp_int;
                if (shift_amt > 55) begin
                    if (((rm == 2'b10) && !sign_f) || ((rm == 2'b11) && sign_f)) begin
                        fp_mul_core = {sign_f, 11'd0, 52'd1};
                    end else begin
                        fp_mul_core = {sign_f, 11'd0, 52'd0};
                    end
                end else begin
                    sub_ext = {3'b000, mant_main};
                    sub_shifted = sub_ext >> shift_amt;
                    if (shift_amt == 0) begin
                        guard_sub = 1'b0;
                        sticky_sub = inexact;
                    end else begin
                        guard_mask = 56'd1 << (shift_amt - 1);
                        guard_sub = |(sub_ext & guard_mask);
                        lost_mask = (56'd1 << shift_amt) - 1;
                        sticky_sub = |((sub_ext & lost_mask) & ~guard_mask) | inexact;
                    end

                    round_inc = 1'b0;
                    case (rm)
                        2'b00: round_inc = guard_sub && (sticky_sub || sub_shifted[0]);
                        2'b01: round_inc = 1'b0;
                        2'b10: round_inc = (~sign_f) && (guard_sub || sticky_sub);
                        default: round_inc = sign_f && (guard_sub || sticky_sub);
                    endcase

                    sub_shifted = sub_shifted + (round_inc ? 56'd1 : 56'd0);
                    if (sub_shifted[52]) begin
                        fp_mul_core = {sign_f, 11'd1, 52'd0};
                    end else begin
                        fp_mul_core = {sign_f, 11'd0, sub_shifted[51:0]};
                    end
                end
            end else begin
                fp_mul_core = {sign_f, exp_int[10:0], mant_main[51:0]};
            end
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ready <= 1'b0;
        outfp <= 64'd0;
        product_shift <= 1'b0;
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
        sign <= 1'b0;
        sign_1 <= 1'b0;
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
        sign_20 <= 1'b0;
        mantissa_a1 <= 52'd0;
        mantissa_a2 <= 52'd0;
        mantissa_b1 <= 52'd0;
        mantissa_b2 <= 52'd0;
        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        count_ready <= 1'b0;
        count_ready_0 <= 1'b0;
        count <= 5'd0;
        a_is_zero <= 1'b0;
        b_is_zero <= 1'b0;
        a_is_inf <= 1'b0;
        b_is_inf <= 1'b0;
        in_inf_1 <= 1'b0;
        in_inf_2 <= 1'b0;
        in_zero_1 <= 1'b0;
        exponent_terms_1 <= 12'd0;
        exponent_terms_2 <= 12'd0;
        exponent_terms_3 <= 12'd0;
        exponent_terms_4 <= 12'd0;
        exponent_terms_5 <= 12'd0;
        exponent_terms_6 <= 12'd0;
        exponent_terms_7 <= 12'd0;
        exponent_terms_8 <= 12'd0;
        exponent_terms_9 <= 12'd0;
        exponent_gt_expoffset <= 1'b0;
        exponent_1 <= 12'd0;
        exponent_2 <= 12'd0;
        exponent_2_0 <= 12'd0;
        exponent_2_1 <= 12'd0;
        exponent_gt_prodshift <= 1'b0;
        exponent_is_infinity <= 1'b0;
        exponent_3 <= 12'd0;
        exponent_4 <= 12'd0;
        set_mantissa_zero <= 1'b0;
        set_mz_1 <= 1'b0;
        mul_a <= 53'd0;
        mul_a1 <= 53'd0;
        mul_a2 <= 53'd0;
        mul_a3 <= 53'd0;
        mul_a4 <= 53'd0;
        mul_a5 <= 53'd0;
        mul_a6 <= 53'd0;
        mul_a7 <= 53'd0;
        mul_a8 <= 53'd0;
        mul_b <= 53'd0;
        mul_b1 <= 53'd0;
        mul_b2 <= 53'd0;
        mul_b3 <= 53'd0;
        mul_b4 <= 53'd0;
        mul_b5 <= 53'd0;
        mul_b6 <= 53'd0;
        mul_b7 <= 53'd0;
        mul_b8 <= 53'd0;
        product <= 106'd0;
        product_1 <= 106'd0;
        product_2 <= 53'd0;
        product_3 <= 53'd0;
        product_4 <= 54'd0;
        product_5 <= 54'd0;
        product_6 <= 54'd0;
        product_7 <= 54'd0;
        product_overflow <= 1'b0;
        exponent_5 <= 12'd0;
        exponent_6 <= 12'd0;
        exponent_7 <= 12'd0;
        exponent_8 <= 12'd0;
        exponent_9 <= 12'd0;
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
        valid_pipe <= 20'd0;
        for (i = 0; i < 20; i = i + 1) begin
            result_pipe[i] <= 64'd0;
        end
    end else if (enable) begin
        ready <= valid_pipe[19];
        outfp <= result_pipe[19];

        for (i = 19; i > 0; i = i - 1) begin
            result_pipe[i] <= result_pipe[i-1];
        end
        result_pipe[0] <= result_next_w;
        valid_pipe <= {valid_pipe[18:0], 1'b1};

        sign <= input_sign_w;
        sign_1 <= sign;
        sign_2 <= sign_1;
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
        sign_20 <= sign_19;

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

        mantissa_a1 <= opa_frac_w;
        mantissa_a2 <= mantissa_a1;
        mantissa_b1 <= opb_frac_w;
        mantissa_b2 <= mantissa_b1;
        exponent_a <= opa_exp_w;
        exponent_b <= opb_exp_w;
        a_is_zero <= a_is_zero_w;
        b_is_zero <= b_is_zero_w;
        a_is_inf <= a_is_inf_w;
        b_is_inf <= b_is_inf_w;
        in_inf_1 <= a_is_inf_w | b_is_inf_w;
        in_inf_2 <= in_inf_1;
        in_zero_1 <= a_is_zero_w | b_is_zero_w;
        count_ready_0 <= 1'b1;
        count_ready <= valid_pipe[18];
        if (count != 5'd20) begin
            count <= count + 5'd1;
        end

        exponent_gt_expoffset <= (exponent_terms_w > 12'd1023);
        exponent_2_0 <= exponent_sum_w;
        exponent_2_1 <= exponent_2_0;
        exponent_gt_prodshift <= (exponent_sum_w > {11'd0, product_shift_w});
        exponent_is_infinity <= (result_next_w[62:52] == 11'h7ff) && (result_next_w[51:0] == 52'd0);
        set_mantissa_zero <= (result_next_w[62:0] == 63'd0);
        set_mz_1 <= set_mantissa_zero;

        exponent_terms_1 <= exponent_terms_w;
        exponent_terms_2 <= exponent_terms_1;
        exponent_terms_3 <= exponent_terms_2;
        exponent_terms_4 <= exponent_terms_3;
        exponent_terms_5 <= exponent_terms_4;
        exponent_terms_6 <= exponent_terms_5;
        exponent_terms_7 <= exponent_terms_6;
        exponent_terms_8 <= exponent_terms_7;
        exponent_terms_9 <= exponent_terms_8;

        exponent_1 <= exponent_sum_w;
        exponent_2 <= exponent_1;
        exponent_3 <= exponent_2;
        exponent_4 <= exponent_3;
        exponent_5 <= exponent_4;
        exponent_6 <= exponent_5;
        exponent_7 <= exponent_6;
        exponent_8 <= exponent_7;
        exponent_9 <= exponent_8;

        mul_a <= mul_a_w;
        mul_a1 <= mul_a;
        mul_a2 <= mul_a1;
        mul_a3 <= mul_a2;
        mul_a4 <= mul_a3;
        mul_a5 <= mul_a4;
        mul_a6 <= mul_a5;
        mul_a7 <= mul_a6;
        mul_a8 <= mul_a7;

        mul_b <= mul_b_w;
        mul_b1 <= mul_b;
        mul_b2 <= mul_b1;
        mul_b3 <= mul_b2;
        mul_b4 <= mul_b3;
        mul_b5 <= mul_b4;
        mul_b6 <= mul_b5;
        mul_b7 <= mul_b6;
        mul_b8 <= mul_b7;

        product <= product_w;
        product_1 <= product;
        product_2 <= mant_main_w;
        product_3 <= product_2;
        product_4 <= {1'b0, product_3};
        product_5 <= product_4;
        product_6 <= product_5;
        product_7 <= product_6;
        product_shift <= product_shift_w;
        product_overflow <= product_w[105] & product_w[104];

        round_nearest_mode <= (rmode == 2'b00);
        round_posinf_mode <= (rmode == 2'b10);
        round_neginf_mode <= (rmode == 2'b11);
        round_nearest_trigger <= guard_w && (round_bit_w || sticky_w || mant_main_w[0]);
        round_nearest_exception <= guard_w || round_bit_w || sticky_w;
        round_nearest_enable <= (rmode == 2'b00) && (guard_w || round_bit_w || sticky_w);
        round_posinf_trigger <= (rmode == 2'b10) && !input_sign_w && (guard_w || round_bit_w || sticky_w);
        round_posinf_enable <= round_posinf_trigger;
        round_neginf_trigger <= (rmode == 2'b11) && input_sign_w && (guard_w || round_bit_w || sticky_w);
        round_neginf_enable <= round_neginf_trigger;
        round_enable <= guard_w || round_bit_w || sticky_w;
    end
end

endmodule
