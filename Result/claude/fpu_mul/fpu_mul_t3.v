module fpu_mul(
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg sign,
    output wire [55:0] product_7,
    output reg [11:0] exponent_5
);

    reg [5:0] product_shift;
    reg [5:0] product_shift_2;
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg a_is_norm;
    reg b_is_norm;
    reg a_is_zero;
    reg b_is_zero;
    reg in_zero;
    reg [11:0] exponent_terms;
    reg [11:0] exponent_under;
    reg [11:0] exponent_1;
    reg [11:0] exponent_2;
    reg [11:0] exponent_3;
    reg [11:0] exponent_4;
    reg [52:0] mul_a;
    reg [52:0] mul_b;
    reg [105:0] product;
    reg [105:0] product_1;
    reg [105:0] product_2;
    reg [105:0] product_3;
    reg [105:0] product_4;
    reg [105:0] product_5;
    reg [105:0] product_6;
    reg product_lsb;
    
    wire [11:0] exponent;
    wire exponent_gt_prodshift;
    
    assign exponent = 12'b0;
    assign exponent_gt_prodshift = (exponent_3 > product_shift_2);
    assign product_7 = { 1'b0, product_6[105:52], product_lsb };

    always @(posedge clk) begin
        if (rst) begin
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            a_is_norm <= 1'b0;
            b_is_norm <= 1'b0;
            a_is_zero <= 1'b0;
            b_is_zero <= 1'b0;
            in_zero <= 1'b0;
            exponent_terms <= 12'b0;
            exponent_under <= 12'b0;
            exponent_1 <= 12'b0;
            exponent_2 <= 12'b0;
            exponent_3 <= 12'b0;
            exponent_4 <= 12'b0;
            mul_a <= 53'b0;
            mul_b <= 53'b0;
            product <= 106'b0;
            product_1 <= 106'b0;
            product_2 <= 106'b0;
            product_3 <= 106'b0;
            product_4 <= 106'b0;
            product_5 <= 106'b0;
            product_6 <= 106'b0;
            product_lsb <= 1'b0;
            product_shift <= 6'b0;
            product_shift_2 <= 6'b0;
            exponent_5 <= 12'b0;
            sign <= 1'b0;
        end
        else if (enable) begin
            sign <= opa[63] ^ opb[63];
            
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            
            a_is_norm <= |opa[62:52];
            b_is_norm <= |opb[62:52];
            a_is_zero <= !(|opa[62:0]);
            b_is_zero <= !(|opb[62:0]);
            in_zero <= a_is_zero | b_is_zero;
            
            mul_a <= a_is_norm ? {1'b1, opa[51:0]} : {1'b0, opa[51:0]};
            mul_b <= b_is_norm ? {1'b1, opb[51:0]} : {1'b0, opb[51:0]};
            
            exponent_terms <= {1'b0, exponent_a} + {1'b0, exponent_b};
            exponent_under <= exponent_terms - 12'd1023;
            
            if (exponent_under < 12'd52) begin
                product <= (mul_a * mul_b) >> exponent_under;
            end else begin
                product <= 106'b0;
            end
            
            product_1 <= product;
            product_2 <= product_1;
            product_3 <= product_2;
            product_4 <= product_3;
            product_5 <= product_4;
            product_6 <= product_5;
            
            product_shift <= 6'b0;
            if (product_6[105:104] != 2'b0) begin
                product_shift <= 6'b0;
            end
            else if (product_6[103]) begin
                product_shift <= 6'd1;
            end
            else if (product_6[102]) begin
                product_shift <= 6'd2;
            end
            
            product_shift_2 <= product_shift;
            
            if (in_zero) begin
                exponent_1 <= 12'b0;
            end else begin
                exponent_1 <= exponent_terms - 12'd1023;
            end
            
            exponent_2 <= exponent_1;
            exponent_3 <= exponent_2;
            
            if (exponent_gt_prodshift) begin
                exponent_4 <= exponent_3 - product_shift_2;
            end else begin
                exponent_4 <= 12'b0;
            end
            
            exponent_5 <= exponent_4;
            
            product_lsb <= |product_6[50:0];
        end
    end

endmodule
