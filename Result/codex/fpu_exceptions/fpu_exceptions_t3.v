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

reg in_et_zero;
reg opa_et_zero;
reg opb_et_zero;
reg input_et_zero;
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
reg a_NaN;
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
reg SNaN_trigger;
wire [10:0] exp_2047 = 11'b11111111111;
wire [10:0] exp_2046 = 11'b11111111110;
reg [62:0] NaN_output_0;
reg [62:0] NaN_output;
wire [51:0] mantissa_max = 52'b1111111111111111111111111111111111111111111111111111;
reg [62:0] inf_round_down;
reg [62:0] out_inf;
reg [63:0] out_0;
reg [63:0] out_1;
reg [63:0] out_2;

wire w_in_et_zero = (in_except[62:0] == 63'd0);
wire w_opa_et_zero = (opa[62:0] == 63'd0);
wire w_opb_et_zero = (opb[62:0] == 63'd0);
wire w_input_et_zero = w_opa_et_zero | w_opb_et_zero;

wire w_add = (fpu_op == 3'b000);
wire w_subtract = (fpu_op == 3'b001);
wire w_multiply = (fpu_op == 3'b010);
wire w_divide = (fpu_op == 3'b011);

wire w_opa_is_nan = (&opa[62:52]) & (|opa[51:0]);
wire w_opb_is_nan = (&opb[62:52]) & (|opb[51:0]);
wire w_opa_QNaN = w_opa_is_nan & opa[51];
wire w_opb_QNaN = w_opb_is_nan & opb[51];
wire w_opa_SNaN = w_opa_is_nan & ~opa[51];
wire w_opb_SNaN = w_opb_is_nan & ~opb[51];

wire w_opa_inf = (&opa[62:52]) & ~(|opa[51:0]);
wire w_opb_inf = (&opb[62:52]) & ~(|opb[51:0]);
wire w_opa_pos_inf = w_opa_inf & ~opa[63];
wire w_opb_pos_inf = w_opb_inf & ~opb[63];
wire w_opa_neg_inf = w_opa_inf & opa[63];
wire w_opb_neg_inf = w_opb_inf & opb[63];

wire w_NaN_input = w_opa_QNaN | w_opb_QNaN | w_opa_SNaN | w_opb_SNaN;
wire w_SNaN_input = w_opa_SNaN | w_opb_SNaN;
wire w_a_NaN = w_opa_is_nan;

wire w_addsub_inf_invalid =
    (w_add & ((w_opa_pos_inf & w_opb_neg_inf) | (w_opa_neg_inf & w_opb_pos_inf))) |
    (w_subtract & ((w_opa_pos_inf & w_opb_pos_inf) | (w_opa_neg_inf & w_opb_neg_inf)));

wire w_mul_0_by_inf = w_multiply &
    ((w_opa_et_zero & w_opb_inf) | (w_opb_et_zero & w_opa_inf));

wire w_div_0_by_0 = w_divide & w_opa_et_zero & w_opb_et_zero;
wire w_div_inf_by_inf = w_divide & w_opa_inf & w_opb_inf;
wire w_div_by_0 = w_divide & w_opb_et_zero & ~w_opa_et_zero & ~w_opa_inf & ~w_NaN_input;
wire w_div_by_inf = w_divide & ~w_opa_inf & ~w_opa_et_zero & w_opb_inf;

wire w_mul_inf = w_multiply & (w_opa_inf | w_opb_inf) & ~w_mul_0_by_inf;
wire w_div_inf = w_divide & w_opa_inf & ~w_opb_inf;
wire w_add_inf = w_add & (w_opa_inf | w_opb_inf) & ~w_addsub_inf_invalid;
wire w_sub_inf = w_subtract & (w_opa_inf | w_opb_inf) & ~w_addsub_inf_invalid;
wire w_addsub_inf = w_add_inf | w_sub_inf;

wire w_exp_overflow = (exponent_in > {1'b0, exp_2046});
wire w_out_inf_trigger = w_mul_inf | w_div_inf | w_addsub_inf | w_div_by_0 | w_exp_overflow;
wire w_out_pos_inf = w_out_inf_trigger & ~in_except[63];
wire w_out_neg_inf = w_out_inf_trigger & in_except[63];

wire w_round_nearest = (rmode == 2'b00);
wire w_round_to_zero = (rmode == 2'b01);
wire w_round_to_pos_inf = (rmode == 2'b10);
wire w_round_to_neg_inf = (rmode == 2'b11);

wire w_inf_round_down_trigger =
    (w_out_pos_inf & (w_round_to_zero | w_round_to_neg_inf)) |
    (w_out_neg_inf & (w_round_to_zero | w_round_to_pos_inf));

wire w_mul_uf = w_multiply & w_in_et_zero &
    ~w_opa_et_zero & ~w_opb_et_zero & ~w_opa_inf & ~w_opb_inf;
wire w_div_uf = w_divide & w_in_et_zero &
    ~w_opa_et_zero & ~w_opb_et_zero & ~w_opa_inf & ~w_opb_inf;
wire w_underflow_trigger = (w_div_by_inf | w_mul_uf | w_div_uf) & ~w_NaN_input;

wire w_invalid_trigger =
    w_SNaN_input | w_addsub_inf_invalid | w_mul_0_by_inf | w_div_0_by_0 | w_div_inf_by_inf;
wire w_overflow_trigger = w_out_inf_trigger & ~w_NaN_input;
wire w_inexact_trigger = ~w_NaN_input &
    ((mantissa_in != 2'b00) | w_out_inf_trigger | w_underflow_trigger);
wire w_except_trigger =
    w_invalid_trigger | w_overflow_trigger | w_underflow_trigger | w_inexact_trigger;
wire w_NaN_out_trigger = w_NaN_input | w_invalid_trigger;
wire w_SNaN_trigger = w_SNaN_input;
wire w_enable_trigger = w_except_trigger | w_NaN_input;

wire [62:0] w_nan_from_input = (w_opa_is_nan ? opa[62:0] : opb[62:0]);
wire [62:0] w_nan_from_input_q = {exp_2047, 1'b1, w_nan_from_input[50:0]};
wire [62:0] w_nan_from_invalid = {exp_2047, 1'b1, opa[50:0]};
wire [62:0] w_NaN_output = w_NaN_input ? w_nan_from_input_q : w_nan_from_invalid;

wire [62:0] w_inf_round_down = {exp_2046, mantissa_max};
wire [62:0] w_out_inf = {exp_2047, 52'd0};

wire [63:0] w_out_0 = w_underflow_trigger ? {in_except[63], 63'd0} : in_except;
wire [63:0] w_out_1 = w_out_inf_trigger
    ? {in_except[63], (w_inf_round_down_trigger ? w_inf_round_down : w_out_inf)}
    : w_out_0;
wire [63:0] w_out_2 = w_NaN_out_trigger ? {in_except[63], w_NaN_output} : w_out_1;

always @(posedge clk) begin
    if (rst) begin
        in_et_zero <= 1'b0;
        opa_et_zero <= 1'b0;
        opb_et_zero <= 1'b0;
        input_et_zero <= 1'b0;
        add <= 1'b0;
        subtract <= 1'b0;
        multiply <= 1'b0;
        divide <= 1'b0;
        opa_QNaN <= 1'b0;
        opb_QNaN <= 1'b0;
        opa_SNaN <= 1'b0;
        opb_SNaN <= 1'b0;
        opa_pos_inf <= 1'b0;
        opb_pos_inf <= 1'b0;
        opa_neg_inf <= 1'b0;
        opb_neg_inf <= 1'b0;
        opa_inf <= 1'b0;
        opb_inf <= 1'b0;
        NaN_input <= 1'b0;
        SNaN_input <= 1'b0;
        a_NaN <= 1'b0;
        div_by_0 <= 1'b0;
        div_0_by_0 <= 1'b0;
        div_inf_by_inf <= 1'b0;
        div_by_inf <= 1'b0;
        mul_0_by_inf <= 1'b0;
        mul_inf <= 1'b0;
        div_inf <= 1'b0;
        add_inf <= 1'b0;
        sub_inf <= 1'b0;
        addsub_inf_invalid <= 1'b0;
        addsub_inf <= 1'b0;
        out_inf_trigger <= 1'b0;
        out_pos_inf <= 1'b0;
        out_neg_inf <= 1'b0;
        round_nearest <= 1'b0;
        round_to_zero <= 1'b0;
        round_to_pos_inf <= 1'b0;
        round_to_neg_inf <= 1'b0;
        inf_round_down_trigger <= 1'b0;
        mul_uf <= 1'b0;
        div_uf <= 1'b0;
        underflow_trigger <= 1'b0;
        invalid_trigger <= 1'b0;
        overflow_trigger <= 1'b0;
        inexact_trigger <= 1'b0;
        except_trigger <= 1'b0;
        enable_trigger <= 1'b0;
        NaN_out_trigger <= 1'b0;
        SNaN_trigger <= 1'b0;
        NaN_output_0 <= 63'd0;
        NaN_output <= 63'd0;
        inf_round_down <= 63'd0;
        out_inf <= 63'd0;
        out_0 <= 64'd0;
        out_1 <= 64'd0;
        out_2 <= 64'd0;
        out <= 64'd0;
        ex_enable <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;
    end else if (enable) begin
        in_et_zero <= w_in_et_zero;
        opa_et_zero <= w_opa_et_zero;
        opb_et_zero <= w_opb_et_zero;
        input_et_zero <= w_input_et_zero;
        add <= w_add;
        subtract <= w_subtract;
        multiply <= w_multiply;
        divide <= w_divide;
        opa_QNaN <= w_opa_QNaN;
        opb_QNaN <= w_opb_QNaN;
        opa_SNaN <= w_opa_SNaN;
        opb_SNaN <= w_opb_SNaN;
        opa_pos_inf <= w_opa_pos_inf;
        opb_pos_inf <= w_opb_pos_inf;
        opa_neg_inf <= w_opa_neg_inf;
        opb_neg_inf <= w_opb_neg_inf;
        opa_inf <= w_opa_inf;
        opb_inf <= w_opb_inf;
        NaN_input <= w_NaN_input;
        SNaN_input <= w_SNaN_input;
        a_NaN <= w_a_NaN;
        div_by_0 <= w_div_by_0;
        div_0_by_0 <= w_div_0_by_0;
        div_inf_by_inf <= w_div_inf_by_inf;
        div_by_inf <= w_div_by_inf;
        mul_0_by_inf <= w_mul_0_by_inf;
        mul_inf <= w_mul_inf;
        div_inf <= w_div_inf;
        add_inf <= w_add_inf;
        sub_inf <= w_sub_inf;
        addsub_inf_invalid <= w_addsub_inf_invalid;
        addsub_inf <= w_addsub_inf;
        out_inf_trigger <= w_out_inf_trigger;
        out_pos_inf <= w_out_pos_inf;
        out_neg_inf <= w_out_neg_inf;
        round_nearest <= w_round_nearest;
        round_to_zero <= w_round_to_zero;
        round_to_pos_inf <= w_round_to_pos_inf;
        round_to_neg_inf <= w_round_to_neg_inf;
        inf_round_down_trigger <= w_inf_round_down_trigger;
        mul_uf <= w_mul_uf;
        div_uf <= w_div_uf;
        underflow_trigger <= w_underflow_trigger;
        invalid_trigger <= w_invalid_trigger;
        overflow_trigger <= w_overflow_trigger;
        inexact_trigger <= w_inexact_trigger;
        except_trigger <= w_except_trigger;
        enable_trigger <= w_enable_trigger;
        NaN_out_trigger <= w_NaN_out_trigger;
        SNaN_trigger <= w_SNaN_trigger;
        NaN_output_0 <= w_NaN_output;
        NaN_output <= w_NaN_output;
        inf_round_down <= w_inf_round_down;
        out_inf <= w_out_inf;
        out_0 <= w_out_0;
        out_1 <= w_out_1;
        out_2 <= w_out_2;
        out <= w_out_2;
        ex_enable <= w_enable_trigger;
        underflow <= w_underflow_trigger;
        overflow <= w_overflow_trigger;
        inexact <= w_inexact_trigger;
        exception <= w_except_trigger;
        invalid <= w_invalid_trigger;
    end
end

endmodule
