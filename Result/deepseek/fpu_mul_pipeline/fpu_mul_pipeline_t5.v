module fpu_mul_pipeline (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output reg ready,
    output [63:0] outfp
);

    // Sign, exponent, mantissa extraction
    wire sign_a = opa[63];
    wire sign_b = opb[63];
    wire [10:0] exp_a = opa[62:52];
    wire [10:0] exp_b = opb[62:52];
    wire [51:0] man_a = opa[51:0];
    wire [51:0] man_b = opb[51:0];

    // Special case detection
    wire a_is_nan = (exp_a == 11'h7FF) && (man_a != 0);
    wire b_is_nan = (exp_b == 11'h7FF) && (man_b != 0);
    wire a_is_zero = (exp_a == 0) && (man_a == 0);
    wire b_is_zero = (exp_b == 0) && (man_b == 0);
    wire a_is_inf = (exp_a == 11'h7FF) && (man_a == 0);
    wire b_is_inf = (exp_b == 11'h7FF) && (man_b == 0);
    wire a_is_denorm = (exp_a == 0) && (man_a != 0);
    wire b_is_denorm = (exp_b == 0) && (man_b != 0);

    // Internal pipeline registers
    reg product_shift;
    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;
    reg sign;
    reg sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10, sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;
    reg [51:0] mantissa_a1, mantissa_a2, mantissa_b1, mantissa_b2;
    reg [10:0] exponent_a, exponent_b;
    reg count_ready, count_ready_0;
    reg [4:0] count;
    reg a_is_zero_reg, b_is_zero_reg, a_is_inf_reg, b_is_inf_reg;
    reg in_inf_1, in_inf_2, in_zero_1;
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3, exponent_terms_4, exponent_terms_5, exponent_terms_6, exponent_terms_7, exponent_terms_8, exponent_terms_9;
    reg exponent_gt_expoffset;
    reg [11:0] exponent_1, exponent_2, exponent_2_0, exponent_2_1, exponent_3, exponent_4, exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;
    reg exponent_gt_prodshift;
    reg exponent_is_infinity;
    reg set_mantissa_zero, set_mz_1;
    reg [52:0] mul_a, mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b, mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;
    reg [40:0] product_a;
    reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5, product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
    reg [40:0] product_b, product_c;
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
    reg [105:0] product;
    reg [105:0] product_1;
    reg [52:0] product_2;
    reg [52:0] product_3;
    reg [53:0] product_4;
    reg [53:0] product_5;
    reg [53:0] product_6;
    reg [53:0] product_7;
    reg product_overflow;
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;

    // Output assignment
    assign outfp = {sign_20, exponent_9[10:0], product_7[51:0]};

    // Bias and constants
    localparam BIAS = 11'd1023;
    localparam EXPOFFSET = 12'd1023;

    // Combinational: exponent calculation
    wire [11:0] exponent_sum = {1'b0, exponent_a} + {1'b0, exponent_b};
    wire [11:0] exponent_unbiased = exponent_sum - EXPOFFSET;

    // Main pipeline logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all pipeline registers
            ready <= 1'b0;
            count_ready <= 1'b0;
            count_ready_0 <= 1'b0;
            count <= 5'd0;
            sign <= 1'b0;
            sign_1 <= 1'b0;
            sign_2 <= 1'b0;
            sign_3 <= 1'b0;
            sign_4 <= 1'b0;
            sign_5 <= 1'b0;
            sign_6 <= 1'b0;
            sign_7 <= 1'b0;
            sign_8 <= 1'b0;
            sign_9 <= 1'b0;
            sign_10 <= 1'b0;
            sign_11 <= 1'b0;
            sign_12 <= 1'b0;
            sign_13 <= 1'b0;
            sign_14 <= 1'b0;
            sign_15 <= 1'b0;
            sign_16 <= 1'b0;
            sign_17 <= 1'b0;
            sign_18 <= 1'b0;
            sign_19 <= 1'b0;
            sign_20 <= 1'b0;
            rm_1 <= 2'b00;
            rm_2 <= 2'b00;
            rm_3 <= 2'b00;
            rm_4 <= 2'b00;
            rm_5 <= 2'b00;
            rm_6 <= 2'b00;
            rm_7 <= 2'b00;
            rm_8 <= 2'b00;
            rm_9 <= 2'b00;
            rm_10 <= 2'b00;
            rm_11 <= 2'b00;
            rm_12 <= 2'b00;
            rm_13 <= 2'b00;
            rm_14 <= 2'b00;
            rm_15 <= 2'b00;
            mantissa_a1 <= 52'd0;
            mantissa_a2 <= 52'd0;
            mantissa_b1 <= 52'd0;
            mantissa_b2 <= 52'd0;
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            a_is_zero_reg <= 1'b0;
            b_is_zero_reg <= 1'b0;
            a_is_inf_reg <= 1'b0;
            b_is_inf_reg <= 1'b0;
            in_inf_1 <= 1'b0;
            in_inf_2 <= 1'b0;
            in_zero_1 <= 1'b0;
            exponent_terms_1 <= 12'd0;
            exponent_terms_2 <= 12'd0;
            exponent_terms_3 <= 12'd0;
            exponent_terms_4 <= 12'd0;
            exponent_terms_5 <= 12'd0;
            exponent_terms_6 <= 12'd0;
            exponent_terms_7 <= 12'd0;
            exponent_terms_8 <= 12'd0;
            exponent_terms_9 <= 12'd0;
            exponent_gt_expoffset <= 1'b0;
            exponent_1 <= 12'd0;
            exponent_2 <= 12'd0;
            exponent_2_0 <= 12'd0;
            exponent_2_1 <= 12'd0;
            exponent_gt_prodshift <= 1'b0;
            exponent_is_infinity <= 1'b0;
            exponent_3 <= 12'd0;
            exponent_4 <= 12'd0;
            exponent_5 <= 12'd0;
            exponent_6 <= 12'd0;
            exponent_7 <= 12'd0;
            exponent_8 <= 12'd0;
            exponent_9 <= 12'd0;
            set_mantissa_zero <= 1'b0;
            set_mz_1 <= 1'b0;
            mul_a <= 53'd0;
            mul_a1 <= 53'd0;
            mul_a2 <= 53'd0;
            mul_a3 <= 53'd0;
            mul_a4 <= 53'd0;
            mul_a5 <= 53'd0;
            mul_a6 <= 53'd0;
            mul_a7 <= 53'd0;
            mul_a8 <= 53'd0;
            mul_b <= 53'd0;
            mul_b1 <= 53'd0;
            mul_b2 <= 53'd0;
            mul_b3 <= 53'd0;
            mul_b4 <= 53'd0;
            mul_b5 <= 53'd0;
            mul_b6 <= 53'd0;
            mul_b7 <= 53'd0;
            mul_b8 <= 53'd0;
            product_a <= 41'd0;
            product_a_2 <= 17'd0;
            product_a_3 <= 17'd0;
            product_a_4 <= 17'd0;
            product_a_5 <= 17'd0;
            product_a_6 <= 17'd0;
            product_a_7 <= 17'd0;
            product_a_8 <= 17'd0;
            product_a_9 <= 17'd0;
            product_a_10 <= 17'd0;
            product_b <= 41'd0;
            product_c <= 41'd0;
            product_d <= 26'd0;
            product_e <= 34'd0;
            product_f <= 34'd0;
            product_g <= 36'd0;
            product_h <= 29'd0;
            product_i <= 29'd0;
            product_j <= 31'd0;
            sum_0 <= 42'd0;
            sum_0_2 <= 7'd0;
            sum_0_3 <= 7'd0;
            sum_0_4 <= 7'd0;
            sum_0_5 <= 7'd0;
            sum_0_6 <= 7'd0;
            sum_0_7 <= 7'd0;
            sum_0_8 <= 7'd0;
            sum_0_9 <= 7'd0;
            sum_1 <= 36'd0;
            sum_1_2 <= 10'd0;
            sum_1_3 <= 10'd0;
            sum_1_4 <= 10'd0;
            sum_1_5 <= 10'd0;
            sum_1_6 <= 10'd0;
            sum_1_7 <= 10'd0;
            sum_1_8 <= 10'd0;
            sum_2 <= 42'd0;
            sum_2_2 <= 7'd0;
            sum_2_3 <= 7'd0;
            sum_2_4 <= 7'd0;
            sum_2_5 <= 7'd0;
            sum_2_6 <= 7'd0;
            sum_2_7 <= 7'd0;
            sum_3 <= 36'd0;
            sum_4 <= 37'd0;
            sum_4_2 <= 10'd0;
            sum_4_3 <= 10'd0;
            sum_4_4 <= 10'd0;
            sum_4_5 <= 10'd0;
            sum_5 <= 28'd0;
            sum_5_2 <= 7'd0;
            sum_5_3 <= 7'd0;
            sum_5_4 <= 7'd0;
            sum_6 <= 30'd0;
            sum_7 <= 37'd0;
            sum_7_2 <= 17'd0;
            sum_8 <= 31'd0;
            product <= 106'd0;
            product_1 <= 106'd0;
            product_2 <= 53'd0;
            product_3 <= 53'd0;
            product_4 <= 54'd0;
            product_5 <= 54'd0;
            product_6 <= 54'd0;
            product_7 <= 54'd0;
            product_overflow <= 1'b0;
            product_shift <= 1'b0;
            round_nearest_mode <= 1'b0;
            round_posinf_mode <= 1'b0;
            round_neginf_mode <= 1'b0;
            round_nearest_trigger <= 1'b0;
            round_nearest_exception <= 1'b0;
            round_nearest_enable <= 1'b0;
            round_posinf_trigger <= 1'b0;
            round_posinf_enable <= 1'b0;
            round_neginf_trigger <= 1'b0;
            round_neginf_enable <= 1'b0;
            round_enable <= 1'b0;
        end else if (enable) begin
            // ========== STAGE 0: Input parsing ==========
            exponent_a <= exp_a;
            exponent_b <= exp_b;
            a_is_zero_reg <= a_is_zero;
            b_is_zero_reg <= b_is_zero;
            a_is_inf_reg <= a_is_inf;
            b_is_inf_reg <= b_is_inf;
            sign <= sign_a ^ sign_b;
            rm_1 <= rmode;

            // Detect special cases
            in_inf_1 <= a_is_inf || b_is_inf;
            in_zero_1 <= a_is_zero || b_is_zero;

            // Build 53-bit mantissa with implicit leading bit
            if (a_is_denorm || a_is_zero)
                mul_a <= {1'b0, man_a};
            else
                mul_a <= {1'b1, man_a};

            if (b_is_denorm || b_is_zero)
                mul_b <= {1'b0, man_b};
            else
                mul_b <= {1'b1, man_b};

            // Exponent calculation
            exponent_terms_1 <= exponent_sum;

            // ========== STAGE 1: Pipeline transfer ==========
            mantissa_a1 <= man_a;
            mantissa_b1 <= man_b;
            sign_1 <= sign;
            rm_2 <= rm_1;
            in_inf_2 <= in_inf_1;
            exponent_terms_2 <= exponent_terms_1;
            mul_a1 <= mul_a;
            mul_b1 <= mul_b;

            // ========== STAGE 2: Mantissa pipeline + start partial products ==========
            mantissa_a2 <= mantissa_a1;
            mantissa_b2 <= mantissa_b1;
            sign_2 <= sign_1;
            rm_3 <= rm_2;
            exponent_terms_3 <= exponent_terms_2;
            mul_a2 <= mul_a1;
            mul_b2 <= mul_b1;

            // Generate first partial product: mul_a * mul_b[16:0]
            product_a <= mul_a1[40:0] * mul_b1[16:0];
            product_b <= mul_a1[40:0] * mul_b1[33:17];
            product_c <= mul_a1[40:0] * mul_b1[52:34];

            // ========== STAGE 3: Partial product reduction ==========
            sign_3 <= sign_2;
            rm_4 <= rm_3;
            exponent_terms_4 <= exponent_terms_3;
            mul_a3 <= mul_a2;
            mul_b3 <= mul_b2;
            product_a_2 <= product_a[40:24];
            sum_0_2 <= product_a[23:17];
            sum_1_2 <= product_a[16:7];
            sum_2_2 <= product_a[6:0];
            product_d <= product_b[25:0];
            product_e[33:0] <= product_b[40:7];
            product_f[33:0] <= product_c[33:0];
            sum_4_2 <= product_c[43:34];

            // ========== STAGE 4: Reduction tree stage 1 ==========
            sign_4 <= sign_3;
            rm_5 <= rm_4;
            exponent_terms_5 <= exponent_terms_4;
            mul_a4 <= mul_a3;
            mul_b4 <= mul_b3;
            product_a_3 <= product_a_2;
            sum_0_3 <= sum_0_2;
            sum_1_3 <= sum_1_2;
            sum_2_3 <= sum_2_2;
            sum_4_3 <= sum_4_2;

            // Combine product_d and product_e with alignment
            sum_0 <= {sum_0_2, product_d[25:0], 10'd0} + {product_e, 8'd0};
            sum_1 <= {product_f, 2'd0};
            sum_2 <= {product_c[36:34], sum_4_2, 29'd0};

            // ========== STAGE 5: Reduction tree stage 2 ==========
            sign_5 <= sign_4;
            rm_6 <= rm_5;
            exponent_terms_6 <= exponent_terms_5;
            mul_a5 <= mul_a4;
            mul_b5 <= mul_b4;
            product_a_4 <= product_a_3;
            sum_0_4 <= sum_0_3;
            sum_1_4 <= sum_1_3;
            sum_2_4 <= sum_2_3;
            sum_4_4 <= sum_4_3;

            sum_3 <= sum_0[35:0];
            sum_4 <= {1'b0, sum_1} + sum_2[35:0];
            sum_5[27:0] <= sum_0[41:14];
            sum_5_2 <= sum_0[13:7];
            sum_5_3 <= sum_0[6:0];

            // ========== STAGE 6: Reduction tree stage 3 ==========
            sign_6 <= sign_5;
            rm_7 <= rm_6;
            exponent_terms_7 <= exponent_terms_6;
            mul_a6 <= mul_a5;
            mul_b6 <= mul_b5;
            product_a_5 <= product_a_4;
            sum_0_5 <= sum_0_4;
            sum_1_5 <= sum_1_4;
            sum_2_5 <= sum_2_4;
            sum_4_5 <= sum_4_4;
            sum_5_4 <= sum_5_3;

            sum_6 <= {sum_5, sum_5_2, 2'd0};
            sum_7 <= sum_4 + sum_3;
            sum_7_2 <= sum_4[36:20];
            sum_8 <= {sum_4[19:0], sum_5_3, 4'd0};

            // ========== STAGE 7: Reduction tree stage 4 ==========
            sign_7 <= sign_6;
            rm_8 <= rm_7;
            exponent_terms_8 <= exponent_terms_7;
            mul_a7 <= mul_a6;
            mul_b7 <= mul_b6;
            product_a_6 <= product_a_5;
            sum_0_6 <= sum_0_5;
            sum_1_6 <= sum_1_5;
            sum_2_6 <= sum_2_5;

            product_g <= sum_6 + sum_7[35:0];
            product_h <= sum_7[28:0];
            product_i <= sum_8[28:0];
            product_j <= {sum_8[30:0]};

            // ========== STAGE 8: Final product accumulation ==========
            sign_8 <= sign_7;
            rm_9 <= rm_8;
            exponent_terms_9 <= exponent_terms_8;
            mul_a8 <= mul_a7;
            mul_b8 <= mul_b7;
            product_a_7 <= product_a_6;
            sum_0_7 <= sum_0_6;
            sum_1_7 <= sum_1_6;
            sum_2_7 <= sum_2_6;

            // Accumulate partial products into final product
            product <= {product_a_6, sum_0_6, sum_1_6, sum_2_6, 24'd0}
                     + {11'd0, product_g}
                     + {13'd0, product_h, 12'd0}
                     + {13'd0, product_i, 13'd0}
                     + {11'd0, product_j, 15'd0};

            // ========== STAGE 9: Product register 1 ==========
            sign_9 <= sign_8;
            rm_10 <= rm_9;
            exponent_1 <= exponent_unbiased;
            product_1 <= product;
            product_a_8 <= product_a_7;
            sum_0_8 <= sum_0_7;
            sum_1_8 <= sum_1_7;

            // ========== STAGE 10: Product normalize check ==========
            sign_10 <= sign_9;
            rm_11 <= rm_10;
            exponent_2 <= exponent_1;
            product_2 <= product_1[105:53];
            product_a_9 <= product_a_8;
            sum_0_9 <= sum_0_8;

            // Check if product needs normalization shift
            product_shift <= product_1[105];
            if (product_1[105] == 1'b1) begin
                product_2 <= product_1[105:53];
            end else begin
                product_2 <= {product_1[104:53], 1'b0};
            end

            // ========== STAGE 11: Normalization shift ==========
            sign_11 <= sign_10;
            rm_12 <= rm_11;
            exponent_2_0 <= exponent_2;
            product_3 <= product_2;
            product_a_10 <= product_a_9;

            if (product_shift) begin
                exponent_2_1 <= exponent_2 + 12'd1;
            end else begin
                exponent_2_1 <= exponent_2;
            end

            // ========== STAGE 12: Exponent adjust ==========
            sign_12 <= sign_11;
            rm_13 <= rm_12;
            exponent_3 <= exponent_2_1;
            product_4 <= {product_3, 1'b0};

            exponent_gt_expoffset <= (exponent_2_1 > EXPOFFSET);
            exponent_gt_prodshift <= (exponent_2_1 > (EXPOFFSET + 12'd1));
            exponent_is_infinity <= (exponent_2_1 >= 12'h7FF);

            // ========== STAGE 13: Special case handling ==========
            sign_13 <= sign_12;
            rm_14 <= rm_13;
            exponent_4 <= exponent_3;
            product_5 <= product_4;

            // Handle zero and infinity results
            if (a_is_zero_reg || b_is_zero_reg) begin
                set_mantissa_zero <= 1'b1;
                exponent_4 <= 12'd0;
            end else if (in_inf_2) begin
                exponent_4 <= 12'h7FF;
                set_mantissa_zero <= 1'b0;
            end else if (exponent_is_infinity) begin
                exponent_4 <= 12'h7FF;
                set_mantissa_zero <= 1'b0;
            end else begin
                set_mantissa_zero <= 1'b0;
            end

            set_mz_1 <= set_mantissa_zero;

            // ========== STAGE 14: Rounding setup ==========
            sign_14 <= sign_13;
            rm_15 <= rm_14;
            exponent_5 <= exponent_4;
            product_6 <= product_5;

            // Rounding mode decoding
            round_nearest_mode <= (rm_14 == 2'b00);
            round_posinf_mode <= (rm_14 == 2'b10);
            round_neginf_mode <= (rm_14 == 2'b11);

            // Guard, round, sticky bits from product_5[53:0]
            // Guard bit = product_5[53], Round bit = product_5[52], Sticky = OR of lower bits
            round_nearest_trigger <= product_5[53] & (product_5[52] | (|product_5[51:0]));
            round_nearest_exception <= product_5[53] & product_5[52] & ~(|product_5[51:0]);
            round_nearest_enable <= (rm_14 == 2'b00) & (product_5[53] & (product_5[52] | (|product_5[51:0])));

            round_posinf_trigger <= (rm_14 == 2'b10) & (|product_5[53:0]) & ~sign_13;
            round_posinf_enable <= (rm_14 == 2'b10) & (|product_5[53:0]) & ~sign_13;

            round_neginf_trigger <= (rm_14 == 2'b11) & (|product_5[53:0]) & sign_13;
            round_neginf_enable <= (rm_14 == 2'b11) & (|product_5[53:0]) & sign_13;

            round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;

            // ========== STAGE 15: Apply rounding ==========
            sign_15 <= sign_14;
            exponent_6 <= exponent_5;
            product_7 <= product_6;

            if (set_mz_1) begin
                product_7 <= 54'd0;
                exponent_6 <= 12'd0;
            end else if (round_enable) begin
                product_7 <= product_6 + 54'd1;
                if (product_6 == 54'h3FFFFFFFFFFFFF) begin
                    exponent_6 <= exponent_5 + 12'd1;
                    product_7 <= 54'h20000000000000;
                end
            end

            product_overflow <= (product_7[53] == 1'b1);

            // ========== STAGE 16: Post-rounding normalize ==========
            sign_16 <= sign_15;
            exponent_7 <= exponent_6;

            if (product_overflow) begin
                exponent_7 <= exponent_6 + 12'd1;
                product_7 <= {1'b0, product_7[53:1]};
            end

            // ========== STAGE 17: Exponent finalize ==========
            sign_17 <= sign_16;
            exponent_8 <= exponent_7;

            // Clamp exponent
            if (exponent_7[10:0] >= 11'h7FF) begin
                exponent_8 <= 12'h7FF;
            end else if (exponent_7[10:0] <= 11'd0) begin
                exponent_8 <= 12'd0;
            end

            // ========== STAGE 18: Final exponent ==========
            sign_18 <= sign_17;
            exponent_9 <= exponent_8;

            // ========== STAGE 19: Sign final pipeline ==========
            sign_19 <= sign_18;

            // ========== STAGE 20: Output stage ==========
            sign_20 <= sign_19;

            // ========== Ready generation ==========
            count_ready_0 <= 1'b1;
            count <= count + 5'd1;
            if (count >= 5'd20) begin
                ready <= 1'b1;
            end else begin
                ready <= 1'b0;
            end
        end
    end

    // Combinational: count_ready pipeline
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_ready <= 1'b0;
        end else if (enable) begin
            count_ready <= count_ready_0;
        end
    end

endmodule
