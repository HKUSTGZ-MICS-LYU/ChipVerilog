module fpu_div (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output sign,
    output [55:0] mantissa_7,
    output reg [11:0] exponent_out
);

    // combinational sign
    assign sign = opa[63] ^ opb[63];

    // Leading zero count for 52-bit fraction
    function [5:0] lzc52;
        input [51:0] in;
        integer i;
        begin
            lzc52 = 0;
            for (i = 51; i >= 0; i = i - 1)
                if (in[i] == 1'b1) begin
                    lzc52 = 52 - i - 1;
                    i = -1;
                end
        end
    endfunction

    // signals for operand fields and adjustments
    reg [63:0] opa_r, opb_r;
    reg sign_r;
    reg [10:0] exp_a, exp_b;
    reg [51:0] frac_a, frac_b;
    reg opa_zero, opb_zero;
    reg [5:0] lzc_a, lzc_b;

    // internal significands (53 bits)
    reg [52:0] sigA, sigB;

    // division state
    reg state; // 0 idle, 1 running
    reg [5:0] cnt; // down counter 53 to 0
    reg [105:0] dividend_ext; // 106-bit dividend
    reg [52:0] divisor; // 53-bit divisor
    reg [52:0] quotient; // 53-bit quotient
    reg [52:0] remainder; // top 53 bits after last iteration

    // exponent handling
    reg [11:0] exp_init; // biased base exponent before normalization

    // output registers
    reg [55:0] mantissa_r;
    assign mantissa_7 = mantissa_r;
    reg [11:0] exponent_r;
    assign exponent_out = exponent_r;

    // combinational logic for final mantissa/exp
    reg [52:0] q_norm;
    reg [5:0] lz_q;
    reg [11:0] exp_adj;
    reg [51:0] mantissa_part;
    reg guard, sticky;
    reg leading_indicator;

    always @* begin
        // normalize quotient
        if (quotient == 53'd0) begin
            lz_q = 6'd53;
        end else begin
            lz_q = 6'd0;
            for (integer i = 52; i >= 0; i = i - 1)
                if (quotient[i] == 1'b1) begin
                    lz_q = 52 - i;
                    i = -1;
                end
        end
        q_norm = quotient << lz_q;
        exp_adj = exp_init - {6'd0, lz_q};

        // denormal result alignment
        if (exp_adj[11] || (exp_adj == 12'd0)) begin // exp_adj <= 0
            // denormal
            leading_indicator = 1'b0;
            exponent_r = 12'd0;
            // right shift by (1 - exp_adj) bits
            integer shift_right;
            reg [105:0] temp;
            shift_right = (exp_adj == 12'd0) ? 1 : ( -{1'b0, exp_adj} );
            // apply right shift; include remainder bits
            temp = {q_norm, 53'b0}; // extend with remainder? Actually we use remainder for sticky. We'll compute combined sticky.
            // For simplicity, compute mantissa_part, guard, sticky with right shift.
            // Note: after right shift, bits shifted out contribute to guard and sticky.
            // We'll compute the effective mantissa part: leading 0, then bits.
            // The normalized mantissa after right shift: result = {1'b0, q_norm} >> shift_right.
            // Then take top 52 bits as mantissa, next bit as guard, rest OR for sticky.
            // Also sticky should include the division remainder (53 bits).
            reg [106:0] wide; // 1 (leading 0) + 53 (q_norm) = 54 bits, then shift.
            wide = {1'b0, q_norm};
