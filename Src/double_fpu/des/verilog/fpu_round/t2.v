`timescale 1ns / 100ps

module fpu_round (
    input clk,
    input rst,
    input enable,
    input [1:0]  round_mode,
    input        sign_term,
    input [55:0] mantissa_term,
    input [11:0] exponent_term,
    output reg [63:0] round_out,
    output reg [11:0] exponent_final
);

    //--------------------------------------------------------------------------
    // Rounding mode decode (combinational)
    //--------------------------------------------------------------------------
    wire round_nearest    = (round_mode == 2'b00);
    wire round_to_zero    = (round_mode == 2'b01);
    wire round_to_pos_inf = (round_mode == 2'b10);
    wire round_to_neg_inf = (round_mode == 2'b11);

    // mantissa_term[55] = reserved 0
    // mantissa_term[54] = leading integer bit
    // mantissa_term[53:2] = 52-bit mantissa field candidate
    // mantissa_term[1:0] = remainder bits (guard, sticky)

    // Rounding triggers
    wire round_nearest_trigger    = round_nearest    &  mantissa_term[1];
    wire round_to_pos_inf_trigger = round_to_pos_inf & ~sign_term & |mantissa_term[1:0];
    wire round_to_neg_inf_trigger = round_to_neg_inf &  sign_term & |mantissa_term[1:0];

    wire round_trigger = round_nearest_trigger    |
                         round_to_pos_inf_trigger |
                         round_to_neg_inf_trigger;

    // rounding_amount: single 1 aligned with LSB of mantissa field = bit[2]
    wire [55:0] rounding_amount = 56'b0000000000000000000000000000000000000000000000000000100;
    // i.e. {53'b0, 1'b1, 2'b0}

    //--------------------------------------------------------------------------
    // Stage 1: Apply rounding increment → sum_round
    //--------------------------------------------------------------------------
    reg [55:0] sum_round;
    reg [11:0] exponent_round;
    reg        sign_r1;

    wire sum_round_overflow = sum_round[55];

    always @(posedge clk) begin
        if (rst) begin
            sum_round      <= 56'd0;
            exponent_round <= 12'd0;
            sign_r1        <= 1'b0;
        end else begin
            sum_round      <= mantissa_term + (round_trigger ? rounding_amount : 56'd0);
            exponent_round <= exponent_term;
            sign_r1        <= sign_term;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 2: Overflow normalisation
    // If sum_round[55]=1 (carry into reserved bit), shift right 1, exp+1
    //--------------------------------------------------------------------------
    reg [55:0] sum_round_2;
    reg [11:0] exponent_r2;
    reg        sign_r2;

    always @(posedge clk) begin
        if (rst) begin
            sum_round_2  <= 56'd0;
            exponent_r2  <= 12'd0;
            sign_r2      <= 1'b0;
        end else begin
            if (sum_round_overflow) begin
                sum_round_2 <= sum_round >> 1;
                exponent_r2 <= exponent_round + 12'd1;
            end else begin
                sum_round_2 <= sum_round;
                exponent_r2 <= exponent_round;
            end
            sign_r2 <= sign_r1;
        end
    end

    //--------------------------------------------------------------------------
    // Stage 3: Pack final result
    // sum_round_2 layout after normalisation:
    //   [55]    = 0 (reserved / overflow guard, now 0)
    //   [54]    = leading integer bit (hidden bit, not stored)
    //   [53:2]  = 52-bit mantissa field
    //   [1:0]   = remainder (discarded)
    //--------------------------------------------------------------------------
    reg [55:0] sum_final;

    always @(posedge clk) begin
        if (rst) begin
            sum_final      <= 56'd0;
            round_out      <= 64'd0;
            exponent_final <= 12'd0;
        end else begin
            sum_final      <= sum_round_2;
            exponent_final <= exponent_r2;
            // Pack: sign | exponent[10:0] | mantissa[51:0]
            // sum_round_2[53:2] = 52-bit mantissa candidate
            // exponent_r2[10:0] = 11-bit biased exponent
            round_out <= {sign_r2, exponent_r2[10:0], sum_round_2[53:2]};
        end
    end

endmodule