module fpu_div(
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output wire sign,
    output reg [55:0] mantissa_7,
    output reg [11:0] exponent_out
);

    reg [53:0] dividend_reg;
    reg [53:0] divisor_reg;
    reg [53:0] quotient;
    reg [53:0] quotient_out;
    reg [53:0] remainder;
    reg [53:0] remainder_out;
    reg remainder_msb;
    reg [5:0] count_out;
    reg [11:0] exponent_temp;
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg enable_reg;
    reg [51:0] mantissa_1;
    
    wire [10:0] expon_a;
    wire [10:0] expon_b;
    wire a_is_norm;
    wire b_is_norm;
    wire [11:0] exponent_a;
    wire [11:0] exponent_b;
    wire [53:0] dividend_1;
    wire [53:0] divisor_1;
    wire [51:0] mantissa_2;
    wire [55:0] remainder_temp;
    wire quotient_msb;
    wire m_norm;
    wire rem_lsb;

    assign sign = opa[63] ^ opb[63];
    assign expon_a = opa[62:52];
    assign expon_b = opb[62:52];
    assign a_is_norm = |expon_a;
    assign b_is_norm = |expon_b;
    assign exponent_a = { 1'b0, expon_a };
    assign exponent_b = { 1'b0, expon_b };
    
    assign dividend_1 = a_is_norm ? { 2'b01, mantissa_a } : { 1'b0, mantissa_a, 1'b0 };
    assign divisor_1 = b_is_norm ? { 2'b01, mantissa_b } : { 1'b0, mantissa_b, 1'b0 };
    
    assign mantissa_2 = quotient_out[52:1];
    assign quotient_msb = quotient_out[53];
    assign m_norm = |exponent_temp;
    assign rem_lsb = |remainder_out[52:0];
    assign remainder_temp = { quotient_out[0], remainder_msb, remainder_out[52:0], 1'b0 };

    always @(posedge clk) begin
        if (rst) begin
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            dividend_reg <= 54'b0;
            divisor_reg <= 54'b0;
            quotient <= 54'b0;
            quotient_out <= 54'b0;
            remainder <= 54'b0;
            remainder_out <= 54'b0;
            remainder_msb <= 1'b0;
            count_out <= 6'b0;
            exponent_temp <= 12'b0;
            exponent_out <= 12'b0;
            mantissa_7 <= 56'b0;
            enable_reg <= 1'b0;
            mantissa_1 <= 52'b0;
        end
        else if (enable) begin
            enable_reg <= 1'b1;
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            
            dividend_reg <= dividend_1;
            divisor_reg <= divisor_1;
            
            if (count_out == 0) begin
                count_out <= 6'd53;
                quotient <= 54'b0;
                remainder <= dividend_1;
            end else begin
                count_out <= count_out - 1;
                
                if (remainder >= divisor_reg) begin
                    quotient <= (quotient << 1) | 54'b1;
                    remainder <= (remainder - divisor_reg) << 1;
                end else begin
                    quotient <= quotient << 1;
                    remainder <= remainder << 1;
                end
            end
            
            quotient_out <= quotient;
            remainder_out <= remainder;
            remainder_msb <= remainder[53];
            
            exponent_temp <= exponent_a - exponent_b + 12'd1023;
            exponent_out <= exponent_temp;
            
            mantissa_1 <= quotient_msb ? mantissa_2 : quotient_out[51:0];
            
            mantissa_7 <= { 1'b0, m_norm, mantissa_1, remainder_temp[55], rem_lsb };
        end
    end

endmodule
