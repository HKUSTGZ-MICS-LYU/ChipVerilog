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

localparam [2:0] OP_ADD = 3'b000;
localparam [2:0] OP_SUB = 3'b001;
localparam [2:0] OP_MUL = 3'b010;
localparam [2:0] OP_DIV = 3'b011;

localparam [1:0] RM_NEAREST = 2'b00;
localparam [1:0] RM_ZERO    = 2'b01;
localparam [1:0] RM_POS_INF = 2'b10;
localparam [1:0] RM_NEG_INF = 2'b11;

localparam [10:0] EXP_2047 = 11'h7ff;
localparam [10:0] EXP_2046 = 11'h7fe;
localparam [51:0] MANTISSA_MAX = 52'hfffffffffffff;

reg in_et_zero;
reg opa_et_zero;
reg opb_et_zero;
reg add;
reg subtract;
reg multiply;
reg divide;
reg opa_QNaN;
reg opb_QNaN;
reg opa_SNaN;
reg opb_SNaN;
reg opa_pos_inf;
reg opb_pos_inf;
reg opa_neg_inf;
reg opb_neg_inf;
reg opa_inf;
reg opb_inf;
reg NaN_input;
reg SNaN_input;
reg div_by_0;
reg div_0_by_0;
reg div_inf_by_inf;
reg div_by_inf;
reg mul_0_by_inf;
reg mul_inf;
reg div_inf;
reg add_inf;
reg sub_inf;
reg addsub_inf_invalid;
reg addsub_inf;
reg out_inf_trigger;
reg out_pos_inf;
reg out_neg_inf;
reg round_nearest;
reg round_to_zero;
reg round_to_pos_inf;
reg round_to_neg_inf;
reg inf_round_down_trigger;
reg mul_uf;
reg div_uf;
reg underflow_trigger;
reg invalid_trigger;
reg overflow_trigger;
reg inexact_trigger;
reg except_trigger;
reg enable_trigger;
reg NaN_out_trigger;
reg [62:0] NaN_output;
reg [62:0] inf_round_down;
reg [62:0] out_inf;
reg [63:0] out_0;
reg [63:0] out_1;
reg [63:0] out_next;
reg ex_enable_next;
reg underflow_next;
reg overflow_next;
reg inexact_next;
reg exception_next;
reg invalid_next;

