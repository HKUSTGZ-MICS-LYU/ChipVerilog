`timescale 1ns / 100ps

module fpu_exceptions (
    input clk,
    input rst,
    input enable,
    input [1:0]  rmode,
    input [63:0] opa,
    input [63:0] opb,
    input [63:0] in_except,
    input [11:0] exponent_in,
    input [1:0]  mantissa_in,
    input [2:0]  fpu_op,
    output reg [63:0] out,
    output reg        ex_enable,
    output reg        underflow,
    output reg        overflow,
    output reg        inexact,
    output reg        exception,
    output reg        invalid
);

    //--------------------------------------------------------------------------
    // Constants
    //--------------------------------------------------------------------------
    wire [10:0] exp_2047     = 11'b11111111111;
    wire [10:0] exp_2046     = 11'b11111111110;
    wire [51:0] mantissa_max = 52'hfffffffffffff;

    //--------------------------------------------------------------------------
    // Internal registered flags
    //--------------------------------------------------------------------------
    reg in_et_zero;
    reg opa_et_zero, opb_et_zero, input_et_zero;
    reg add, subtract, multiply, divide;
    reg opa_QNaN, opb_QNaN;
    reg opa_SNaN, opb_SNaN;
    reg opa_pos_inf, opb_pos_inf;
    reg opa_neg_inf, opb_neg_inf;
    reg opa_inf, opb_inf;
    reg NaN_input, SNaN_input;
    reg a_NaN;
    reg div_by_0, div_0_by_0, div_inf_by_inf, div_by_inf;
    reg mul_0_by_inf, mul_inf, div_inf;
    reg add_inf, sub_inf;
    reg addsub_inf_invalid, addsub_inf;
    reg out_inf_trigger, out_pos_inf, out_neg_inf;
    reg round_nearest, round_to_zero, round_to_pos_inf, round_to_neg_inf;
    reg inf_round_down_trigger;
    reg mul_uf, div_uf;
    reg underflow_trigger;
    reg invalid_trigger;
    reg overflow_trigger;
    reg inexact_trigger;
    reg except_trigger;
    reg enable_trigger;
    reg NaN_out_trigger, SNaN_trigger;

    reg [62:0] NaN_output_0;
    reg [62:0] NaN_output;
    reg [62:0] inf_round_down;
    reg [62:0] out_inf;
    reg [63:0] out_0, out_1, out_2;

    //--------------------------------------------------------------------------
    // Stage 1: Decode operands and operation
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            in_et_zero      <= 0; opa_et_zero    <= 0; opb_et_zero     <= 0;
            input_et_zero   <= 0;
            add             <= 0; subtract        <= 0; multiply        <= 0; divide <= 0;
            opa_QNaN        <= 0; opb_QNaN        <= 0;
            opa_SNaN        <= 0; opb_SNaN        <= 0;
            opa_pos_inf     <= 0; opb_pos_inf     <= 0;
            opa_neg_inf     <= 0; opb_neg_inf     <= 0;
            opa_inf         <= 0; opb_inf         <= 0;
            NaN_input       <= 0; SNaN_input      <= 0;
            a_NaN           <= 0;
            round_nearest   <= 0; round_to_zero   <= 0;
            round_to_pos_inf<= 0; round_to_neg_inf<= 0;
            enable_trigger  <= 0;
        end else if (enable) begin
            // Zero detection
            opa_et_zero   <= (opa[62:0] == 63'd0);
            opb_et_zero   <= (opb[62:0] == 63'd0);
            in_et_zero    <= (in_except[62:0] == 63'd0);
            input_et_zero <= (opa[62:0] == 63'd0) | (opb[62:0] == 63'd0);

            // Operation decode
            add      <= (fpu_op == 3'b000);
            subtract <= (fpu_op == 3'b001);
            multiply <= (fpu_op == 3'b010);
            divide   <= (fpu_op == 3'b011);

            // NaN detection
            // QNaN: exp all-ones, frac nonzero, frac[51]=1
            // SNaN: exp all-ones, frac nonzero, frac[51]=0
            opa_QNaN <= (&opa[62:52]) & (|opa[51:0]) &  opa[51];
            opb_QNaN <= (&opb[62:52]) & (|opb[51:0]) &  opb[51];
            opa_SNaN <= (&opa[62:52]) & (|opa[51:0]) & ~opa[51];
            opb_SNaN <= (&opb[62:52]) & (|opb[51:0]) & ~opb[51];

            // Infinity detection
            opa_pos_inf <= (&opa[62:52]) & ~(|opa[51:0]) & ~opa[63];
            opa_neg_inf <= (&opa[62:52]) & ~(|opa[51:0]) &  opa[63];
            opb_pos_inf <= (&opb[62:52]) & ~(|opb[51:0]) & ~opb[63];
            opb_neg_inf <= (&opb[62:52]) & ~(|opb[51:0]) &  opb[63];
            opa_inf     <= (&opa[62:52]) & ~(|opa[51:0]);
            opb_inf     <= (&opb[62:52]) & ~(|opb[51:0]);

            // NaN summary
            NaN_input  <= ((&opa[62:52]) & (|opa[51:0])) |
                          ((&opb[62:52]) & (|opb[51:0]));
            SNaN_input <= ((&opa[62:52]) & (|opa[51:0]) & ~opa[51]) |
                          ((&opb[62:52]) & (|opb[51:0]) & ~opb[51]);
            // Prefer opa NaN; otherwise use opb
            a_NaN <= (&opa[62:52]) & (|opa[51:0]);

            // Rounding mode
            round_nearest    <= (rmode == 2'b00);
            round_to_zero    <= (rmode == 2'b01);
            round_to_pos_inf <= (rmode == 2'b10);
            round_to_neg_inf <= (rmode == 2'b11);

            enable_trigger <= 1'b1;
        end else begin
            enable_trigger <= 1'b0;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 2: Special-case detection
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            div_by_0          <= 0; div_0_by_0       <= 0;
            div_inf_by_inf    <= 0; div_by_inf        <= 0;
            mul_0_by_inf      <= 0; mul_inf           <= 0; div_inf <= 0;
            add_inf           <= 0; sub_inf           <= 0;
            addsub_inf_invalid<= 0; addsub_inf        <= 0;
            out_inf_trigger   <= 0; out_pos_inf       <= 0; out_neg_inf <= 0;
            inf_round_down_trigger <= 0;
            mul_uf            <= 0; div_uf            <= 0;
            underflow_trigger <= 0; invalid_trigger   <= 0;
            overflow_trigger  <= 0; inexact_trigger   <= 0;
            except_trigger    <= 0;
            NaN_out_trigger   <= 0; SNaN_trigger      <= 0;
            NaN_output_0      <= 0; inf_round_down    <= 0;
            out_inf           <= 0; out_0             <= 0;
        end else if (enable_trigger) begin

            //------------------------------------------------------------------
            // Divide special cases
            //------------------------------------------------------------------
            // 0/0
            div_0_by_0     <= divide & opa_et_zero & opb_et_zero;
            // inf/inf
            div_inf_by_inf <= divide & opa_inf & opb_inf;
            // nonzero / 0  (div by zero, not 0/0)
            div_by_0       <= divide & ~opa_et_zero & opb_et_zero;
            // finite / inf
            div_by_inf     <= divide & ~opa_inf & opb_inf;

            //------------------------------------------------------------------
            // Multiply special cases
            //------------------------------------------------------------------
            // 0 * inf
            mul_0_by_inf   <= multiply & ((opa_et_zero & opb_inf) |
                                          (opb_et_zero & opa_inf));
            // inf * anything (non-zero)
            mul_inf        <= multiply & (opa_inf | opb_inf);
            // div any / inf (producing inf result via datapath)
            div_inf        <= divide & opa_inf & ~opb_inf;

            //------------------------------------------------------------------
            // Add/Sub infinity cases
            //------------------------------------------------------------------
            // Add: +inf + -inf or -inf + +inf  → invalid
            // Sub: +inf - +inf or -inf - -inf  → invalid
            add_inf <= add & (opa_inf | opb_inf);
            sub_inf <= subtract & (opa_inf | opb_inf);

            addsub_inf_invalid <=
                (add & ((opa_pos_inf & opb_neg_inf) | (opa_neg_inf & opb_pos_inf))) |
                (subtract & ((opa_pos_inf & opb_pos_inf) | (opa_neg_inf & opb_neg_inf)));

            addsub_inf <=
                ((add | subtract) & (opa_inf | opb_inf)) &
               ~((add & ((opa_pos_inf & opb_neg_inf) | (opa_neg_inf & opb_pos_inf))) |
                 (subtract & ((opa_pos_inf & opb_pos_inf) | (opa_neg_inf & opb_neg_inf))));

            //------------------------------------------------------------------
            // Invalid trigger
            //------------------------------------------------------------------
            invalid_trigger <=
                SNaN_input                              |   // SNaN input
                addsub_inf_invalid                      |   // inf +/- inf invalid combos
                (multiply & ((opa_et_zero & opb_inf) |
                             (opb_et_zero & opa_inf)))  |   // 0 * inf
                (divide & opa_et_zero & opb_et_zero)    |   // 0/0
                (divide & opa_inf & opb_inf);               // inf/inf

            //------------------------------------------------------------------
            // Infinity output trigger
            // Asserted for: valid inf result, div-by-zero, exponent overflow
            //------------------------------------------------------------------
            out_inf_trigger <=
                (addsub_inf & ~addsub_inf_invalid)     |
                (mul_inf & ~mul_0_by_inf)              |
                (div_inf)                              |
                (divide & ~opa_et_zero & opb_et_zero)  |   // div by zero → inf
                (exponent_in > 12'd2046);

            out_pos_inf <= ~in_except[63];
            out_neg_inf <=  in_except[63];

            //------------------------------------------------------------------
            // Infinity round-down: replace inf with max finite
            //------------------------------------------------------------------
            // +inf, rmode=toward_zero or rmode=toward_neg_inf → max pos finite
            // -inf, rmode=toward_zero or rmode=toward_pos_inf → max neg finite
            inf_round_down_trigger <=
                (~in_except[63] & (round_to_zero | round_to_neg_inf)) |
                ( in_except[63] & (round_to_zero | round_to_pos_inf));

            // Precompute round-down replacement value (magnitude only, sign applied later)
            inf_round_down <= {exp_2046, mantissa_max};

            // Precompute infinity magnitude
            out_inf <= {exp_2047, 52'd0};

            //------------------------------------------------------------------
            // Underflow detection
            //------------------------------------------------------------------
            // finite/inf → zero
            div_uf <= divide & ~opa_inf & opb_inf & ~opa_et_zero;
            // nonzero mul → zero candidate
            mul_uf <= multiply & ~opa_et_zero & ~opb_et_zero & in_et_zero;

            underflow_trigger <=
                (divide & ~opa_inf & opb_inf & ~opa_et_zero)        |   // finite/inf
                (multiply & ~opa_et_zero & ~opb_et_zero & in_et_zero)|   // nonzero*x→0
                (divide & ~opa_et_zero & ~opb_et_zero & in_et_zero);    // nonzero/x→0

            //------------------------------------------------------------------
            // NaN output trigger
            //------------------------------------------------------------------
            NaN_out_trigger <=
                NaN_input       |
                invalid_trigger;   // will be updated next cycle; use current

            SNaN_trigger <= SNaN_input;

            //------------------------------------------------------------------
            // NaN output payload construction
            // Prefer opa payload; set quiet bit; use in_except[63] as sign
            //------------------------------------------------------------------
            // NaN_output_0: payload[62:0] without sign
            NaN_output_0 <=
                a_NaN ? {exp_2047, 1'b1, opa[50:0]}   // opa QNaN
                       : ((&opa[62:52]) & (|opa[51:0]))
                         ? {exp_2047, 1'b1, opa[50:0]}
                         : {exp_2047, 1'b1, opb[50:0]};

            //------------------------------------------------------------------
            // Overflow trigger (inf output but no NaN)
            //------------------------------------------------------------------
            overflow_trigger <= out_inf_trigger & ~NaN_input;

            //------------------------------------------------------------------
            // Inexact trigger
            //------------------------------------------------------------------
            inexact_trigger <=
                (|mantissa_in)                         |
                (out_inf_trigger & ~NaN_input)         |
                (underflow_trigger & ~NaN_input);

            //------------------------------------------------------------------
            // Exception summary
            //------------------------------------------------------------------
            except_trigger <=
                invalid_trigger                        |
                overflow_trigger                       |
                underflow_trigger                      |
                (|mantissa_in);

            //------------------------------------------------------------------
            // Stage-0 output selection: underflow → signed zero, else in_except
            //------------------------------------------------------------------
            out_0 <= underflow_trigger ? {in_except[63], 63'd0} : in_except;

        end
    end

    //--------------------------------------------------------------------------
    // Stage 3: Apply infinity / NaN replacement, assemble NaN_output
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            NaN_output <= 0;
            out_1      <= 0;
            out_2      <= 0;
        end else if (enable_trigger) begin

            // Finalize NaN payload (quiet bit forced)
            NaN_output <= NaN_output_0;

            // Apply infinity or round-down-to-max-finite replacement on top of out_0
            if (out_inf_trigger && !NaN_out_trigger) begin
                if (inf_round_down_trigger)
                    out_1 <= {in_except[63], inf_round_down};
                else
                    out_1 <= {in_except[63], out_inf};
            end else begin
                out_1 <= out_0;
            end

        end
    end

    always @(posedge clk) begin
        if (rst) begin
            out_2 <= 0;
        end else if (enable_trigger) begin
            // Apply NaN replacement on top of out_1
            if (NaN_out_trigger)
                out_2 <= {in_except[63], NaN_output};
            else
                out_2 <= out_1;
        end
    end

    //--------------------------------------------------------------------------
    // Output registration
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            out       <= 64'd0;
            ex_enable <= 1'b0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            inexact   <= 1'b0;
            exception <= 1'b0;
            invalid   <= 1'b0;
        end else if (enable_trigger) begin
            out       <= out_2;
            ex_enable <= NaN_out_trigger | out_inf_trigger |
                         underflow_trigger | (|mantissa_in);
            underflow <= underflow_trigger & ~NaN_input;
            overflow  <= overflow_trigger;
            inexact   <= inexact_trigger  & ~NaN_input;
            exception <= except_trigger;
            invalid   <= invalid_trigger;
        end
    end

endmodule