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

wire [55:0] rounding_amount;
wire round_nearest;
wire round_to_zero;
wire round_to_pos_inf;
wire round_to_neg_inf;
wire round_nearest_trigger;
wire round_to_pos_inf_trigger;
wire round_to_neg_inf_trigger;
wire round_trigger;
wire [55:0] sum_round_next;
wire sum_round_overflow_next;
wire [55:0] sum_final_next;
wire [11:0] exponent_final_next;
wire [63:0] round_out_next;
reg [55:0] sum_round;
wire sum_round_overflow;
reg [55:0] sum_round_2;
reg [11:0] exponent_round;
reg [55:0] sum_final;

assign rounding_amount = {53'b0, 1'b1, 2'b0};
assign round_nearest = (round_mode == 2'b00);
assign round_to_zero = (round_mode == 2'b01);
assign round_to_pos_inf = (round_mode == 2'b10);
assign round_to_neg_inf = (round_mode == 2'b11);
assign round_nearest_trigger = round_nearest & mantissa_term[1];
assign round_to_pos_inf_trigger = !sign_term & |mantissa_term[1:0];
assign round_to_neg_inf_trigger = sign_term & |mantissa_term[1:0];
assign round_trigger = (round_nearest & round_nearest_trigger) |
                       (round_to_pos_inf & round_to_pos_inf_trigger) |
                       (round_to_neg_inf & round_to_neg_inf_trigger);
assign sum_round_next = round_trigger ? (mantissa_term + rounding_amount) : mantissa_term;
assign sum_round_overflow_next = sum_round_next[55];
assign sum_final_next = sum_round_overflow_next ? (sum_round_next >> 1) : sum_round_next;
assign exponent_final_next = sum_round_overflow_next ? (exponent_term + 12'd1) : exponent_term;
assign round_out_next = {sign_term, exponent_final_next[10:0], sum_final_next[53:2]};
assign sum_round_overflow = sum_round[55];

always @(posedge clk) begin
    if (rst) begin
        sum_round <= 56'd0;
        sum_round_2 <= 56'd0;
        exponent_round <= 12'd0;
        sum_final <= 56'd0;
        exponent_final <= 12'd0;
        round_out <= 64'd0;
    end else begin
        sum_round <= sum_round_next;
        sum_round_2 <= sum_round_next;
        exponent_round <= exponent_final_next;
        sum_final <= sum_final_next;
        exponent_final <= exponent_final_next;
        round_out <= round_out_next;
    end
end

endmodule
