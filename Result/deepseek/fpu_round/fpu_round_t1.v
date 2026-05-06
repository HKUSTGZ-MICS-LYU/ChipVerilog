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
    wire round_to_pos_inf_trigger = ~sign_term & |mantissa_term[1:0];
    wire round_to_neg_inf_trigger = sign_term & |mantissa_term[1:0];

    wire round_trigger = (round_nearest & round_nearest_trigger) |
                         (round_to_pos_inf & round_to_pos_inf_trigger) |
                         (round_to_neg_inf & round_to_neg_inf_trigger);

    reg [55:0] sum_round;
    reg [11:0] exponent_round;
    reg sign_round;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_round <= 56'd0;
            exponent_round <= 12'd0;
            sign_round <= 1'b0;
        end else begin
            sum_round <= mantissa_term + (round_trigger ? rounding_amount : 56'd0);
            exponent_round <= exponent_term;
            sign_round <= sign_term;
        end
    end

    wire sum_round_overflow = sum_round[55];

    reg [55:0] sum_final;
    reg [11:0] exponent_final_internal;
    reg sign_final;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_final <= 56'd0;
            exponent_final_internal <= 12'd0;
            sign_final <= 1'b0;
        end else begin
            if (sum_round_overflow) begin
                sum_final <= {1'b0, sum_round[55:1]};
                exponent_final_internal <= exponent_round + 12'd1;
            end else begin
                sum_final <= sum_round;
                exponent_final_internal <= exponent_round;
            end
            sign_final <= sign_round;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            round_out <= 64'd0;
            exponent_final <= 12'd0;
        end else begin
            round_out <= {sign_final, exponent_final_internal[10:0], sum_final[52:1]};
            exponent_final <= exponent_final_internal;
        end
    end

endmodule
