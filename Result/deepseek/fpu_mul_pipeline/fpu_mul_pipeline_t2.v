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

    // Pipeline registers for rounding mode
    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;
    // Pipeline registers for sign
    reg sign, sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10, sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;
    // Pipeline registers for mantissas
    reg [51:0] mantissa_a1, mantissa_a2;
    reg [51:0] mantissa_b1, mantissa_b2;
    // Exponents
    reg [10:0] exponent_a, exponent_b;
    // Ready flag
    reg ready_reg;
    reg count_ready, count_ready_0;
    reg [4:0] count;
    // Special flags
    reg a_is_zero, b_is_zero, a_is_inf, b_is_inf;
    reg in_inf_1, in_inf_2, in_zero_1;
    // Exponent terms pipeline
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3, exponent_terms_4, exponent_terms_5, exponent_terms_6, exponent_terms_7, exponent_terms_8, exponent_terms_9;
    reg exponent_gt_expoffset;
    // Exponent pipeline
    wire [11:0] exponent_w = 12'd0; // unused
    reg [11:0] exponent_1, exponent_2, exponent_2_0, exponent_2_1;
    reg exponent_gt_prodshift, exponent_is_infinity;
    reg [11:0] exponent_3, exponent_4;
    reg set_mantissa_zero, set_mz_1;
    // Multiply operands
    reg [52:0] mul_a, mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b, mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;
    // Partial products
    reg [40:0] product_a;
    reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5, product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
    reg [40:0] product_b;
    reg [40:0] product_c;
    reg [25:0] product_d;
    reg [33:0] product_e;
    reg [33:0] product_f;
    reg [35:0] product_g;
    reg [28:0] product_h;
    reg [28:0] product_i;
    reg [30:0] product_j;
    // Sums
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
    // Product registers
    reg [105:0] product;
    reg [105:0] product_1;
    reg [52:0] product_2;
    reg [52:0] product_3;
    reg [53:0] product_4, product_5, product_6, product_7;
    reg product_overflow;
    reg product_shift;
    // Exponent pipeline continued
    reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;
    // Rounding control
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;

    // Output wire
    wire [63:0] outfp_w = {sign_20, exponent_9[10:0], product_7[51:0]};

    assign outfp = outfp_w;
    assign ready = ready_reg;

    // Count logic for pipeline completion
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 5'd0;
            count_ready <= 1'b0;
            count_ready_0 <= 1'b0;
            ready_reg <= 1'b0;
        end else if (enable) begin
            count_ready_0 <= count_ready;
            if (count_ready_0) ready_reg <= 1'b1;
            else ready_reg <= 1'b0;

            if (count == 5'd20) begin
                count_ready <= 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end

    // Input decoding and special case detection (stage 0)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_is_inf <= 1'b0;
            b_is_inf <= 1'b0;
            a_is_zero <= 1'b0;
            b_is_zero <= 1'b0;
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            mantissa_a1 <= 52'd0;
            mantissa_b1 <= 52'd0;
            sign <= 1'b0;
            rm_1 <= 2'b00;
            mul_a <= 53'd0;
            mul_b <= 53'd0;
        end else if (enable) begin
            a_is_inf <= (opa[62:52] == 11'h7FF) && (opa[51:0] == 52'd0);
            b_is_inf <= (opb[62:52] == 11'h7FF) && (opb[51:0] == 52'd0);
            a_is_zero <= (opa[62:52] == 11'd0) && (opa[51:0] == 52'd0);
            b_is_zero <= (opb[62:52] == 11'd0) && (opb[51:0] == 52'd0);
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a1 <= opa[51:0];
            mantissa_b1 <= opb[51:0];
            sign <= opa[63] ^ opb[63];
            rm_1 <= rmode;
            // Form 53-bit multiplicands with implicit leading 1
            mul_a <= {|opa[62:52], opa[51:0]};
            mul_b <= {|opb[62:52], opb[51:0]};
        end
    end

    // Pipeline stage 1
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mantissa_a2 <= 52'd0;
            mantissa_b2 <= 52'd0;
            sign_1 <= 1'b0;
            rm_2 <= 2'b00;
            in_inf_1 <= 1'b0;
            in_zero_1 <= 1'b0;
            exponent_terms_1 <= 12'd0;
            exponent_1 <= 12'd0;
            set_mz_1 <= 1'b0;
            mul_a1 <= 53'd0;
            mul_b1 <= 53'd0;
            product_1 <= 106'd0;
        end else if (enable) begin
            mantissa_a2 <= mantissa_a1;
            mantissa_b2 <= mantissa_b1;
            sign_1 <= sign;
            rm_2 <= rm_1;
            in_inf_1 <= a_is_inf | b_is_inf;
            in_zero_1 <= a_is_zero | b_is_zero;
            exponent_terms_1 <= {1'b0, exponent_a} + {1'b0, exponent_b} - 12'd1023;
            exponent_1 <= {1'b0, exponent_a} + {1'b0, exponent_b} - 12'd1023;
            set_mz_1 <= 1'b0;
            mul_a1 <= mul_a;
            mul_b1 <= mul_b;
            product_1 <= mul_a * mul_b;
        end
    end

    // Pipeline stage 2
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_2 <= 1'b0;
            rm_3 <= 2'b00;
            in_inf_2 <= 1'b0;
            exponent_terms_2 <= 12'd0;
            exponent_2 <= 12'd0;
            mul_a2 <= 53'd0;
            mul_b2 <= 53'd0;
            product_2 <= 53'd0;
            set_mantissa_zero <= 1'b0;
        end else if (enable) begin
            sign_2 <= sign_1;
            rm_3 <= rm_2;
            in_inf_2 <= in_inf_1;
            exponent_terms_2 <= exponent_terms_1;
            exponent_2 <= exponent_1;
            mul_a2 <= mul_a1;
            mul_b2 <= mul_b1;
            // Product normalization: product_1 is 106 bits, we extract 53 bits starting from bit 105
            product_2 <= product_1[105:53];
            set_mantissa_zero <= in_zero_1 | (exponent_1[11:10] == 2'b11);
        end
    end

    // Pipeline stage 3
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_3 <= 1'b0;
            rm_4 <= 2'b00;
            exponent_terms_3 <= 12'd0;
            exponent_3 <= 12'd0;
            mul_a3 <= 53'd0;
            mul_b3 <= 53'd0;
            product_3 <= 53'd0;
            product_overflow <= 1'b0;
        end else if (enable) begin
            sign_3 <= sign_2;
            rm_4 <= rm_3;
            exponent_terms_3 <= exponent_terms_2;
            exponent_3 <= exponent_2;
            mul_a3 <= mul_a2;
            mul_b3 <= mul_b2;
            product_3 <= product_2;
            product_overflow <= product_2[52];
        end
    end

    // Pipeline stage 4
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_4 <= 1'b0;
            rm_5 <= 2'b00;
            exponent_terms_4 <= 12'd0;
            exponent_4 <= 12'd0;
            mul_a4 <= 53'd0;
            mul_b4 <= 53'd0;
            product_4 <= 54'd0;
            product_shift <= 1'b0;
        end else if (enable) begin
            sign_4 <= sign_3;
            rm_5 <= rm_4;
            exponent_terms_4 <= exponent_terms_3;
            if (product_overflow) begin
                exponent_4 <= exponent_3 + 12'd1;
                product_4 <= {1'b0, product_3[52:0]};
                product_shift <= 1'b0;
            end else if (!product_3[52]) begin
                exponent_4 <= exponent_3 - 12'd1;
                product_4 <= {product_3[51:0], 2'b00};
                product_shift <= 1'b1;
            end else begin
                exponent_4 <= exponent_3;
                product_4 <= {1'b0, product_3};
                product_shift <= 1'b0;
            end
            mul_a4 <= mul_a3;
            mul_b4 <= mul_b3;
        end
    end

    // Pipeline stage 5
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_5 <= 1'b0;
            rm_6 <= 2'b00;
            exponent_terms_5 <= 12'd0;
            exponent_5 <= 12'd0;
            mul_a5 <= 53'd0;
            mul_b5 <= 53'd0;
            product_5 <= 54'd0;
        end else if (enable) begin
            sign_5 <= sign_4;
            rm_6 <= rm_5;
            exponent_terms_5 <= exponent_terms_4;
            exponent_5 <= exponent_4;
            mul_a5 <= mul_a4;
            mul_b5 <= mul_b4;
            product_5 <= product_4;
        end
    end

    // Pipeline stage 6
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_6 <= 1'b0;
            rm_7 <= 2'b00;
            exponent_terms_6 <= 12'd0;
            exponent_6 <= 12'd0;
            mul_a6 <= 53'd0;
            mul_b6 <= 53'd0;
            product_6 <= 54'd0;
        end else if (enable) begin
            sign_6 <= sign_5;
            rm_7 <= rm_6;
            exponent_terms_6 <= exponent_terms_5;
            exponent_6 <= exponent_5;
            mul_a6 <= mul_a5;
            mul_b6 <= mul_b5;
            product_6 <= product_5;
        end
    end

    // Pipeline stage 7
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_7 <= 1'b0;
            rm_8 <= 2'b00;
            exponent_terms_7 <= 12'd0;
            exponent_7 <= 12'd0;
            mul_a7 <= 53'd0;
            mul_b7 <= 53'd0;
            product_7 <= 54'd0;
        end else if (enable) begin
            sign_7 <= sign_6;
            rm_8 <= rm_7;
            exponent_terms_7 <= exponent_terms_6;
            exponent_7 <= exponent_6;
            mul_a7 <= mul_a6;
            mul_b7 <= mul_b6;
            product_7 <= product_6;
        end
    end

    // Pipeline stage 8
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_8 <= 1'b0;
            rm_9 <= 2'b00;
            exponent_terms_8 <= 12'd0;
            exponent_8 <= 12'd0;
            mul_a8 <= 53'd0;
            mul_b8 <= 53'd0;
        end else if (enable) begin
            sign_8 <= sign_7;
            rm_9 <= rm_8;
            exponent_terms_8 <= exponent_terms_7;
            exponent_8 <= exponent_7;
            mul_a8 <= mul_a7;
            mul_b8 <= mul_b7;
        end
    end

    // Pipeline stage 9
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_9 <= 1'b0;
            rm_10 <= 2'b00;
            exponent_terms_9 <= 12'd0;
            exponent_9 <= 12'd0;
        end else if (enable) begin
            sign_9 <= sign_8;
            rm_10 <= rm_9;
            exponent_terms_9 <= exponent_terms_8;
            exponent_9 <= exponent_8;
        end
    end

    // Pipeline stages 10-20 (sign and rounding mode propagation)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_10 <= 1'b0; rm_11 <= 2'b00;
            sign_11 <= 1'b0; rm_12 <= 2'b00;
            sign_12 <= 1'b0; rm_13 <= 2'b00;
            sign_13 <= 1'b0; rm_14 <= 2'b00;
            sign_14 <= 1'b0; rm_15 <= 2'b00;
            sign_15 <= 1'b0;
            sign_16 <= 1'b0;
            sign_17 <= 1'b0;
            sign_18 <= 1'b0;
            sign_19 <= 1'b0;
            sign_20 <= 1'b0;
        end else if (enable) begin
            sign_10 <= sign_9; rm_11 <= rm_10;
            sign_11 <= sign_10; rm_12 <= rm_11;
            sign_12 <= sign_11; rm_13 <= rm_12;
            sign_13 <= sign_12; rm_14 <= rm_13;
            sign_14 <= sign_13; rm_15 <= rm_14;
            sign_15 <= sign_14;
            sign_16 <= sign_15;
            sign_17 <= sign_16;
            sign_18 <= sign_17;
            sign_19 <= sign_18;
            sign_20 <= sign_19;
        end
    end

endmodule
