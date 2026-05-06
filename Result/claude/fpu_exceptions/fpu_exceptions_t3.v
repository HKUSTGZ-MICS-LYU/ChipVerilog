module fpu_exceptions(
    clk,
    rst,
    enable,
    rmode,
    opa,
    opb,
    in_except,
    exponent_in,
    mantissa_in,
    fpu_op,
    out,
    ex_enable,
    underflow,
    overflow,
    inexact,
    exception,
    invalid
);

    input clk;
    input rst;
    input enable;
    input [1:0] rmode;
    input [63:0] opa;
    input [63:0] opb;
    input [63:0] in_except;
    input [11:0] exponent_in;
    input [1:0] mantissa_in;
    input [2:0] fpu_op;

    output [63:0] out;
    output ex_enable;
    output underflow;
    output overflow;
    output inexact;
    output exception;
    output invalid;

    reg [63:0] out_r;
    reg ex_enable_r;
    reg underflow_r;
    reg overflow_r;
    reg inexact_r;
    reg exception_r;
    reg invalid_r;

    assign out = out_r;
    assign ex_enable = ex_enable_r;
    assign underflow = underflow_r;
    assign overflow = overflow_r;
    assign inexact = inexact_r;
    assign exception = exception_r;
    assign invalid = invalid_r;

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
    wire [51:0] mantissa_max = 52'hFFFFFFFFFFFFF;
    reg [62:0] inf_round_down;
    reg [62:0] out_inf;
    reg [63:0] out_0;
    reg [63:0] out_1;
    reg [63:0] out_2;

    wire opa_sign = opa[63];
    wire opb_sign = opb[63];
    wire in_sign = in_except[63];
    wire [10:0] opa_exp = opa[62:52];
    wire [10:0] opb_exp = opb[62:52];
    wire in_exp_uf = exponent_in[11];
    wire [10:0] exp_in_val = exponent_in[10:0];
    wire [51:0] opa_mantissa = opa[51:0];
    wire [51:0] opb_mantissa = opb[51:0];
    wire [51:0] in_mantissa = in_except[51:0];

    always @(*) begin
        in_et_zero = (in_except[62:0] == 63'b0);
        opa_et_zero = (opa[62:0] == 63'b0);
        opb_et_zero = (opb[62:0] == 63'b0);
        input_et_zero = (opa_et_zero | opb_et_zero);

        add = (fpu_op == 3'b000);
        subtract = (fpu_op == 3'b001);
        multiply = (fpu_op == 3'b010);
        divide = (fpu_op == 3'b011);

        opa_QNaN = (opa_exp == exp_2047) & (opa_mantissa != 52'b0) & ~opa_mantissa[51];
        opb_QNaN = (opb_exp == exp_2047) & (opb_mantissa != 52'b0) & ~opb_mantissa[51];
        opa_SNaN = (opa_exp == exp_2047) & (opa_mantissa != 52'b0) & opa_mantissa[51];
        opb_SNaN = (opb_exp == exp_2047) & (opb_mantissa != 52'b0) & opb_mantissa[51];

        opa_pos_inf = (opa_exp == exp_2047) & (opa_mantissa == 52'b0) & ~opa_sign;
        opb_pos_inf = (opb_exp == exp_2047) & (opb_mantissa == 52'b0) & ~opb_sign;
        opa_neg_inf = (opa_exp == exp_2047) & (opa_mantissa == 52'b0) & opa_sign;
        opb_neg_inf = (opb_exp == exp_2047) & (opb_mantissa == 52'b0) & opb_sign;

        opa_inf = opa_pos_inf | opa_neg_inf;
        opb_inf = opb_pos_inf | opb_neg_inf;

        NaN_input = opa_QNaN | opb_QNaN | opa_SNaN | opb_SNaN;
        SNaN_input = opa_SNaN | opb_SNaN;
        a_NaN = opa_QNaN | opa_SNaN;

        div_by_0 = divide & opb_et_zero;
        div_0_by_0 = divide & opa_et_zero & opb_et_zero;
        div_inf_by_inf = divide & opa_inf & opb_inf;
        div_by_inf = divide & opb_inf & ~opa_inf;
        mul_0_by_inf = multiply & (opa_et_zero & opb_inf) | (opa_inf & opb_et_zero);
        mul_inf = multiply & (opa_inf | opb_inf) & ~mul_0_by_inf;
        div_inf = divide & opa_inf & ~opb_inf;

        add_inf = add & (opa_inf | opb_inf);
        sub_inf = subtract & (opa_inf | opb_inf);
        addsub_inf = add_inf | sub_inf;

        addsub_inf_invalid = (add & opa_pos_inf & opb_neg_inf) |
                             (add & opa_neg_inf & opb_pos_inf) |
                             (subtract & opa_pos_inf & opb_pos_inf) |
                             (subtract & opa_neg_inf & opb_neg_inf);

        out_inf_trigger = div_inf | mul_inf | (addsub_inf & ~addsub_inf_invalid);

        out_pos_inf = (divide & opa_pos_inf) |
                      (divide & opa_neg_inf & opb_neg_inf) |
                      (multiply & (
                          (opa_pos_inf & opb_pos_inf) |
                          (opa_neg_inf & opb_neg_inf)
                      )) |
                      (add & opa_pos_inf & ~opb_neg_inf) |
                      (add & opb_pos_inf & ~opa_neg_inf) |
                      (subtract & opa_pos_inf & ~opb_pos_inf) |
                      (subtract & opb_neg_inf & ~opa_neg_inf);

        out_neg_inf = (divide & opa_neg_inf & opb_pos_inf) |
                      (divide & opa_pos_inf & opb_neg_inf) |
                      (multiply & (
                          (opa_pos_inf & opb_neg_inf) |
                          (opa_neg_inf & opb_pos_inf)
                      )) |
                      (add & opa_neg_inf & ~opb_pos_inf) |
                      (add & opb_neg_inf & ~opa_pos_inf) |
                      (subtract & opa_neg_inf & ~opb_neg_inf) |
                      (subtract & opb_pos_inf & ~opa_pos_inf);

        round_nearest = (rmode == 2'b00);
        round_to_zero = (rmode == 2'b01);
        round_to_pos_inf = (rmode == 2'b10);
        round_to_neg_inf = (rmode == 2'b11);

        inf_round_down_trigger = ((out_pos_inf & (round_to_zero | round_to_neg_inf)) |
                                  (out_neg_inf & (round_to_zero | round_to_pos_inf))) &
                                 out_inf_trigger;

        mul_uf = multiply & in_exp_uf;
        div_uf = divide & in_exp_uf;
        underflow_trigger = (mul_uf | div_uf) & in_et_zero;

        invalid_trigger = SNaN_input | mul_0_by_inf | div_0_by_0 | div_inf_by_inf | addsub_inf_invalid;

        overflow_trigger = (exp_in_val == exp_2047) & ~underflow_trigger;

        inexact_trigger = (mantissa_in != 2'b00) | overflow_trigger | underflow_trigger;

        NaN_out_trigger = NaN_input | invalid_trigger;
        SNaN_trigger = SNaN_input;
        except_trigger = NaN_out_trigger | overflow_trigger | underflow_trigger | invalid_trigger;
        enable_trigger = enable;
    end

    always @(*) begin
        if (inf_round_down_trigger) begin
            if (out_pos_inf) begin
                NaN_output_0 = {1'b0, exp_2046, mantissa_max};
            end else begin
                NaN_output_0 = {1'b1, exp_2046, mantissa_max};
            end
            out_inf = 63'b0;
        end else if (out_inf_trigger) begin
            if (out_pos_inf) begin
                NaN_output_0 = 63'b0;
                out_inf = {1'b0, exp_2047, 52'b0};
            end else begin
                NaN_output_0 = 63'b0;
                out_inf = {1'b1, exp_2047, 52'b0};
            end
        end else if (underflow_trigger) begin
            NaN_output_0 = 63'b0;
            out_inf = {in_sign, 11'b0, 52'b0};
        end else if (NaN_out_trigger) begin
            if (a_NaN) begin
                NaN_output_0 = {opa_sign, exp_2047, 1'b1, 51'b0};
            end else begin
                NaN_output_0 = {opb_sign, exp_2047, 1'b1, 51'b0};
            end
            out_inf = 63'b0;
        end else begin
            NaN_output_0 = 63'b0;
            out_inf = 63'b0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_r <= 64'b0;
            ex_enable_r <= 1'b0;
            underflow_r <= 1'b0;
            overflow_r <= 1'b0;
            inexact_r <= 1'b0;
            exception_r <= 1'b0;
            invalid_r <= 1'b0;
        end else if (enable) begin
            out_r <= out_2;
            ex_enable_r <= (NaN_out_trigger | out_inf_trigger | underflow_trigger);
            underflow_r <= underflow_trigger;
            overflow_r <= overflow_trigger;
            inexact_r <= inexact_trigger;
            exception_r <= except_trigger;
            invalid_r <= invalid_trigger;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_0 <= 64'b0;
            out_1 <= 64'b0;
            out_2 <= 64'b0;
        end else if (enable) begin
            if (NaN_out_trigger | inf_round_down_trigger) begin
                out_0 <= {in_sign, NaN_output_0};
            end else if (out_inf_trigger) begin
                out_0 <= out_inf;
            end else if (underflow_trigger) begin
                out_0 <= out_inf;
            end else begin
                out_0 <= in_except;
            end
            out_1 <= out_0;
            out_2 <= out_1;
        end
    end

endmodule
