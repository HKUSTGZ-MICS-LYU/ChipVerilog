module fpu_div (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output sign,
    output [55:0] mantissa_7,
    output reg [11:0] exponent_out
);

function [5:0] leading_zero52;
    input [51:0] value;
    integer idx;
    begin
        leading_zero52 = 6'd52;
        for (idx = 51; idx >= 0; idx = idx - 1) begin
            if ((value[idx] == 1'b1) && (leading_zero52 == 6'd52)) begin
                leading_zero52 = 6'd51 - idx;
            end
        end
    end
endfunction

reg [63:0] opa_d;
reg [63:0] opb_d;
reg enable_d;
reg running;
reg sign_reg;
reg [55:0] mantissa_reg;
reg [53:0] dividend_reg;
reg [53:0] divisor_reg;
reg [53:0] quotient_reg;
reg [5:0] count;
reg signed [13:0] exp_base_reg;

reg compare_bit;
reg [53:0] dividend_next;
reg [53:0] quotient_next;
reg [53:0] quotient_work;
reg [53:0] quotient_aligned;
reg [53:0] sticky_mask;
reg sticky_work;
reg sticky_final;
reg signed [13:0] exp_work;
integer denorm_shift;

wire [10:0] expa_field_d = opa_d[62:52];
wire [10:0] expb_field_d = opb_d[62:52];
wire [51:0] fraca_d = opa_d[51:0];
wire [51:0] fracb_d = opb_d[51:0];
wire expa_denorm = (expa_field_d == 11'd0);
wire expb_denorm = (expb_field_d == 11'd0);
wire a_zero_w = expa_denorm && (fraca_d == 52'd0);
wire b_zero_w = expb_denorm && (fracb_d == 52'd0);
wire [5:0] shift_a_w = (expa_denorm && !a_zero_w) ? (leading_zero52(fraca_d) + 6'd1) : 6'd0;
wire [5:0] shift_b_w = (expb_denorm && !b_zero_w) ? (leading_zero52(fracb_d) + 6'd1) : 6'd0;
wire [52:0] sig_a_core_w = a_zero_w ? 53'd0 : (expa_denorm ? (({1'b0, fraca_d}) << shift_a_w) : {1'b1, fraca_d});
wire [52:0] sig_b_core_w = b_zero_w ? 53'd0 : (expb_denorm ? (({1'b0, fracb_d}) << shift_b_w) : {1'b1, fracb_d});
wire [53:0] sig_a_w = {sig_a_core_w, 1'b0};
wire [53:0] sig_b_w = {sig_b_core_w, 1'b0};
wire signed [13:0] exp_init_w =
    $signed({3'b000, (expa_denorm ? 11'd1 : expa_field_d)}) +
    14'sd1023 -
    $signed({3'b000, (expb_denorm ? 11'd1 : expb_field_d)}) -
    $signed({8'd0, shift_a_w}) +
    $signed({8'd0, shift_b_w});

assign sign = sign_reg;
assign mantissa_7 = mantissa_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        opa_d <= 64'd0;
        opb_d <= 64'd0;
        enable_d <= 1'b0;
        running <= 1'b0;
        sign_reg <= 1'b0;
        mantissa_reg <= 56'd0;
        exponent_out <= 12'd0;
        dividend_reg <= 54'd0;
        divisor_reg <= 54'd0;
        quotient_reg <= 54'd0;
        count <= 6'd0;
        exp_base_reg <= 14'sd0;
        compare_bit <= 1'b0;
        dividend_next <= 54'd0;
        quotient_next <= 54'd0;
        quotient_work <= 54'd0;
        quotient_aligned <= 54'd0;
        sticky_mask <= 54'd0;
        sticky_work <= 1'b0;
        sticky_final <= 1'b0;
        exp_work <= 14'sd0;
        denorm_shift <= 0;
    end else begin
        if (enable && !running && !enable_d) begin
            opa_d <= opa;
            opb_d <= opb;
            enable_d <= 1'b1;
        end else begin
            enable_d <= 1'b0;
        end

        if (enable_d && !running) begin
            sign_reg <= opa_d[63] ^ opb_d[63];
            if (a_zero_w) begin
                running <= 1'b0;
                dividend_reg <= 54'd0;
                divisor_reg <= 54'd0;
                quotient_reg <= 54'd0;
                count <= 6'd0;
                exp_base_reg <= 14'sd0;
                mantissa_reg <= 56'd0;
                exponent_out <= 12'd0;
            end else begin
                running <= 1'b1;
                dividend_reg <= sig_a_w;
                divisor_reg <= (sig_b_w == 54'd0) ? 54'd1 : sig_b_w;
                quotient_reg <= 54'd0;
                count <= 6'd53;
                exp_base_reg <= exp_init_w;
            end
        end else if (running) begin
            compare_bit = (dividend_reg >= divisor_reg);
            if (compare_bit) begin
                dividend_next = (dividend_reg - divisor_reg) << 1;
            end else begin
                dividend_next = dividend_reg << 1;
            end

            quotient_next = quotient_reg;
            quotient_next[count] = compare_bit;

            if (count == 6'd0) begin
                running <= 1'b0;
                dividend_reg <= dividend_next;
                quotient_reg <= quotient_next;

                quotient_work = quotient_next;
                exp_work = exp_base_reg;
                sticky_work = |dividend_next;

                if ((quotient_work[53] == 1'b0) && (|quotient_work)) begin
                    quotient_work = quotient_work << 1;
                    exp_work = exp_work - 14'sd1;
                end

                quotient_aligned = quotient_work;
                sticky_final = sticky_work;

                if (exp_work <= 14'sd0) begin
                    denorm_shift = 1 - exp_work;
                    exponent_out <= 12'd0;
                    if (denorm_shift >= 54) begin
                        sticky_final = sticky_work | (|quotient_work);
                        quotient_aligned = 54'd0;
                    end else begin
                        sticky_mask = (54'd1 << denorm_shift) - 54'd1;
                        sticky_final = sticky_work | (|(quotient_work & sticky_mask));
                        quotient_aligned = quotient_work >> denorm_shift;
                    end
                end else begin
                    exponent_out <= exp_work[11:0];
                end

                mantissa_reg <= {1'b0, quotient_aligned[53], quotient_aligned[52:1], quotient_aligned[0], sticky_final};
            end else begin
                dividend_reg <= dividend_next;
                quotient_reg <= quotient_next;
                count <= count - 6'd1;
            end
        end
    end
end

endmodule
