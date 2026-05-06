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

    // Internal wires for operand fields
    wire [10:0] exp_a = opa[62:52];
    wire [10:0] exp_b = opb[62:52];
    wire [51:0] frac_a = opa[51:0];
    wire [51:0] frac_b = opb[51:0];
    wire sign_a = opa[63];
    wire sign_b = opb[63];

    // Constants
    wire [10:0] exp_2047 = 11'b11111111111;
    wire [10:0] exp_2046 = 11'b11111111110;
    wire [51:0] mantissa_max = 52'b1111111111111111111111111111111111111111111111111111;

    // Internal registers
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

    // Next state variables (computed combinationally)
    reg next_in_et_zero;
    reg next_opa_et_zero;
    reg next_opb_et_zero;
    reg next_input_et_zero;
    reg next_add;
    reg next_subtract;
    reg next_multiply;
    reg next_divide;
    reg next_opa_QNaN;
    reg next_opb_QNaN;
    reg next_opa_SNaN;
    reg next_opb_SNaN;
    reg next_opa_pos_inf;
    reg next_opb_pos_inf;
    reg next_opa_neg_inf;
    reg next_opb_neg_inf;
    reg next_opa_inf;
    reg next_opb_inf;
    reg next_NaN_input;
    reg next_SNaN_input;
    reg next_a_NaN;
    reg next_div_by_0;
    reg next_div_0_by_0;
    reg next_div_inf_by_inf;
    reg next_div_by_inf;
    reg next_mul_0_by_inf;
    reg next_mul_inf;
    reg next_div_inf;
    reg next_add_inf;
    reg next_sub_inf;
    reg next_addsub_inf_invalid;
    reg next_addsub_inf;
    reg next_out_inf_trigger;
    reg next_out_pos_inf;
    reg next_out_neg_inf;
    reg next_inf_round_down_trigger;
    reg next_mul_uf;
    reg next_div_uf;
    reg next_underflow_trigger;
    reg next_invalid_trigger;
    reg next_overflow_trigger;
    reg next_inexact_trigger;
    reg next_except_trigger;
    reg next_enable_trigger;
    reg next_NaN_out_trigger;
    reg next_SNaN_trigger;
    reg [62:0] next_NaN_output_0;
    reg [62:0] next_NaN_output;
    reg [62:0] next_inf_round_down;
    reg [62:0] next_out_inf;
    reg [63:0] next_out_0;
    reg [63:0] next_out_1;
    reg [63:0] next_out_2;
    reg [63:0] next_out;
    reg next_ex_enable;
    reg next_underflow;
    reg next_overflow;
    reg next_inexact;
    reg next_exception;
    reg next_invalid;

    // Combinational logic: decode operands
    always @(*) begin
        // Defaults
        next_in_et_zero = (in_except[62:0] == 63'b0);
        next_opa_et_zero = (opa[62:0] == 63'b0);
        next_opb_et_zero = (opb[62:0] == 63'b0);
        next_opb_et_zero = (opb[62:0] == 63'b0);
        next_opa_QNaN = (exp_a == exp_2047) && (frac_a != 52'b0) && (frac_a[51] == 1'b1);
        next_opb_QNaN = (exp_b == exp_2047) && (frac_b != 52'b0) && (frac_b[51] == 1'b1);
        next_opa_SNaN = (exp_a == exp_2047) && (frac_a != 52'b0) && (frac_a[51] == 1'b0);
        next_opb_SNaN = (exp_b == exp_2047) && (frac_b != 52'b0) && (frac_b[51] == 1'b0);
        next_opa_pos_inf = (exp_a == exp_2047) && (frac_a == 52'b0) && (sign_a == 1'b0);
        next_opb_pos_inf = (exp_b == exp_2047) && (frac_b == 52'b0) && (sign_b == 1'b0);
        next_opa_neg_inf = (exp_a == exp_2047) && (frac_a == 52'b0) && (sign_a == 1'b1);
        next_opb_neg_inf = (exp_b == exp_2047) && (frac_b == 52'b0) && (sign_b == 1'b1);
        next_opa_inf = (exp_a == exp_2047) && (frac_a == 52'b0);
        next_opb_inf = (exp_b == exp_2047) && (frac_b == 52'b0);

        // Decode operation
        next_add = (fpu_op == 3'b000);
        next_subtract = (fpu_op == 3'b001);
        next_multiply = (fpu_op == 3'b010);
        next_divide = (fpu_op == 3'b011);

        // NaN and SNaN detection
        next_NaN_input = (next_opa_QNaN || next_opb_QNaN || next_opa_SNaN || next_opb_SNaN);
        next_SNaN_input = (next_opa_SNaN || next_opb_SNaN);
        next_a_NaN = next_opa_QNaN || next_opa_SNaN;

        // Divide by zero
        next_div_by_0 = next_divide && next_opb_et_zero && !next_opa_et_zero;
        next_div_0_by_0 = next_divide && next_opa_et_zero && next_opb_et_zero;
        next_div_inf_by_inf = next_divide && next_opa_inf && next_opb_inf;
        next_div_by_inf = next_divide && !next_opa_inf && next_opb_inf;
        next_mul_0_by_inf = next_multiply && ((next_opa_et_zero && next_opb_inf) || (next_opa_inf && next_opb_et_zero));
        next_mul_inf = next_multiply && (next_opa_inf || next_opb_inf) && !next_mul_0_by_inf;
        next_div_inf = next_divide && (next_opa_inf || next_opb_inf) && !next_div_inf_by_inf && !next_div_by_inf;
        // For add/subtract, infinity combinations
        next_add_inf = next_add && (next_opa_inf || next_opb_inf);
        next_sub_inf = next_subtract && (next_opa_inf || next_opb_inf);
        next_addsub_inf_invalid = 0;
        if (next_add) begin
            if (next_opa_pos_inf && next_opb_neg_inf) next_addsub_inf_invalid = 1;
            if (next_opa_neg_inf && next_opb_pos_inf) next_addsub_inf_invalid = 1;
        end
        if (next_subtract) begin
            if (next_opa_pos_inf && next_opb_pos_inf) next_addsub_inf_invalid = 1;
            if (next_opa_neg_inf && next_opb_neg_inf) next_addsub_inf_invalid = 1;
        end
        next_addsub_inf = (next_add_inf || next_sub_inf) && !next_addsub_inf_invalid;

        // Invalid trigger
        next_invalid_trigger = next_SNaN_input || next_div_0_by_0 || next_div_inf_by_inf || next_mul_0_by_inf || next_addsub_inf_invalid;

        // Overflow trigger: when exponent_in > 2046 or infinity-producing operations (excluding NaN input)
        next_out_inf_trigger = (exponent_in > 11'd2046) || next_div_by_0 || next_mul_inf || next_div_inf || next_addsub_inf;
        // But not if NaN input (should be handled by NaN later)
        // Actually NaN input will produce NaN, so overflow trigger should be suppressed if NaN input.
        // But we'll let NaN override later.

        // Determine sign for infinity result from in_except sign
        next_out_pos_inf = next_out_inf_trigger && !next_NaN_input && (in_except[63] == 1'b0);
        next_out_neg_inf = next_out_inf_trigger && !next_NaN_input && (in_except[63] == 1'b1);

        // Rounding mode decoding
        next_round_nearest = (rmode == 2'b00);
        next_round_to_zero = (rmode == 2'b01);
        next_round_to_pos_inf = (rmode == 2'b10);
        next_round_to_neg_inf = (rmode == 2'b11);

        // Infinity round down trigger
        next_inf_round_down_trigger = 0;
        if (next_out_pos_inf && (next_round_to_zero || next_round_to_neg_inf)) next_inf_round_down_trigger = 1;
        if (next_out_neg_inf && (next_round_to_zero || next_round_to_pos_inf)) next_inf_round_down_trigger = 1;

        // Underflow detection
        next_mul_uf = next_multiply && (in_except[62:0] == 63'b0) && !next_opa_et_zero && !next_opb_et_zero;
        next_div_uf = next_divide && (in_except[62:0] == 63'b0) && !next_opa_et_zero && !next_opb_et_zero;
        next_underflow_trigger = next_div_by_inf || next_mul_uf || next_div_uf;

        // Underflow sign from in_except[63]
        // And underflow produces zero

        // Inexact trigger
        next_inexact_trigger = (|mantissa_in) || (next_out_inf_trigger && !next_NaN_input) || (next_underflow_trigger && !next_NaN_input);

        // Overflow trigger for flag:
        next_overflow_trigger = next_out_inf_trigger && !next_NaN_input;

        // Exception trigger
        next_except_trigger = next_invalid_trigger || next_overflow_trigger || next_underflow_trigger || next_inexact_trigger;

        // Enable trigger (ex_enable) - we set it to except_trigger per spec interpretation
        next_enable_trigger = next_except_trigger;

        // NaN output generation
        // If input NaN, use payload from that operand, with quiet bit set.
        // If invalid operation, generate NaN from opa payload.
        next_NaN_output_0 = 63'b0;
        if (next_NaN_input) begin
            // Prefer opa if a is NaN; else opb
            if (next_a_NaN) begin
                // Set quiet bit
                next_NaN_output_0[51] = 1'b1;
                // Keep other fraction bits from opa
                next_NaN_output_0[50:0] = frac_a[50:0];
                next_NaN_output_0[62:52] = exp_2047;
            end else begin
                next_NaN_output_0[51] = 1'b1;
                next_NaN_output_0[50:0] = frac_b[50:0];
                next_NaN_output_0[62:52] = exp_2047;
            end
        end else if (next_invalid_trigger || next_div_0_by_0 || next_div_inf_by_inf || next_mul_0_by_inf || next_addsub_inf_invalid || next_SNaN_input) begin
            // For generated NaN (invalid operations not from input NaN), use opa fraction with quiet bit set
            next_NaN_output_0[51] = 1'b1;
            next_NaN_output_0[50:0] = frac_a[50:0];
            next_NaN_output_0[62:52] = exp_2047;
        end

        next_NaN_output = next_NaN_output_0;

        // NaN output trigger (should be set when a NaN output is produced)
        next_NaN_out_trigger = next_NaN_input || (next_invalid_trigger && !next_NaN_input) || next_SNaN_input;
        // Also include any invalid operation that produces NaN
        if (next_div_0_by_0 || next_div_inf_by_inf || next_mul_0_by_inf || next_addsub_inf_invalid) next_NaN_out_trigger = 1;

        // Build intermediate outputs
        // out_0: select normal or underflow zero
        if (next_underflow_trigger && !next_NaN_input) begin
            next_out_0 = {in_except[63], 63'b0};
        end else begin
            next_out_0 = in_except;
        end

        // out_1: apply infinity or max finite
        if (next_out_inf_trigger && !next_NaN_input && !next_underflow_trigger) begin
            if (next_inf_round_down_trigger) begin
                // Largest finite number
                next_out_1 = {in_except[63], exp_2046, mantissa_max};
            end else begin
                // Infinity
                next_out_1 = {in_except[63], exp_2047, 52'b0};
            end
        end else begin
            next_out_1 = next_out_0;
        end

        // out_2: apply NaN
        if (next_NaN_out_trigger) begin
            next_out_2 = {in_except[63], next_NaN_output};
        end else begin
            next_out_2 = next_out_1;
        end

        // Final output
        next_out = next_out_2;
        next_ex_enable = next_enable_trigger;
        next_underflow = next_underflow_trigger;
        next_overflow = next_overflow_trigger;
        next_inexact = next_inexact_trigger;
        next_exception = next_except_trigger;
        next_invalid = next_invalid_trigger;
    end

    // Sequential logic
    always @(posedge clk) begin
        if (rst) begin
            in_et_zero <= 0;
            opa_et_zero <= 0;
            opb_et_zero <= 0;
            input_et_zero <= 0;
            add <= 0;
            subtract <= 0;
            multiply <= 0;
            divide <= 0;
            opa_QNaN <= 0;
            opb_QNaN <= 0;
            opa_SNaN <= 0;
            opb_SNaN <= 0;
            opa_pos_inf <= 0;
            opb_pos_inf <= 0;
            opa_neg_inf <= 0;
            opb_neg_inf <= 0;
            opa_inf <= 0;
            opb_inf <= 0;
            NaN_input <= 0;
            SNaN_input <= 0;
            a_NaN <= 0;
            div_by_0 <= 0;
            div_0_by_0 <= 0;
            div_inf_by_inf <= 0;
            div_by_inf <= 0;
            mul_0_by_inf <= 0;
            mul_inf <= 0;
            div_inf <= 0;
            add_inf <= 0;
            sub_inf <= 0;
            addsub_inf_invalid <= 0;
            addsub_inf <= 0;
            out_inf_trigger <= 0;
            out_pos_inf <= 0;
            out_neg_inf <= 0;
            round_nearest <= 0;
            round_to_zero <= 0;
            round_to_pos_inf <= 0;
            round_to_neg_inf <= 0;
            inf_round_down_trigger <= 0;
            mul_uf <= 0;
            div_uf <= 0;
            underflow_trigger <= 0;
            invalid_trigger <= 0;
            overflow_trigger <= 0;
            inexact_trigger <= 0;
            except_trigger <= 0;
            enable_trigger <= 0;
            NaN_out_trigger <= 0;
            SNaN_trigger <= 0;
            NaN_output_0 <= 0;
            NaN_output <= 0;
            inf_round_down <= 0;
            out_inf <= 0;
            out_0 <= 0;
            out_1 <= 0;
            out_2 <= 0;
            out <= 0;
            ex_enable <= 0;
            underflow <= 0;
            overflow <= 0;
            inexact <= 0;
            exception <= 0;
            invalid <= 0;
        end else if (enable) begin
            in_et_zero <= next_in_et_zero;
            opa_et_zero <= next_opa_et_zero;
            opb_et_zero <= next_opb_et_zero;
            input_et_zero <= next_input_et_zero;
            add <= next_add;
            subtract <= next_subtract;
            multiply <= next_multiply;
            divide <= next_divide;
            opa_QNaN <= next_opa_QNaN;
            opb_QNaN <= next_opb_QNaN;
            opa_SNaN <= next_opa_SNaN;
            opb_SNaN <= next_opb_SNaN;
            opa_pos_inf <= next_opa_pos_inf;
            opb_pos_inf <= next_opb_pos_inf;
            opa_neg_inf <= next_opa_neg_inf;
            opb_neg_inf <= next_opb_neg_inf;
            opa_inf <= next_opa_inf;
            opb_inf <= next_opb_inf;
            NaN_input <= next_NaN_input;
            SNaN_input <= next_SNaN_input;
            a_NaN <= next_a_NaN;
            div_by_0 <= next_div_by_0;
            div_0_by_0 <= next_div_0_by_0;
            div_inf_by_inf <= next_div_inf_by_inf;
            div_by_inf <= next_div_by_inf;
            mul_0_by_inf <= next_mul_0_by_inf;
            mul_inf <= next_mul_inf;
            div_inf <= next_div_inf;
            add_inf <= next_add_inf;
            sub_inf <= next_sub_inf;
            addsub_inf_invalid <= next_addsub_inf_invalid;
            addsub_inf <= next_addsub_inf;
            out_inf_trigger <= next_out_inf_trigger;
            out_pos_inf <= next_out_pos_inf;
            out_neg_inf <= next_out_neg_inf;
            round_nearest <= next_round_nearest;
            round_to_zero <= next_round_to_zero;
            round_to_pos_inf <= next_round_to_pos_inf;
            round_to_neg_inf <= next_round_to_neg_inf;
            inf_round_down_trigger <= next_inf_round_down_trigger;
            mul_uf <= next_mul_uf;
            div_uf <= next_div_uf;
            underflow_trigger <= next_underflow_trigger;
            invalid_trigger <= next_invalid_trigger;
            overflow_trigger <= next_overflow_trigger;
            inexact_trigger <= next_inexact_trigger;
            except_trigger <= next_except_trigger;
            enable_trigger <= next_enable_trigger;
            NaN_out_trigger <= next_NaN_out_trigger;
            SNaN_trigger <= next_SNaN_trigger;
            NaN_output_0 <= next_NaN_output_0;
            NaN_output <= next_NaN_output;
            inf_round_down <= next_inf_round_down;
            out_inf <= next_out_inf;
            out_0 <= next_out_0;
            out_1 <= next_out_1;
            out_2 <= next_out_2;
            out <= next_out;
            ex_enable <= next_ex_enable;
            underflow <= next_underflow;
            overflow <= next_overflow;
            inexact <= next_inexact;
            exception <= next_exception;
            invalid <= next_invalid;
        end
    end

endmodule
