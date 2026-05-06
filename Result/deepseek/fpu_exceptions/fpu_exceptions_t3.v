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

    // Opcodes (from spec)
    localparam ADD = 3'b000;
    localparam SUB = 3'b001;
    localparam MUL = 3'b010;
    localparam DIV = 3'b011;

    // Rounding modes
    localparam ROUND_NEAREST = 2'b00;
    localparam ROUND_TO_ZERO = 2'b01;
    localparam ROUND_TO_POS_INF = 2'b10;
    localparam ROUND_TO_NEG_INF = 2'b11;

    // Constants for double-precision
    wire [10:0] EXP_ALL_ONES = 11'h7FF;
    wire [10:0] EXP_MAX_FINITE = 11'h7FE;
    wire [51:0] MANTISSA_ALL_ONES = 52'hFFFFFFFFFFFFF;

    // Internal signals as per spec
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

    wire [62:0] NaN_output;
    reg [62:0] NaN_output_0;
    wire [62:0] inf_round_down;
    wire [62:0] out_inf;

    // Intermediate output stages (combinational)
    reg [63:0] out_0;
    reg [63:0] out_1;
    reg [63:0] out_2;

    // Combinational decoding and trigger logic
    always @(*) begin
        // Operand decoding
        opa_et_zero = (opa[62:0] == 0);
        opb_et_zero = (opb[62:0] == 0);

        opa_inf = (opa[62:52] == EXP_ALL_ONES) && (opa[51:0] == 0);
        opb_inf = (opb[62:52] == EXP_ALL_ONES) && (opb[51:0] == 0);
        opa_pos_inf = opa_inf && (opa[63] == 0);
        opb_pos_inf = opb_inf && (opb[63] == 0);
        opa_neg_inf = opa_inf && (opa[63] == 1);
        opb_neg_inf = opb_inf && (opb[63] == 1);

        opa_QNaN = (opa[62:52] == EXP_ALL_ONES) && (opa[51] == 1) && (|opa[50:0]);
        opb_QNaN = (opb[62:52] == EXP_ALL_ONES) && (opb[51] == 1) && (|opb[50:0]);
        opa_SNaN = (opa[62:52] == EXP_ALL_ONES) && (opa[51] == 0) && (|opa[50:0]);
        opb_SNaN = (opb[62:52] == EXP_ALL_ONES) && (opb[51] == 0) && (|opb[50:0]);

        NaN_input = opa_QNaN || opb_QNaN || opa_SNaN || opb_SNaN;
        SNaN_input = opa_SNaN || opb_SNaN;
        a_NaN = opa_QNaN || opa_SNaN;

        // Operation decode
        add = (fpu_op == ADD);
        subtract = (fpu_op == SUB);
        multiply = (fpu_op == MUL);
        divide = (fpu_op == DIV);

        // Rounding mode decode
        round_nearest = (rmode == ROUND_NEAREST);
        round_to_zero = (rmode == ROUND_TO_ZERO);
        round_to_pos_inf = (rmode == ROUND_TO_POS_INF);
        round_to_neg_inf = (rmode == ROUND_TO_NEG_INF);

        // Special case detection
        div_by_0 = divide && opb_et_zero && !opa_et_zero && !opa_inf && !NaN_input;
        div_0_by_0 = divide && opa_et_zero && opb_et_zero;
        div_inf_by_inf = divide && opa_inf && opb_inf;
        div_by_inf = divide && opb_inf && !opa_inf && !NaN_input;
        mul_0_by_inf = multiply && ((opa_et_zero && opb_inf) || (opa_inf && opb_et_zero));
        mul_inf = multiply && !mul_0_by_inf && ((opa_inf && !opb_et_zero && !NaN_input) || (opb_inf && !opa_et_zero && !NaN_input));
        div_inf = divide && opa_inf && !opb_inf && !opb_et_zero && !NaN_input;

        // Infinity add/sub invalid combinations: +inf + (-inf), -inf + (+inf), +inf - (+inf), -inf - (-inf)
        addsub_inf_invalid = (add && ((opa_pos_inf && opb_neg_inf) || (opa_neg_inf && opb_pos_inf))) ||
                             (subtract && ((opa_pos_inf && opb_pos_inf) || (opa_neg_inf && opb_neg_inf)));
        addsub_inf = (add || subtract) && (opa_inf || opb_inf) && !addsub_inf_invalid && !NaN_input;

        // Infinity output trigger
        out_inf_trigger = addsub_inf || mul_inf || div_inf || div_by_0 || (exponent_in > 12'd2046);

        // Overflow
        overflow_trigger = out_inf_trigger && !NaN_input;

        // Underflow detection
        // Division by infinity, or multiply/divide yielding zero with nonzero operands (excluding special NaN/inf cases)
        input_et_zero = (in_except[62:0] == 0);
        underflow_trigger = (div_by_inf && !NaN_input) ||
                            (multiply && !opa_et_zero && !opb_et_zero && input_et_zero && !NaN_input && !opa_inf && !opb_inf) ||
                            (divide && !opa_et_zero && !opb_et_zero && !opb_inf && input_et_zero && !NaN_input && !opa_inf);
        // Also include cases where result underflows from normal arithmetic (exponent <= 0) – spec mentions underflow for zero candidate; we rely on in_except being zero.

        // Inexact
        inexact_trigger = (|mantissa_in) || (overflow_trigger && !NaN_input) || (underflow_trigger && !NaN_input);

        // Invalid
        invalid_trigger = SNaN_input || addsub_inf_invalid || mul_0_by_inf || div_0_by_0 || div_inf_by_inf;

        // Exception summary
        except_trigger = invalid_trigger || overflow_trigger || underflow_trigger || inexact_trigger;

        // Enable trigger for ex_enable
        enable_trigger = except_trigger;

        // NaN output trigger
        NaN_out_trigger = NaN_input || SNaN_input || div_0_by_0 || div_inf_by_inf || mul_0_by_inf || addsub_inf_invalid;

        // SNaN trigger
        SNaN_trigger = SNaN_input;

        // Infinity rounding down conditions
        inf_round_down_trigger = out_inf_trigger &&
                                 ((in_except[63]==0 && (round_to_zero || round_to_neg_inf)) ||
                                  (in_except[63]==1 && (round_to_zero || round_to_pos_inf)));

        // NaN output payload
        if (opa_QNaN || opa_SNaN) begin
            NaN_output_0 = {EXP_ALL_ONES, opa[51:0] | 52'h0008000000000000};
        end else if (opb_QNaN || opb_SNaN) begin
            NaN_output_0 = {EXP_ALL_ONES, opb[51:0] | 52'h0008000000000000};
        end else begin
            NaN_output_0 = {EXP_ALL_ONES, opa[51:0] | 52'h0008000000000000};
        end
        // NaN_output is assign from NaN_output_0 (could be combinational)
        // Actually we define NaN_output as wire later.

        // Infinity and max-finite magnitudes
        out_inf = {EXP_ALL_ONES, 52'b0};
        inf_round_down = {EXP_MAX_FINITE, MANTISSA_ALL_ONES};

        // Output selection priority: underflow -> infinity -> NaN
        // Underflow handling
        out_0 = underflow_trigger ? {in_except[63], 63'b0} : in_except;

        // Infinity replacement
        if (out_inf_trigger && !NaN_out_trigger) begin
            if (inf_round_down_trigger)
                out_1 = {in_except[63], inf_round_down};
            else
                out_1 = {in_except[63], out_inf};
        end else begin
            out_1 = out_0;
        end

        // NaN replacement
        if (NaN_out_trigger) begin
            out_2 = {in_except[63], NaN_output_0};
        end else begin
            out_2 = out_1;
        end
    end

    // Wire assignments for constants
    assign NaN_output = NaN_output_0;  // combinational alias

    // Registered outputs
    always @(posedge clk) begin
        if (rst) begin
            out <= 64'b0;
            ex_enable <= 1'b0;
            underflow <= 1'b0;
            overflow <= 1'b0;
            inexact <= 1'b0;
            exception <= 1'b0;
            invalid <= 1'b0;
        end else if (enable) begin
            out <= out_2;
            ex_enable <= enable_trigger;
            underflow <= underflow_trigger && !NaN_input;
            overflow <= overflow_trigger;
            inexact <= inexact_trigger;
            exception <= except_trigger;
            invalid <= invalid_trigger;
        end
    end

endmodule
