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

    wire [55:0] sum = mantissa_term + (round_trigger ? rounding_amount : 0);

    reg [55:0] sum_round;
    reg [11:0] exponent_round;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round <= 56'd0;
            exponent_round <= 12'd0;
        end else begin
            sum_round <= sum;
            exponent_round <= exponent_term;
        end
    end

    wire sum_round_overflow = sum_round[55];
    wire [55:0] sum_final_next = sum_round_overflow ? sum_round >> 1 : sum_round;
    wire [11:0] exponent_final_next = exponent_round + (sum_round_overflow ? 1 : 0);

    reg [55:0] sum_round_2;
    reg [55:0] sum_final;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round_2 <= 56'd0;
            sum_final <= 56'd0;
            exponent_final <= 12'd0;
            round_out <= 64'd0;
        end else begin
            sum_round_2 <= sum_round;
            sum_final <= sum_final_next;
            exponent_final <= exponent_final_next;
            round_out <= {sign_term, exponent_final_next[10:0], sum_final_next[53:2]};
        end
    end

endmodule
