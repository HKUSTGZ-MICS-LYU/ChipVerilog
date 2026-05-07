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

localparam [1:0] RM_RNE = 2'b00;
localparam [1:0] RM_RTZ = 2'b01;
localparam [1:0] RM_RUP = 2'b10;
localparam [1:0] RM_RDN = 2'b11;

localparam [63:0] CANONICAL_QNAN = 64'h7ff8_0000_0000_0000;
localparam [63:0] POS_INF        = 64'h7ff0_0000_0000_0000;
localparam [63:0] NEG_INF        = 64'hfff0_0000_0000_0000;
localparam [63:0] POS_ZERO       = 64'h0000_0000_0000_0000;
localparam [63:0] NEG_ZERO       = 64'h8000_0000_0000_0000;

localparam integer LATENCY = 4;

reg prev_enable;
reg busy;
reg [2:0] countdown;

reg [63:0] opa_reg;
reg [63:0] opb_reg;
reg [2:0] op_reg;
reg [1:0] rmode_reg;

reg [63:0] result_next;
reg underflow_next;
reg overflow_next;
reg inexact_next;
reg exception_next;
reg invalid_next;

reg [63:0] result_hold;
reg hold_underflow;
reg hold_overflow;
reg hold_inexact;
reg hold_exception;
reg hold_invalid;

