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
wire round_trigger = (round_nearest & round_nearest_trigger) |
                     (round_to_pos_inf & round_to_pos_inf_trigger) |
                     (round_to_neg_inf & round_to_neg_inf_trigger);

reg [55:0] sum_round;
wire sum_round_overflow = sum_round[55];
reg [55:0] sum_round_2;
reg [11:0] exponent_round;
reg [55:0] sum_final;

wire [55:0] sum_round_next = mantissa_term + (round_trigger ? rounding_amount : 56'b0);
wire sum_round_next_overflow = sum_round_next[55];
wire [55:0] sum_final_next = sum_round_next_overflow ? {1'b0, sum_round_next[55:1]} : sum_round_next;
wire [11:0] exponent_next = exponent_term + (sum_round_next_overflow ? 12'd1 : 12'd0);
wire [63:0] round_out_next = {sign_term, exponent_next[10:0], sum_final_next[53:2]};
wire _unused = enable ^ round_to_zero ^ sum_round_overflow ^ sum_round_2[0] ^ exponent_round[0];

always @(posedge clk) begin
    if (rst) begin
        sum_round <= 56'b0;
        sum_round_2 <= 56'b0;
        exponent_round <= 12'b0;
        sum_final <= 56'b0;
        exponent_final <= 12'b0;
        round_out <= 64'b0;
    end else begin
        sum_round <= sum_round_next;
        sum_round_2 <= sum_round_next;
        exponent_round <= exponent_next;
        sum_final <= sum_final_next;
        exponent_final <= exponent_next;
        round_out <= round_out_next;
    end
end

endmodule
