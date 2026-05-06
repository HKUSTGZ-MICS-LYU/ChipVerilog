module fpu_round(
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

    reg [55:0] sum_round;
    reg [55:0] sum_round_2;
    reg [11:0] exponent_round;
    reg [55:0] sum_final;
    reg sign_term_r;

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
            exponent_round <= 0;
            sum_final <= 0;
            exponent_final <= 0;
            round_out <= 0;
            sign_term_r <= 0;
        end else begin
            sign_term_r <= sign_term;
            
            if (round_trigger) begin
                sum_round <= mantissa_term + 56'd4;
            end else begin
                sum_round <= mantissa_term;
            end
            
            sum_round_2 <= sum_round;
            exponent_round <= exponent_term;
            
            if (sum_round_overflow) begin
                sum_final <= (sum_round >> 1);
                exponent_final <= exponent_round + 1;
            end else begin
                sum_final <= sum_round;
                exponent_final <= exponent_round;
            end
            
            round_out <= {sign_term_r, exponent_final[10:0], sum_final[52:1]};
        end
    end

endmodule
