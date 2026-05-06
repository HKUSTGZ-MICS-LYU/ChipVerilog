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

function [5:0] leading_zeros52;
    input [51:0] value;
    integer i;
    reg found;
    begin
        leading_zeros52 = 6'd52;
        found = 1'b0;
        for (i = 51; i >= 0; i = i - 1) begin
            if (!found && value[i]) begin
                leading_zeros52 = 6'd51 - i;
                found = 1'b1;
            end
        end
    end
endfunction

function [53:0] build_significand54;
    input [10:0] exponent_field;
    input [51:0] fraction_field;
    reg [5:0] shift_amount;
    begin
        if (exponent_field != 11'd0) begin
            build_significand54 = {1'b1, fraction_field, 1'b0};
        end else if (fraction_field != 52'd0) begin
            shift_amount = leading_zeros52(fraction_field) + 6'd1;
            build_significand54 = ({1'b0, fraction_field, 1'b0} << shift_amount);
        end else begin
            build_significand54 = 54'd0;
        end
    end
endfunction

function signed [13:0] effective_exponent;
    input [10:0] exponent_field;
    input [51:0] fraction_field;
    reg [5:0] shift_amount;
    begin
        if (exponent_field != 11'd0) begin
            effective_exponent = $signed({3'b000, exponent_field});
        end else if (fraction_field != 52'd0) begin
            shift_amount = leading_zeros52(fraction_field) + 6'd1;
            effective_exponent = 14'sd1 - $signed({8'd0, shift_amount});
        end else begin
            effective_exponent = 14'sd0;
        end
    end
endfunction

function [55:0] build_mantissa_bundle;
    input [53:0] quotient_value;
    input sticky_in;
    input signed [13:0] exponent_value;
    reg [54:0] packed_value;
    reg [54:0] shifted_value;
    reg lost_bits;
    integer shift_amount;
    integer j;
    begin
        packed_value = {quotient_value, sticky_in};
        if (exponent_value <= 14'sd0) begin
            shift_amount = 1 - exponent_value;
            if (shift_amount >= 55) begin
                build_mantissa_bundle = 56'd0;
                build_mantissa_bundle[0] = |packed_value;
            end else begin
                shifted_value = packed_value >> shift_amount;
                lost_bits = 1'b0;
                for (j = 0; j < 55; j = j + 1) begin
                    if (j < shift_amount) begin
                        lost_bits = lost_bits | packed_value[j];
                    end
                end
                build_mantissa_bundle = {1'b0, shifted_value};
                build_mantissa_bundle[0] = shifted_value[0] | lost_bits;
            end
        end else begin
            build_mantissa_bundle = {1'b0, packed_value};
        end
    end
endfunction

reg enable_d;
reg [63:0] opa_d;
reg [63:0] opb_d;
reg busy;
reg sign_r;
reg a_zero_r;
reg [5:0] count;
reg signed [13:0] exponent_seed_r;
reg [55:0] dividend_r;
reg [55:0] divisor_r;
reg [53:0] quotient_r;
reg [55:0] mantissa_r;

reg [53:0] sig_a;
reg [53:0] sig_b;
reg signed [13:0] exp_a_eff;
reg signed [13:0] exp_b_eff;
reg [53:0] quotient_next;
reg [53:0] quotient_norm;
reg [55:0] dividend_next;
reg [55:0] remainder_now;
reg sticky_now;
reg signed [13:0] exponent_final;

assign sign = sign_r;
assign mantissa_7 = mantissa_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        enable_d <= 1'b0;
        opa_d <= 64'd0;
        opb_d <= 64'd0;
        busy <= 1'b0;
        sign_r <= 1'b0;
        a_zero_r <= 1'b0;
        count <= 6'd0;
        exponent_seed_r <= 14'sd0;
        dividend_r <= 56'd0;
        divisor_r <= 56'd0;
        quotient_r <= 54'd0;
        mantissa_r <= 56'd0;
        exponent_out <= 12'd0;
    end else begin
        enable_d <= enable;
        if (enable) begin
            opa_d <= opa;
            opb_d <= opb;
            sign_r <= opa[63] ^ opb[63];
        end

        if (enable_d && !busy) begin
            sig_a = build_significand54(opa_d[62:52], opa_d[51:0]);
            sig_b = build_significand54(opb_d[62:52], opb_d[51:0]);
            exp_a_eff = effective_exponent(opa_d[62:52], opa_d[51:0]);
            exp_b_eff = effective_exponent(opb_d[62:52], opb_d[51:0]);

            a_zero_r <= (opa_d[62:0] == 63'd0);
            exponent_seed_r <= exp_a_eff + 14'sd1023 - exp_b_eff;
            dividend_r <= {2'b00, sig_a};
            divisor_r <= {2'b00, sig_b};
            quotient_r <= 54'd0;
            count <= 6'd53;
            busy <= 1'b1;
        end else if (busy) begin
            quotient_next = quotient_r;
            if (dividend_r >= divisor_r) begin
                remainder_now = dividend_r - divisor_r;
                quotient_next[count] = 1'b1;
                dividend_next = (dividend_r - divisor_r) << 1;
            end else begin
                remainder_now = dividend_r;
                quotient_next[count] = 1'b0;
                dividend_next = dividend_r << 1;
            end

            quotient_r <= quotient_next;
            dividend_r <= dividend_next;

            if (count == 6'd0) begin
                busy <= 1'b0;
                if (a_zero_r) begin
                    mantissa_r <= 56'd0;
                    exponent_out <= 12'd0;
                end else begin
                    if (quotient_next[53]) begin
                        quotient_norm = quotient_next;
                        exponent_final = exponent_seed_r;
                    end else begin
                        quotient_norm = quotient_next << 1;
                        exponent_final = exponent_seed_r - 14'sd1;
                    end
                    sticky_now = |remainder_now;
                    mantissa_r <= build_mantissa_bundle(quotient_norm, sticky_now, exponent_final);
                    if (exponent_final <= 14'sd0) begin
                        exponent_out <= 12'd0;
                    end else begin
                        exponent_out <= exponent_final[11:0];
                    end
                end
            end else begin
                count <= count - 6'd1;
            end
        end
    end
end

endmodule
