module fpu_mul(
    clk,
    rst,
    enable,
    rmode,
    opa,
    opb,
    ready,
    outfp
);

input clk;
input rst;
input enable;
input [1:0] rmode;
input [63:0] opa;
input [63:0] opb;
output ready;
output [63:0] outfp;

reg ready;
reg [63:0] outfp_reg;
assign outfp = outfp_reg;

reg product_shift;
reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;
reg sign;
reg sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10;
reg sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;
reg [51:0] mantissa_a1, mantissa_a2;
reg [51:0] mantissa_b1, mantissa_b2;
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
reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3, exponent_terms_4, exponent_terms_5;
reg [11:0] exponent_terms_6, exponent_terms_7, exponent_terms_8, exponent_terms_9;
reg exponent_gt_expoffset;
reg [11:0] exponent_1;
wire [11:0] exponent;
assign exponent = 12'd0;
reg [11:0] exponent_2;
reg [11:0] exponent_2_0;
reg [11:0] exponent_2_1;
reg exponent_gt_prodshift;
reg exponent_is_infinity;
reg [11:0] exponent_3, exponent_4;
reg set_mantissa_zero;
reg set_mz_1;
reg [52:0] mul_a, mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
reg [52:0] mul_b, mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;
reg [40:0] product_a;
reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5, product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
reg [40:0] product_b;
reg [40:0] product_c;
reg [25:0] product_d;
reg [33:0] product_e;
reg [33:0] product_f;
reg [35:0] product_g;
reg [28:0] product_h;
reg [28:0] product_i;
reg [30:0] product_j;
reg [41:0] sum_0;
reg [6:0] sum_0_2, sum_0_3, sum_0_4, sum_0_5, sum_0_6, sum_0_7, sum_0_8, sum_0_9;
reg [35:0] sum_1;
reg [9:0] sum_1_2, sum_1_3, sum_1_4, sum_1_5, sum_1_6, sum_1_7, sum_1_8;
reg [41:0] sum_2;
reg [6:0] sum_2_2, sum_2_3, sum_2_4, sum_2_5, sum_2_6, sum_2_7;
reg [35:0] sum_3;
reg [36:0] sum_4;
reg [9:0] sum_4_2, sum_4_3, sum_4_4, sum_4_5;
reg [27:0] sum_5;
reg [6:0] sum_5_2, sum_5_3, sum_5_4;
reg [29:0] sum_6;
reg [36:0] sum_7;
reg [16:0] sum_7_2;
reg [30:0] sum_8;
reg [105:0] product;
reg [105:0] product_1;
reg [52:0] product_2;
reg [52:0] product_3;
reg [53:0] product_4, product_5, product_6, product_7;
reg product_overflow;
reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;
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

wire sign_in;
wire [10:0] exponent_a_in;
wire [10:0] exponent_b_in;
wire [51:0] mantissa_a_in;
wire [51:0] mantissa_b_in;
wire a_is_zero_in;
wire b_is_zero_in;
wire a_is_inf_in;
wire b_is_inf_in;
wire in_inf_in;
wire in_zero_in;
wire [52:0] mul_a_in;
wire [52:0] mul_b_in;
wire [105:0] product_in;
wire product_shift_in;
wire [11:0] exponent_terms_in;
wire [11:0] exponent_stage1_in;
wire [52:0] normalized_product_in;
wire guard_in;
wire sticky_in;
wire round_any_in;

