// Auto-generated from local textual module descriptions.
// Source files: description.txt + detail.txt
// This file is standalone and does not depend on paths outside this directory.
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

wire [55:0] rounding_amount = {53'b0, 1'b1, 2'b0};
wire round_nearest = (round_mode == 2'b00);
wire round_to_zero = (round_mode == 2'b01);
wire round_to_pos_inf = (round_mode == 2'b10);
wire round_to_neg_inf = (round_mode == 2'b11);
wire round_nearest_trigger = round_nearest & mantissa_term[1];
wire round_to_pos_inf_trigger = !sign_term & |mantissa_term[1:0];
wire round_to_neg_inf_trigger = sign_term & |mantissa_term[1:0];
wire round_trigger =
    (round_nearest & round_nearest_trigger) |
    (round_to_pos_inf & round_to_pos_inf_trigger) |
    (round_to_neg_inf & round_to_neg_inf_trigger);
reg [55:0] sum_round;
wire sum_round_overflow = sum_round[55];
reg [55:0] sum_round_2;
reg [11:0] exponent_round;
reg [55:0] sum_final;

always @(posedge clk) begin
    if (rst) begin
        sum_round <= 56'b0;
        sum_round_2 <= 56'b0;
        exponent_round <= 12'b0;
        sum_final <= 56'b0;
        round_out <= 64'b0;
        exponent_final <= 12'b0;
    end else begin
        sum_round <= mantissa_term + rounding_amount;
        sum_round_2 <= sum_round_overflow ? (sum_round >> 1) : sum_round;
        exponent_round <= sum_round_overflow ? (exponent_term + 12'd1) : exponent_term;
        sum_final <= round_trigger ? sum_round_2 : mantissa_term;
        exponent_final <= round_trigger ? exponent_round : exponent_term;
        round_out <= {sign_term, exponent_final[10:0], sum_final[53:2]};
    end
end

endmodule
