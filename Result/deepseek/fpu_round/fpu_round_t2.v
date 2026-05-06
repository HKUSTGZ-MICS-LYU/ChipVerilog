module fpu_round (
    input clk,
    input rst,
    input enable,
    input [1:0] round_mode,
    input sign_term,
    input [55:0] mantissa_term,
    input [11:0] exponent_term,
    output reg [63:0] round_out,
    output reg [11:0] exponent_final
);

    // Rounding amount constant: 1 at LSB of mantissa
    wire [55:0] rounding_amount = {53'b0, 1'b1, 2'b0};

    // Rounding mode decode
    wire round_nearest    = (round_mode == 2'b00);
    wire round_to_zero    = (round_mode == 2'b01);
    wire round_to_pos_inf = (round_mode == 2'b10);
    wire round_to_neg_inf = (round_mode == 2'b11);

    // Individual rounding triggers
    wire round_nearest_trigger    = round_nearest & mantissa_term[1];
    wire round_to_pos_inf_trigger = round_to_pos_inf & ~sign_term & (|mantissa_term[1:0]);
    wire round_to_neg_inf_trigger = round_to_neg_inf &  sign_term & (|mantissa_term[1:0]);

    // Combined round trigger
    wire round_trigger = (round_nearest    & round_nearest_trigger) |
                         (round_to_pos_inf & round_to_pos_inf_trigger) |
                         (round_to_neg_inf & round_to_neg_inf_trigger);

    // Internal pipeline registers
    reg [55:0] sum_round;
    reg        sum_round_overflow;
    reg [55:0] sum_round_2;
    reg [11:0] exponent_round;

    // First pipeline stage: compute sum with rounding amount
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round          <= 56'd0;
            sum_round_overflow <= 1'b0;
            sum_round_2        <= 56'd0;
            exponent_round     <= 12'd0;
            exponent_final     <= 12'd0;
            round_out          <= 64'd0;
        end else begin
            // Stage 1: add rounding amount if triggered
            if (round_trigger)
                sum_round <= mantissa_term + rounding_amount;
            else
                sum_round <= mantissa_term;

            sum_round_overflow <= sum_round[55];

            // Stage 2: pipeline copy
            sum_round_2    <= sum_round;
            exponent_round <= exponent_term;

            // Stage 3: final exponent and output assembly
            if (sum_round_overflow) begin
                // Mantissa overflow: shift right by 1, increment exponent
                exponent_final <= exponent_round + 12'd1;
                round_out <= {sign_term, exponent_round[10:0] + 11'd1, sum_round_2[54:3]};
            end else begin
                exponent_final <= exponent_round;
                round_out <= {sign_term, exponent_round[10:0], sum_round_2[53:2]};
            end
        end
    end

endmodule
