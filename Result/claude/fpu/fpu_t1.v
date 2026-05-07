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

    localparam [1:0] RM_NEAREST = 2'b00;
    localparam [1:0] RM_ZERO    = 2'b01;
    localparam [1:0] RM_PINF    = 2'b10;
    localparam [1:0] RM_NINF    = 2'b11;

    localparam [63:0] QNAN = 64'h7ff8_0000_0000_0000;

    localparam integer LATENCY = 4;

    reg enable_d;
    reg busy;
    reg [2:0] latency_cnt;

    reg [63:0] opa_r, opb_r;
    reg [2:0]  op_r;
    reg [1:0]  rm_r;

    wire start = enable & ~enable_d;

    wire a_sign = opa_r[63];
    wire [10:0] a_exp = opa_r[62:52];
    wire [51:0] a_frac = opa_r[51:0];
    wire b_sign = opb_r[63];
    wire [10:0] b_exp = opb_r[62:52];
    wire [51:0] b_frac = opb_r[51:0];

    wire a_is_zero = (a_exp == 11'd0) && (a_frac == 52'd0);
    wire b_is_zero = (b_exp == 11'd0) && (b_frac == 52'd0);
    wire a_is_inf  = (a_exp == 11'h7ff) && (a_frac == 52'd0);
    wire b_is_inf  = (b_exp == 11'h7ff) && (b_frac == 52'd0);
    wire a_is_nan  = (a_exp == 11'h7ff) && (a_frac != 52'd0);
    wire b_is_nan  = (b_exp == 11'h7ff) && (b_frac != 52'd0);

    reg res_sign;
    reg [12:0] res_exp_ext;
    reg [56:0] res_mant_ext;
    reg any_discarded;

    reg rounded_sign;
    reg [10:0] rounded_exp;
    reg [51:0] rounded_frac;
    reg round_inexact;

    reg ovf, unf, inv, exc;
    reg [63:0] out_next;
    reg [63:0] rounded_packed;

    reg [53:0] ma;
    reg [53:0] mb;
    reg [56:0] ma_ext;
    reg [56:0] mb_ext;
    reg [56:0] big_m;
    reg [56:0] sml_m;
    reg big_s;
    reg sml_s;
    reg [10:0] big_e;
    reg [10:0] sml_e;
    reg [11:0] exp_work;
    reg [57:0] sum_ext;
    reg [56:0] diff_ext;
    reg [6:0] sh;
    reg sticky_local;
    reg [105:0] mul_full;
    reg [12:0] div_num;
    reg [105:0] div_numer;
    reg [55:0] div_q;
    reg [55:0] div_r;
    reg [11:0] exp_tmp;

    integer i;

    always @(*) begin
        res_sign = 1'b0;
        res_exp_ext = 13'd0;
        res_mant_ext = 57'd0;
        any_discarded = 1'b0;

        ma = { (a_exp != 11'd0), a_frac };
        mb = { (b_exp != 11'd0), b_frac };
        ma_ext = {ma, 3'b000};
        mb_ext = {mb, 3'b000};
        big_m = 57'd0;
        sml_m = 57'd0;
        big_s = 1'b0;
        sml_s = 1'b0;
        big_e = 11'd0;
        sml_e = 11'd0;
        exp_work = 12'd0;
        sum_ext = 58'd0;
        diff_ext = 57'd0;
        sh = 7'd0;
        sticky_local = 1'b0;
        mul_full = 106'd0;
        div_num = 13'd0;
        div_numer = 106'd0;
        div_q = 56'd0;
        div_r = 56'd0;
        exp_tmp = 12'd0;

        if (op_r == OP_SUB) begin
            mb_ext = {mb, 3'b000};
        end

        case (op_r)
            OP_ADD, OP_SUB: begin
                if (a_exp >= b_exp) begin
                    big_m = ma_ext;
                    big_s = a_sign;
                    big_e = a_exp;
                    sml_m = mb_ext;
                    sml_s = (op_r == OP_SUB) ? ~b_sign : b_sign;
                    sml_e = b_exp;
                end else begin
                    big_m = mb_ext;
                    big_s = (op_r == OP_SUB) ? ~b_sign : b_sign;
                    big_e = b_exp;
                    sml_m = ma_ext;
                    sml_s = a_sign;
                    sml_e = a_exp;
                end

                sh = big_e - sml_e;
                sticky_local = 1'b0;
                if (sh != 0) begin
                    if (sh >= 57) begin
                        sticky_local = |sml_m;
                        sml_m = 57'd0;
                    end else begin
                        sticky_local = |(sml_m & ((57'd1 << sh) - 57'd1));
                        sml_m = sml_m >> sh;
                    end
                end
                if (sticky_local)
                    sml_m[0] = 1'b1;

                exp_work = {1'b0, big_e};
                if (big_s == sml_s) begin
                    sum_ext = {1'b0, big_m} + {1'b0, sml_m};
                    res_sign = big_s;
                    if (sum_ext[57]) begin
                        res_mant_ext = sum_ext[57:1];
                        any_discarded = sum_ext[0];
                        res_exp_ext = exp_work + 13'd1;
                    end else begin
                        res_mant_ext = sum_ext[56:0];
                        res_exp_ext = exp_work;
                    end
                end else begin
                    if (big_m >= sml_m) begin
                        diff_ext = big_m - sml_m;
                        res_sign = big_s;
                    end else begin
                        diff_ext = sml_m - big_m;
                        res_sign = sml_s;
                    end
                    if (diff_ext == 57'd0) begin
                        res_sign = (rm_r == RM_NINF);
                        res_exp_ext = 13'd0;
                        res_mant_ext = 57'd0;
                    end else begin
                        res_mant_ext = diff_ext;
                        res_exp_ext = exp_work;
                        for (i = 0; i < 56; i = i + 1) begin
                            if (!res_mant_ext[56] && (res_exp_ext > 0)) begin
                                res_mant_ext = res_mant_ext << 1;
                                res_exp_ext = res_exp_ext - 13'd1;
                            end
                        end
                    end
                end
            end

            OP_MUL: begin
                if (a_is_zero || b_is_zero) begin
                    res_sign = a_sign ^ b_sign;
                    res_exp_ext = 13'd0;
                    res_mant_ext = 57'd0;
                end else begin
                    mul_full = ma * mb;
                    res_sign = a_sign ^ b_sign;
                    exp_tmp = {1'b0, a_exp} + {1'b0, b_exp} - 12'd1023;
                    if (mul_full[105]) begin
                        res_mant_ext = {mul_full[105:50], 1'b0};
                        any_discarded = |mul_full[49:0];
                        res_exp_ext = exp_tmp + 13'd1;
                    end else begin
                        res_mant_ext = {mul_full[104:49], 1'b0};
                        any_discarded = |mul_full[48:0];
                        res_exp_ext = exp_tmp;
                    end
                end
            end

            OP_DIV: begin
                if (a_is_zero && !b_is_zero) begin
                    res_sign = a_sign ^ b_sign;
                    res_exp_ext = 13'd0;
                    res_mant_ext = 57'd0;
                end else if (!a_is_zero && b_is_zero) begin
                    res_sign = a_sign ^ b_sign;
                    res_exp_ext = 13'd4095;
                    res_mant_ext = 57'd0;
                end else if (a_is_zero && b_is_zero) begin
                    res_sign = 1'b0;
                    res_exp_ext = 13'd4095;
                    res_mant_ext = 57'd1;
                end else begin
                    div_num = {1'b0, a_exp} - {1'b0, b_exp} + 13'd1023;
                    div_numer = {ma, 52'd0};
                    div_q = div_numer / mb;
                    div_r = div_numer % mb;
                    res_sign = a_sign ^ b_sign;
                    if (div_q[55]) begin
                        res_mant_ext = {div_q[55:0], 1'b0};
                        res_exp_ext = div_num;
                    end else begin
                        res_mant_ext = {div_q[54:0], 2'b00};
                        res_exp_ext = div_num - 13'd1;
                    end
                    any_discarded = (div_r != 0);
                end
            end

            default: begin
                res_sign = 1'b0;
                res_exp_ext = 13'd0;
                res_mant_ext = 57'd0;
                any_discarded = 1'b0;
            end
        endcase
    end

    always @(*) begin
        rounded_sign = res_sign;
        rounded_exp = (res_exp_ext[12]) ? 11'd0 : res_exp_ext[10:0];
        rounded_frac = 52'd0;
        round_inexact = any_discarded | res_mant_ext[2] | res_mant_ext[1] | res_mant_ext[0];

        begin
            reg [53:0] mant_main;
            reg guard_bit, round_bit, sticky_bit;
            reg round_up;
            reg [54:0] mant_inc;
            mant_main = res_mant_ext[56:3];
            guard_bit = res_mant_ext[2];
            round_bit = res_mant_ext[1];
            sticky_bit = res_mant_ext[0] | any_discarded;

            case (rm_r)
                RM_NEAREST: round_up = guard_bit & (round_bit | sticky_bit | mant_main[0]);
                RM_ZERO:    round_up = 1'b0;
                RM_PINF:    round_up = (~res_sign) & (guard_bit | round_bit | sticky_bit);
                RM_NINF:    round_up = ( res_sign) & (guard_bit | round_bit | sticky_bit);
                default:    round_up = 1'b0;
            endcase

            mant_inc = {1'b0, mant_main} + round_up;
            if (mant_inc[54]) begin
                mant_main = mant_inc[54:1];
                rounded_exp = rounded_exp + 11'd1;
            end else begin
                mant_main = mant_inc[53:0];
            end

            rounded_frac = mant_main[51:0];
        end

        rounded_packed = {rounded_sign, rounded_exp, rounded_frac};
    end

    always @(*) begin
        inv = 1'b0;
        ovf = 1'b0;
        unf = 1'b0;
        exc = 1'b0;
        out_next = rounded_packed;

        if (a_is_nan || b_is_nan) begin
            inv = 1'b1;
            out_next = QNAN;
        end else begin
            case (op_r)
                OP_ADD, OP_SUB: begin
                    if (a_is_inf && b_is_inf) begin
                        if ((op_r == OP_ADD && (a_sign != b_sign)) ||
                            (op_r == OP_SUB && (a_sign == b_sign))) begin
                            inv = 1'b1;
                            out_next = QNAN;
                        end else begin
                            out_next = {a_sign, 11'h7ff, 52'd0};
                        end
                    end else if (a_is_inf) begin
                        out_next = {a_sign, 11'h7ff, 52'd0};
                    end else if (b_is_inf) begin
                        out_next = {(op_r == OP_SUB) ? ~b_sign : b_sign, 11'h7ff, 52'd0};
                    end
                end

                OP_MUL: begin
                    if ((a_is_inf && b_is_zero) || (b_is_inf && a_is_zero)) begin
                        inv = 1'b1;
                        out_next = QNAN;
                    end else if (a_is_inf || b_is_inf) begin
                        out_next = {a_sign ^ b_sign, 11'h7ff, 52'd0};
                    end
                end

                OP_DIV: begin
                    if ((a_is_zero && b_is_zero) || (a_is_inf && b_is_inf)) begin
                        inv = 1'b1;
                        out_next = QNAN;
                    end else if (a_is_inf && !b_is_inf) begin
                        out_next = {a_sign ^ b_sign, 11'h7ff, 52'd0};
                    end else if (!a_is_inf && b_is_inf) begin
                        out_next = {a_sign ^ b_sign, 11'd0, 52'd0};
                    end else if (!a_is_zero && b_is_zero) begin
                        out_next = {a_sign ^ b_sign, 11'h7ff, 52'd0};
                        exc = 1'b1;
                    end
                end

                default: begin
                    out_next = 64'd0;
                    inv = 1'b1;
                end
            endcase
        end

        if (!inv) begin
            if (rounded_exp >= 11'h7ff) begin
                ovf = 1'b1;
                out_next = {rounded_sign, 11'h7ff, 52'd0};
            end else if ((rounded_exp == 11'd0) && (rounded_frac != 52'd0)) begin
                unf = 1'b1;
            end
        end

        exc = exc | inv | ovf | unf;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enable_d   <= 1'b0;
            busy       <= 1'b0;
            latency_cnt <= 3'd0;
            opa_r      <= 64'd0;
            opb_r      <= 64'd0;
            op_r       <= 3'd0;
            rm_r       <= 2'd0;
            out        <= 64'd0;
            ready      <= 1'b0;
            underflow  <= 1'b0;
            overflow   <= 1'b0;
            inexact    <= 1'b0;
            exception  <= 1'b0;
            invalid    <= 1'b0;
        end else begin
            enable_d <= enable;
            ready <= 1'b0;

            if (start && !busy) begin
                opa_r <= opa;
                opb_r <= opb;
                op_r <= fpu_op;
                rm_r <= rmode;
                busy <= 1'b1;
                latency_cnt <= LATENCY - 1;
                underflow <= 1'b0;
                overflow <= 1'b0;
                inexact <= 1'b0;
                exception <= 1'b0;
                invalid <= 1'b0;
            end else if (busy) begin
                if (latency_cnt != 0) begin
                    latency_cnt <= latency_cnt - 1'b1;
                end else begin
                    busy <= 1'b0;
                    out <= out_next;
                    ready <= 1'b1;
                    underflow <= unf;
                    overflow <= ovf;
                    inexact <= round_inexact;
                    exception <= exc | round_inexact;
                    invalid <= inv;
                end
            end
        end
    end

endmodule
