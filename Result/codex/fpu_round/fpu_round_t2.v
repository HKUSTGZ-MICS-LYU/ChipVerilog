module fpu_round( clk, rst, enable, round_mode, sign_term, mantissa_term, exponent_term, round_out, exponent_final);

input clk;
input rst;
input enable;
input [1:0] round_mode;
input sign_term;
input [55:0] mantissa_term;
input [11:0] exponent_term;
output reg [63:0] round_out;
output reg [11:0] exponent_final;

wire [55:0] rounding_amount;
wire round_nearest;
wire round_to_zero;
wire round_to_pos_inf;
wire round_to_neg_inf;
wire round_nearest_trigger;
wire round_to_pos_inf_trigger;
wire round_to_neg_inf_trigger;
wire round_trigger;
wire sum_round_overflow;

reg [55:0] sum_round;
reg [55:0] sum_round_2;
reg [11:0] exponent_round;
reg [55:0] sum_final;

assign rounding_amount = {53'b0, 1'b1, 2'b0};
assign round_nearest = (round_mode == 2'b00);
assign round_to_zero = (round_mode == 2'b01);
assign round_to_pos_inf = (round_mode == 2'b10);
assign round_to_neg_inf = (round_mode == 2'b11);
assign round_nearest_trigger = round_nearest & mantissa_term[1];
assign round_to_pos_inf_trigger = !sign_term & (|mantissa_term[1:0]);
assign round_to_neg_inf_trigger = sign_term & (|mantissa_term[1:0]);
assign round_trigger = (round_nearest & round_nearest_trigger) |
                       (round_to_pos_inf & round_to_pos_inf_trigger) |
                       (round_to_neg_inf & round_to_neg_inf_trigger);
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
        sum_round <= mantissa_term + rounding_amount;
        if (sum_round_overflow) begin
            sum_round_2 <= sum_round >> 1;
            exponent_round <= exponent_term + 12'd1;
        end else begin
            sum_round_2 <= sum_round;
            exponent_round <= exponent_term;
        end

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
