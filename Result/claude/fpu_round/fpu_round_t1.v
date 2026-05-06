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

    reg [55:0] sum_round, sum_round_2, sum_final;
    reg [11:0] exponent_round;
    
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
    wire sum_round_overflow = sum_round[55];

    always @(posedge clk) begin
        if (rst) begin
            sum_round <= 0;
            sum_round_2 <= 0;
            sum_final <= 0;
            exponent_round <= 0;
            exponent_final <= 0;
            round_out <= 0;
        end else begin
            sum_round <= mantissa_term + rounding_amount;
            sum_round_2 <= sum_round_overflow ? (sum_round >> 1) : sum_round;
            exponent_round <= sum_round_overflow ? (exponent_term + 1) : exponent_term;
            
            if (round_trigger) begin
                sum_final <= sum_round_2;
                exponent_final <= exponent_round;
            end else begin
                sum_final <= mantissa_term;
                exponent_final <= exponent_term;
            end
            
            round_out <= {sign_term, exponent_final[10:0], sum_final[53:2]};
        end
    end

endmodule
