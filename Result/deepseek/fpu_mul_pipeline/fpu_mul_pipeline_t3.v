`timescale 1ns / 1ps
module fpu_mul_pipeline (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output ready,
    output [63:0] outfp
);

reg product_shift;
reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;
reg sign;
reg sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10, sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;
reg [51:0] mantissa_a1, mantissa_a2, mantissa_b1, mantissa_b2;
reg [10:0] exponent_a, exponent_b;
reg ready;
reg count_ready;
reg count_ready_0;
reg [4:0] count;
reg a_is_zero, b_is_zero, a_is_inf, b_is_inf;
reg in_inf_1, in_inf_2;
reg in_zero_1;
reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3, exponent_terms_4, exponent_terms_5, exponent_terms_6, exponent_terms_7, exponent_terms_8, exponent_terms_9;
reg exponent_gt_expoffset;
reg [11:0] exponent_1, exponent_2, exponent_2_0, exponent_2_1, exponent_3, exponent_4, exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;
reg exponent_gt_prodshift;
reg exponent_is_infinity;
reg set_mantissa_zero;
reg set_mz_1;
reg [52:0] mul_a, mul_b;
reg [52:0] mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
reg [52:0] mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;
reg [40:0] product_a, product_b;
reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5, product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
reg [40:0] product_c;
reg [25:0] product_d;
reg [33:0] product_e, product_f;
reg [35:0] product_g;
reg [28:0] product_h, product_i;
reg [30:0] product_j;
reg [41:0] sum_0;
reg [6:0] sum_0_2, sum_0_3, sum_0_4, sum_0_5, sum_0_6, sum_0_7, sum_0_8, sum_0_9;
reg [35:0] sum_1;
reg [9:0] sum_1_2, sum_1_3, sum_1_4, sum_1_5, sum_1_6, sum_1_7, sum_1_8;
reg [41:0] sum_2;
reg [6:0] sum_2_2, sum_2_3, sum_2_4, sum_2_5, sum_2_6, sum_2_7;
reg [35:0] sum_3;
reg [36:0] sum_4;
reg [9:0] sum_4_2, sum_4_3, sum_4_4, sum_4_5;
reg [27:0] sum_5;
reg [6:0] sum_5_2, sum_5_3, sum_5_4;
reg [29:0] sum_6;
reg [36:0] sum_7;
reg [16:0] sum_7_2;
reg [30:0] sum_8;
reg [105:0] product, product_1;
reg [52:0] product_2, product_3;
reg [53:0] product_4, product_5, product_6, product_7;
reg product_overflow;
reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
reg round_posinf_trigger, round_posinf_enable;
reg round_neginf_trigger, round_neginf_enable;
reg round_enable;

wire [11:0] exponent = 0; // placeholder

assign outfp = {sign, exponent_9[10:0], product_7[51:0]};

// Internal combinational wires for compute
wire sign_a = opa[63];
wire sign_b = opb[63];
wire [10:0] exp_a = opa[62:52];
wire [10:0] exp_b = opb[62:52];
wire [51:0] mant_a = opa[51:0];
wire [51:0] mant_b = opb[51:0];

wire opa_zero = (exp_a == 11'd0) && (mant_a == 52'd0);
wire opb_zero = (exp_b == 11'd0) && (mant_b == 52'd0);
wire opa_inf = (exp_a == 11'h7FF) && (mant_a == 52'd0);
wire opb_inf = (exp_b == 11'h7FF) && (mant_b == 52'd0);

wire [52:0] sig_a = opa_zero ? 53'd0 : {1'b1, mant_a};
wire [52:0] sig_b = opb_zero ? 53'd0 : {1'b1, mant_b};

wire [105:0] product_full = sig_a * sig_b;

// Rounding constants
wire guard_bit = product_7[52];
wire round_bit = product_7[51];
wire sticky_bit = |product_7[50:0];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset all registers
        rm_1 <= 0; rm_2 <= 0; rm_3 <= 0; rm_4 <= 0; rm_5 <= 0;
        rm_6 <= 0; rm_7 <= 0; rm_8 <= 0; rm_9 <= 0; rm_10 <= 0;
        rm_11 <= 0; rm_12 <= 0; rm_13 <= 0; rm_14 <= 0; rm_15 <= 0;
        sign <= 0;
        sign_1 <= 0; sign_2 <= 0; sign_3 <= 0; sign_4 <= 0;
        sign_5 <= 0; sign_6 <= 0; sign_7 <= 0; sign_8 <= 0;
        sign_9 <= 0; sign_10 <= 0; sign_11 <= 0; sign_12 <= 0;
        sign_13 <= 0; sign_14 <= 0; sign_15 <= 0; sign_16 <= 0;
        sign_17 <= 0; sign_18 <= 0; sign_19 <= 0; sign_20 <= 0;
        mantissa_a1 <= 0; mantissa_a2 <= 0;
        mantissa_b1 <= 0; mantissa_b2 <= 0;
        exponent_a <= 0; exponent_b <= 0;
        ready <= 0; count_ready <= 0; count_ready_0 <= 0;
        count <= 0;
        a_is_zero <= 0; b_is_zero <= 0; a_is_inf <= 0; b_is_inf <= 0;
        in_inf_1 <= 0; in_inf_2 <= 0; in_zero_1 <= 0;
        exponent_terms_1 <= 0; exponent_terms_2 <= 0; exponent_terms_3 <= 0;
        exponent_terms_4 <= 0; exponent_terms_5 <= 0; exponent_terms_6 <= 0;
        exponent_terms_7 <= 0; exponent_terms_8 <= 0; exponent_terms_9 <= 0;
        exponent_gt_expoffset <= 0;
        exponent_1 <= 0; exponent_2 <= 0; exponent_2_0 <= 0; exponent_2_1 <= 0;
        exponent_3 <= 0; exponent_4 <= 0; exponent_5 <= 0; exponent_6 <= 0;
        exponent_7 <= 0; exponent_8 <= 0; exponent_9 <= 0;
        exponent_gt_prodshift <= 0; exponent_is_infinity <= 0;
        set_mantissa_zero <= 0; set_mz_1 <= 0;
        mul_a <= 0; mul_b <= 0; mul_a1 <= 0; mul_a2 <= 0; mul_a3 <= 0;
        mul_a4 <= 0; mul_a5 <= 0; mul_a6 <= 0; mul_a7 <= 0; mul_a8 <= 0;
        mul_b1 <= 0; mul_b2 <= 0; mul_b3 <= 0; mul_b4 <= 0; mul_b5 <= 0;
        mul_b6 <= 0; mul_b7 <= 0; mul_b8 <= 0;
        product_a <= 0; product_b <= 0; product_a_2 <= 0; product_a_3 <= 0;
        product_a_4 <= 0; product_a_5 <= 0; product_a_6 <= 0; product_a_7 <= 0;
        product_a_8 <= 0; product_a_9 <= 0; product_a_10 <= 0;
        product_c <= 0; product_d <= 0; product_e <= 0; product_f <= 0;
        product_g <= 0; product_h <= 0; product_i <= 0; product_j <= 0;
        sum_0 <= 0; sum_0_2 <= 0; sum_0_3 <= 0; sum_0_4 <= 0;
        sum_0_5 <= 0; sum_0_6 <= 0; sum_0_7 <= 0; sum_0_8 <= 0; sum_0_9 <= 0;
        sum_1 <= 0; sum_1_2 <= 0; sum_1_3 <= 0; sum_1_4 <= 0;
        sum_1_5 <= 0; sum_1_6 <= 0; sum_1_7 <= 0; sum_1_8 <= 0;
        sum_2 <= 0; sum_2_2 <= 0; sum_2_3 <= 0; sum_2_4 <= 0;
        sum_2_5 <= 0; sum_2_6 <= 0; sum_2_7 <= 0;
        sum_3 <= 0; sum_4 <= 0; sum_4_2 <= 0; sum_4_3 <= 0;
        sum_4_4 <= 0; sum_4_5 <= 0;
        sum_5 <= 0; sum_5_2 <= 0; sum_5_3 <= 0; sum_5_4 <= 0;
        sum_6 <= 0; sum_7 <= 0; sum_7_2 <= 0; sum_8 <= 0;
        product <= 0; product_1 <= 0; product_2 <= 0; product_3 <= 0;
        product_4 <= 0; product_5 <= 0; product_6 <= 0; product_7 <= 0;
        product_overflow <= 0;
        round_nearest_mode <= 0; round_posinf_mode <= 0; round_neginf_mode <= 0;
        round_nearest_trigger <= 0; round_nearest_exception <= 0;
        round_nearest_enable <= 0; round_posinf_trigger <= 0;
        round_posinf_enable <= 0; round_neginf_trigger <= 0;
        round_neginf_enable <= 0; round_enable <= 0;
    end else if (enable) begin
        // Stage 0: Initial unpacking and special detection
        a_is_zero <= opa_zero;
        b_is_zero <= opb_zero;
        a_is_inf <= opa_inf;
        b_is_inf <= opb_inf;
        in_inf_1 <= opa_inf || opb_inf;
        in_zero_1 <= opa_zero || opb_zero;
        sign <= sign_a ^ sign_b;
        exponent_a <= exp_a;
        exponent_b <= exp_b;
        mantissa_a1 <= mant_a;
        mantissa_b1 <= mant_b;
        rm_1 <= rmode;
        // Stage 1
        mantissa_a2 <= mantissa_a1;
        mantissa_b2 <= mantissa_b1;
        exponent_terms_1 <= exponent_a + exponent_b;
        rm_2 <= rm_1;
        sign_1 <= sign;
        // Stage 2
        exponent_terms_2 <= exponent_terms_1;
        rm_3 <= rm_2;
        sign_2 <= sign_1;
        exponent_1 <= exponent_terms_1 - 11'd1023; // subtract bias
        // Stage 3
        exponent_terms_3 <= exponent_terms_2;
        rm_4 <= rm_3;
        sign_3 <= sign_2;
        exponent_2 <= exponent_1;
        exponent_2_0 <= exponent_1;
        // Stage 4
        exponent_terms_4 <= exponent_terms_3;
        rm_5 <= rm_4;
        sign_4 <= sign_3;
        exponent_3 <= exponent_2;
        exponent_2_1 <= exponent_2_0;
        // Stage 5
        exponent_terms_5 <= exponent_terms_4;
        rm_6 <= rm_5;
        sign_5 <= sign_4;
        exponent_4 <= exponent_3;
        // Mul
        mul_a <= sig_a;
        mul_b <= sig_b;
        mul_a1 <= mul_a;
        mul_b1 <= mul_b;
        // Stage 6
        exponent_terms_6 <= exponent_terms_5;
        rm_7 <= rm_6;
        sign_6 <= sign_5;
        exponent_5 <= exponent_4;
        mul_a2 <= mul_a1;
        mul_b2 <= mul_b1;
        // Stage 7
        exponent_terms_7 <= exponent_terms_6;
        rm_8 <= rm_7;
        sign_7 <= sign_6;
        exponent_6 <= exponent_5;
        mul_a3 <= mul_a2;
        mul_b3 <= mul_b2;
        // Stage 8
        exponent_terms_8 <= exponent_terms_7;
        rm_9 <= rm_8;
        sign_8 <= sign_7;
        exponent_7 <= exponent_6;
        mul_a4 <= mul_a3;
        mul_b4 <= mul_b3;
        // Stage 9
        exponent_terms_9 <= exponent_terms_8;
        rm_10 <= rm_9;
        sign_9 <= sign_8;
        exponent_8 <= exponent_7;
        mul_a5 <= mul_a4;
        mul_b5 <= mul_b4;
        // Stage 10
        rm_11 <= rm_10;
        sign_10 <= sign_9;
        exponent_9 <= exponent_8;
        mul_a6 <= mul_a5;
        mul_b6 <= mul_b5;
        // Stage 11
        rm_12 <= rm_11;
        sign_11 <= sign_10;
        mul_a7 <= mul_a6;
        mul_b7 <= mul_b6;
        // Stage 12
        rm_13 <= rm_12;
        sign_12 <= sign_11;
        mul_a8 <= mul_a7;
        mul_b8 <= mul_b7;
        // Stage 13
        rm_14 <= rm_13;
        sign_13 <= sign_12;
        // Stage 14
        rm_15 <= rm_14;
        sign_14 <= sign_13;
        // Stage 15
        sign_15 <= sign_14;
        // Stage 16
        sign_16 <= sign_15;
        // Stage 17
        sign_17 <= sign_16;
        // Stage 18
        sign_18 <= sign_17;
        // Stage 19
        sign_19 <= sign_18;
        // Stage 20
        sign_20 <= sign_19;

        // Product pipeline (simplified multiplier using product_full)
        // In real design this would be a CSA tree, here we use full product
        product <= product_full;
        product_1 <= product;
        product_2 <= product_1[104:52]; // high part
        product_3 <= product_2;
        product_4[53:0] <= {product_3[51:0], 1'b0}; // align for normalization
        product_overflow <= product_3[52];
        product_5 <= product_4;
        // normalization
        if (product_overflow)
            product_6 <= product_5 >> 1;
        else
            product_6 <= product_5;
        product_7 <= product_6;

        // Ready counter
        if (count < 5'd20)
            count <= count + 1'b1;
        else
            count <= count;
        ready <= (count == 5'd19) ? 1'b1 : 1'b0;
        count_ready <= ready;
        count_ready_0 <= count_ready;

        // Rounding mode flags
        round_nearest_mode <= (rm_15 == 2'b00);
        round_posinf_mode  <= (rm_15 == 2'b10);
        round_neginf_mode  <= (rm_15 == 2'b11);
        round_nearest_trigger <= guard_bit & (round_bit | sticky_bit);
        round_nearest_exception <= round_bit & ~sticky_bit;
        round_nearest_enable <= round_nearest_trigger | round_nearest_exception;
        round_posinf_trigger <= guard_bit | (round_bit & sticky_bit);
        round_posinf_enable <= round_posinf_trigger & (sign_20 == 1'b0);
        round_neginf_trigger <= guard_bit | (round_bit & sticky_bit);
        round_neginf_enable <= round_neginf_trigger & (sign_20 == 1'b1);
        round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;

        // Special case handling for zero and infinity
        if (a_is_zero || b_is_zero) begin
            set_mantissa_zero <= 1'b1;
            sign_20 <= sign;
            exponent_9 <= 11'd0;
            product_7 <= 53'd0;
        end else if (a_is_inf || b_is_inf) begin
            set_mantissa_zero <= 1'b0;
            sign_20 <= sign;
            exponent_9 <= 11'h7FF;
            product_7 <= 53'd0;
        end else if (set_mz_1) begin
            product_7 <= 53'd0;
            exponent_9 <= 11'd0;
        end

        set_mz_1 <= set_mantissa_zero;
    end
end

// Additional combinatorial assignments for pipeline signals not covered
always @* begin
    // Exponent greater than offset check
    exponent_gt_expoffset = (exponent_1 > 11'd2047);
    exponent_gt_prodshift = (exponent_1 > product_shift); // product_shift not defined, placeholder
    exponent_is_infinity = (exponent_5 == 11'h7FF);
    // Other combinational signals can be assigned as needed
    // product_shift set based on overflow
    product_shift = product_overflow;
end

endmodule