always @* begin
    in_et_zero = (in_except[62:0] == 63'd0);
    opa_et_zero = (opa[62:0] == 63'd0);
    opb_et_zero = (opb[62:0] == 63'd0);

    add = (fpu_op == OP_ADD);
    subtract = (fpu_op == OP_SUB);
    multiply = (fpu_op == OP_MUL);
    divide = (fpu_op == OP_DIV);

    opa_QNaN = (opa[62:52] == EXP_2047) && (opa[51:0] != 52'd0) && opa[51];
    opb_QNaN = (opb[62:52] == EXP_2047) && (opb[51:0] != 52'd0) && opb[51];
    opa_SNaN = (opa[62:52] == EXP_2047) && (opa[51:0] != 52'd0) && !opa[51];
    opb_SNaN = (opb[62:52] == EXP_2047) && (opb[51:0] != 52'd0) && !opb[51];

    opa_pos_inf = (opa[63] == 1'b0) && (opa[62:52] == EXP_2047) && (opa[51:0] == 52'd0);
    opb_pos_inf = (opb[63] == 1'b0) && (opb[62:52] == EXP_2047) && (opb[51:0] == 52'd0);
    opa_neg_inf = (opa[63] == 1'b1) && (opa[62:52] == EXP_2047) && (opa[51:0] == 52'd0);
    opb_neg_inf = (opb[63] == 1'b1) && (opb[62:52] == EXP_2047) && (opb[51:0] == 52'd0);

    opa_inf = opa_pos_inf | opa_neg_inf;
    opb_inf = opb_pos_inf | opb_neg_inf;

    NaN_input = opa_QNaN | opb_QNaN | opa_SNaN | opb_SNaN;
    SNaN_input = opa_SNaN | opb_SNaN;

    div_0_by_0 = divide && opa_et_zero && opb_et_zero;
    div_inf_by_inf = divide && opa_inf && opb_inf;
    div_by_0 = divide && !opa_et_zero && opb_et_zero && !opa_inf && !NaN_input;
    div_by_inf = divide && opb_inf && !opa_inf && !NaN_input;

    mul_0_by_inf = multiply && ((opa_et_zero && opb_inf) || (opb_et_zero && opa_inf));
    mul_inf = multiply && (opa_inf || opb_inf) && !mul_0_by_inf && !NaN_input;
    div_inf = divide && opa_inf && !opb_inf && !NaN_input;

    addsub_inf_invalid =
        (add && ((opa_pos_inf && opb_neg_inf) || (opa_neg_inf && opb_pos_inf))) ||
        (subtract && ((opa_pos_inf && opb_pos_inf) || (opa_neg_inf && opb_neg_inf)));

    add_inf = add && (opa_inf || opb_inf) && !addsub_inf_invalid && !NaN_input;
    sub_inf = subtract && (opa_inf || opb_inf) && !addsub_inf_invalid && !NaN_input;
    addsub_inf = add_inf || sub_inf;

    round_nearest = (rmode == RM_NEAREST);
    round_to_zero = (rmode == RM_ZERO);
    round_to_pos_inf = (rmode == RM_POS_INF);
    round_to_neg_inf = (rmode == RM_NEG_INF);

    out_inf_trigger = !NaN_input && (addsub_inf || mul_inf || div_inf || div_by_0 || (exponent_in > 12'd2046));
    out_pos_inf = out_inf_trigger && (in_except[63] == 1'b0);
    out_neg_inf = out_inf_trigger && (in_except[63] == 1'b1);

    inf_round_down_trigger =
        (out_pos_inf && (round_to_zero || round_to_neg_inf)) ||
        (out_neg_inf && (round_to_zero || round_to_pos_inf));

    mul_uf = multiply && in_et_zero && !opa_et_zero && !opb_et_zero && !opa_inf && !opb_inf && !NaN_input;
    div_uf = divide && in_et_zero && !opa_et_zero && !opb_et_zero && !opa_inf && !opb_inf && !NaN_input;
    underflow_trigger = !NaN_input && (div_by_inf || mul_uf || div_uf);

    invalid_trigger = SNaN_input || addsub_inf_invalid || mul_0_by_inf || div_0_by_0 || div_inf_by_inf;
    overflow_trigger = out_inf_trigger;
    inexact_trigger = (mantissa_in != 2'b00) || out_inf_trigger || underflow_trigger;
    except_trigger = invalid_trigger || overflow_trigger || underflow_trigger || inexact_trigger;
    NaN_out_trigger = NaN_input || invalid_trigger;
    enable_trigger = NaN_out_trigger || out_inf_trigger || underflow_trigger || inexact_trigger;

    if (opa_QNaN || opa_SNaN) begin
        NaN_output = {EXP_2047, 1'b1, opa[50:0]};
    end else if (opb_QNaN || opb_SNaN) begin
        NaN_output = {EXP_2047, 1'b1, opb[50:0]};
    end else begin
        NaN_output = {EXP_2047, 1'b1, opa[50:0]};
    end

    inf_round_down = {EXP_2046, MANTISSA_MAX};
    out_inf = {EXP_2047, 52'd0};

    out_0 = underflow_trigger ? {in_except[63], 63'd0} : in_except;
    out_1 = out_inf_trigger ? {in_except[63], (inf_round_down_trigger ? inf_round_down : out_inf)} : out_0;
    out_next = NaN_out_trigger ? {in_except[63], NaN_output} : out_1;

    ex_enable_next = enable_trigger;
    underflow_next = underflow_trigger;
    overflow_next = overflow_trigger;
    inexact_next = inexact_trigger;
    exception_next = except_trigger;
    invalid_next = invalid_trigger;
end

always @(posedge clk) begin
    if (rst) begin
        out <= 64'd0;
        ex_enable <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else if (enable) begin
        out <= out_next;
        ex_enable <= ex_enable_next;
        underflow <= underflow_next;
        overflow <= overflow_next;
        inexact <= inexact_next;
        exception <= exception_next;
        invalid <= invalid_next;
    end
end

endmodule
