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

    // -----------------------------------------------------------------
    // State and control
    // -----------------------------------------------------------------
    localparam IDLE = 1'b0,
               DIV  = 1'b1;

    reg state;
    reg [5:0] counter;          // 0..53
    reg       sticky;           // accumulated sticky bit
    reg       zero_a_reg;       // flag that operand A is zero

    // -----------------------------------------------------------------
    // Datapath registers
    // -----------------------------------------------------------------
    reg [53:0] dividend;        // 54-bit dividend
    reg [53:0] divisor;         // 54-bit divisor
    reg [52:0] quotient;        // 53-bit quotient

    // -----------------------------------------------------------------
    // Leading zero count for 52-bit fraction (combinational)
    // -----------------------------------------------------------------
    function [5:0] lzc52;
        input [51:0] f;
        integer i;
        begin
            lzc52 = 6'd52;
            for (i = 51; i >= 0; i = i - 1) begin
                if (f[i] == 1'b1) begin
                    lzc52 = 6'd51 - i;
                    disable lzc52;
                end
            end
        end
    endfunction

    // -----------------------------------------------------------------
    // Sign is combinatorial
    // -----------------------------------------------------------------
    assign sign = opa[63] ^ opb[63];

    // -----------------------------------------------------------------
    // Mantissa output is always driven (updated when division done)
    // -----------------------------------------------------------------
    reg [55:0] mantissa_7_int;
    assign mantissa_7 = mantissa_7_int;

    // -----------------------------------------------------------------
    // Main sequential block
    // -----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            counter        <= 6'd0;
            dividend       <= 54'd0;
            divisor        <= 54'd0;
            quotient       <= 53'd0;
            sticky         <= 1'b0;
            zero_a_reg     <= 1'b0;
            exponent_out   <= 12'd0;
            mantissa_7_int <= 56'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (enable) begin
                        // -----------------------------------------------------------------
                        // Decode input operands
                        // -----------------------------------------------------------------
                        wire        sign_a   = opa[63];
                        wire        sign_b   = opb[63];
                        wire [10:0] exp_a    = opa[62:52];
                        wire [10:0] exp_b    = opb[62:52];
                        wire [51:0] frac_a   = opa[51:0];
                        wire [51:0] frac_b   = opb[51:0];
                        wire        zero_a   = (exp_a == 11'd0) && (frac_a == 52'd0);
                        wire        zero_b   = (exp_b == 11'd0) && (frac_b == 52'd0);

                        zero_a_reg <= zero_a;

                        // -----------------------------------------------------------------
                        // Compute effective significands and exponents
                        // -----------------------------------------------------------------
                        reg [53:0] sig_a, sig_b;     // 54-bit significands
                        reg signed [12:0] unb_exp_a; // unbiased exponent (13 bits)
                        reg signed [12:0] unb_exp_b;

                        // -- operand A --
                        if (exp_a != 11'd0) begin
                            // normalized
                            sig_a = {1'b1, frac_a, 1'b0};
                            unb_exp_a = $signed({1'b0, exp_a}) - 13'd1023;
                        end else if (zero_a) begin
                            sig_a = 54'd0;
                            unb_exp_a = -13'd1022;         // not used when zero
                        end else begin
                            // denormal
                            automatic [5:0] lz = lzc52(frac_a);
                            sig_a = {1'b1, (frac_a << lz), 1'b0};
                            unb_exp_a = -13'd1022 - $signed({7'd0, lz});
                        end

                        // -- operand B --
                        if (exp_b != 11'd0) begin
                            sig_b = {1'b1, frac_b, 1'b0};
                            unb_exp_b = $signed({1'b0, exp_b}) - 13'd1023;
                        end else if (zero_b) begin
                            sig_b = 54'd0;
                            unb_exp_b = -13'd1022;
                        end else begin
                            automatic [5:0] lz = lzc52(frac_b);
                            sig_b = {1'b1, (frac_b << lz), 1'b0};
                            unb_exp_b = -13'd1022 - $signed({7'd0, lz});
                        end

                        // -----------------------------------------------------------------
                        // Load division loop registers
                        // -----------------------------------------------------------------
                        if (zero_a) begin
                            dividend <= 54'd0;
                            exponent_out <= 12'd0;
                        end else begin
                            dividend <= sig_a;
                            // Compute initial biased exponent
                            // result unbiased = unb_exp_a - unb_exp_b
                            // biased = result_unb + 1023
                            exponent_out <= $signed(unb_exp_a - unb_exp_b) + 13'd1023;
                        end
                        divisor  <= (zero_b) ? 54'd0 : sig_b; // not used when opb zero, but safe
                        quotient <= 53'd0;
                        sticky   <= 1'b0;
                        counter  <= 6'd53;
                        state    <= DIV;
                    end
                end

                DIV: begin
                    if (counter > 6'd0) begin
                        // -------------------------------------------------------------
                        // One division iteration
                        // -------------------------------------------------------------
                        reg [53:0] remainder;
                        reg        qbit;

                        if (dividend >= divisor) begin
                            remainder = dividend - divisor;
                            qbit = 1'b1;
                        end else begin
                            remainder = dividend;
                            qbit = 1'b0;
                        end

                        // Capture sticky from the bit that will be shifted out
                        sticky <= sticky | remainder[0];

                        // Shift left the remainder and store to dividend
                        dividend <= remainder << 1;

                        // Shift left the quotient and insert new bit at LSB
                        quotient <= {quotient[51:0], qbit};

                        counter <= counter - 6'd1;

                        // When last iteration, stay in DIV but next clock counter==0
                        // and we compute outputs below
                        if (counter == 6'd1) begin
                            // ---------------------------------------------------------
                            // Division finished – compute final mantissa_7 and exponent
                            // ---------------------------------------------------------
                            // quotient[52] is leading bit indicator
                            // mantissa bits: quotient[52:1] (52 bits)
                            // guard bit: quotient[0]
                            // sticky: accumulated
                            mantissa_7_int[55] <= 1'b0; // reserved
                            mantissa_7_int[54] <= quotient[52];
                            mantissa_7_int[53:2] <= quotient[52:1];
                            mantissa_7_int[1]   <= quotient[0];
                            mantissa_7_int[0]   <= sticky;

                            // Adjust exponent for quotient leading zero
                            if (quotient[52] == 1'b0) begin
                                exponent_out <= exponent_out - 12'd1;
                            end
                            // Force zero if input A was zero
                            if (zero_a_reg) begin
                                exponent_out <= 12'd0;
                                mantissa_7_int <= 56'd0;
                            end
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

endmodule
