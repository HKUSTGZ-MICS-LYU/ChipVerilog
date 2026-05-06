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
reg [62:0] NaN_output_0;
reg [62:0] NaN_output;
reg [62:0] inf_round_down;
reg [62:0] out_inf;
reg [63:0] out_0;
reg [63:0] out_1;
reg [63:0] out_2;

wire [10:0] exp_2047;
wire [10:0] exp_2046;
wire [51:0] mantissa_max;

assign exp_2047 = 11'b11111111111;
assign exp_2046 = 11'b11111111110;
assign mantissa_max = 52'b1111111111111111111111111111111111111111111111111111;

always @(posedge clk) begin
    if (rst) begin
        out <= 64'd0;
        ex_enable <= 1'b0;
        underflow <= 1'b0;
        overflow <= 1'b0;
        inexact <= 1'b0;
        exception <= 1'b0;
        invalid <= 1'b0;

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
    end else if (enable) begin
        in_et_zero = !(|in_except[62:0]);
        opa_et_zero = !(|opa[62:0]);
        opb_et_zero = !(|opb[62:0]);
        input_et_zero = opa_et_zero | opb_et_zero;

        add = (fpu_op == 3'b000);
        subtract = (fpu_op == 3'b001);
        multiply = (fpu_op == 3'b010);
        divide = (fpu_op == 3'b011);

        opa_QNaN = (opa[62:52] == exp_2047) & (|opa[51:0]) & opa[51];
        opb_QNaN = (opb[62:52] == exp_2047) & (|opb[51:0]) & opb[51];
        opa_SNaN = (opa[62:52] == exp_2047) & (|opa[51:0]) & !opa[51];
        opb_SNaN = (opb[62:52] == exp_2047) & (|opb[51:0]) & !opb[51];

        opa_pos_inf = !opa[63] & (opa[62:52] == exp_2047) & !(|opa[51:0]);
        opb_pos_inf = !opb[63] & (opb[62:52] == exp_2047) & !(|opb[51:0]);
        opa_neg_inf = opa[63] & (opa[62:52] == exp_2047) & !(|opa[51:0]);
        opb_neg_inf = opb[63] & (opb[62:52] == exp_2047) & !(|opb[51:0]);
        opa_inf = opa_pos_inf | opa_neg_inf;
        opb_inf = opb_pos_inf | opb_neg_inf;

        NaN_input = opa_QNaN | opb_QNaN | opa_SNaN | opb_SNaN;
        SNaN_input = opa_SNaN | opb_SNaN;
        a_NaN = opa_QNaN | opa_SNaN;

        div_by_0 = divide & opb_et_zero & !opa_et_zero;
        div_0_by_0 = divide & opa_et_zero & opb_et_zero;
        div_inf_by_inf = divide & opa_inf & opb_inf;
        div_by_inf = divide & !opa_inf & opb_inf;
        mul_0_by_inf = multiply & ((opa_inf & opb_et_zero) | (opa_et_zero & opb_inf));
        mul_inf = multiply & (opa_inf | opb_inf) & !mul_0_by_inf;
        div_inf = divide & opa_inf & !opb_inf;
        add_inf = add & (opa_inf | opb_inf);
        sub_inf = subtract & (opa_inf | opb_inf);

        addsub_inf_invalid =
            (add & ((opa_pos_inf & opb_neg_inf) | (opa_neg_inf & opb_pos_inf))) |
            (subtract & ((opa_pos_inf & opb_pos_inf) | (opa_neg_inf & opb_neg_inf)));
        addsub_inf = (add_inf | sub_inf) & !addsub_inf_invalid;

        out_inf_trigger =
            addsub_inf |
            mul_inf |
            div_inf |
            div_by_0 |
            (exponent_in > {1'b0, exp_2046});

        out_pos_inf = out_inf_trigger & !in_except[63];
        out_neg_inf = out_inf_trigger & in_except[63];

        round_nearest = (rmode == 2'b00);
        round_to_zero = (rmode == 2'b01);
        round_to_pos_inf = (rmode == 2'b10);
        round_to_neg_inf = (rmode == 2'b11);

        inf_round_down_trigger =
            out_inf_trigger &
            (round_to_zero |
             (out_pos_inf & round_to_neg_inf) |
             (out_neg_inf & round_to_pos_inf));

        mul_uf = multiply & !opa_et_zero & !opb_et_zero & in_et_zero;
        div_uf = divide & !opa_et_zero & in_et_zero;
        underflow_trigger = div_by_inf | mul_uf | div_uf;

        invalid_trigger =
            SNaN_input |
            addsub_inf_invalid |
            mul_0_by_inf |
            div_0_by_0 |
            div_inf_by_inf;

        overflow_trigger = out_inf_trigger & !NaN_input;
        inexact_trigger = ((|mantissa_in) | out_inf_trigger | underflow_trigger) & !NaN_input;
        except_trigger = invalid_trigger | overflow_trigger | underflow_trigger | inexact_trigger;
        enable_trigger = except_trigger | out_inf_trigger | NaN_input;
        NaN_out_trigger = NaN_input | invalid_trigger;
        SNaN_trigger = invalid_trigger & !SNaN_input;

        NaN_output_0 = a_NaN ? {exp_2047, 1'b1, opa[50:0]} : {exp_2047, 1'b1, opb[50:0]};
        NaN_output = SNaN_trigger ? {exp_2047, 2'b01, opa[49:0]} : NaN_output_0;

        inf_round_down = {exp_2046, mantissa_max};
        out_inf = inf_round_down_trigger ? inf_round_down : {exp_2047, 52'd0};

        out_0 = underflow_trigger ? {in_except[63], 63'd0} : in_except;
        out_1 = out_inf_trigger ? {in_except[63], out_inf} : out_0;
        out_2 = NaN_out_trigger ? {in_except[63], NaN_output} : out_1;

        in_et_zero <= in_et_zero;
        opa_et_zero <= opa_et_zero;
        opb_et_zero <= opb_et_zero;
        input_et_zero <= input_et_zero;
        add <= add;
        subtract <= subtract;
        multiply <= multiply;
        divide <= divide;
        opa_QNaN <= opa_QNaN;
        opb_QNaN <= opb_QNaN;
        opa_SNaN <= opa_SNaN;
        opb_SNaN <= opb_SNaN;
        opa_pos_inf <= opa_pos_inf;
        opb_pos_inf <= opb_pos_inf;
        opa_neg_inf <= opa_neg_inf;
        opb_neg_inf <= opb_neg_inf;
        opa_inf <= opa_inf;
        opb_inf <= opb_inf;
        NaN_input <= NaN_input;
        SNaN_input <= SNaN_input;
        a_NaN <= a_NaN;
        div_by_0 <= div_by_0;
        div_0_by_0 <= div_0_by_0;
        div_inf_by_inf <= div_inf_by_inf;
        div_by_inf <= div_by_inf;
        mul_0_by_inf <= mul_0_by_inf;
        mul_inf <= mul_inf;
        div_inf <= div_inf;
        add_inf <= add_inf;
        sub_inf <= sub_inf;
        addsub_inf_invalid <= addsub_inf_invalid;
        addsub_inf <= addsub_inf;
        out_inf_trigger <= out_inf_trigger;
        out_pos_inf <= out_pos_inf;
        out_neg_inf <= out_neg_inf;
        round_nearest <= round_nearest;
        round_to_zero <= round_to_zero;
        round_to_pos_inf <= round_to_pos_inf;
        round_to_neg_inf <= round_to_neg_inf;
        inf_round_down_trigger <= inf_round_down_trigger;
        mul_uf <= mul_uf;
        div_uf <= div_uf;
        underflow_trigger <= underflow_trigger;
        invalid_trigger <= invalid_trigger;
        overflow_trigger <= overflow_trigger;
        inexact_trigger <= inexact_trigger;
        except_trigger <= except_trigger;
        enable_trigger <= enable_trigger;
        NaN_out_trigger <= NaN_out_trigger;
        SNaN_trigger <= SNaN_trigger;
        NaN_output_0 <= NaN_output_0;
        NaN_output <= NaN_output;
        inf_round_down <= inf_round_down;
        out_inf <= out_inf;
        out_0 <= out_0;
        out_1 <= out_1;
        out_2 <= out_2;

        out <= out_2;
        ex_enable <= enable_trigger;
        underflow <= underflow_trigger;
        overflow <= overflow_trigger;
        inexact <= inexact_trigger;
        exception <= except_trigger;
        invalid <= invalid_trigger;
    end
end

endmodule
