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

    // Internal registers and wires
    reg sign_reg;
    reg [53:0] dividend;
    reg [53:0] divisor_int;
    reg [55:0] quotient;
    reg [5:0] count;
    reg [11:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg [11:0] exp_diff;
    reg [5:0] lza, lzb;
    reg [11:0] exp_a_norm, exp_b_norm;
    reg [53:0] sig_a, sig_b;
    reg [11:0] exponent_reg;
    reg opa_zero;
    reg sticky_reg;

    wire sign_wire;
    assign sign = sign_reg;
    assign sign_wire = opa[63] ^ opb[63];

    // Leading zero detection for denormal handling
    function [5:0] count_leading_zeros;
        input [51:0] fraction;
        integer i;
        begin
            count_leading_zeros = 0;
            for (i = 51; i >= 0; i = i - 1) begin
                if (fraction[i] == 1'b1) begin
                    count_leading_zeros = 51 - i;
                    i = -1;
                end
            end
            if (fraction == 52'b0)
                count_leading_zeros = 52;
        end
    endfunction

    // Stage 1: Input capture and exponent/mantissa extraction
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent_a <= 12'd0;
            exponent_b <= 12'd0;
            mantissa_a <= 52'd0;
            mantissa_b <= 52'd0;
            sign_reg <= 1'b0;
            opa_zero <= 1'b0;
        end else if (enable) begin
            sign_reg <= sign_wire;
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            opa_zero <= (opa[62:52] == 11'd0) && (opa[51:0] == 52'd0);
        end
    end

    // Stage 2: Normalization and significand formation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exp_a_norm <= 12'd0;
            exp_b_norm <= 12'd0;
            lza <= 6'd0;
            lzb <= 6'd0;
        end else if (enable) begin
            if (exponent_a == 11'd0) begin
                lza <= count_leading_zeros(mantissa_a);
                exp_a_norm <= 12'd1 - count_leading_zeros(mantissa_a);
            end else begin
                lza <= 6'd0;
                exp_a_norm <= exponent_a;
            end

            if (exponent_b == 11'd0) begin
                lzb <= count_leading_zeros(mantissa_b);
                exp_b_norm <= 12'd1 - count_leading_zeros(mantissa_b);
            end else begin
                lzb <= 6'd0;
                exp_b_norm <= exponent_b;
            end
        end
    end

    // Stage 3: Build 54-bit significands with implicit bit
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sig_a <= 54'd0;
            sig_b <= 54'd0;
        end else if (enable) begin
            if (exponent_a == 11'd0)
                sig_a <= {mantissa_a, 2'b00} << lza;
            else
                sig_a <= {1'b1, mantissa_a, 1'b0};

            if (exponent_b == 11'd0)
                sig_b <= {mantissa_b, 2'b00} << lzb;
            else
                sig_b <= {1'b1, mantissa_b, 1'b0};
        end
    end

    // Stage 4: Initialize division loop registers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dividend <= 54'd0;
            divisor_int <= 54'd0;
            quotient <= 56'd0;
            count <= 6'd0;
            sticky_reg <= 1'b0;
        end else if (enable) begin
            dividend <= sig_a;
            divisor_int <= sig_b;
            quotient <= 56'd0;
            count <= 6'd53;
            sticky_reg <= 1'b0;
        end else if (count > 0) begin
            if (dividend >= divisor_int) begin
                quotient <= {quotient[54:0], 1'b1};
                dividend <= (dividend - divisor_int) << 1;
            end else begin
                quotient <= {quotient[54:0], 1'b0};
                dividend <= dividend << 1;
            end
            count <= count - 1;
            sticky_reg <= sticky_reg | (|dividend[52:0]);
        end
    end

    // Stage 5: Exponent calculation and output
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exponent_reg <= 12'd0;
            exp_diff <= 12'd0;
        end else if (enable) begin
            exp_diff <= exp_a_norm + 12'd1023 - exp_b_norm;
        end else if (count == 0) begin
            // Adjust exponent based on quotient normalization
            if (quotient[55])
                exponent_reg <= exp_diff + 1;
            else
                exponent_reg <= exp_diff;
        end
    end

    // Output assignments
    assign mantissa_7 = quotient;

    always @(posedge clk or posedge rst) begin
        if (rst)
            exponent_out <= 12'd0;
        else if (count == 0)
            exponent_out <= opa_zero ? 12'd0 : exponent_reg;
    end

endmodule
