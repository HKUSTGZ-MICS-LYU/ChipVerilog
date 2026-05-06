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
    always @* begin
        if (round_trigger)
            sum_round = mantissa_term + rounding_amount;
        else
            sum_round = mantissa_term;
    end

    reg [55:0] sum_round_2;
    reg [11:0] exponent_round;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round_2 <= 56'b0;
            exponent_round <= 12'b0;
        end else begin
            sum_round_2 <= sum_round;
            exponent_round <= exponent_term;
        end
    end

    reg [55:0] sum_final;
    reg [11:0] exponent_final_int;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_final <= 56'b0;
            exponent_final_int <= 12'b0;
        end else begin
            if (sum_round_2[55]) begin
                sum_final <= sum_round_2 >> 1;
                exponent_final_int <= exponent_round + 1'b1;
            end else begin
                sum_final <= sum_round_2;
                exponent_final_int <= exponent_round;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            round_out <= 64'b0;
            exponent_final <= 12'b0;
        end else begin
            round_out[63] <= sign_term;
            round_out[62:52] <= exponent_final_int[10:0];
            if (sum_round_2[55])
                round_out[51:0] <= sum_final[53:2];
            else
                round_out[51:0] <= sum_final[54:3];
            exponent_final <= exponent_final_int;
        end
    end

endmodule
