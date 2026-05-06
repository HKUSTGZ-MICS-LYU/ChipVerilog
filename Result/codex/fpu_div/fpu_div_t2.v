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

function [5:0] lzc52;
    input [51:0] value;
    integer i;
    reg found;
    begin
        lzc52 = 6'd52;
        found = 1'b0;
        for (i = 51; i >= 0; i = i - 1) begin
            if (!found && value[i]) begin
                lzc52 = 6'd51 - i;
                found = 1'b1;
            end
        end
    end
endfunction

reg [55:0] mantissa_7_reg;
reg [1:0] en_pipe;
reg [63:0] opa_p1;
reg [63:0] opb_p1;
reg [63:0] opa_p2;
reg [63:0] opb_p2;

reg running;
reg [5:0] count_reg;
reg [53:0] dividend_reg;
reg [53:0] divisor_reg;
reg [53:0] quotient_reg;
reg signed [13:0] exp_base_reg;

reg [10:0] expa;
reg [10:0] expb;
reg [51:0] fraca;
reg [51:0] fracb;
reg a_denorm;
reg b_denorm;
reg [5:0] shift_a;
reg [5:0] shift_b;
reg [52:0] sig_a53;
reg [52:0] sig_b53;
reg signed [13:0] exp_base_tmp;
reg a_zero_now;

reg [53:0] q_final;
reg [53:0] rem_final;
reg lead_bit;
reg [51:0] mant_field;
reg guard_bit;
reg sticky_bit;
reg next_qbit;
reg [54:0] rem_scaled;
reg [54:0] rem_after_guard;
reg signed [13:0] exp_work;
reg [53:0] norm_pack;
reg [53:0] shifted_pack;
reg sticky_accum;
integer shift_amt_i;
integer j;

wire cmp_ge_w;
wire [53:0] sub_w;
wire [53:0] rem_w;
wire [53:0] dividend_next_w;

assign cmp_ge_w = (dividend_reg >= divisor_reg);
assign sub_w = dividend_reg - divisor_reg;
assign rem_w = cmp_ge_w ? sub_w : dividend_reg;
assign dividend_next_w = {rem_w[52:0], 1'b0};

assign sign = opa[63] ^ opb[63];
assign mantissa_7 = mantissa_7_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        en_pipe <= 2'b00;
        opa_p1 <= 64'd0;
        opb_p1 <= 64'd0;
        opa_p2 <= 64'd0;
        opb_p2 <= 64'd0;
        running <= 1'b0;
        count_reg <= 6'd0;
        dividend_reg <= 54'd0;
        divisor_reg <= 54'd0;
        quotient_reg <= 54'd0;
        exp_base_reg <= 14'sd0;
        mantissa_7_reg <= 56'd0;
        exponent_out <= 12'd0;
    end else begin
        en_pipe <= {en_pipe[0], enable};
        if (enable) begin
            opa_p1 <= opa;
            opb_p1 <= opb;
        end
        if (en_pipe[0]) begin
            opa_p2 <= opa_p1;
            opb_p2 <= opb_p1;
        end

        if (en_pipe[1]) begin
            expa = opa_p2[62:52];
            expb = opb_p2[62:52];
            fraca = opa_p2[51:0];
            fracb = opb_p2[51:0];

            a_zero_now = (opa_p2[62:0] == 63'd0);
            a_denorm = (expa == 11'd0) && (fraca != 52'd0);
            b_denorm = (expb == 11'd0) && (fracb != 52'd0);

            shift_a = a_denorm ? (lzc52(fraca) + 6'd1) : 6'd0;
            shift_b = b_denorm ? (lzc52(fracb) + 6'd1) : 6'd0;

            if (expa != 11'd0) begin
                sig_a53 = {1'b1, fraca};
            end else if (a_denorm) begin
                sig_a53 = ({1'b0, fraca} << shift_a);
            end else begin
                sig_a53 = 53'd0;
            end

            if (expb != 11'd0) begin
                sig_b53 = {1'b1, fracb};
            end else if (b_denorm) begin
                sig_b53 = ({1'b0, fracb} << shift_b);
            end else begin
                sig_b53 = 53'd0;
            end

            exp_base_tmp = $signed({1'b0, expa}) + 14'sd1023 - $signed({1'b0, expb});
            if (a_denorm) begin
                exp_base_tmp = exp_base_tmp + 14'sd1 - $signed({8'd0, shift_a});
            end
            if (b_denorm) begin
                exp_base_tmp = exp_base_tmp - 14'sd1 + $signed({8'd0, shift_b});
            end

            if (a_zero_now) begin
                running <= 1'b0;
                count_reg <= 6'd0;
                dividend_reg <= 54'd0;
                divisor_reg <= 54'd0;
                quotient_reg <= 54'd0;
                exp_base_reg <= 14'sd0;
                exponent_out <= 12'd0;
                mantissa_7_reg <= 56'd0;
            end else begin
                running <= 1'b1;
                count_reg <= 6'd53;
                dividend_reg <= {sig_a53, 1'b0};
                divisor_reg <= {sig_b53, 1'b0};
                quotient_reg <= 54'd0;
                exp_base_reg <= exp_base_tmp;
            end
        end else if (running) begin
            quotient_reg[count_reg] <= cmp_ge_w;
            dividend_reg <= dividend_next_w;

            if (count_reg == 6'd0) begin
                running <= 1'b0;

                q_final = {quotient_reg[53:1], cmp_ge_w};
                rem_final = rem_w;

                rem_scaled = {rem_final, 1'b0};
                if (rem_scaled >= {1'b0, divisor_reg}) begin
                    next_qbit = 1'b1;
                    rem_after_guard = rem_scaled - {1'b0, divisor_reg};
                end else begin
                    next_qbit = 1'b0;
                    rem_after_guard = rem_scaled;
                end

                lead_bit = q_final[53];
                if (lead_bit) begin
                    mant_field = q_final[52:1];
                    guard_bit = q_final[0];
                    sticky_bit = |rem_after_guard;
                end else begin
                    mant_field = q_final[51:0];
                    guard_bit = next_qbit;
                    sticky_bit = |rem_after_guard;
                end

                exp_work = exp_base_reg - (lead_bit ? 14'sd0 : 14'sd1);
                norm_pack = {lead_bit, mant_field, guard_bit};
                shifted_pack = norm_pack;
                sticky_accum = sticky_bit;

                if (exp_work <= 14'sd0) begin
                    shift_amt_i = 1 - exp_work;
                    for (j = 0; j < 54; j = j + 1) begin
                        if (j < shift_amt_i) begin
                            sticky_accum = sticky_accum | shifted_pack[0];
                            shifted_pack = {1'b0, shifted_pack[53:1]};
                        end
                    end
                    exponent_out <= 12'd0;
                end else if (exp_work > 14'sd4095) begin
                    exponent_out <= 12'hfff;
                end else begin
                    exponent_out <= exp_work[11:0];
                end

                mantissa_7_reg <= {1'b0, shifted_pack[53], shifted_pack[52:1], shifted_pack[0], sticky_accum};
            end else begin
                count_reg <= count_reg - 6'd1;
            end
        end
    end
end

endmodule
