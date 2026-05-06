module fpu_mul_pipeline (
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output reg ready,
    output reg [63:0] outfp
);

    // Internal signals
    reg product_shift;
    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;
    reg sign;
    reg sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10,
        sign_11, sign_12, sign_13, sign_14, sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;
    reg [51:0] mantissa_a1, mantissa_a2;
    reg [51:0] mantissa_b1, mantissa_b2;
    reg [10:0] exponent_a, exponent_b;
    reg count_ready, count_ready_0;
    reg [4:0] count;
    reg a_is_zero, b_is_zero;
    reg a_is_inf, b_is_inf;
    reg in_inf_1, in_inf_2;
    reg in_zero_1;
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3, exponent_terms_4,
               exponent_terms_5, exponent_terms_6, exponent_terms_7, exponent_terms_8, exponent_terms_9;
    reg exponent_gt_expoffset;
    reg [11:0] exponent_1;
    wire [11:0] exponent = 12'd0;
    reg [11:0] exponent_2, exponent_2_0, exponent_2_1;
    reg exponent_gt_prodshift;
    reg exponent_is_infinity;
    reg [11:0] exponent_3, exponent_4;
    reg set_mantissa_zero, set_mz_1;
    reg [52:0] mul_a, mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b, mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;
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
    reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;

    // Pipeline stage 0: Input decoding and special case handling
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign <= 1'b0;
            sign_1 <= 1'b0;
            rm_1 <= 2'b00;
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            mantissa_a1 <= 52'd0;
            mantissa_b1 <= 52'd0;
            mul_a <= 53'd0;
            mul_b <= 53'd0;
            a_is_zero <= 1'b0;
            b_is_zero <= 1'b0;
            a_is_inf <= 1'b0;
            b_is_inf <= 1'b0;
            exponent_terms_1 <= 12'd0;
            count_ready_0 <= 1'b0;
            count <= 5'd0;
            exponent_2_0 <= 12'd0;
        end else if (enable) begin
            sign <= opa[63] ^ opb[63];
            sign_1 <= opa[63] ^ opb[63];
            rm_1 <= rmode;
            exponent_a <= {3'b0, opa[62:52]};
            exponent_b <= {3'b0, opb[62:52]};
            mantissa_a1 <= opa[51:0];
            mantissa_b1 <= opb[51:0];
            a_is_zero <= (opa[62:52] == 11'd0) && (opa[51:0] == 52'd0);
            b_is_zero <= (opb[62:52] == 11'd0) && (opb[51:0] == 52'd0);
            a_is_inf <= (opa[62:52] == 11'h7FF) && (opa[51:0] == 52'd0);
            b_is_inf <= (opb[62:52] == 11'h7FF) && (opb[51:0] == 52'd0);
            mul_a <= {1'b1, opa[51:0]};
            mul_b <= {1'b1, opb[51:0]};
            exponent_terms_1 <= {3'b0, opa[62:52]} + {3'b0, opb[62:52]} - 12'd1023;
            count <= count + 5'd1;
            count_ready_0 <= (count == 5'd19);
            exponent_2_0 <= 12'd0;
        end
    end

    // Pipeline stage 1
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_2 <= 1'b0;
            rm_2 <= 2'b00;
            mantissa_a2 <= 52'd0;
            mantissa_b2 <= 52'd0;
            mul_a1 <= 53'd0;
            mul_b1 <= 53'd0;
            in_inf_1 <= 1'b0;
            in_zero_1 <= 1'b0;
            exponent_terms_2 <= 12'd0;
            exponent_1 <= 12'd0;
            exponent_2_1 <= 12'd0;
            set_mz_1 <= 1'b0;
        end else if (enable) begin
            sign_2 <= sign_1;
            rm_2 <= rm_1;
            mantissa_a2 <= mantissa_a1;
            mantissa_b2 <= mantissa_b1;
            mul_a1 <= mul_a;
            mul_b1 <= mul_b;
            in_inf_1 <= a_is_inf | b_is_inf;
            in_zero_1 <= a_is_zero | b_is_zero;
            exponent_terms_2 <= exponent_terms_1;
            exponent_1 <= exponent_terms_1;
            exponent_2_1 <= exponent_2_0;
            set_mz_1 <= 1'b0;
        end
    end

    // Pipeline stage 2
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_3 <= 1'b0;
            rm_3 <= 2'b00;
            mul_a2 <= 53'd0;
            mul_b2 <= 53'd0;
            in_inf_2 <= 1'b0;
            exponent_terms_3 <= 12'd0;
            exponent_2 <= 12'd0;
            product_a <= 41'd0;
            product_a_2 <= 17'd0;
            sum_0 <= 42'd0;
            sum_0_2 <= 7'd0;
            sum_1 <= 36'd0;
            sum_1_2 <= 10'd0;
            sum_2 <= 42'd0;
            sum_2_2 <= 7'd0;
            sum_4_2 <= 10'd0;
            sum_5_2 <= 7'd0;
            sum_7_2 <= 17'd0;
        end else if (enable) begin
            sign_3 <= sign_2;
            rm_3 <= rm_2;
            mul_a2 <= mul_a1;
            mul_b2 <= mul_b1;
            in_inf_2 <= in_inf_1;
            exponent_terms_3 <= exponent_terms_2;
            exponent_2 <= exponent_1;
            // Partial product generation
            product_a <= mul_a1[52:12] * mul_b1[15:0];
            product_a_2 <= mul_a1[52:36] * mul_b1[52:36];
            sum_0 <= {1'b0, mul_a1[52:12]} * {1'b0, mul_b1[31:16]};
            sum_0_2 <= mul_a1[52:46] * mul_b1[52:46];
            sum_1 <= mul_a1[52:17] * mul_b1[47:32];
            sum_1_2 <= mul_a1[52:43] * mul_b1[52:43];
            sum_2 <= {1'b0, mul_a1[52:12]} * {1'b0, mul_b1[47:32]};
            sum_2_2 <= mul_a1[52:46] * mul_b1[52:46];
            sum_4_2 <= mul_a1[52:43] * mul_b1[52:43];
            sum_5_2 <= mul_a1[52:46] * mul_b1[52:46];
            sum_7_2 <= mul_a1[52:36] * mul_b1[52:36];
        end
    end

    // Pipeline stage 3
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_4 <= 1'b0;
            rm_4 <= 2'b00;
            mul_a3 <= 53'd0;
            mul_b3 <= 53'd0;
            exponent_terms_4 <= 12'd0;
            exponent_3 <= 12'd0;
            product_a_3 <= 17'd0;
            product_b <= 41'd0;
            sum_0_3 <= 7'd0;
            sum_1_3 <= 10'd0;
            sum_2_3 <= 7'd0;
            sum_3 <= 36'd0;
            sum_4_3 <= 10'd0;
            sum_5_3 <= 7'd0;
        end else if (enable) begin
            sign_4 <= sign_3;
            rm_4 <= rm_3;
            mul_a3 <= mul_a2;
            mul_b3 <= mul_b2;
            exponent_terms_4 <= exponent_terms_3;
            exponent_3 <= exponent_2;
            product_a_3 <= product_a_2;
            product_b <= mul_a2[52:12] * mul_b2[31:16];
            sum_0_3 <= sum_0_2;
            sum_1_3 <= sum_1_2;
            sum_2_3 <= sum_2_2;
            sum_3 <= mul_a2[52:17] * mul_b2[31:16];
            sum_4_3 <= sum_4_2;
            sum_5_3 <= sum_5_2;
        end
    end

    // Pipeline stage 4
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_5 <= 1'b0;
            rm_5 <= 2'b00;
            mul_a4 <= 53'd0;
            mul_b4 <= 53'd0;
            exponent_terms_5 <= 12'd0;
            exponent_4 <= 12'd0;
            product_a_4 <= 17'd0;
            product_c <= 41'd0;
            sum_0_4 <= 7'd0;
            sum_1_4 <= 10'd0;
            sum_2_4 <= 7'd0;
            sum_4 <= 37'd0;
            sum_4_4 <= 10'd0;
            sum_5_4 <= 7'd0;
        end else if (enable) begin
            sign_5 <= sign_4;
            rm_5 <= rm_4;
            mul_a4 <= mul_a3;
            mul_b4 <= mul_b3;
            exponent_terms_5 <= exponent_terms_4;
            exponent_4 <= exponent_3;
            product_a_4 <= product_a_3;
            product_c <= mul_a3[52:12] * mul_b3[47:32];
            sum_0_4 <= sum_0_3;
            sum_1_4 <= sum_1_3;
            sum_2_4 <= sum_2_3;
            sum_4 <= mul_a3[52:17] * mul_b3[47:32];
            sum_4_4 <= sum_4_3;
            sum_5_4 <= sum_5_3;
        end
    end

    // Pipeline stage 5
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_6 <= 1'b0;
            rm_6 <= 2'b00;
            mul_a5 <= 53'd0;
            mul_b5 <= 53'd0;
            exponent_terms_6 <= 12'd0;
            exponent_5 <= 12'd0;
            product_a_5 <= 17'd0;
            product_d <= 26'd0;
            sum_0_5 <= 7'd0;
            sum_1_5 <= 10'd0;
            sum_2_5 <= 7'd0;
            sum_4_5 <= 10'd0;
            sum_5 <= 28'd0;
        end else if (enable) begin
            sign_6 <= sign_5;
            rm_6 <= rm_5;
            mul_a5 <= mul_a4;
            mul_b5 <= mul_b4;
            exponent_terms_6 <= exponent_terms_5;
            exponent_5 <= exponent_4;
            product_a_5 <= product_a_4;
            product_d <= mul_a4[52:27] * mul_b4[15:0];
            sum_0_5 <= sum_0_4;
            sum_1_5 <= sum_1_4;
            sum_2_5 <= sum_2_4;
            sum_4_5 <= sum_4_4;
            sum_5 <= mul_a4[52:25] * mul_b4[31:16];
        end
    end

    // Pipeline stage 6
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_7 <= 1'b0;
            rm_7 <= 2'b00;
            mul_a6 <= 53'd0;
            mul_b6 <= 53'd0;
            exponent_terms_7 <= 12'd0;
            exponent_6 <= 12'd0;
            product_a_6 <= 17'd0;
            product_e <= 34'd0;
            sum_0_6 <= 7'd0;
            sum_1_6 <= 10'd0;
            sum_2_6 <= 7'd0;
            sum_6 <= 30'd0;
        end else if (enable) begin
            sign_7 <= sign_6;
            rm_7 <= rm_6;
            mul_a6 <= mul_a5;
            mul_b6 <= mul_b5;
            exponent_terms_7 <= exponent_terms_6;
            exponent_6 <= exponent_5;
            product_a_6 <= product_a_5;
            product_e <= mul_a5[52:19] * mul_b5[31:16];
            sum_0_6 <= sum_0_5;
            sum_1_6 <= sum_1_5;
            sum_2_6 <= sum_2_5;
            sum_6 <= mul_a5[52:23] * mul_b5[47:32];
        end
    end

    // Pipeline stage 7
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_8 <= 1'b0;
            rm_8 <= 2'b00;
            mul_a7 <= 53'd0;
            mul_b7 <= 53'd0;
            exponent_terms_8 <= 12'd0;
            exponent_7 <= 12'd0;
            product_a_7 <= 17'd0;
            product_f <= 34'd0;
            sum_0_7 <= 7'd0;
            sum_1_7 <= 10'd0;
            sum_2_7 <= 7'd0;
            sum_7 <= 37'd0;
        end else if (enable) begin
            sign_8 <= sign_7;
            rm_8 <= rm_7;
            mul_a7 <= mul_a6;
            mul_b7 <= mul_b6;
            exponent_terms_8 <= exponent_terms_7;
            exponent_7 <= exponent_6;
            product_a_7 <= product_a_6;
            product_f <= mul_a6[52:19] * mul_b6[47:32];
            sum_0_7 <= sum_0_6;
            sum_1_7 <= sum_1_6;
            sum_2_7 <= sum_2_6;
            sum_7 <= mul_a6[52:16] * mul_b6[15:0];
        end
    end

    // Pipeline stage 8
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_9 <= 1'b0;
            rm_9 <= 2'b00;
            mul_a8 <= 53'd0;
            mul_b8 <= 53'd0;
            exponent_terms_9 <= 12'd0;
            exponent_8 <= 12'd0;
            product_a_8 <= 17'd0;
            product_g <= 36'd0;
            sum_0_8 <= 7'd0;
            sum_1_8 <= 10'd0;
            sum_8 <= 31'd0;
        end else if (enable) begin
            sign_9 <= sign_8;
            rm_9 <= rm_8;
            mul_a8 <= mul_a7;
            mul_b8 <= mul_b7;
            exponent_terms_9 <= exponent_terms_8;
            exponent_8 <= exponent_7;
            product_a_8 <= product_a_7;
            product_g <= mul_a7[52:17] * mul_b7[15:0];
            sum_0_8 <= sum_0_7;
            sum_1_8 <= sum_1_7;
            sum_8 <= mul_a7[52:22] * mul_b7[31:16];
        end
    end

    // Pipeline stage 9: Partial product accumulation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_10 <= 1'b0;
            rm_10 <= 2'b00;
            exponent_9 <= 12'd0;
            product_a_9 <= 17'd0;
            product_h <= 29'd0;
            sum_0_9 <= 7'd0;
            product <= 106'd0;
        end else if (enable) begin
            sign_10 <= sign_9;
            rm_10 <= rm_9;
            exponent_9 <= exponent_8;
            product_a_9 <= product_a_8;
            product_h <= mul_a8[52:24] * mul_b8[47:32];
            sum_0_9 <= sum_0_8;
            // Accumulate partial products into product
            product <= {product_a, 65'd0} + {product_b, 49'd0} + {product_c, 33'd0} +
                       {product_d, 17'd0} + {product_e, 12'd0} + {product_f, 12'd0} +
                       {product_g, 12'd0} + {product_h, 12'd0} + {sum_0, 12'd0} +
                       {sum_1, 12'd0} + {sum_2, 12'd0} + {sum_3, 12'd0} +
                       {sum_4, 12'd0} + {sum_5, 12'd0} + {sum_6, 12'd0} +
                       {sum_7, 12'd0} + {sum_8, 12'd0};
        end
    end

    // Pipeline stage 10
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_11 <= 1'b0;
            rm_11 <= 2'b00;
            product_a_10 <= 17'd0;
            product_1 <= 106'd0;
        end else if (enable) begin
            sign_11 <= sign_10;
            rm_11 <= rm_10;
            product_a_10 <= product_a_9;
            product_1 <= product;
        end
    end

    // Pipeline stage 11
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_12 <= 1'b0;
            rm_12 <= 2'b00;
            product_2 <= 53'd0;
        end else if (enable) begin
            sign_12 <= sign_11;
            rm_12 <= rm_11;
            product_2 <= product_1[105:53];
        end
    end

    // Pipeline stage 12
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_13 <= 1'b0;
            rm_13 <= 2'b00;
            product_3 <= 53'd0;
            product_shift <= 1'b0;
        end else if (enable) begin
            sign_13 <= sign_12;
            rm_13 <= rm_12;
            product_3 <= product_2;
            product_shift <= product_2[52];
        end
    end

    // Pipeline stage 13
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_14 <= 1'b0;
            rm_14 <= 2'b00;
            product_4 <= 54'd0;
        end else if (enable) begin
            sign_14 <= sign_13;
            rm_14 <= rm_13;
            if (product_shift)
                product_4 <= {1'b0, product_3[52:0]};
            else
                product_4 <= {product_3, 1'b0};
        end
    end

    // Pipeline stage 14
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_15 <= 1'b0;
            rm_15 <= 2'b00;
            product_5 <= 54'd0;
        end else if (enable) begin
            sign_15 <= sign_14;
            rm_15 <= rm_14;
            product_5 <= product_4;
        end
    end

    // Pipeline stage 15
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_16 <= 1'b0;
            product_6 <= 54'd0;
            product_overflow <= 1'b0;
            round_nearest_mode <= 1'b0;
            round_posinf_mode <= 1'b0;
            round_neginf_mode <= 1'b0;
        end else if (enable) begin
            sign_16 <= sign_15;
            product_6 <= product_5;
            product_overflow <= product_5[53];
            round_nearest_mode <= (rm_15 == 2'b00);
            round_posinf_mode <= (rm_15 == 2'b10);
            round_neginf_mode <= (rm_15 == 2'b11);
        end
    end

    // Pipeline stage 16: Rounding logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_17 <= 1'b0;
            product_7 <= 54'd0;
            round_nearest_trigger <= 1'b0;
            round_nearest_exception <= 1'b0;
            round_nearest_enable <= 1'b0;
            round_posinf_trigger <= 1'b0;
            round_posinf_enable <= 1'b0;
            round_neginf_trigger <= 1'b0;
            round_neginf_enable <= 1'b0;
            round_enable <= 1'b0;
            exponent_gt_prodshift <= 1'b0;
            exponent_is_infinity <= 1'b0;
            set_mantissa_zero <= 1'b0;
            exponent_gt_expoffset <= 1'b0;
        end else if (enable) begin
            sign_17 <= sign_16;
            product_7 <= product_6;
            // Rounding triggers
            round_nearest_trigger <= product_6[0] & (product_5[1] | |product_5[0]);
            round_nearest_exception <= product_6[0] & ~product_5[1] & ~|product_5[0];
            round_nearest_enable <= round_nearest_mode & (product_6[0] | round_nearest_exception);
            round_posinf_trigger <= |product_5[0] & ~sign_16;
            round_posinf_enable <= round_posinf_mode & round_posinf_trigger;
            round_neginf_trigger <= |product_5[0] & sign_16;
            round_neginf_enable <= round_neginf_mode & round_neginf_trigger;
            round_enable <= round_nearest_enable | round_posinf_enable | round_neginf_enable;
            exponent_gt_prodshift <= 1'b0;
            exponent_is_infinity <= 1'b0;
            set_mantissa_zero <= 1'b0;
            exponent_gt_expoffset <= 1'b0;
        end
    end

    // Pipeline stage 17
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_18 <= 1'b0;
        end else if (enable) begin
            sign_18 <= sign_17;
        end
    end

    // Pipeline stage 18
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_19 <= 1'b0;
        end else if (enable) begin
            sign_19 <= sign_18;
        end
    end

    // Pipeline stage 19
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_20 <= 1'b0;
            outfp <= 64'd0;
            ready <= 1'b0;
        end else if (enable) begin
            sign_20 <= sign_19;
            if (round_enable) begin
                if (product_overflow)
                    outfp <= {sign_20, 11'd0, 52'd0};
                else
                    outfp <= {sign_20, exponent_9[10:0], product_7[52:1] + 1'b1};
            end else begin
                if (product_overflow)
                    outfp <= {sign_20, 11'd0, 52'd0};
                else
                    outfp <= {sign_20, exponent_9[10:0], product_7[52:1]};
            end
            ready <= 1'b1;
        end
    end

endmodule