function [52:0] frac_with_hidden;
    input [63:0] val;
    begin
        if (val[62:52] == 11'd0) begin
            frac_with_hidden = {1'b0, val[51:0]};
        end else begin
            frac_with_hidden = {1'b1, val[51:0]};
        end
    end
endfunction

function [63:0] pack_fp;
    input sign;
    input [10:0] exp;
    input [51:0] frac;
    begin
        pack_fp = {sign, exp, frac};
    end
endfunction

function is_nan;
    input [63:0] val;
    begin
        is_nan = (val[62:52] == 11'h7ff) && (val[51:0] != 52'd0);
    end
endfunction

function is_inf;
    input [63:0] val;
    begin
        is_inf = (val[62:52] == 11'h7ff) && (val[51:0] == 52'd0);
    end
endfunction

function is_zero;
    input [63:0] val;
    begin
        is_zero = (val[62:52] == 11'd0) && (val[51:0] == 52'd0);
    end
endfunction

function [63:0] next_up;
    input [63:0] val;
    begin
        if (is_nan(val) || (val == POS_INF)) begin
            next_up = val;
        end else if (val[63]) begin
            if (val == NEG_ZERO) begin
                next_up = 64'h0000_0000_0000_0001;
            end else begin
                next_up = val - 64'd1;
            end
        end else begin
            next_up = val + 64'd1;
        end
    end
endfunction

function [63:0] next_down;
    input [63:0] val;
    begin
        if (is_nan(val) || (val == NEG_INF)) begin
            next_down = val;
        end else if (val[63]) begin
            next_down = val + 64'd1;
        end else begin
            if (val == POS_ZERO) begin
                next_down = 64'h8000_0000_0000_0001;
            end else begin
                next_down = val - 64'd1;
            end
        end
    end
endfunction

always @(*) begin
    reg sign_a;
    reg sign_b;
    reg [10:0] exp_a;
    reg [10:0] exp_b;
    reg [51:0] frac_a;
    reg [51:0] frac_b;
    reg [52:0] mant_a;
    reg [52:0] mant_b;
    reg [63:0] result_tmp;
    reg sign_res;
    reg [10:0] exp_res;
    reg [51:0] frac_res;
    reg [105:0] product_full;
    reg [55:0] product_norm;
    reg [10:0] exp_mul;
    reg [63:0] div_quot;
    reg [10:0] exp_div;
    reg [53:0] sum_ext;
    reg [53:0] diff_ext;
    reg [10:0] exp_large;
    reg [52:0] mant_large;
    reg [52:0] mant_small;
    reg sign_large;
    reg sign_small;
    reg [10:0] exp_diff;
    reg [55:0] small_shift_ext;
    reg [55:0] large_ext;
    reg [55:0] add_ext;
    reg [55:0] sub_ext;
    reg [55:0] norm_ext;
    reg [10:0] exp_work;
    reg guard_bit;
    reg round_bit;
    reg sticky_bit;
    reg round_inc;
    reg [52:0] mant_round;
    reg [63:0] rounded_tmp;
    reg invalid_tmp;
    reg overflow_tmp;
    reg underflow_tmp;
    reg inexact_tmp;
    reg exception_tmp;
    reg special_zero;
    reg [63:0] special_result;
    integer i;

    sign_a = opa_reg[63];
    sign_b = opb_reg[63];
    exp_a = opa_reg[62:52];
    exp_b = opb_reg[62:52];
    frac_a = opa_reg[51:0];
    frac_b = opb_reg[51:0];
    mant_a = frac_with_hidden(opa_reg);
    mant_b = frac_with_hidden(opb_reg);

    result_tmp = POS_ZERO;
    rounded_tmp = POS_ZERO;
    invalid_tmp = 1'b0;
    overflow_tmp = 1'b0;
    underflow_tmp = 1'b0;
    inexact_tmp = 1'b0;
    exception_tmp = 1'b0;
    special_zero = 1'b0;
    special_result = POS_ZERO;

    if (is_nan(opa_reg) || is_nan(opb_reg)) begin
        result_tmp = CANONICAL_QNAN;
        invalid_tmp = 1'b1;
    end else begin
        case (op_reg)
            OP_ADD,
            OP_SUB: begin
                reg effective_sign_b;
                effective_sign_b = sign_b ^ (op_reg == OP_SUB);

                if (is_inf(opa_reg) && is_inf(opb_reg)) begin
                    if (sign_a != effective_sign_b) begin
                        result_tmp = CANONICAL_QNAN;
                        invalid_tmp = 1'b1;
                    end else begin
                        result_tmp = {sign_a, 11'h7ff, 52'd0};
                    end
                end else if (is_inf(opa_reg)) begin
                    result_tmp = {sign_a, 11'h7ff, 52'd0};
                end else if (is_inf(opb_reg)) begin
                    result_tmp = {effective_sign_b, 11'h7ff, 52'd0};
                end else if (is_zero(opa_reg) && is_zero(opb_reg)) begin
                    if (rmode_reg == RM_RDN) begin
                        result_tmp = NEG_ZERO;
                    end else begin
                        result_tmp = POS_ZERO;
                    end
                    special_zero = 1'b1;
                end else begin
                    if ((exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b))) begin
                        exp_large = exp_a;
                        mant_large = mant_a;
                        sign_large = sign_a;
                        exp_diff = exp_a - exp_b;
                        mant_small = mant_b;
                        sign_small = effective_sign_b;
                    end else begin
                        exp_large = exp_b;
                        mant_large = mant_b;
                        sign_large = effective_sign_b;
                        exp_diff = exp_b - exp_a;
                        mant_small = mant_a;
                        sign_small = sign_a;
                    end

                    if (exp_diff > 11'd55) begin
                        small_shift_ext = 56'd1;
                    end else begin
                        small_shift_ext = {mant_small, 3'b000} >> exp_diff;
                        if (exp_diff != 0) begin
                            if (({mant_small, 3'b000} & ((56'd1 << exp_diff) - 56'd1)) != 0)
                                small_shift_ext[0] = 1'b1;
                        end
                    end

                    large_ext = {mant_large, 3'b000};
                    exp_work = exp_large;

                    if (sign_large == sign_small) begin
                        add_ext = large_ext + small_shift_ext;
                        norm_ext = add_ext;
                        sign_res = sign_large;
                        if (norm_ext[55]) begin
                            norm_ext = norm_ext >> 1;
                            exp_work = exp_work + 11'd1;
                        end
                    end else begin
                        sub_ext = large_ext - small_shift_ext;
                        norm_ext = sub_ext;
                        sign_res = sign_large;
                        if (norm_ext == 56'd0) begin
                            special_zero = 1'b1;
                            if (rmode_reg == RM_RDN)
                                result_tmp = NEG_ZERO;
                            else
                                result_tmp = POS_ZERO;
                        end else begin
                            for (i = 0; i < 55; i = i + 1) begin
                                if ((norm_ext[54] == 1'b0) && (exp_work > 11'd0)) begin
                                    norm_ext = norm_ext << 1;
                                    exp_work = exp_work - 11'd1;
                                end
                            end
                        end
                    end

                    if (!special_zero) begin
                        guard_bit = norm_ext[2];
                        round_bit = norm_ext[1];
                        sticky_bit = norm_ext[0];
                        mant_round = norm_ext[55:3];
                        inexact_tmp = guard_bit | round_bit | sticky_bit;

                        round_inc = 1'b0;
                        case (rmode_reg)
                            RM_RNE: round_inc = guard_bit && (round_bit || sticky_bit || mant_round[0]);
                            RM_RTZ: round_inc = 1'b0;
                            RM_RUP: round_inc = !sign_res && inexact_tmp;
                            RM_RDN: round_inc = sign_res && inexact_tmp;
                            default: round_inc = 1'b0;
                        endcase

                        if (round_inc) begin
                            mant_round = mant_round + 53'd1;
                            if (mant_round[52]) begin
                                mant_round = mant_round >> 1;
                                exp_work = exp_work + 11'd1;
                            end
                        end

                        if (exp_work >= 11'h7ff) begin
                            overflow_tmp = 1'b1;
                            inexact_tmp = 1'b1;
                            case (rmode_reg)
                                RM_RTZ: rounded_tmp = sign_res ? NEG_INF - 64'd1 : POS_INF - 64'd1;
                                RM_RUP: rounded_tmp = sign_res ? (NEG_INF - 64'd1) : POS_INF;
                                RM_RDN: rounded_tmp = sign_res ? NEG_INF : (POS_INF - 64'd1);
                                default: rounded_tmp = {sign_res, 11'h7ff, 52'd0};
                            endcase
                        end else if (exp_work == 11'd0) begin
                            underflow_tmp = inexact_tmp | (mant_round[51:0] != 52'd0);
                            rounded_tmp = {sign_res, 11'd0, mant_round[51:0]};
                        end else begin
                            rounded_tmp = {sign_res, exp_work, mant_round[51:0]};
                        end

                        result_tmp = rounded_tmp;
                    end
                end
            end

            OP_MUL: begin
                if ((is_inf(opa_reg) && is_zero(opb_reg)) || (is_inf(opb_reg) && is_zero(opa_reg))) begin
                    result_tmp = CANONICAL_QNAN;
                    invalid_tmp = 1'b1;
                end else if (is_inf(opa_reg) || is_inf(opb_reg)) begin
                    result_tmp = {sign_a ^ sign_b, 11'h7ff, 52'd0};
                end else if (is_zero(opa_reg) || is_zero(opb_reg)) begin
                    result_tmp = {(sign_a ^ sign_b), 63'd0};
                end else begin
                    product_full = mant_a * mant_b;
                    exp_mul = exp_a + exp_b - 11'd1023;
                    if (product_full[105]) begin
                        product_norm = product_full[105:50];
                        exp_mul = exp_mul + 11'd1;
                    end else begin
                        product_norm = product_full[104:49];
                    end

                    sign_res = sign_a ^ sign_b;
                    guard_bit = product_norm[2];
                    round_bit = product_norm[1];
                    sticky_bit = product_norm[0];
                    mant_round = product_norm[55:3];
                    inexact_tmp = guard_bit | round_bit | sticky_bit;

                    round_inc = 1'b0;
                    case (rmode_reg)
                        RM_RNE: round_inc = guard_bit && (round_bit || sticky_bit || mant_round[0]);
                        RM_RTZ: round_inc = 1'b0;
                        RM_RUP: round_inc = !sign_res && inexact_tmp;
                        RM_RDN: round_inc = sign_res && inexact_tmp;
                        default: round_inc = 1'b0;
                    endcase

                    if (round_inc) begin
                        mant_round = mant_round + 53'd1;
                        if (mant_round[52]) begin
                            mant_round = mant_round >> 1;
                            exp_mul = exp_mul + 11'd1;
                        end
                    end

                    if (exp_mul >= 11'h7ff) begin
                        overflow_tmp = 1'b1;
                        inexact_tmp = 1'b1;
                        case (rmode_reg)
                            RM_RTZ: result_tmp = sign_res ? NEG_INF - 64'd1 : POS_INF - 64'd1;
                            RM_RUP: result_tmp = sign_res ? (NEG_INF - 64'd1) : POS_INF;
                            RM_RDN: result_tmp = sign_res ? NEG_INF : (POS_INF - 64'd1);
                            default: result_tmp = {sign_res, 11'h7ff, 52'd0};
                        endcase
                    end else if (exp_mul == 11'd0) begin
                        underflow_tmp = inexact_tmp | (mant_round[51:0] != 52'd0);
                        result_tmp = {sign_res, 11'd0, mant_round[51:0]};
                    end else begin
                        result_tmp = {sign_res, exp_mul, mant_round[51:0]};
                    end
                end
            end

            OP_DIV: begin
                if ((is_zero(opb_reg)) && (is_zero(opa_reg))) begin
                    result_tmp = CANONICAL_QNAN;
                    invalid_tmp = 1'b1;
                end else if (is_inf(opa_reg) && is_inf(opb_reg)) begin
                    result_tmp = CANONICAL_QNAN;
                    invalid_tmp = 1'b1;
                end else if (is_zero(opb_reg)) begin
                    result_tmp = {sign_a ^ sign_b, 11'h7ff, 52'd0};
                    exception_tmp = 1'b1;
                end else if (is_inf(opa_reg)) begin
                    result_tmp = {sign_a ^ sign_b, 11'h7ff, 52'd0};
                end else if (is_inf(opb_reg)) begin
                    result_tmp = {(sign_a ^ sign_b), 63'd0};
                end else if (is_zero(opa_reg)) begin
                    result_tmp = {(sign_a ^ sign_b), 63'd0};
                end else begin
                    div_quot = ({mant_a, 53'd0}) / mant_b;
                    exp_div = exp_a - exp_b + 11'd1023;
                    if (!div_quot[53]) begin
                        div_quot = div_quot << 1;
                        exp_div = exp_div - 11'd1;
                    end

                    sign_res = sign_a ^ sign_b;
                    guard_bit = div_quot[1];
                    round_bit = div_quot[0];
                    sticky_bit = 1'b0;
                    mant_round = div_quot[54:2];
                    inexact_tmp = (({mant_a, 53'd0}) % mant_b) != 0;

                    round_inc = 1'b0;
                    case (rmode_reg)
                        RM_RNE: round_inc = guard_bit && (round_bit || inexact_tmp || mant_round[0]);
                        RM_RTZ: round_inc = 1'b0;
                        RM_RUP: round_inc = !sign_res && (guard_bit || round_bit || inexact_tmp);
                        RM_RDN: round_inc = sign_res && (guard_bit || round_bit || inexact_tmp);
                        default: round_inc = 1'b0;
                    endcase

                    if (round_inc) begin
                        mant_round = mant_round + 53'd1;
                        if (mant_round[52]) begin
                            mant_round = mant_round >> 1;
                            exp_div = exp_div + 11'd1;
                        end
                    end

                    if (exp_div >= 11'h7ff) begin
                        overflow_tmp = 1'b1;
                        inexact_tmp = 1'b1;
                        case (rmode_reg)
                            RM_RTZ: result_tmp = sign_res ? NEG_INF - 64'd1 : POS_INF - 64'd1;
                            RM_RUP: result_tmp = sign_res ? (NEG_INF - 64'd1) : POS_INF;
                            RM_RDN: result_tmp = sign_res ? NEG_INF : (POS_INF - 64'd1);
                            default: result_tmp = {sign_res, 11'h7ff, 52'd0};
                        endcase
                    end else if (exp_div == 11'd0) begin
                        underflow_tmp = inexact_tmp | (mant_round[51:0] != 52'd0);
                        result_tmp = {sign_res, 11'd0, mant_round[51:0]};
                    end else begin
                        result_tmp = {sign_res, exp_div, mant_round[51:0]};
                    end
                end
            end

            default: begin
                result_tmp = CANONICAL_QNAN;
                invalid_tmp = 1'b1;
            end
        endcase
    end

    if (invalid_tmp) begin
        result_next = CANONICAL_QNAN;
    end else begin
        result_next = result_tmp;
    end

    underflow_next = underflow_tmp;
    overflow_next = overflow_tmp;
    inexact_next = inexact_tmp;
    invalid_next = invalid_tmp;
    exception_next = exception_tmp | invalid_tmp | overflow_tmp | underflow_tmp;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev_enable <= 1'b0;
        busy <= 1'b0;
        countdown <= 3'd0;
        opa_reg <= 64'd0;
        opb_reg <= 64'd0;
        op_reg <= 3'd0;
        rmode_reg <= 2'd0;
        result_hold <= 64'd0;
        hold_underflow <= 1'b0;
        hold_overflow <= 1'b0;
        hold_inexact <= 1'b0;
        hold_exception <= 1'b0;
        hold_invalid <= 1'b0;
        out <= 64'd0;
        ready <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else begin
        prev_enable <= enable;
        ready <= 1'b0;

        if (!busy && enable && !prev_enable) begin
            opa_reg <= opa;
            opb_reg <= opb;
            op_reg <= fpu_op;
            rmode_reg <= rmode;
            busy <= 1'b1;
            countdown <= LATENCY - 1;
            result_hold <= result_next;
            hold_underflow <= underflow_next;
            hold_overflow <= overflow_next;
            hold_inexact <= inexact_next;
            hold_exception <= exception_next;
            hold_invalid <= invalid_next;
        end else if (busy) begin
            if (countdown != 0) begin
                countdown <= countdown - 3'd1;
            end else begin
                busy <= 1'b0;
                out <= result_hold;
                ready <= 1'b1;
                underflow <= hold_underflow;
                overflow <= hold_overflow;
                inexact <= hold_inexact;
                exception <= hold_exception;
                invalid <= hold_invalid;
            end
        end
    end
end

endmodule
