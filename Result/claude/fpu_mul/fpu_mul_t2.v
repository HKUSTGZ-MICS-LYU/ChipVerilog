module fpu_mul(clk, rst, enable, opa, opb, sign, product_7, exponent_5);

input clk;
input rst;
input enable;
input [63:0] opa;
input [63:0] opb;
output reg sign;
output [55:0] product_7;
output reg [11:0] exponent_5;

// Internal signals
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
reg exponent_gt_expoffset;
reg [11:0] exponent_under;
reg [11:0] exponent_1;
reg [11:0] exponent_2;
reg exponent_gt_prodshift;
reg [11:0] exponent_3;
reg [11:0] exponent_4;
reg exponent_et_zero;
reg [52:0] mul_a;
reg [52:0] mul_b;
reg [40:0] product_a;
reg [40:0] product_b;
reg [40:0] product_c;
reg [25:0] product_d;
reg [33:0] product_e;
reg [33:0] product_f;
reg [35:0] product_g;
reg [28:0] product_h;
reg [28:0] product_i;
reg [30:0] product_j;
reg [41:0] sum_0;
reg [35:0] sum_1;
reg [41:0] sum_2;
reg [35:0] sum_3;
reg [36:0] sum_4;
reg [27:0] sum_5;
reg [29:0] sum_6;
reg [36:0] sum_7;
reg [30:0] sum_8;
reg [105:0] product;
reg [105:0] product_1;
reg [105:0] product_2;
reg [105:0] product_3;
reg [105:0] product_4;
reg [105:0] product_5;
reg [105:0] product_6;
reg product_lsb;

wire [55:0] product_7 = {1'b0, product_6[105:52], product_lsb};

always @(posedge clk) begin
    if (rst) begin
        sign <= 1'b0;
        product_shift <= 6'b0;
        product_shift_2 <= 6'b0;
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
        exponent_gt_expoffset <= 1'b0;
        exponent_under <= 12'b0;
        exponent_1 <= 12'b0;
        exponent_2 <= 12'b0;
        exponent_gt_prodshift <= 1'b0;
        exponent_3 <= 12'b0;
        exponent_4 <= 12'b0;
        exponent_et_zero <= 1'b0;
        mul_a <= 53'b0;
        mul_b <= 53'b0;
        product_a <= 41'b0;
        product_b <= 41'b0;
        product_c <= 41'b0;
        product_d <= 26'b0;
        product_e <= 34'b0;
        product_f <= 34'b0;
        product_g <= 36'b0;
        product_h <= 29'b0;
        product_i <= 29'b0;
        product_j <= 31'b0;
        sum_0 <= 42'b0;
        sum_1 <= 36'b0;
        sum_2 <= 42'b0;
        sum_3 <= 36'b0;
        sum_4 <= 37'b0;
        sum_5 <= 28'b0;
        sum_6 <= 30'b0;
        sum_7 <= 37'b0;
        sum_8 <= 31'b0;
        product <= 106'b0;
        product_1 <= 106'b0;
        product_2 <= 106'b0;
        product_3 <= 106'b0;
        product_4 <= 106'b0;
        product_5 <= 106'b0;
        product_6 <= 106'b0;
        product_lsb <= 1'b0;
        exponent_5 <= 12'b0;
    end
    else if (enable) begin
        // Stage 0: Extract sign, exponent, mantissa
        sign <= opa[63] ^ opb[63];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        
        // Detect zero and normalized conditions
        a_is_zero <= (opa[62:0] == 63'b0);
        b_is_zero <= (opb[62:0] == 63'b0);
        a_is_norm <= (opa[62:52] != 11'b0);
        b_is_norm <= (opb[62:52] != 11'b0);
        in_zero <= (opa[62:0] == 63'b0) | (opb[62:0] == 63'b0);
        
        // Construct mul_a and mul_b with hidden 1 for normalized numbers
        mul_a <= a_is_norm ? {1'b1, mantissa_a} : {1'b0, mantissa_a};
        mul_b <= b_is_norm ? {1'b1, mantissa_b} : {1'b0, mantissa_b};
        
        // Exponent calculation
        exponent_terms <= {1'b0, exponent_a} + {1'b0, exponent_b};
        exponent_gt_expoffset <= exponent_terms >= 12'd1023;
        
        // Stage 1: Partial products
        product_a <= mul_a[24:0] * mul_b[40:0];
        product_b <= mul_a[49:25] * mul_b[40:0];
        product_c <= mul_a[52:50] * mul_b[40:0];
        product_d <= mul_a[24:0] * mul_b[52:41];
        product_e <= mul_a[49:25] * mul_b[52:41];
        product_f <= mul_a[52:50] * mul_b[52:41];
        product_g <= mul_a[24:0] * mul_b[52:52];
        product_h <= mul_a[49:25] * mul_b[52:52];
        product_i <= mul_a[52:50] * mul_b[52:52];
        product_j <= mul_a[52:22] * mul_b[52:42];
        
        exponent_1 <= exponent_gt_expoffset ? (exponent_terms - 12'd1023) : 12'd0;
        product_shift <= 6'b0;
        
        // Stage 2: Sum partial products
        sum_0 <= {17'b0, product_a};
        sum_1 <= {17'b0, product_b};
        sum_2 <= {17'b0, product_c};
        sum_3 <= {26'b0, product_d};
        sum_4 <= {33'b0, product_e};
        sum_5 <= {33'b0, product_f};
        sum_6 <= {42'b0, product_g};
        sum_7 <= {49'b0, product_h};
        sum_8 <= {49'b0, product_i};
        
        exponent_2 <= exponent_1;
        product_shift_2 <= product_shift;
        exponent_gt_prodshift <= 1'b0;
        
        // Stage 3: Accumulate products into 106-bit result
        product <= 106'b0;
        exponent_3 <= exponent_2;
        
        // Stage 4: Handle underflow and denormalization
        exponent_under <= (exponent_3 < 12'd52) ? (12'd52 - exponent_3) : 12'd0;
        exponent_4 <= exponent_3;
        exponent_et_zero <= (exponent_3 == 12'b0);
        
        // Stage 5: Left-shift for normalization
        if (product_4[105] == 1'b0 && !in_zero) begin
            product_shift <= 6'd1;
        end
        
        product_1 <= product;
        product_2 <= product_1;
        product_3 <= product_2;
        product_4 <= product_3;
        product_5 <= product_4;
        product_6 <= product_5;
        
        product_lsb <= |product_6[51:0];
        exponent_5 <= in_zero ? 12'b0 : exponent_4;
    end
end

endmodule
