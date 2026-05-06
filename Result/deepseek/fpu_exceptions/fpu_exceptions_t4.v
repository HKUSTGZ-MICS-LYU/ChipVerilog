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

    // rounding mode constants
    localparam RNE = 2'b00;
    localparam RTZ = 2'b01;
    localparam RTP = 2'b10;
    localparam RTN = 2'b11;


    // ---------- operand decoding (combinational) ----------
    reg opa_et_zero, opb_et_zero;
    reg opa_pos_inf, opa_neg_inf, opa_inf;
    reg opb_pos_inf, opb_neg_inf, opb_inf;
    reg opa_QNaN, opb_QNaN, opa_SNaN, opb_SNaN;
    reg NaN_input, SNaN_input;
    reg add, subtract, multiply, divide;
    reg div_by_0, div_0_by_0, div_inf_by_inf, div_by_inf;
    reg mul_0_by_inf, mul_inf;
    reg addsub_inf, addsub_inf_invalid;
    reg in_except_zero;

    always @* begin
        // zero detection
        opa_et_zero = (opa[62:0] == 63'b0);
        opb_et_zero = (opb[62:0] == 63'b0);

        // exponent and mantissa
        // operands are 64-bit double: sign bit[63], exponent[62:52], mantissa[51:0]
        // infinity: exponent == 11'b11111111111 && mantissa == 52'b0
        // NaN: exponent == 11'b11111111111 && mantissa != 52'b0
        // quiet NaN: mantissa[51] == 1
        // signaling NaN: mantissa[51] == 0

        // operand A
        opa_inf  = (opa[62:52] == 11'b11111111111) && (opa[51:0] == 52'b0);
        opa_pos_inf = opa_inf && (opa[63] == 1'b0);
        opa_neg_inf = opa_inf && (opa[63] == 1'b1);
        opa_QNaN = (opa[62:52] == 11'b11111111111) && (opa[51:0] != 52'b0) && (opa[51] == 1'b1);
        opa_SNaN = (opa[62:52] == 11'b11111111111) && (opa[51:0] != 52'b0) && (opa[51] == 1'b0);

        // operand B
        opb_inf  = (opb[62:52] == 11'b11111111111) && (opb[51:0] == 52'b0);
        opb_pos_inf = opb_inf && (opb[63] == 1'b0);
        opb_neg_inf = opb_inf && (opb[63] == 1'b1);
        opb_QNaN = (opb[62:52] == 11'b11111111111) && (opb[51:0] != 52'b0) && (opb[51] == 1'b1);
        opb_SNaN = (opb[62:52] == 11'b11111111111) && (opb[51:0] != 52'b0) && (opb[51] == 1'b0);

        // aggregated NaN flags
        NaN_input = opa_QNaN | opa_SNaN | opb_QNaN | opb_SNaN;
        SNaN_input = opa_SNaN | opb_SNaN;

        // operation decode
        add      = (fpu_op == 3'b000);
        subtract = (fpu_op == 3'b001);
        multiply = (fpu_op == 3'b010);
        divide   = (fpu_op == 3'b011);

        // in_except zero detection
        in_except_zero = (in_except[62:0] == 63'b0);

        // effective sign for add/sub (after subtraction inversion)
        wire effective_opb_sign = subtract ? ~opb[63] : opb[63];

        // add/sub infinity invalid: both inf and effective signs differ
        addsub_inf_invalid = (add || subtract) && opa_inf && opb_inf && (opa[63] ^ effective_opb_sign);

        // add/sub valid infinity: exactly one operand is infinity (XOR)
        addsub_inf = (add || subtract) && (opa_inf ^ opb_inf);

        // multiply 0 * inf
        mul_0_by_inf = multiply && ((opa_et_zero && opb_inf) || (opa_inf && opb_et_zero));

        // multiply infinity (valid, excludes 0*inf)
        mul_inf = multiply && ((opa_inf && !opb_et_zero) || (opb_inf && !opa_et_zero)) && !mul_0_by_inf;

        // division special cases
        div_by_0      = divide && opb_et_zero && !opa_et_zero;  // nonzero or inf / 0
        div_0_by_0    = divide && opa_et_zero && opb_et_zero;
        div_inf_by_inf = divide && opa_inf && opb_inf;
        div_by_inf    = divide && !opa_et_zero && !opa_inf && opb_inf;  // finite nonzero / inf
        // div_inf for valid infinity from division (inf/finite or finite/0 or inf/0)
        // include div_by_0 and opa_inf & !opb_inf (inf/finite)
        wire div_inf_valid = (div_by_0) || (divide && opa_inf && !opb_inf);
    end


    // ---------- trigger signals (combinational) ----------
    reg overflow_trigger, underflow_trigger, invalid_trigger, inexact_trigger;
    reg out_inf_trigger, NaN_out_trigger;
    reg [63:0] out_stage1, out_stage2, out_final;
    reg [51:0] nan_payload;
    reg ex_enable_comb;

    always @* begin
        // clock gating not needed – all combinational

        // invalid trigger (sets invalid flag and forces NaN output)
        invalid_trigger = SNaN_input || addsub_inf_invalid || mul_0_by_inf || div_0_by_0 || div_inf_by_inf;

        // infinity output trigger: valid infinity from operation or exponent overflow (>2046)
        out_inf_trigger = (mul_inf || addsub_inf || div_inf_valid) || (exponent_in > 12'h7FE); // exponent_in is 12-bit? spec says [11:0]; max finite exponent = 2046 = 12'h7FE; >2046 is 2047 or more, but 2047+ causes overflow.

        // overflow trigger: infinity trigger and no NaN input
        overflow_trigger = out_inf_trigger && !NaN_input;

        // underflow trigger: cases specified
        underflow_trigger = (div_by_inf) ||
                            (multiply && in_except_zero && !NaN_input && !invalid_trigger) ||
                            (divide   && in_except_zero && !NaN_input && !invalid_trigger);

        // inexact trigger
        inexact_trigger = ((mantissa_in[0] | mantissa_in[1]) || out_inf_trigger || underflow_trigger) && !NaN_input;

        // priority: underflow -> overflow (inf/max finite) -> NaN
        // stage1: underflow zero replacement
        if (underflow_trigger)
            out_stage1 = {in_except[63], 63'b0};
        else
            out_stage1 = in_except;

        // stage2: infinity / max finite replacement
        if (out_inf_trigger && !NaN_input && !invalid_trigger) begin
            if (in_except[63] == 1'b0) begin // positive
                if ((rmode == RTZ) || (rmode == RTN))
                    out_stage2 = {1'b0, 11'b11111111110, 52'b1111111111111111111111111111111111111111111111111111};
                else
                    out_stage2 = {1'b0, 11'b11111111111, 52'b0};
            end else begin // negative
                if ((rmode == RTZ) || (rmode == RTP))
                    out_stage2 = {1'b1, 11'b11111111110, 52'b1111111111111111111111111111111111111111111111111111};
                else
                    out_stage2 = {1'b1, 11'b11111111111, 52'b0};
            end
        end else begin
            out_stage2 = out_stage1;
        end

        // NaN generation
        NaN_out_trigger = NaN_input || invalid_trigger;
        if (NaN_out_trigger) begin
            // construct NaN payload
            if (opa[62:52] == 11'b11111111111 && opa[51:0] != 52'b0) begin // opa is NaN
                nan_payload = {1'b1, opa[50:0]};
            end else if (opb[62:52] == 11'b11111111111 && opb[51:0] != 52'b0) begin
                nan_payload = {1'b1, opb[50:0]};
            end else begin // generated from invalid operation
                nan_payload = {1'b1, opa[50:0]};
            end
            out_final = {in_except[63], 11'b11111111111, nan_payload};
        end else begin
            out_final = out_stage2;
        end

        // ex_enable: asserted when any override occurs (underflow, infinity/max, NaN)
        ex_enable_comb = underflow_trigger || (out_inf_trigger && !NaN_input && !invalid_trigger) || NaN_out_trigger;
    end


    // ---------- registered outputs ----------
    always @(posedge clk) begin
        if (rst) begin
            out       <= 64'b0;
            ex_enable <= 1'b0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            inexact   <= 1'b0;
            exception <= 1'b0;
            invalid   <= 1'b0;
        end else if (enable) begin
            out       <= out_final;
            ex_enable <= ex_enable_comb;
            underflow <= underflow_trigger;
            overflow  <= overflow_trigger;
            inexact   <= inexact_trigger;
            exception <= invalid_trigger | overflow_trigger | underflow_trigger | inexact_trigger;
            invalid   <= invalid_trigger;
        end
        // else hold state
    end

endmodule