assign sign_in = opa[63] ^ opb[63];
assign exponent_a_in = opa[62:52];
assign exponent_b_in = opb[62:52];
assign mantissa_a_in = opa[51:0];
assign mantissa_b_in = opb[51:0];
assign a_is_zero_in = (opa[62:0] == 63'd0);
assign b_is_zero_in = (opb[62:0] == 63'd0);
assign a_is_inf_in = (opa[62:52] == 11'h7ff) && (opa[51:0] == 52'd0);
assign b_is_inf_in = (opb[62:52] == 11'h7ff) && (opb[51:0] == 52'd0);
assign in_inf_in = a_is_inf_in | b_is_inf_in;
assign in_zero_in = a_is_zero_in | b_is_zero_in;
assign mul_a_in = (opa[62:52] == 11'd0) ? {1'b0, opa[51:0]} : {1'b1, opa[51:0]};
assign mul_b_in = (opb[62:52] == 11'd0) ? {1'b0, opb[51:0]} : {1'b1, opb[51:0]};
assign product_in = mul_a_in * mul_b_in;
assign product_shift_in = product_in[105];
assign exponent_terms_in = ((opa[62:52] == 11'd0) ? 12'd1 : {1'b0, opa[62:52]}) +
                           ((opb[62:52] == 11'd0) ? 12'd1 : {1'b0, opb[62:52]});
assign exponent_stage1_in = exponent_terms_in - 12'd1023 + {11'd0, product_shift_in};
assign normalized_product_in = product_shift_in ? product_in[105:53] : product_in[104:52];
assign guard_in = product_shift_in ? product_in[52] : product_in[51];
assign sticky_in = product_shift_in ? |product_in[51:0] : |product_in[50:0];
assign round_any_in = guard_in | sticky_in;

function [63:0] fp_mul_core;
    input [63:0] opa_i;
    input [63:0] opb_i;
    input [1:0] rmode_i;
    reg sign_r;
    reg [10:0] expa;
    reg [10:0] expb;
    reg [51:0] fraca;
    reg [51:0] fracb;
    reg a_zero;
    reg b_zero;
    reg a_inf;
    reg b_inf;
    reg a_nan;
    reg b_nan;
    reg [52:0] siga;
    reg [52:0] sigb;
    reg [105:0] prod;
    reg norm_shift;
    reg [52:0] mant53;
    reg guard_bit;
    reg sticky_bit;
    reg round_up;
    reg [53:0] mant54;
    integer exp_int;
    integer expa_eff;
    integer expb_eff;
    integer shift_amt;
    reg [55:0] sub_pack;
    reg [55:0] sub_shifted;
    reg [55:0] lost_mask;
    reg lost_nonzero;
    reg [51:0] sub_frac;
    reg sub_guard;
    reg sub_sticky;
    reg sub_round_up;
    reg [52:0] sub_frac_round;
    begin
        sign_r = opa_i[63] ^ opb_i[63];
        expa = opa_i[62:52];
        expb = opb_i[62:52];
        fraca = opa_i[51:0];
        fracb = opb_i[51:0];
        a_zero = (opa_i[62:0] == 63'd0);
        b_zero = (opb_i[62:0] == 63'd0);
        a_inf = (expa == 11'h7ff) && (fraca == 52'd0);
        b_inf = (expb == 11'h7ff) && (fracb == 52'd0);
        a_nan = (expa == 11'h7ff) && (fraca != 52'd0);
        b_nan = (expb == 11'h7ff) && (fracb != 52'd0);

        if (a_nan || b_nan || ((a_inf || b_inf) && (a_zero || b_zero))) begin
            fp_mul_core = 64'h7ff8000000000000;
        end else if (a_inf || b_inf) begin
            fp_mul_core = {sign_r, 11'h7ff, 52'd0};
        end else if (a_zero || b_zero) begin
            fp_mul_core = {sign_r, 11'd0, 52'd0};
        end else begin
            siga = (expa == 11'd0) ? {1'b0, fraca} : {1'b1, fraca};
            sigb = (expb == 11'd0) ? {1'b0, fracb} : {1'b1, fracb};
            expa_eff = (expa == 11'd0) ? 1 : expa;
            expb_eff = (expb == 11'd0) ? 1 : expb;
            prod = siga * sigb;

            if (prod == 106'd0) begin
                fp_mul_core = {sign_r, 11'd0, 52'd0};
            end else begin
                norm_shift = prod[105];
                exp_int = expa_eff + expb_eff - 1023 + (norm_shift ? 1 : 0);
                mant53 = norm_shift ? prod[105:53] : prod[104:52];
                guard_bit = norm_shift ? prod[52] : prod[51];
                sticky_bit = norm_shift ? |prod[51:0] : |prod[50:0];

                case (rmode_i)
                    2'b00: round_up = guard_bit & (sticky_bit | mant53[0]);
                    2'b01: round_up = 1'b0;
                    2'b10: round_up = (~sign_r) & (guard_bit | sticky_bit);
                    default: round_up = sign_r & (guard_bit | sticky_bit);
                endcase

                if (round_up) begin
                    mant54 = {1'b0, mant53} + 54'd1;
                    if (mant54[53]) begin
                        mant53 = mant54[53:1];
                        exp_int = exp_int + 1;
                    end else begin
                        mant53 = mant54[52:0];
                    end
                end

                if (exp_int >= 2047) begin
                    if ((rmode_i == 2'b01) || ((rmode_i == 2'b10) && sign_r) || ((rmode_i == 2'b11) && !sign_r)) begin
                        fp_mul_core = {sign_r, 11'h7fe, 52'hfffffffffffff};
                    end else begin
                        fp_mul_core = {sign_r, 11'h7ff, 52'd0};
                    end
                end else if (exp_int <= 0) begin
                    shift_amt = 1 - exp_int;
                    sub_pack = {1'b0, mant53, guard_bit, sticky_bit};

                    if (shift_amt >= 56) begin
                        sub_shifted = 56'd0;
                        lost_nonzero = |sub_pack;
                    end else begin
                        sub_shifted = sub_pack >> shift_amt;
                        if (shift_amt == 0) begin
                            lost_mask = 56'd0;
                        end else begin
                            lost_mask = (56'd1 << shift_amt) - 56'd1;
                        end
                        lost_nonzero = |(sub_pack & lost_mask);
                    end

                    sub_frac = sub_shifted[53:2];
                    sub_guard = sub_shifted[1];
                    sub_sticky = sub_shifted[0] | lost_nonzero;

                    case (rmode_i)
                        2'b00: sub_round_up = sub_guard & (sub_sticky | sub_frac[0]);
                        2'b01: sub_round_up = 1'b0;
                        2'b10: sub_round_up = (~sign_r) & (sub_guard | sub_sticky);
                        default: sub_round_up = sign_r & (sub_guard | sub_sticky);
                    endcase

                    if (sub_round_up) begin
                        sub_frac_round = {1'b0, sub_frac} + 53'd1;
                        if (sub_frac_round[52]) begin
                            fp_mul_core = {sign_r, 11'd1, 52'd0};
                        end else begin
                            fp_mul_core = {sign_r, 11'd0, sub_frac_round[51:0]};
                        end
                    end else if (sub_frac == 52'd0) begin
                        fp_mul_core = {sign_r, 11'd0, 52'd0};
                    end else begin
                        fp_mul_core = {sign_r, 11'd0, sub_frac};
                    end
                end else begin
                    fp_mul_core = {sign_r, exp_int[10:0], mant53[51:0]};
                end
            end
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ready <= 1'b0;
        outfp_reg <= 64'd0;
        valid_pipe <= 20'd0;
        for (i = 0; i < 20; i = i + 1) begin
            result_pipe[i] <= 64'd0;
        end

        product_shift <= 1'b0;
        rm_1 <= 2'd0; rm_2 <= 2'd0; rm_3 <= 2'd0; rm_4 <= 2'd0; rm_5 <= 2'd0;
        rm_6 <= 2'd0; rm_7 <= 2'd0; rm_8 <= 2'd0; rm_9 <= 2'd0; rm_10 <= 2'd0;
        rm_11 <= 2'd0; rm_12 <= 2'd0; rm_13 <= 2'd0; rm_14 <= 2'd0; rm_15 <= 2'd0;
        sign <= 1'b0; sign_1 <= 1'b0; sign_2 <= 1'b0; sign_3 <= 1'b0; sign_4 <= 1'b0;
        sign_5 <= 1'b0; sign_6 <= 1'b0; sign_7 <= 1'b0; sign_8 <= 1'b0; sign_9 <= 1'b0;
        sign_10 <= 1'b0; sign_11 <= 1'b0; sign_12 <= 1'b0; sign_13 <= 1'b0; sign_14 <= 1'b0;
        sign_15 <= 1'b0; sign_16 <= 1'b0; sign_17 <= 1'b0; sign_18 <= 1'b0; sign_19 <= 1'b0; sign_20 <= 1'b0;
        mantissa_a1 <= 52'd0; mantissa_a2 <= 52'd0; mantissa_b1 <= 52'd0; mantissa_b2 <= 52'd0;
        exponent_a <= 11'd0; exponent_b <= 11'd0;
        count_ready <= 1'b0; count_ready_0 <= 1'b0; count <= 5'd0;
        a_is_zero <= 1'b0; b_is_zero <= 1'b0; a_is_inf <= 1'b0; b_is_inf <= 1'b0;
        in_inf_1 <= 1'b0; in_inf_2 <= 1'b0; in_zero_1 <= 1'b0;
        exponent_terms_1 <= 12'd0; exponent_terms_2 <= 12'd0; exponent_terms_3 <= 12'd0; exponent_terms_4 <= 12'd0;
        exponent_terms_5 <= 12'd0; exponent_terms_6 <= 12'd0; exponent_terms_7 <= 12'd0; exponent_terms_8 <= 12'd0; exponent_terms_9 <= 12'd0;
        exponent_gt_expoffset <= 1'b0; exponent_1 <= 12'd0; exponent_2 <= 12'd0; exponent_2_0 <= 12'd0; exponent_2_1 <= 12'd0;
        exponent_gt_prodshift <= 1'b0; exponent_is_infinity <= 1'b0; exponent_3 <= 12'd0; exponent_4 <= 12'd0;
        set_mantissa_zero <= 1'b0; set_mz_1 <= 1'b0;
        mul_a <= 53'd0; mul_a1 <= 53'd0; mul_a2 <= 53'd0; mul_a3 <= 53'd0; mul_a4 <= 53'd0;
        mul_a5 <= 53'd0; mul_a6 <= 53'd0; mul_a7 <= 53'd0; mul_a8 <= 53'd0;
        mul_b <= 53'd0; mul_b1 <= 53'd0; mul_b2 <= 53'd0; mul_b3 <= 53'd0; mul_b4 <= 53'd0;
        mul_b5 <= 53'd0; mul_b6 <= 53'd0; mul_b7 <= 53'd0; mul_b8 <= 53'd0;
        product_a <= 41'd0; product_a_2 <= 17'd0; product_a_3 <= 17'd0; product_a_4 <= 17'd0; product_a_5 <= 17'd0;
        product_a_6 <= 17'd0; product_a_7 <= 17'd0; product_a_8 <= 17'd0; product_a_9 <= 17'd0; product_a_10 <= 17'd0;
        product_b <= 41'd0; product_c <= 41'd0; product_d <= 26'd0; product_e <= 34'd0; product_f <= 34'd0;
        product_g <= 36'd0; product_h <= 29'd0; product_i <= 29'd0; product_j <= 31'd0;
        sum_0 <= 42'd0; sum_0_2 <= 7'd0; sum_0_3 <= 7'd0; sum_0_4 <= 7'd0; sum_0_5 <= 7'd0;
        sum_0_6 <= 7'd0; sum_0_7 <= 7'd0; sum_0_8 <= 7'd0; sum_0_9 <= 7'd0;
        sum_1 <= 36'd0; sum_1_2 <= 10'd0; sum_1_3 <= 10'd0; sum_1_4 <= 10'd0; sum_1_5 <= 10'd0;
        sum_1_6 <= 10'd0; sum_1_7 <= 10'd0; sum_1_8 <= 10'd0;
        sum_2 <= 42'd0; sum_2_2 <= 7'd0; sum_2_3 <= 7'd0; sum_2_4 <= 7'd0; sum_2_5 <= 7'd0; sum_2_6 <= 7'd0; sum_2_7 <= 7'd0;
        sum_3 <= 36'd0; sum_4 <= 37'd0; sum_4_2 <= 10'd0; sum_4_3 <= 10'd0; sum_4_4 <= 10'd0; sum_4_5 <= 10'd0;
        sum_5 <= 28'd0; sum_5_2 <= 7'd0; sum_5_3 <= 7'd0; sum_5_4 <= 7'd0;
        sum_6 <= 30'd0; sum_7 <= 37'd0; sum_7_2 <= 17'd0; sum_8 <= 31'd0;
        product <= 106'd0; product_1 <= 106'd0; product_2 <= 53'd0; product_3 <= 53'd0;
        product_4 <= 54'd0; product_5 <= 54'd0; product_6 <= 54'd0; product_7 <= 54'd0;
        product_overflow <= 1'b0;
        exponent_5 <= 12'd0; exponent_6 <= 12'd0; exponent_7 <= 12'd0; exponent_8 <= 12'd0; exponent_9 <= 12'd0;
        round_nearest_mode <= 1'b0; round_posinf_mode <= 1'b0; round_neginf_mode <= 1'b0;
        round_nearest_trigger <= 1'b0; round_nearest_exception <= 1'b0; round_nearest_enable <= 1'b0;
        round_posinf_trigger <= 1'b0; round_posinf_enable <= 1'b0; round_neginf_trigger <= 1'b0; round_neginf_enable <= 1'b0;
        round_enable <= 1'b0;
    end else if (enable) begin
        ready <= valid_pipe[19];
        outfp_reg <= result_pipe[19];
        valid_pipe <= {valid_pipe[18:0], 1'b1};
        for (i = 19; i > 0; i = i - 1) begin
            result_pipe[i] <= result_pipe[i-1];
        end
        result_pipe[0] <= fp_mul_core(opa, opb, rmode);

        product_shift <= product_shift_in;
        rm_1 <= rmode; rm_2 <= rm_1; rm_3 <= rm_2; rm_4 <= rm_3; rm_5 <= rm_4;
        rm_6 <= rm_5; rm_7 <= rm_6; rm_8 <= rm_7; rm_9 <= rm_8; rm_10 <= rm_9;
        rm_11 <= rm_10; rm_12 <= rm_11; rm_13 <= rm_12; rm_14 <= rm_13; rm_15 <= rm_14;

        sign <= sign_in; sign_1 <= sign_in; sign_2 <= sign_1; sign_3 <= sign_2; sign_4 <= sign_3;
        sign_5 <= sign_4; sign_6 <= sign_5; sign_7 <= sign_6; sign_8 <= sign_7; sign_9 <= sign_8;
        sign_10 <= sign_9; sign_11 <= sign_10; sign_12 <= sign_11; sign_13 <= sign_12; sign_14 <= sign_13;
        sign_15 <= sign_14; sign_16 <= sign_15; sign_17 <= sign_16; sign_18 <= sign_17; sign_19 <= sign_18; sign_20 <= sign_19;

        mantissa_a1 <= mantissa_a_in; mantissa_a2 <= mantissa_a1;
        mantissa_b1 <= mantissa_b_in; mantissa_b2 <= mantissa_b1;
        exponent_a <= exponent_a_in; exponent_b <= exponent_b_in;

        if (count != 5'd20) begin
            count <= count + 5'd1;
        end else begin
            count <= count;
        end
        count_ready_0 <= 1'b1;
        count_ready <= valid_pipe[18];

        a_is_zero <= a_is_zero_in; b_is_zero <= b_is_zero_in; a_is_inf <= a_is_inf_in; b_is_inf <= b_is_inf_in;
        in_inf_1 <= in_inf_in; in_inf_2 <= in_inf_1; in_zero_1 <= in_zero_in;

        exponent_terms_1 <= exponent_terms_in; exponent_terms_2 <= exponent_terms_1; exponent_terms_3 <= exponent_terms_2;
        exponent_terms_4 <= exponent_terms_3; exponent_terms_5 <= exponent_terms_4; exponent_terms_6 <= exponent_terms_5;
        exponent_terms_7 <= exponent_terms_6; exponent_terms_8 <= exponent_terms_7; exponent_terms_9 <= exponent_terms_8;

        exponent_gt_expoffset <= (exponent_terms_in > 12'd1023);
        exponent_1 <= exponent_stage1_in;
        exponent_2_0 <= exponent_stage1_in;
        exponent_2_1 <= exponent_2_0;
        exponent_2 <= exponent_2_1;
        exponent_gt_prodshift <= (exponent_stage1_in > {11'd0, product_shift_in});
        exponent_is_infinity <= (exponent_stage1_in >= 12'h7ff);
        exponent_3 <= exponent_2; exponent_4 <= exponent_3; exponent_5 <= exponent_4; exponent_6 <= exponent_5;
        exponent_7 <= exponent_6; exponent_8 <= exponent_7; exponent_9 <= exponent_8;

        set_mantissa_zero <= in_zero_in;
        set_mz_1 <= set_mantissa_zero;

        mul_a <= mul_a_in; mul_a1 <= mul_a; mul_a2 <= mul_a1; mul_a3 <= mul_a2; mul_a4 <= mul_a3;
        mul_a5 <= mul_a4; mul_a6 <= mul_a5; mul_a7 <= mul_a6; mul_a8 <= mul_a7;
        mul_b <= mul_b_in; mul_b1 <= mul_b; mul_b2 <= mul_b1; mul_b3 <= mul_b2; mul_b4 <= mul_b3;
        mul_b5 <= mul_b4; mul_b6 <= mul_b5; mul_b7 <= mul_b6; mul_b8 <= mul_b7;

        product_a <= mul_a_in[40:0];
        product_a_2 <= product_in[16:0]; product_a_3 <= product_a_2; product_a_4 <= product_a_3; product_a_5 <= product_a_4;
        product_a_6 <= product_a_5; product_a_7 <= product_a_6; product_a_8 <= product_a_7; product_a_9 <= product_a_8; product_a_10 <= product_a_9;
        product_b <= mul_b_in[40:0];
        product_c <= product_in[40:0];
        product_d <= product_in[66:41];
        product_e <= product_in[74:41];
        product_f <= product_in[107-1:72];
        product_g <= product_in[105:70];
        product_h <= product_in[69:41];
        product_i <= product_in[95:67];
        product_j <= product_in[71:41];

        sum_0 <= product_in[41:0];
        sum_0_2 <= product_in[6:0]; sum_0_3 <= sum_0_2; sum_0_4 <= sum_0_3; sum_0_5 <= sum_0_4;
        sum_0_6 <= sum_0_5; sum_0_7 <= sum_0_6; sum_0_8 <= sum_0_7; sum_0_9 <= sum_0_8;
        sum_1 <= product_in[77:42];
        sum_1_2 <= product_in[51:42]; sum_1_3 <= sum_1_2; sum_1_4 <= sum_1_3; sum_1_5 <= sum_1_4;
        sum_1_6 <= sum_1_5; sum_1_7 <= sum_1_6; sum_1_8 <= sum_1_7;
        sum_2 <= product_in[83:42];
        sum_2_2 <= product_in[48:42]; sum_2_3 <= sum_2_2; sum_2_4 <= sum_2_3; sum_2_5 <= sum_2_4; sum_2_6 <= sum_2_5; sum_2_7 <= sum_2_6;
        sum_3 <= product_in[89:54];
        sum_4 <= product_in[90:54];
        sum_4_2 <= product_in[63:54]; sum_4_3 <= sum_4_2; sum_4_4 <= sum_4_3; sum_4_5 <= sum_4_4;
        sum_5 <= product_in[81:54];
        sum_5_2 <= product_in[60:54]; sum_5_3 <= sum_5_2; sum_5_4 <= sum_5_3;
        sum_6 <= product_in[83:54];
        sum_7 <= product_in[90:54];
        sum_7_2 <= product_in[70:54];
        sum_8 <= product_in[84:54];

        product <= product_in;
        product_1 <= product;
        product_2 <= normalized_product_in;
        product_3 <= product_2;
        product_4 <= {1'b0, product_3};
        product_5 <= product_4;
        product_6 <= product_5;
        product_7 <= product_6;
        product_overflow <= product_shift_in;

        round_nearest_mode <= (rmode == 2'b00);
        round_posinf_mode <= (rmode == 2'b10);
        round_neginf_mode <= (rmode == 2'b11);
        round_nearest_trigger <= guard_in & (sticky_in | normalized_product_in[0]);
        round_nearest_exception <= guard_in & (~sticky_in) & (~normalized_product_in[0]);
        round_nearest_enable <= (rmode == 2'b00) & round_any_in;
        round_posinf_trigger <= (~sign_in) & round_any_in;
        round_posinf_enable <= (rmode == 2'b10) & (~sign_in) & round_any_in;
        round_neginf_trigger <= sign_in & round_any_in;
        round_neginf_enable <= (rmode == 2'b11) & sign_in & round_any_in;
        round_enable <= round_any_in;
    end
end

endmodule
