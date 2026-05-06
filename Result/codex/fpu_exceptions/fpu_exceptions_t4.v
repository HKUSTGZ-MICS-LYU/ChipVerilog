module fpu_exceptions (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    input [63:0] in_except,
    input [11:0] exponent_in,
    input [1:0] mantissa_in,
    input [2:0] fpu_op,
    output reg [63:0] out,
    output reg ex_enable,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg exception,
    output reg invalid
);

    localparam [2:0] FPU_ADD = 3'b000;
    localparam [2:0] FPU_SUB = 3'b001;
    localparam [2:0] FPU_MUL = 3'b010;
    localparam [2:0] FPU_DIV = 3'b011;

    localparam [1:0] RM_NEAREST = 2'b00;
    localparam [1:0] RM_ZERO    = 2'b01;
    localparam [1:0] RM_POS_INF = 2'b10;
    localparam [1:0] RM_NEG_INF = 2'b11;

    localparam [10:0] EXP_2047 = 11'b11111111111;
    localparam [10:0] EXP_2046 = 11'b11111111110;

    localparam [51:0] MANT_ZERO = 52'b0;
    localparam [51:0] MANT_MAX  = 52'hfffffffffffff;

    localparam [63:0] QNAN_CANONICAL = 64'h7ff8_0000_0000_0000;
    localparam [63:0] POS_INF        = 64'h7ff0_0000_0000_0000;
    localparam [63:0] NEG_INF        = 64'hfff0_0000_0000_0000;
    localparam [63:0] POS_ZERO       = 64'h0000_0000_0000_0000;
    localparam [63:0] NEG_ZERO       = 64'h8000_0000_0000_0000;

    wire opa_sign = opa[63];
    wire opb_sign = opb[63];
    wire res_sign = in_except[63];

    wire [10:0] opa_exp = opa[62:52];
    wire [10:0] opb_exp = opb[62:52];
    wire [51:0] opa_man = opa[51:0];
    wire [51:0] opb_man = opb[51:0];

    wire [10:0] in_exp = in_except[62:52];
    wire [51:0] in_man = in_except[51:0];

    wire opa_et_zero = (opa_exp == 11'd0) && (opa_man == MANT_ZERO);
    wire opb_et_zero = (opb_exp == 11'd0) && (opb_man == MANT_ZERO);
    wire in_et_zero  = (in_exp  == 11'd0) && (in_man  == MANT_ZERO);

    wire add      = (fpu_op == FPU_ADD);
    wire subtract = (fpu_op == FPU_SUB);
    wire multiply = (fpu_op == FPU_MUL);
    wire divide   = (fpu_op == FPU_DIV);

    wire opa_is_nan = (opa_exp == EXP_2047) && (opa_man != MANT_ZERO);
    wire opb_is_nan = (opb_exp == EXP_2047) && (opb_man != MANT_ZERO);

    wire opa_QNaN = opa_is_nan &&  opa_man[51];
    wire opb_QNaN = opb_is_nan &&  opb_man[51];

    wire opa_SNaN = opa_is_nan && !opa_man[51];
    wire opb_SNaN = opb_is_nan && !opb_man[51];

    wire opa_pos_inf = (opa == POS_INF);
    wire opb_pos_inf = (opb == POS_INF);
    wire opa_neg_inf = (opa == NEG_INF);
    wire opb_neg_inf = (opb == NEG_INF);

    wire opa_inf = (opa_exp == EXP_2047) && (opa_man == MANT_ZERO);
    wire opb_inf = (opb_exp == EXP_2047) && (opb_man == MANT_ZERO);

    wire NaN_input  = opa_is_nan || opb_is_nan;
    wire SNaN_input = opa_SNaN || opb_SNaN;

    wire div_by_0       = divide && !opa_et_zero &&  opb_et_zero && !opa_inf && !NaN_input;
    wire div_0_by_0     = divide &&  opa_et_zero &&  opb_et_zero;
    wire div_inf_by_inf = divide &&  opa_inf     &&  opb_inf;
    wire div_by_inf     = divide && !opa_inf     &&  opb_inf && !opa_et_zero && !NaN_input;

    wire mul_0_by_inf = multiply && ((opa_et_zero && opb_inf) || (opb_et_zero && opa_inf));
    wire mul_inf      = multiply && (opa_inf || opb_inf) && !mul_0_by_inf && !NaN_input;

    wire div_inf = divide && opa_inf && !opb_inf && !opb_et_zero && !NaN_input;

    wire add_inf = add && (opa_inf || opb_inf) && !NaN_input;
    wire sub_inf = subtract && (opa_inf || opb_inf) && !NaN_input;

    wire add_inf_invalid = add &&
                           ((opa_pos_inf && opb_neg_inf) ||
                            (opa_neg_inf && opb_pos_inf));

    wire sub_inf_invalid = subtract &&
                           ((opa_pos_inf && opb_pos_inf) ||
                            (opa_neg_inf && opb_neg_inf));

    wire addsub_inf_invalid = add_inf_invalid || sub_inf_invalid;

    wire addsub_inf = (add_inf || sub_inf) && !addsub_inf_invalid;

    wire result_sign_div = opa_sign ^ opb_sign;
    wire result_sign_mul = opa_sign ^ opb_sign;

    wire round_nearest    = (rmode == RM_NEAREST);
    wire round_to_zero    = (rmode == RM_ZERO);
    wire round_to_pos_inf = (rmode == RM_POS_INF);
    wire round_to_neg_inf = (rmode == RM_NEG_INF);

    /*
        Overflow policy:
        exponent_in is 12 bits, so exponent_in[11] can represent carry beyond
        the IEEE-754 double exponent field. Also, exponent 2047 is not finite.
    */
    wire arithmetic_overflow =
        (exponent_in[11] == 1'b1) ||
        (exponent_in[10:0] >= EXP_2047);

    /*
        Underflow policy:
        This implementation asserts underflow when the datapath result becomes
        zero while discarded low bits indicate the result was not exact.
    */
    wire arithmetic_underflow =
        in_et_zero && (mantissa_in != 2'b00) && !arithmetic_overflow;

    wire invalid_trigger =
        SNaN_input       ||
        div_0_by_0       ||
        div_inf_by_inf   ||
        mul_0_by_inf     ||
        addsub_inf_invalid;

    wire overflow_trigger =
        arithmetic_overflow &&
        !NaN_input &&
        !invalid_trigger &&
        !div_by_0 &&
        !mul_inf &&
        !div_inf &&
        !addsub_inf;

    wire underflow_trigger =
        arithmetic_underflow &&
        !NaN_input &&
        !invalid_trigger &&
        !overflow_trigger;

    wire div_by_zero_trigger =
        div_by_0;

    wire special_inf_trigger =
        div_by_zero_trigger ||
        mul_inf             ||
        div_inf             ||
        addsub_inf;

    wire inexact_trigger =
        (mantissa_in != 2'b00) ||
        overflow_trigger       ||
        underflow_trigger;

    wire except_trigger =
        invalid_trigger      ||
        overflow_trigger     ||
        underflow_trigger    ||
        div_by_zero_trigger  ||
        inexact_trigger;

    wire NaN_out_trigger =
        NaN_input || invalid_trigger;

    wire out_pos_inf =
        (div_by_zero_trigger && !result_sign_div) ||
        (mul_inf             && !result_sign_mul) ||
        (div_inf             && !result_sign_div) ||
        (addsub_inf          && ((add && (opa_pos_inf || opb_pos_inf)) ||
                                 (subtract && ((opa_pos_inf && !opb_inf) ||
                                               (opb_neg_inf && !opa_inf))))) ||
        (overflow_trigger    && !res_sign);

    wire out_neg_inf =
        (div_by_zero_trigger &&  result_sign_div) ||
        (mul_inf             &&  result_sign_mul) ||
        (div_inf             &&  result_sign_div) ||
        (addsub_inf          && ((add && (opa_neg_inf || opb_neg_inf)) ||
                                 (subtract && ((opa_neg_inf && !opb_inf) ||
                                               (opb_pos_inf && !opa_inf))))) ||
        (overflow_trigger    &&  res_sign);

    wire inf_round_down_pos =
        overflow_trigger &&
        out_pos_inf &&
        (round_to_zero || round_to_neg_inf);

    wire inf_round_down_neg =
        overflow_trigger &&
        out_neg_inf &&
        (round_to_zero || round_to_pos_inf);

    wire inf_round_down_trigger =
        inf_round_down_pos || inf_round_down_neg;

    wire [63:0] max_pos_finite = {1'b0, EXP_2046, MANT_MAX};
    wire [63:0] max_neg_finite = {1'b1, EXP_2046, MANT_MAX};

    wire [63:0] inf_round_down =
        inf_round_down_pos ? max_pos_finite :
        inf_round_down_neg ? max_neg_finite :
                             64'b0;

    wire [63:0] out_inf =
        out_neg_inf ? NEG_INF :
        out_pos_inf ? POS_INF :
                      64'b0;

    wire [63:0] div_by_inf_zero =
        result_sign_div ? NEG_ZERO : POS_ZERO;

    wire [63:0] underflow_zero =
        res_sign ? NEG_ZERO : POS_ZERO;

    wire [63:0] NaN_output =
        opa_SNaN ? {opa[63], EXP_2047, 1'b1, opa_man[50:0]} :
        opb_SNaN ? {opb[63], EXP_2047, 1'b1, opb_man[50:0]} :
        opa_QNaN ? opa :
        opb_QNaN ? opb :
                   QNAN_CANONICAL;

    reg [63:0] out_next;
    reg        ex_enable_next;
    reg        underflow_next;
    reg        overflow_next;
    reg        inexact_next;
    reg        exception_next;
    reg        invalid_next;

    always @(*) begin
        out_next        = in_except;
        ex_enable_next  = 1'b0;
        underflow_next  = underflow_trigger;
        overflow_next   = overflow_trigger;
        inexact_next    = inexact_trigger;
        exception_next  = except_trigger;
        invalid_next    = invalid_trigger;

        if (NaN_out_trigger) begin
            out_next       = NaN_output;
            ex_enable_next = 1'b1;
        end
        else if (inf_round_down_trigger) begin
            out_next       = inf_round_down;
            ex_enable_next = 1'b1;
        end
        else if (special_inf_trigger || overflow_trigger) begin
            out_next       = out_inf;
            ex_enable_next = 1'b1;
        end
        else if (div_by_inf) begin
            out_next       = div_by_inf_zero;
            ex_enable_next = 1'b1;
        end
        else if (underflow_trigger && in_et_zero) begin
            out_next       = underflow_zero;
            ex_enable_next = 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out        <= 64'b0;
            ex_enable  <= 1'b0;
            underflow  <= 1'b0;
            overflow   <= 1'b0;
            inexact    <= 1'b0;
            exception  <= 1'b0;
            invalid    <= 1'b0;
        end
        else if (enable) begin
            out        <= out_next;
            ex_enable  <= ex_enable_next;
            underflow  <= underflow_next;
            overflow   <= overflow_next;
            inexact    <= inexact_next;
            exception  <= exception_next;
            invalid    <= invalid_next;
        end
    end

endmodule