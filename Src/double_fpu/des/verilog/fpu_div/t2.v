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

    //--------------------------------------------------------------------------
    // Sign
    //--------------------------------------------------------------------------
    assign sign = opa[63] ^ opb[63];

    //--------------------------------------------------------------------------
    // Field extraction
    //--------------------------------------------------------------------------
    wire [10:0] exp_a  = opa[62:52];
    wire [10:0] exp_b  = opb[62:52];
    wire [51:0] frac_a = opa[51:0];
    wire [51:0] frac_b = opb[51:0];

    wire a_is_zero   = (exp_a == 11'd0) && (frac_a == 52'd0);
    wire a_is_denorm = (exp_a == 11'd0) && (frac_a != 52'd0);
    wire b_is_denorm = (exp_b == 11'd0) && (frac_b != 52'd0);

    //--------------------------------------------------------------------------
    // Leading-zero count for denormals (53-bit: hidden + fraction)
    //--------------------------------------------------------------------------
    function [5:0] lzc53;
        input [52:0] v;
        integer i;
        begin
            lzc53 = 6'd53;
            for (i = 52; i >= 0; i = i - 1)
                if (v[i]) lzc53 = 6'd52 - i;
        end
    endfunction

    wire [5:0] lz_a = lzc53({1'b0, frac_a});
    wire [5:0] lz_b = lzc53({1'b0, frac_b});

    // 54-bit internal significands
    wire [53:0] sig_a_raw = a_is_denorm ? ({1'b0, frac_a, 1'b0} << lz_a)
                                        : {1'b1, frac_a, 1'b0};
    wire [53:0] sig_b_raw = b_is_denorm ? ({1'b0, frac_b, 1'b0} << lz_b)
                                        : {1'b1, frac_b, 1'b0};

    //--------------------------------------------------------------------------
    // Enable pipeline (2-stage to align with significand load)
    //--------------------------------------------------------------------------
    reg enable_r1, enable_r2;
    always @(posedge clk) begin
        if (rst) begin
            enable_r1 <= 0;
            enable_r2 <= 0;
        end else begin
            enable_r1 <= enable;
            enable_r2 <= enable_r1;
        end
    end

    //--------------------------------------------------------------------------
    // Exponent datapath (registered on enable)
    //--------------------------------------------------------------------------
    reg [11:0] exp_raw;       // exponent_a + 1023 - exponent_b
    reg [5:0]  lz_a_r, lz_b_r;
    reg        a_denorm_r, b_denorm_r, a_zero_r;

    always @(posedge clk) begin
        if (rst) begin
            exp_raw    <= 0;
            lz_a_r     <= 0;
            lz_b_r     <= 0;
            a_denorm_r <= 0;
            b_denorm_r <= 0;
            a_zero_r   <= 0;
        end else if (enable) begin
            exp_raw    <= {1'b0, exp_a} + 12'd1023 - {1'b0, exp_b};
            lz_a_r     <= lz_a;
            lz_b_r     <= lz_b;
            a_denorm_r <= a_is_denorm;
            b_denorm_r <= b_is_denorm;
            a_zero_r   <= a_is_zero;
        end
    end

    //--------------------------------------------------------------------------
    // Iterative long-division datapath
    //--------------------------------------------------------------------------
    // preset = 53 → 54 quotient bits (bit 53 down to bit 0)
    localparam PRESET = 6'd53;

    reg [53:0] dividend_reg;
    reg [53:0] divisor_reg;
    reg [53:0] quotient_reg;
    reg [5:0]  count;
    reg        div_running;
    reg        div_done;

    // remainder after each step (one extra bit for borrow)
    wire [54:0] diff = {1'b0, dividend_reg} - {1'b0, divisor_reg};

    always @(posedge clk) begin
        if (rst) begin
            dividend_reg <= 0;
            divisor_reg  <= 0;
            quotient_reg <= 0;
            count        <= 0;
            div_running  <= 0;
            div_done     <= 0;
        end else begin
            if (enable_r2 && !div_running) begin
                // Load operands and start
                dividend_reg <= sig_a_raw;
                divisor_reg  <= sig_b_raw;
                quotient_reg <= 0;
                count        <= PRESET;
                div_running  <= 1;
                div_done     <= 0;
            end else if (div_running) begin
                if (diff[54] == 1'b0) begin
                    // dividend >= divisor: quotient bit = 1
                    quotient_reg <= (quotient_reg << 1) | 54'd1;
                    dividend_reg <= diff[53:0] << 1;
                end else begin
                    // dividend < divisor: quotient bit = 0
                    quotient_reg <= quotient_reg << 1;
                    dividend_reg <= dividend_reg << 1;
                end

                if (count == 0) begin
                    div_running <= 0;
                    div_done    <= 1;
                end else begin
                    count    <= count - 1;
                    div_done <= 0;
                end
            end else begin
                div_done <= 0;
            end
        end
    end

    //--------------------------------------------------------------------------
    // Sticky bit: OR-reduce lower remainder bits after division
    //--------------------------------------------------------------------------
    wire sticky = |dividend_reg[51:0];

    //--------------------------------------------------------------------------
    // Quotient normalization detect
    //--------------------------------------------------------------------------
    // After 54 iterations quotient is 54 bits wide.
    // Bit 53 is the leading bit if result is >= 1 (normalized).
    wire quot_leading = quotient_reg[53];

    //--------------------------------------------------------------------------
    // Exponent correction
    //--------------------------------------------------------------------------
    // Base: exp_a + 1023 - exp_b
    // Denorm correction: subtract (lz_a - 1) for denorm A, add (lz_b - 1) for denorm B
    // Normalization: if quotient leading bit is 0, subtract 1
    wire [11:0] exp_corr_a  = a_denorm_r ? (exp_raw - {6'b0, lz_a_r} + 12'd1) : exp_raw;
    wire [11:0] exp_corr_b  = b_denorm_r ? (exp_corr_a + {6'b0, lz_b_r} - 12'd1) : exp_corr_a;
    wire [11:0] exp_norm    = quot_leading ? exp_corr_b : (exp_corr_b - 12'd1);

    //--------------------------------------------------------------------------
    // mantissa_7 bundle
    // [55]    = reserved (0)
    // [54]    = leading bit indicator (quot_leading)
    // [53:2]  = 52-bit mantissa candidate
    // [1]     = guard bit (next quotient bit)
    // [0]     = sticky
    //--------------------------------------------------------------------------
    // When quot_leading=1: mantissa = quotient[52:1], guard = quotient[0]
    // When quot_leading=0: mantissa = quotient[51:0], guard = 0 (shifted)
    wire [51:0] mantissa_bits = quot_leading ? quotient_reg[52:1] : quotient_reg[51:0];
    wire        guard_bit     = quot_leading ? quotient_reg[0]    : 1'b0;

    assign mantissa_7 = {1'b0, quot_leading, mantissa_bits, guard_bit, sticky};

    //--------------------------------------------------------------------------
    // exponent_out (registered at div_done)
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            exponent_out <= 0;
        end else if (div_done) begin
            exponent_out <= a_zero_r ? 12'd0 : exp_norm;
        end
    end

endmodule