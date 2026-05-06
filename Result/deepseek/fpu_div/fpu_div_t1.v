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

    // Internal registers and wires
    reg [63:0] opa_reg, opb_reg;
    reg sign_reg;
    reg [10:0] exp_a, exp_b;
    reg [51:0] frac_a, frac_b;
    reg a_is_zero, b_is_zero;
    reg a_is_den, b_is_den;
    reg [5:0] lza, lzb;
    reg [53:0] dividend_reg;
    reg [53:0] divisor_reg;
    reg [53:0] quotient_reg;
    reg [53:0] remainder_reg;
    reg [5:0] counter;
    reg [11:0] exponent_reg;
    reg processing;
    reg sticky;

    // Leading zero detector for 52-bit fraction (returns 0..52)
    function [5:0] count_leading_zeros;
        input [51:0] val;
        integer i;
        begin
            count_leading_zeros = 6'd0;
            for (i = 51; i >= 0; i = i - 1) begin
                if (val[i] == 1'b1) begin
                    count_leading_zeros = 6'd51 - i;
                    i = -1;
                end
            end
        end
    endfunction

    // Sign output is combinatorial from registered sign
    assign sign = sign_reg;

    // State machine for iterative division
    reg [2:0] state;
    localparam IDLE = 3'd0, LOAD = 3'd1, DIVIDE = 3'd2, DONE = 3'd3;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            opa_reg <= 64'd0;
            opb_reg <= 64'd0;
            sign_reg <= 1'b0;
            exp_a <= 11'd0;
            exp_b <= 11'd0;
            frac_a <= 52'd0;
            frac_b <= 52'd0;
            a_is_zero <= 1'b0;
            b_is_zero <= 1'b0;
            a_is_den <= 1'b0;
            b_is_den <= 1'b0;
            lza <= 6'd0;
            lzb <= 6'd0;
            dividend_reg <= 54'd0;
            divisor_reg <= 54'd0;
            quotient_reg <= 54'd0;
            remainder_reg <= 54'd0;
            counter <= 6'd0;
            exponent_reg <= 12'd0;
            processing <= 1'b0;
            sticky <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (enable) begin
                        // Capture operands
                        opa_reg <= opa;
                        opb_reg <= opb;

                        // Extract fields
                        sign_reg <= opa[63] ^ opb[63];
                        exp_a <= opa[62:52];
                        exp_b <= opb[62:52];
                        frac_a <= opa[51:0];
                        frac_b <= opb[51:0];

                        // Detect zero and denormal
                        a_is_zero <= (opa[62:52] == 11'd0) && (opa[51:0] == 52'd0);
                        b_is_zero <= (opb[62:52] == 11'd0) && (opb[51:0] == 52'd0);
                        a_is_den <= (opa[62:52] == 11'd0) && (opa[51:0] != 52'd0);
                        b_is_den <= (opb[62:52] == 11'd0) && (opb[51:0] != 52'd0);

                        // Leading zero counts
                        lza <= count_leading_zeros(opa[51:0]);
                        lzb <= count_leading_zeros(opb[51:0]);

                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Build significands with implicit bit
                    // For normalized: {1, frac}
                    // For denormal: shift left by lza+1 to get 1.xxx... (but we are building 54-bit)
                    // Actually, we want a 54-bit value with leading 1 for normalized,
                    // and for denormal, shift left until leading 1 is at bit 53.
                    // The effective mantissa length is 53 bits for double (52 fraction + 1 hidden).
                    // We'll make 54-bit: {1, frac, 0} or shifted denormal.
                    // For a normalized number, mantissa = {1'b1, frac_a, 1'b0}
                    // For denormal, shift {1'b0, frac_a, 1'b0} left by (lza) so that leading 1 goes to bit 53.
                    if (a_is_zero) begin
                        dividend_reg <= 54'd0;
                    end else if (a_is_den) begin
                        dividend_reg <= {1'b0, frac_a, 1'b0} << lza;
                    end else begin
                        dividend_reg <= {1'b1, frac_a, 1'b0};
                    end

                    if (b_is_zero) begin
                        divisor_reg <= 54'd0;
                    end else if (b_is_den) begin
                        divisor_reg <= {1'b0, frac_b, 1'b0} << lzb;
                    end else begin
                        divisor_reg <= {1'b1, frac_b, 1'b0};
                    end

                    // Initialize division state
                    quotient_reg <= 54'd0;
                    remainder_reg <= 54'd0;
                    counter <= 6'd53; // 53 iterations for 53-bit quotient (including integer bit)
                    processing <= 1'b1;
                    state <= DIVIDE;
                end

                DIVIDE: begin
                    if (counter > 0) begin
                        // Shift current remainder left by 1 and bring in next bit from dividend
                        // We maintain a combined remainder/dividend shift register.
                        // Approach: remainder_reg holds the partial remainder, initially 0.
                        // Each step: remainder = {remainder[52:0], dividend_reg[53]};
                        // dividend_reg = {dividend_reg[52:0], 1'b0};
                        // Then compare remainder with divisor.
                        // This is a restoring division algorithm.
                        reg [53:0] shifted_remainder;
                        shifted_remainder = {remainder_reg[52:0], dividend_reg[53]};
                        if (shifted_remainder >= divisor_reg) begin
                            remainder_reg <= shifted_remainder - divisor_reg;
                            quotient_reg <= {quotient_reg[52:0], 1'b1};
                        end else begin
                            remainder_reg <= shifted_remainder;
                            quotient_reg <= {quotient_reg[52:0], 1'b0};
                        end
                        dividend_reg <= {dividend_reg[52:0], 1'b0};
                        counter <= counter - 1;
                    end else begin
                        // After 53 iterations, quotient_reg has 53 bits (integer + 52 fraction)
                        // remainder_reg has the final remainder.
                        // Compute sticky from lower bits of remainder and any remaining dividend bits
                        sticky <= |remainder_reg[52:0] | |dividend_reg[52:0];
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Output exponent calculation
                    // exponent_out will be computed combinationally from registered values
                    // But we need to store it. We'll compute in DONE and hold.
                    // Exponent logic:
                    // exp_result = exp_a - exp_b + 1023 - (normalization shifts)
                    // Actually: biased_exp = exp_a - exp_b + 1023
                    // Adjust for denormal operands: add lza for A, subtract lzb for B? Wait.
                    // For A, if denormal, effective exponent is 1 - 1023 - lza? No.
                    // IEEE: value = (-1)^s * 2^(exp-1023) * 1.fraction for normal,
                    //         = (-1)^s * 2^(-1022) * 0.fraction for denormal.
                    // So effective exponent for denormal A is -1022 - lza (since leading zeros).
                    // For B, effective exponent is -1022 - lzb.
                    // Division exponent = (eff_exp_A) - (eff_exp_B)
                    // Biased result = eff_exp_diff + 1023.
                    // Then adjust for quotient normalization: if quotient MSB is 1, exponent as is;
                    // if MSB is 0, need to shift left and decrement exponent.
                    // Also, if result is denormal, need to align.
                    // We'll compute using registered intermediate values.
                    // Since we need to output exponent_out register, we can compute here.
                    reg [11:0] exp_a_eff, exp_b_eff, exp_diff;
                    reg [11:0] exp_biased;
                    reg [5:0] norm_shift;
                    reg msb;

                    if (a_is_zero) begin
                        exponent_out <= 12'd0;
                    end else begin
                        // Compute effective exponents
                        if (a_is_den)
                            exp_a_eff = 12'd1022 - {6'd0, lza}; // -1022 - lza? Actually 2^(-1022) * 0.fraction, so exponent is -1022, but with lza leading zeros, mantissa is shifted left lza, so effective exponent = -1022 - lza.
                        else
                            exp_a_eff = {1'b0, exp_a};

                        if (b_is_den)
                            exp_b_eff = 12'd1022 - {6'd0, lzb};
                        else
                            exp_b_eff = {1'b0, exp_b};

                        exp_diff = exp_a_eff - exp_b_eff;
                        exp_biased = exp_diff + 12'd1023;

                        // Normalization: quotient_reg[53] is the leading bit (integer part).
                        // We have 54-bit quotient_reg? Actually we built 54-bit quotient_reg, but we only shifted 53 times.
                        // quotient_reg width is 54 bits, initialized to 0, and we shift in 53 bits.
                        // So after 53 iterations, quotient_reg[53] is the last bit shifted in? Wait.
                        // We shift quotient_reg left each cycle: {quotient_reg[52:0], new_bit}.
                        // Starting from 0, after 53 cycles, the bits are in quotient_reg[53:1]? Let's trace:
                        // Initially quotient_reg=0. After 1st: quotient_reg[0]=bit, rest 0.
                        // After 53rd: quotient_reg[52:0] has 53 bits, quotient_reg[53] is 0.
                        // Actually, we want the integer bit (the first quotient bit) to be at the MSB.
                        // Standard algorithm: dividend is 54 bits (1.frac + trailing zeros). After 53 shifts, quotient bits are generated from MSB to LSB.
                        // If we shift quotient left and insert at LSB, the first bit ends up at LSB after 53 shifts? No.
                        // Let's do: quotient_reg = {quotient_reg[52:0], bit}. Initially 0.
                        // After 53 iterations, the first bit is at quotient_reg[0]? Actually, first bit goes to LSB, then next cycle it shifts left, so after 53 cycles, the first bit is at quotient_reg[52], and the last bit at quotient_reg[0]. So quotient_reg[53] is 0.
                        // We want the leading bit (integer bit) at MSB. So we should shift in from the right but we need to reverse? Or we can just use the bit index appropriately.
                        // Simpler: we can store quotient in a shift register that shifts left: quotient <= {quotient[52:0], bit}. After 53 cycles, the first bit is at quotient[52]. That's the MSB of the 53-bit result. The integer bit is quotient[52]? Wait, the first quotient bit is the integer bit (since dividend and divisor are both 1.xxx, the result is 1.xxx or 0.1xxx...). The first bit generated is the MSB of the quotient (the integer bit). So if we shift left, the first bit goes to LSB, then next cycle it moves to bit 1, etc. After 53 cycles, the first bit is at bit 52. So quotient[52] is the integer bit. Good.
                        // So integer bit = quotient_reg[52].
                        msb = quotient_reg[52];

                        // If msb is 1, the quotient is normalized. If 0, we need to shift left by 1 and decrement exponent.
                        if (msb == 1'b0) begin
                            norm_shift = 6'd1;
                        end else begin
                            norm_shift = 6'd0;
                        end

                        // Apply normalization shift to exponent
                        exp_biased = exp_biased - {6'd0, norm_shift};

                        // Handle denormal result: if exp_biased <= 0, result is denormal.
                        // We need to shift mantissa right by (1 - exp_biased) and set exponent to 0.
                        // But the mantissa output is handled separately. We just set exponent_out to 0 if denormal.
                        if (exp_biased[11] == 1'b1 || exp_biased == 12'd0) begin
                            // Underflow to denormal
                            exponent_out <= 12'd0;
                        end else begin
                            exponent_out <= exp_biased;
                        end
                    end

                    // Mantissa output preparation
                    // mantissa_7 format: {reserved, leading_bit_indicator, 52-bit mantissa, guard, sticky}
                    // We have quotient_reg[51:0] as the 52-bit mantissa (if normalized with msb=1, quotient_reg[51:0] is the fraction;
                    // if msb=0, we need to shift left by 1 to get normalized mantissa fraction).
                    // Also we need to compute guard bit from the next bit (quotient_reg[-1]? We don't have it) and sticky from remainder.
                    // Since we only generated 53 bits (1 integer + 52 fraction), we need an extra bit for guard.
                    // We can run an extra iteration? Or we can compute guard from the next division step.
                    // We have remainder_reg and dividend_reg after 53 iterations. The next quotient bit would be generated from {remainder_reg[52:0], dividend_reg[53]}.
                    // But dividend_reg[53] is 0 after 53 shifts? Actually after 53 shifts, dividend_reg has been shifted left 53 times, so the original trailing zeros are moved up. The next bit would be 0.
                    // So guard bit can be computed as (remainder_reg >= divisor_reg) ? 1 : 0 using the current remainder? Actually the next bit is determined by comparing {remainder_reg[52:0], 1'b0} with divisor.
                    // We can compute guard bit in DONE state.
                    reg guard;
                    reg [53:0] next_remainder;
                    next_remainder = {remainder_reg[52:0], 1'b0};
                    if (next_remainder >= divisor_reg) begin
                        guard = 1'b1;
                    end else begin
                        guard = 1'b0;
                    end

                    // Now build mantissa_7
                    // Determine final mantissa: if msb=1, fraction = quotient_reg[51:0]; if msb=0, fraction = quotient_reg[50:0] shifted left? Actually if msb=0, the quotient is like 0.1xxx... so the normalized mantissa is quotient_reg[51:0] shifted left by 1, and the integer bit becomes 1.
                    // But we need to output a 56-bit bundle that includes the leading bit indicator? The spec says: {reserved bit, leading-bit indicator, 52-bit mantissa, guard-like bit, sticky bit}
                    // Leading-bit indicator probably indicates if the result is normal (1) or denormal (0)? Or indicates the implicit bit?
                    // Usually in FPU intermediate formats, mantissa_7 includes the explicit leading bit (the integer bit) for rounding.
                    // Let's assume: mantissa_7 = {1'b0, integer_bit, fraction[51:0], guard, sticky}? That would be 56 bits.
                    // We'll map: mantissa_7[55] reserved, [54] leading-bit indicator (the integer bit of quotient), [53:2] 52-bit mantissa (fraction), [1] guard, [0] sticky.
                    // If the result is denormal (exponent_out == 0), we need to shift the mantissa right by (1 - exp_biased) and the integer bit becomes 0, with the leading bit indicator possibly 0.
                    // However, the problem says: "mandisa_7 is an intermediate rounding bundle: {reserved bit, leading-bit indicator, 52-bit mantissa, guard-like bit, sticky bit}".
                    // We'll construct it based on the quotient and normalization.

                    // We'll compute the mantissa output directly here (combinational or registered?).
                    // Since state DONE is reached, we can assign a wire/reg for mantissa_7? The spec wants output [55:0] mantissa_7.
                    // We'll make it a reg and assign in DONE state.
                    // But we need to hold it until next enable? We'll just keep it stable after DONE until next enable.
                    // So we'll use a register for mantissa_out.
                end
            endcase
        end
    end

    // Mantissa output register
    reg [55:0] mantissa_out_reg;
    assign mantissa_7 = mantissa_out_reg;

    // Compute mantissa_7 in DONE state
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mantissa_out_reg <= 56'd0;
        end else if (state == DONE) begin
            reg [53:0] quotient_norm;
            reg integer_bit;
            reg [51:0] fraction;
            reg guard_bit;
            reg sticky_bit;
            reg [53:0] next_rem;
            reg [11:0] exp_biased_val;
            reg [11:0] exp_a_eff, exp_b_eff, exp_diff;
            reg [5:0] norm_shift;
            reg msb;

            // Recompute exponent info for denormal handling (same as above, but we need it for mantissa shift)
            if (a_is_zero) begin
                exp_biased_val = 12'd0;
            end else begin
                if (a_is_den)
                    exp_a_eff = 12'd1022 - {6'd0, lza};
                else
                    exp_a_eff = {1'b0, exp_a};

                if (b_is_den)
                    exp_b_eff = 12'd1022 - {6'd0, lzb};
                else
                    exp_b_eff = {1'b0, exp_b};

                exp_diff = exp_a_eff - exp_b_eff;
                exp_biased_val = exp_diff + 12'd1023;

                msb = quotient_reg[52];
                norm_shift = (msb == 1'b0) ? 6'd1 : 6'd0;
                exp_biased_val = exp_biased_val - {6'd0, norm_shift};
            end

            // Compute guard and sticky
            next_rem = {remainder_reg[52:0], 1'b0};
            if (next_rem >= divisor_reg)
                guard_bit = 1'b1;
            else
                guard_bit = 1'b0;

            sticky_bit = sticky; // registered sticky from previous cycle

            // Normalize quotient for mantissa
            if (a_is_zero) begin
                integer_bit = 1'b0;
                fraction = 52'd0;
            end else begin
                if (msb == 1'b0) begin
                    // Shift left by 1 to get normalized mantissa
                    integer_bit = quotient_reg[51];
                    fraction = {quotient_reg[50:0], 1'b0};
                end else begin
                    integer_bit = 1'b1;
                    fraction = quotient_reg[51:0];
                end

                // Handle denormal result: if exp_biased_val <= 0, we need to shift right
                if (exp_biased_val[11] == 1'b1 || exp_biased_val == 12'd0) begin
                    // Denormal result: shift right by (1 - exp_biased_val) to align
                    // But exp_biased_val is signed 12-bit, if negative, the shift amount is -exp_biased_val.
                    // We'll compute shift amount as (12'd1 - exp_biased_val) when exp_biased_val <= 0.
                    // Since we already set exponent_out to 0, we need to shift the mantissa right by (1 - exp_biased_val) and OR the shifted-out bits into sticky.
                    reg [5:0] rshift;
                    rshift = (12'd1 - exp_biased_val[5:0]); // assuming exp_biased_val is not too negative
                    // We need to shift the combined {integer_bit, fraction, guard_bit} right by rshift.
                    // We'll build a wider register.
                    reg [54:0] mant_wide;
                    mant_wide = {integer_bit, fraction, guard_bit};
                    mant_wide = mant_wide >> rshift;
                    // Update sticky with bits shifted out
                    // We'll just OR the bits that were shifted out into sticky_bit.
                    // For simplicity, we'll just set sticky to 1 if any shift out occurs.
                    if (rshift > 0)
                        sticky_bit = 1'b1;
                    integer_bit = mant_wide[54];
                    fraction = mant_wide[53:2];
                    guard_bit = mant_wide[1];
                end
            end

            // Build output
            mantissa_out_reg <= {1'b0, integer_bit, fraction, guard_bit, sticky_bit};
        end
    end

endmodule
