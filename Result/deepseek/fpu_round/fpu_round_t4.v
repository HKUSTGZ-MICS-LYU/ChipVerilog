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
    reg [11:0] exponent_final_reg;    // internal copy for exponent_final
    reg [63:0] round_out;

    wire overflow = sum_round[55];
    wire [55:0] sum_final_comb = overflow ? {1'b1, sum_round[55:1]} : sum_round;
    wire [11:0] exponent_final_comb = exponent_round + (overflow ? 12'd1 : 12'd0);
    wire [63:0] round_out_comb = {sign_term, exponent_final_comb[10:0], sum_final_comb[54:3]};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round <= 56'd0;
            sum_round_2 <= 56'd0;
            exponent_round <= 12'd0;
            sum_final <= 56'd0;
            exponent_final_reg <= 12'd0;
            round_out <= 64'd0;
        end else begin
            sum_round <= mantissa_term + (round_trigger ? rounding_amount : 56'd0);
            exponent_round <= exponent_term;
            sum_round_2 <= sum_round;
            sum_final <= sum_final_comb;
            exponent_final_reg <= exponent_final_comb;
            round_out <= round_out_comb;
        end
    end

    assign exponent_final = exponent_final_reg;

endmodule
