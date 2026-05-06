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
wire [10:0] exp_2047;
wire [10:0] exp_2046;
reg [62:0] NaN_output_0;
reg [62:0] NaN_output;
wire [51:0] mantissa_max;
reg [62:0] inf_round_down;
reg [62:0] out_inf;
reg [63:0] out_0;
reg [63:0] out_1;
reg [63:0] out_2;

assign exp_2047 = 11'b11111111111;
assign exp_2046 = 11'b11111111110;
assign mantissa_max = 52'hFFFFFFFFFFFFF;

always @(posedge clk) begin
    if (rst) begin
        out = 64'd0;
        ex_enable = 1'b0;
        underflow = 1'b0;
        overflow = 1'b0;
        inexact = 1'b0;
        exception = 1'b0;
        invalid = 1'b0;
        in_et_zero = 1'b0;
        opa_et_zero = 1'b0;
        opb_et_zero = 1'b0;
        input_et_zero = 1'b0;
        add = 1'b0;
        subtract = 1'b0;
        multiply = 1'b0;
        divide = 1'b0;
        opa_QNaN = 1'b0;
        opb_QNaN = 1'b0;
        opa_SNaN = 1'b0;
        opb_SNaN = 1'b0;
        opa_pos_inf = 1'b0;
        opb_pos_inf = 1'b0;
        opa_neg_inf = 1'b0;
        opb_neg_inf = 1'b0;
        opa_inf = 1'b0;
        opb_inf = 1'b0;
        NaN_input = 1'b0;
        SNaN_input = 1'b0;
        a_NaN = 1'b0;
        div_by_0 = 1'b0;
        div_0_by_0 = 1'b0;
        div_inf_by_inf = 1'b0;
        div_by_inf = 1'b0;
        mul_0_by_inf = 1'b0;
        mul_inf = 1'b0;
        div_inf = 1'b0;
        add_inf = 1'b0;
        sub_inf = 1'b0;
        addsub_inf_invalid = 1'b0;
        addsub_inf = 1'b0;
        out_inf_trigger = 1'b0;
        out_pos_inf = 1'b0;
        out_neg_inf = 1'b0;
        round_nearest = 1'b0;
        round_to_zero = 1'b0;
        round_to_pos_inf = 1'b0;
        round_to_neg_inf = 1'b0;
        inf_round_down_trigger = 1'b0;
        mul_uf = 1'b0;
        div_uf = 1'b0;
        underflow_trigger = 1'b0;
        invalid_trigger = 1'b0;
        overflow_trigger = 1'b0;
        inexact_trigger = 1'b0;
        except_trigger = 1'b0;
        enable_trigger = 1'b0;
        NaN_out_trigger = 1'b0;
        SNaN_trigger = 1'b0;
        NaN_output_0 = 63'd0;
        NaN_output = 63'd0;
        inf_round_down = 63'd0;
        out_inf = 63'd0;
        out_0 = 64'd0;
        out_1 = 64'd0;
        out_2 = 64'd0;
    end else if (enable) begin
        in_et_zero = (in_except[62:0] == 63'd0);
        opa_et_zero = (opa[62:0] == 63'd0);
        opb_et_zero = (opb[62:0] == 63'd0);
        input_et_zero = opa_et_zero | opb_et_zero;

        add = (fpu_op == 3'b000);
        subtract = (fpu_op == 3'b001);
        multiply = (fpu_op == 3'b010);
        divide = (fpu_op == 3'b011);

        round_nearest = (rmode == 2'b00);
        round_to_zero = (rmode == 2'b01);
        round_to_pos_inf = (rmode == 2'b10);
        round_to_neg_inf = (rmode == 2'b11);

        opa_QNaN = (opa[62:52] == exp_2047) && (opa[51:0] != 52'd0) && opa[51];
        opb_QNaN = (opb[62:52] == exp_2047) && (opb[51:0] != 52'd0) && opb[51];
        opa_SNaN = (opa[62:52] == exp_2047) && (opa[51:0] != 52'd0) && !opa[51];
        opb_SNaN = (opb[62:52] == exp_2047) && (opb[51:0] != 52'd0) && !opb[51];

        opa_pos_inf = (opa[63] == 1'b0) && (opa[62:52] == exp_2047) && (opa[51:0] == 52'd0);
        opb_pos_inf = (opb[63] == 1'b0) && (opb[62:52] == exp_2047) && (opb[51:0] == 52'd0);
        opa_neg_inf = (opa[63] == 1'b1) && (opa[62:52] == exp_2047) && (opa[51:0] == 52'd0);
        opb_neg_inf = (opb[63] == 1'b1) && (opb[62:52] == exp_2047) && (opb[51:0] == 52'd0);
        opa_inf = opa_pos_inf | opa_neg_inf;
        opb_inf = opb_pos_inf | opb_neg_inf;

        NaN_input = opa_QNaN | opb_QNaN | opa_SNaN | opb_SNaN;
        SNaN_input = opa_SNaN | opb_SNaN;
        a_NaN = opa_QNaN | opa_SNaN;

        div_0_by_0 = divide && !NaN_input && opa_et_zero && opb_et_zero;
        div_inf_by_inf = divide && !NaN_input && opa_inf && opb_inf;
        div_by_0 = divide && !NaN_input && !opa_inf && !opb_inf && !opa_et_zero && opb_et_zero;
        div_by_inf = divide && !NaN_input && !opa_inf && !opa_et_zero && opb_inf;

        mul_0_by_inf = multiply && !NaN_input &&
                       ((opa_et_zero && opb_inf) || (opb_et_zero && opa_inf));
        mul_inf = multiply && !NaN_input && !mul_0_by_inf && (opa_inf || opb_inf);
        div_inf = divide && !NaN_input && !div_0_by_0 && !div_inf_by_inf && opa_inf;

        addsub_inf_invalid = !NaN_input &&
                             ((add && ((opa_pos_inf && opb_neg_inf) ||
                                       (opa_neg_inf && opb_pos_inf))) ||
                              (subtract && ((opa_pos_inf && opb_pos_inf) ||
                                            (opa_neg_inf && opb_neg_inf))));

        add_inf = add && !NaN_input && !addsub_inf_invalid && (opa_inf || opb_inf);
        sub_inf = subtract && !NaN_input && !addsub_inf_invalid && (opa_inf || opb_inf);
        addsub_inf = add_inf || sub_inf;

        out_inf_trigger = addsub_inf || mul_inf || div_inf || div_by_0 ||
                          (exponent_in > {1'b0, exp_2046});
        out_pos_inf = out_inf_trigger && !in_except[63];
        out_neg_inf = out_inf_trigger && in_except[63];

        inf_round_down_trigger = (out_pos_inf && (round_to_zero || round_to_neg_inf)) ||
                                 (out_neg_inf && (round_to_zero || round_to_pos_inf));

        mul_uf = multiply && !NaN_input && !opa_et_zero && !opb_et_zero &&
                 !opa_inf && !opb_inf && in_et_zero;
        div_uf = divide && !NaN_input && !opa_et_zero && !opb_et_zero &&
                 !opa_inf && !opb_inf && in_et_zero;
        underflow_trigger = !NaN_input && (div_by_inf || mul_uf || div_uf);

        SNaN_trigger = SNaN_input;
        invalid_trigger = SNaN_trigger || addsub_inf_invalid || mul_0_by_inf ||
                          div_0_by_0 || div_inf_by_inf;
        overflow_trigger = out_inf_trigger && !NaN_input;
        inexact_trigger = !NaN_input && ((mantissa_in != 2'b00) || out_inf_trigger || underflow_trigger);
        except_trigger = invalid_trigger || overflow_trigger || underflow_trigger || inexact_trigger;
        NaN_out_trigger = NaN_input || invalid_trigger;

        if (NaN_input) begin
            if (a_NaN) begin
                NaN_output_0 = {exp_2047, 1'b1, opa[50:0]};
            end else begin
                NaN_output_0 = {exp_2047, 1'b1, opb[50:0]};
            end
        end else begin
            NaN_output_0 = {exp_2047, 1'b1, opa[50:0]};
        end
        NaN_output = NaN_output_0;

        inf_round_down = {exp_2046, mantissa_max};
        if (inf_round_down_trigger) begin
            out_inf = inf_round_down;
        end else begin
            out_inf = {exp_2047, 52'd0};
        end

        if (underflow_trigger) begin
            out_0 = {in_except[63], 63'd0};
        end else begin
            out_0 = in_except;
        end

        if (out_inf_trigger) begin
            out_1 = {in_except[63], out_inf};
        end else begin
            out_1 = out_0;
        end

        if (NaN_out_trigger) begin
            out_2 = {in_except[63], NaN_output};
        end else begin
            out_2 = out_1;
        end

        enable_trigger = except_trigger || NaN_out_trigger;

        out = out_2;
        ex_enable = enable_trigger;
        underflow = underflow_trigger;
        overflow = overflow_trigger;
        inexact = inexact_trigger;
        exception = except_trigger;
        invalid = invalid_trigger;
    end
end

endmodule
