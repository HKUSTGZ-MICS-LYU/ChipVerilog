`timescale 1ns / 1ps

module fpu_div (
    input  wire        clk,
    input  wire        rst,        // active-high synchronous reset
    input  wire        enable,

    input  wire [63:0] opa,
    input  wire [63:0] opb,

    output wire        sign,
    output reg  [11:0] exponent_out,
    output reg  [55:0] mantissa_7
);

    // ------------------------------------------------------------
    // IEEE-754 double fields
    // ------------------------------------------------------------
    wire        sign_a;
    wire        sign_b;
    wire [10:0] exp_a;
    wire [10:0] exp_b;
    wire [51:0] frac_a;
    wire [51:0] frac_b;

    assign sign_a = opa[63];
    assign sign_b = opb[63];
    assign exp_a  = opa[62:52];
    assign exp_b  = opb[62:52];
    assign frac_a = opa[51:0];
    assign frac_b = opb[51:0];

    assign sign = sign_a ^ sign_b;

    // ------------------------------------------------------------
    // Leading-zero counter for 52-bit denormal fractions
    // Returns 0..52
    // ------------------------------------------------------------
    function [5:0] lzc52;
        input [51:0] value;
        integer i;
        reg found;
        begin
            lzc52 = 6'd52;
            found = 1'b0;

            for (i = 51; i >= 0; i = i - 1) begin
                if (!found && value[i]) begin
                    lzc52 = 6'd51 - i[5:0];
                    found = 1'b1;
                end
            end
        end
    endfunction

    // ------------------------------------------------------------
    // Operand normalization
    //
    // For normal numbers:
    //   significand = {1'b1, frac}
    //
    // For denormal numbers:
    //   significand = frac shifted left until leading 1 reaches bit 52.
    //
    // The denormal shift is later compensated in the exponent datapath.
    // ------------------------------------------------------------
    wire        a_is_denorm;
    wire        b_is_denorm;

    wire [5:0]  lzc_a;
    wire [5:0]  lzc_b;

    wire [52:0] sig_a_norm;
    wire [52:0] sig_b_norm;

    wire signed [12:0] exp_a_unbiased_adj;
    wire signed [12:0] exp_b_unbiased_adj;
    wire signed [13:0] exp_div_base;

    assign a_is_denorm = (exp_a == 11'd0);
    assign b_is_denorm = (exp_b == 11'd0);

    assign lzc_a = lzc52(frac_a);
    assign lzc_b = lzc52(frac_b);

    assign sig_a_norm =
        a_is_denorm ? ({1'b0, frac_a} << lzc_a) :
                      {1'b1, frac_a};

    assign sig_b_norm =
        b_is_denorm ? ({1'b0, frac_b} << lzc_b) :
                      {1'b1, frac_b};

    // Normal exponent unbiased value:
    //   E = exp - 1023
    //
    // Denormal value:
    //   value = frac * 2^-1074
    //   after left normalization by lzc:
    //   adjusted unbiased exponent = -1022 - lzc
    //
    // This is an intermediate datapath, so zero/special cases are expected
    // to be filtered or handled by surrounding FPU logic.
    assign exp_a_unbiased_adj =
        a_is_denorm ? (-13'sd1022 - $signed({7'd0, lzc_a})) :
                      ($signed({2'b00, exp_a}) - 13'sd1023);

    assign exp_b_unbiased_adj =
        b_is_denorm ? (-13'sd1022 - $signed({7'd0, lzc_b})) :
                      ($signed({2'b00, exp_b}) - 13'sd1023);

    // Biased result exponent before quotient normalization.
    assign exp_div_base =
        $signed(exp_a_unbiased_adj) -
        $signed(exp_b_unbiased_adj) +
        14'sd1023;

    // ------------------------------------------------------------
    // Iterative restoring division datapath
    //
    // We compute 55 quotient-related bits:
    //   bit 54 : possible leading bit
    //   bits 53:2 : mantissa candidate
    //   bit 1 : guard-like bit
    //   bit 0 : extra remainder-related quotient bit
    //
    // sticky is derived from final remainder.
    // ------------------------------------------------------------
    localparam [6:0] PRESET = 7'd53;

    localparam [1:0]
        ST_IDLE = 2'd0,
        ST_RUN  = 2'd1,
        ST_DONE = 2'd2;

    reg [1:0] state;

    reg [6:0]  count;

    reg [108:0] dividend_reg;
    reg [108:0] divisor_reg;
    reg [54:0]  quotient_reg;

    reg signed [13:0] exponent_work;

    wire div_ge;
    wire [108:0] div_sub;
    wire [108:0] dividend_next_if_ge;
    wire [108:0] dividend_next_if_lt;

    assign div_ge = (dividend_reg >= divisor_reg);
    assign div_sub = dividend_reg - divisor_reg;

    assign dividend_next_if_ge = div_sub << 1;
    assign dividend_next_if_lt = dividend_reg << 1;

    // ------------------------------------------------------------
    // Quotient normalization / mantissa package generation
    // ------------------------------------------------------------
    reg [54:0] quotient_norm;
    reg signed [13:0] exponent_norm;

    reg [51:0] mantissa_bits;
    reg        guard_like_bit;
    reg        sticky_bit;
    reg        leading_bit_indicator;

    always @* begin
        quotient_norm = quotient_reg;
        exponent_norm = exponent_work;

        // For division of normalized significands, quotient is usually
        // in [0.5, 2). If the top bit is not set, shift left once and
        // decrement exponent.
        if (quotient_reg[54] == 1'b0) begin
            quotient_norm = quotient_reg << 1;
            exponent_norm = exponent_work - 14'sd1;
        end

        mantissa_bits = quotient_norm[53:2];
        guard_like_bit = quotient_norm[1];

        // Sticky combines remaining quotient/remainder information.
        sticky_bit = quotient_norm[0] | (|dividend_reg);

        // Indicates whether final intermediate exponent is nonzero.
        leading_bit_indicator = (exponent_norm > 14'sd0);
    end

    // ------------------------------------------------------------
    // Main sequential logic
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state        <= ST_IDLE;
            count        <= 7'd0;

            dividend_reg <= 109'd0;
            divisor_reg  <= 109'd0;
            quotient_reg <= 55'd0;

            exponent_work <= 14'sd0;

            exponent_out <= 12'd0;
            mantissa_7   <= 56'd0;
        end else begin
            case (state)

                ST_IDLE: begin
                    if (enable) begin
                        // Dividend and divisor are aligned to the same
                        // high-order position for restoring division.
                        //
                        // dividend_reg is shifted by one extra bit to begin
                        // quotient generation immediately.
                        dividend_reg <= {sig_a_norm, 56'd0};
                        divisor_reg  <= {1'b0, sig_b_norm, 55'd0};

                        quotient_reg <= 55'd0;
                        count        <= PRESET;

                        exponent_work <= exp_div_base;

                        state <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    if (div_ge) begin
                        dividend_reg <= dividend_next_if_ge;
                        quotient_reg[count] <= 1'b1;
                    end else begin
                        dividend_reg <= dividend_next_if_lt;
                        quotient_reg[count] <= 1'b0;
                    end

                    if (count == 7'd0) begin
                        state <= ST_DONE;
                    end else begin
                        count <= count - 7'd1;
                    end
                end

                ST_DONE: begin
                    // Underflow-related alignment.
                    //
                    // This module does not finalize denormal packing.
                    // If exponent_norm is <= 0, shift the quotient-derived
                    // bundle right so the rounding/packing stage can consume
                    // an aligned intermediate significand.
                    if (exponent_norm <= 14'sd0) begin
                        if ((1 - exponent_norm) >= 14'd55) begin
                            exponent_out <= 12'd0;
                            mantissa_7   <= {
                                1'b0,       // reserved_bit
                                1'b0,       // leading_bit_indicator
                                52'd0,      // mantissa_bits
                                1'b0,       // guard_like_bit
                                |quotient_norm | |dividend_reg
                            };
                        end else begin
                            exponent_out <= 12'd0;
                            mantissa_7   <= {
                                1'b0,
                                1'b0,
                                ({quotient_norm[53:2]} >> (1 - exponent_norm)),
                                quotient_norm[1],
                                quotient_norm[0] | |dividend_reg
                            };
                        end
                    end else begin
                        exponent_out <= exponent_norm[11:0];
                        mantissa_7   <= {
                            1'b0,                  // reserved_bit
                            leading_bit_indicator, // exponent nonzero indicator
                            mantissa_bits,         // 52 quotient-derived bits
                            guard_like_bit,
                            sticky_bit
                        };
                    end

                    if (enable) begin
                        dividend_reg <= {sig_a_norm, 56'd0};
                        divisor_reg  <= {1'b0, sig_b_norm, 55'd0};

                        quotient_reg <= 55'd0;
                        count        <= PRESET;

                        exponent_work <= exp_div_base;

                        state <= ST_RUN;
                    end else begin
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end

            endcase
        end
    end

endmodule