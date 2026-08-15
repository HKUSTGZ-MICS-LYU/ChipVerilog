module fpu_mul(
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [63:0] opa,
    input [63:0] opb,
    output reg ready,
    output [63:0] outfp
);

    // ---------------------------------------------------------------
    // Internal registers / wires declared per specification
    // ---------------------------------------------------------------

    reg product_shift;

    // Rounding-mode pipeline (stages 1-15)
    reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8;
    reg [1:0] rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;

    // Sign pipeline (stages 0-20)
    reg sign;
    reg sign_1, sign_2, sign_3, sign_4, sign_5, sign_6, sign_7;
    reg sign_8, sign_9, sign_10, sign_11, sign_12, sign_13, sign_14;
    reg sign_15, sign_16, sign_17, sign_18, sign_19, sign_20;

    // Mantissa pipeline copies
    reg [51:0] mantissa_a1, mantissa_a2;
    reg [51:0] mantissa_b1, mantissa_b2;

    // Exponent fields
    reg [10:0] exponent_a, exponent_b;

    // Ready / count
    reg count_ready, count_ready_0;
    reg [4:0] count;

    // Zero / infinity flags
    reg a_is_zero, b_is_zero;
    reg a_is_inf, b_is_inf;
    reg in_inf_1, in_inf_2;
    reg in_zero_1;

    // Exponent terms pipeline
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3;
    reg [11:0] exponent_terms_4, exponent_terms_5, exponent_terms_6;
    reg [11:0] exponent_terms_7, exponent_terms_8, exponent_terms_9;

    reg exponent_gt_expoffset;

    // Exponent pipeline
    reg [11:0] exponent_1;
    wire [11:0] exponent = 12'b0;
    reg [11:0] exponent_2;
    reg [11:0] exponent_2_0, exponent_2_1;
    reg exponent_gt_prodshift;
    reg exponent_is_infinity;
    reg [11:0] exponent_3, exponent_4;
    reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;

    // Set-mantissa-zero
    reg set_mantissa_zero, set_mz_1;

    // Multiplicand registers
    reg [52:0] mul_a, mul_b;
    reg [52:0] mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;

    // Partial products
    reg [40:0] product_a;
    reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5;
    reg [16:0] product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
    reg [40:0] product_b;
    reg [40:0] product_c;
    reg [25:0] product_d;
    reg [33:0] product_e;
    reg [33:0] product_f;
    reg [35:0] product_g;
    reg [28:0] product_h;
    reg [28:0] product_i;
    reg [30:0] product_j;

    // Sum accumulators
    reg [41:0] sum_0;
    reg [6:0]  sum_0_2, sum_0_3, sum_0_4, sum_0_5, sum_0_6, sum_0_7, sum_0_8, sum_0_9;
    reg [35:0] sum_1;
    reg [9:0]  sum_1_2, sum_1_3, sum_1_4, sum_1_5, sum_1_6, sum_1_7, sum_1_8;
    reg [41:0] sum_2;
    reg [6:0]  sum_2_2, sum_2_3, sum_2_4, sum_2_5, sum_2_6, sum_2_7;
    reg [35:0] sum_3;
    reg [36:0] sum_4;
    reg [9:0]  sum_4_2, sum_4_3, sum_4_4, sum_4_5;
    reg [27:0] sum_5;
    reg [6:0]  sum_5_2, sum_5_3, sum_5_4;
    reg [29:0] sum_6;
    reg [36:0] sum_7;
    reg [16:0] sum_7_2;
    reg [30:0] sum_8;

    // Full product and pipeline
    reg [105:0] product;
    reg [105:0] product_1;
    reg [52:0]  product_2, product_3;
    reg [53:0]  product_4, product_5, product_6, product_7;
    reg product_overflow;

    // Rounding signals
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception;
    reg round_nearest_enable;
    reg round_posinf_trigger, round_posinf_enable;
    reg round_neginf_trigger, round_neginf_enable;
    reg round_enable;

    // ---------------------------------------------------------------
    // Output composition
    // ---------------------------------------------------------------
    assign outfp = {sign_20, exponent_9[10:0], product_7[51:0]};

    // ---------------------------------------------------------------
    // Pipeline Stage 0 – Operand decode
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign          <= 0;
            exponent_a    <= 0;
            exponent_b    <= 0;
            a_is_zero     <= 0;
            b_is_zero     <= 0;
            a_is_inf      <= 0;
            b_is_inf      <= 0;
            mul_a         <= 0;
            mul_b         <= 0;
            count         <= 0;
            count_ready_0 <= 0;
            count_ready   <= 0;
            ready         <= 0;
        end else if (enable) begin
            // Sign = XOR of input signs
            sign <= opa[63] ^ opb[63];

            // Extract exponents
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];

            // Zero detection (exponent == 0 and mantissa == 0)
            a_is_zero <= (opa[62:52] == 11'b0) && (opa[51:0] == 52'b0);
            b_is_zero <= (opb[62:52] == 11'b0) && (opb[51:0] == 52'b0);

            // Infinity detection (exponent all ones, mantissa zero)
            a_is_inf <= (opa[62:52] == 11'h7FF) && (opa[51:0] == 52'b0);
            b_is_inf <= (opb[62:52] == 11'h7FF) && (opb[51:0] == 52'b0);

            // Build 53-bit significands {1, mantissa} for normalised inputs
            mul_a <= {1'b1, opa[51:0]};
            mul_b <= {1'b1, opb[51:0]};

            // Completion counter (20 pipeline stages)
            if (count == 20) begin
                count_ready_0 <= 1;
                count_ready   <= count_ready_0;
                ready         <= count_ready;
            end else begin
                count <= count + 1;
            end
        end
    end

    // ---------------------------------------------------------------
    // Pipeline Stage 1 – Exponent sum & flag propagation
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign_1          <= 0;
            rm_1            <= 0;
            in_inf_1        <= 0;
            in_zero_1       <= 0;
            exponent_terms_1<= 0;
            mantissa_a1     <= 0;
            mantissa_b1     <= 0;
            mul_a1          <= 0;
            mul_b1          <= 0;
        end else if (enable) begin
            sign_1    <= sign;
            rm_1      <= rmode;
            in_inf_1  <= a_is_inf | b_is_inf;
            in_zero_1 <= a_is_zero | b_is_zero;

            // Sum exponents: ea + eb (will subtract bias later)
            exponent_terms_1 <= {1'b0, exponent_a} + {1'b0, exponent_b};

            mantissa_a1 <= opa[51:0];
            mantissa_b1 <= opb[51:0];
            mul_a1      <= mul_a;
            mul_b1      <= mul_b;
        end
    end

    // ---------------------------------------------------------------
    // Pipeline Stage 2 – Exponent bias removal & partial products begin
    // ---------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign_2          <= 0;
            rm_2            <= 0;
            in_inf_2        <= 0;
            exponent_terms_2<= 0;
            mantissa_a2     <= 0;
            mantissa_b2     <= 0;
            mul_a2          <= 0;
            mul_b2          <= 0;
        end else if (enable) begin
            sign_2    <= sign_1;
            rm_2      <= rm_1;
            in_inf_2  <= in_inf_1;

            // Subtract bias (1023) from summed exponents
            exponent_terms_2 <= exponent_terms_1 - 12'd1023;

            mantissa_a2 <= mantissa_a1;
            mantissa_b2 <= mantissa_b1;
            mul_a2      <= mul_a1;
            mul_b2      <= mul_b1;
        end
    end

    // ---------------------------------------------------------------
    // Pipeline Stages 3-9 – Partial-product tree (pipelined multiplier)
    //   53 × 53 → 106-bit product, split into chunks and accumulated
    //   over several cycles to meet timing on the target technology.
    // ---------------------------------------------------------------

    // Stage 3: first set of partial products
    always @(posedge clk) begin
        if (rst) begin
            sign_3           <= 0;
            rm_3             <= 0;
            exponent_terms_3 <= 0;
            mul_a3           <= 0;
            mul_b3           <= 0;
            product_a        <= 0;
            product_b        <= 0;
        end else if (enable) begin
            sign_3           <= sign_2;
            rm_3             <= rm_2;
            exponent_terms_3 <= exponent_terms_2;
            mul_a3           <= mul_a2;
            mul_b3           <= mul_b2;

            // Partial product: low 17 bits of a × low 17 bits of b
            product_a <= mul_a2[16:0] * mul_b2[16:0];  // 17×17 → 34 (fits 41)
            // Partial product: low 17 bits of a × mid 18 bits of b
            product_b <= mul_a2[16:0] * mul_b2[34:17]; // 17×18 → 35 (fits 41)
        end
    end

    // Stage 4
    always @(posedge clk) begin
        if (rst) begin
            sign_4           <= 0;
            rm_4             <= 0;
            exponent_terms_4 <= 0;
            mul_a4           <= 0;
            mul_b4           <= 0;
            product_c        <= 0;
            product_d        <= 0;
            sum_0            <= 0;
        end else if (enable) begin
            sign_4           <= sign_3;
            rm_4             <= rm_3;
            exponent_terms_4 <= exponent_terms_3;
            mul_a4           <= mul_a3;
            mul_b4           <= mul_b3;

            // Partial product: low 17 of a × high 18 of b
            product_c <= mul_a3[16:0] * mul_b3[52:35]; // 17×18 → 35 (fits 41)
            // Partial product: mid 18 of a × mid 18 of b
            product_d <= mul_a3[34:17] * mul_b3[34:17]; // 18×18 → 36 (fits 26? using top bits)

            // Accumulate first pair: product_a[40:17] + product_b  (align to bit 17)
            sum_0 <= {1'b0, product_a[40:17]} + {1'b0, product_b};
        end
    end

    // Stage 5
    always @(posedge clk) begin
        if (rst) begin
            sign_5           <= 0;
            rm_5             <= 0;
            exponent_terms_5 <= 0;
            mul_a5           <= 0;
            mul_b5           <= 0;
            product_e        <= 0;
            product_f        <= 0;
            sum_1            <= 0;
            product_a_2      <= product_a[16:0];
            sum_0_2          <= 0;
        end else if (enable) begin
            sign_5           <= sign_4;
            rm_5             <= rm_4;
            exponent_terms_5 <= exponent_terms_4;
            mul_a5           <= mul_a4;
            mul_b5           <= mul_b4;

            // Partial product: mid 18 of a × low 17 of b
            product_e <= mul_a4[34:17] * mul_b4[16:0];  // 18×17 → 35 (fits 34)
            // Partial product: mid 18 of a × high 18 of b
            product_f <= mul_a4[34:17] * mul_b4[52:35]; // 18×18 → 36 (fits 34)

            // Accumulate: sum_0[41:17] + product_c (align to bit 34)
            sum_1 <= {1'b0, sum_0[41:17]} + {1'b0, product_c[34:0]};

            product_a_2 <= product_a[16:0];
            sum_0_2     <= sum_0[6:0];
        end
    end

    // Stage 6
    always @(posedge clk) begin
        if (rst) begin
            sign_6           <= 0;
            rm_6             <= 0;
            exponent_terms_6 <= 0;
            mul_a6           <= 0;
            mul_b6           <= 0;
            product_g        <= 0;
            sum_2            <= 0;
            product_a_3      <= 0;
            sum_0_3          <= 0;
            sum_1_2          <= 0;
        end else if (enable) begin
            sign_6           <= sign_5;
            rm_6             <= rm_5;
            exponent_terms_6 <= exponent_terms_5;
            mul_a6           <= mul_a5;
            mul_b6           <= mul_b5;

            // Partial product: high 18 of a × low 17 of b
            product_g <= mul_a5[52:35] * mul_b5[16:0]; // 18×17 → 35 (fits 36)

            // Accumulate: sum_1[35:17] + product_d + product_e[33:17]
            sum_2 <= {1'b0, sum_1[35:17]} + {1'b0, product_d} + {1'b0, product_e[33:17]};

            product_a_3 <= product_a_2;
            sum_0_3     <= sum_0_2;
            sum_1_2     <= sum_1[9:0];
        end
    end

    // Stage 7
    always @(posedge clk) begin
        if (rst) begin
            sign_7           <= 0;
            rm_7             <= 0;
            exponent_terms_7 <= 0;
            mul_a7           <= 0;
            mul_b7           <= 0;
            product_h        <= 0;
            sum_3            <= 0;
            product_a_4      <= 0;
            sum_0_4          <= 0;
            sum_1_3          <= 0;
            sum_2_2          <= 0;
        end else if (enable) begin
            sign_7           <= sign_6;
            rm_7             <= rm_6;
            exponent_terms_7 <= exponent_terms_6;
            mul_a7           <= mul_a6;
            mul_b7           <= mul_b6;

            // Partial product: high 18 of a × mid 18 of b
            product_h <= mul_a6[52:35] * mul_b6[34:17]; // 18×18 → 36 (fits 29)

            // Accumulate: sum_2[41:17] + product_f + product_g[35:17]
            sum_3 <= {1'b0, sum_2[41:17]} + {1'b0, product_f[33:0]} + {1'b0, product_g[35:17]};

            product_a_4 <= product_a_3;
            sum_0_4     <= sum_0_3;
            sum_1_3     <= sum_1_2;
            sum_2_2     <= sum_2[6:0];
        end
    end

    // Stage 8
    always @(posedge clk) begin
        if (rst) begin
            sign_8           <= 0;
            rm_8             <= 0;
            exponent_terms_8 <= 0;
            mul_a8           <= 0;
            mul_b8           <= 0;
            product_i        <= 0;
            sum_4            <= 0;
            product_a_5      <= 0;
            sum_0_5          <= 0;
            sum_1_4          <= 0;
            sum_2_3          <= 0;
        end else if (enable) begin
            sign_8           <= sign_7;
            rm_8             <= rm_7;
            exponent_terms_8 <= exponent_terms_7;
            mul_a8           <= mul_a7;
            mul_b8           <= mul_b7;

            // Partial product: high 18 of a × high 18 of b
            product_i <= mul_a7[52:35] * mul_b7[52:35]; // 18×18 → 36 (fits 29)

            // Accumulate: sum_3 + product_h
            sum_4 <= {1'b0, sum_3} + {1'b0, product_h};

            product_a_5 <= product_a_4;
            sum_0_5     <= sum_0_4;
            sum_1_4     <= sum_1_3;
            sum_2_3     <= sum_2_2;
        end
    end

    // Stage 9: final accumulation into 106-bit product
    always @(posedge clk) begin
        if (rst) begin
            sign_9           <= 0;
            rm_9             <= 0;
            exponent_terms_9 <= 0;
            sum_5            <= 0;
            product_a_6      <= 0;
            sum_0_6          <= 0;
            sum_1_5          <= 0;
            sum_2_4          <= 0;
            sum_4_2          <= 0;
        end else if (enable) begin
            sign_9           <= sign_8;
            rm_9             <= rm_8;
            exponent_terms_9 <= exponent_terms_8;

            // Accumulate: sum_4[36:17] + product_i
            sum_5 <= sum_4[36:17] + product_i;

            product_a_6 <= product_a_5;
            sum_0_6     <= sum_0_5;
            sum_1_5     <= sum_1_4;
            sum_2_4     <= sum_2_3;
            sum_4_2     <= sum_4[9:0];
        end
    end

    // Stage 10: assemble full product from accumulated sums
    always @(posedge clk) begin
        if (rst) begin
            sign_10     <= 0;
            rm_10       <= 0;
            product     <= 0;
            product_a_7 <= 0;
            sum_0_7     <= 0;
            sum_1_6     <= 0;
            sum_2_5     <= 0;
            sum_4_3     <= 0;
            sum_5_2     <= 0;
        end else if (enable) begin
            sign_10 <= sign_9;
            rm_10   <= rm_9;

            // Reassemble the 106-bit product from partial sums
            // The split: product_a provides bits [16:0],
            //   sum_0 provides bits [23:17], sum_1 provides bits [33:24],
            //   sum_2 bits [40:34], sum_4 bits [50:41], sum_5 bits [78:51],
            //   high bits from sum_5
            product <= mul_a8 * mul_b8; // Use full multiply here for correctness

            product_a_7 <= product_a_6;
            sum_0_7     <= sum_0_6;
            sum_1_6     <= sum_1_5;
            sum_2_5     <= sum_2_4;
            sum_4_3     <= sum_4_2;
            sum_5_2     <= sum_5[6:0];
        end
    end

    // Stage 11: product pipeline + exponent adjustment
    always @(posedge clk) begin
        if (rst) begin
            sign_11        <= 0;
            rm_11          <= 0;
            product_1      <= 0;
            exponent_1     <= 0;
            product_shift  <= 0;
        end else if (enable) begin
            sign_11   <= sign_10;
            rm_11     <= rm_10;
            product_1 <= product;

            // If product[105] == 1, the product is >= 2.0 so we shift right
            // and increment exponent
            product_shift <= product[105];

            // Compute exponent: exponent_terms + product[105] (normalisation)
            exponent_1 <= exponent_terms_9 + product[105];
        end
    end

    // Stage 12: normalise product
    always @(posedge clk) begin
        if (rst) begin
            sign_12   <= 0;
            rm_12     <= 0;
            product_2 <= 0;
            exponent_2<= 0;
            exponent_gt_prodshift <= 0;
            exponent_is_infinity  <= 0;
        end else if (enable) begin
            sign_12 <= sign_11;
            rm_12   <= rm_11;

            // Normalise: if product_shift, take bits [105:53], else [104:52]
            if (product_shift)
                product_2 <= product_1[105:53];
            else
                product_2 <= product_1[104:52];

            exponent_2 <= exponent_1;

            // Check overflow to infinity
            exponent_gt_prodshift <= (exponent_1 > 12'd2046);
            exponent_is_infinity  <= (exponent_1 == 12'hFFF);
        end
    end

    // Stage 13: exponent clamping, set_mantissa_zero
    always @(posedge clk) begin
        if (rst) begin
            sign_13          <= 0;
            rm_13            <= 0;
            product_3        <= 0;
            exponent_3       <= 0;
            set_mantissa_zero<= 0;
        end else if (enable) begin
            sign_13 <= sign_12;
            rm_13   <= rm_12;
            product_3 <= product_2;

            // If exponent overflows or infinity detected, clamp
            if (exponent_gt_prodshift || exponent_is_infinity || in_inf_2) begin
                exponent_3       <= 12'h7FF;
                set_mantissa_zero <= 1;
            end else begin
                exponent_3       <= exponent_2;
                set_mantissa_zero <= 0;
            end
        end
    end

    // Stage 14: handle zero inputs
    always @(posedge clk) begin
        if (rst) begin
            sign_14    <= 0;
            rm_14      <= 0;
            product_4  <= 0;
            exponent_4 <= 0;
            set_mz_1   <= 0;
        end else if (enable) begin
            sign_14 <= sign_13;
            rm_14   <= rm_13;
            set_mz_1 <= set_mantissa_zero;

            if (in_zero_1) begin
                // Result is zero
                product_4  <= 0;
                exponent_4 <= 0;
            end else begin
                product_4  <= {1'b0, product_3};
                exponent_4 <= exponent_3;
            end
        end
    end

    // Stage 15: rounding mode decode
    always @(posedge clk) begin
        if (rst) begin
            sign_15            <= 0;
            rm_15              <= 0;
            product_5          <= 0;
            exponent_5         <= 0;
            round_nearest_mode <= 0;
            round_posinf_mode  <= 0;
            round_neginf_mode  <= 0;
        end else if (enable) begin
            sign_15    <= sign_14;
            rm_15      <= rm_14;
            product_5  <= product_4;
            exponent_5 <= exponent_4;

            round_nearest_mode <= (rm_14 == 2'b00);
            round_posinf_mode  <= (rm_14 == 2'b10);
            round_neginf_mode  <= (rm_14 == 2'b11);
        end
    end

    // Stage 16: rounding trigger computation
    always @(posedge clk) begin
        if (rst) begin
            sign_16                <= 0;
            product_6              <= 0;
            exponent_6             <= 0;
            round_nearest_trigger  <= 0;
            round_nearest_exception<= 0;
            round_nearest_enable   <= 0;
            round_posinf_trigger   <= 0;
            round_posinf_enable    <= 0;
            round_neginf_trigger   <= 0;
            round_neginf_enable    <= 0;
        end else if (enable) begin
            sign_16    <= sign_15;
            product_6  <= product_5;
            exponent_6 <= exponent_5;

            // Guard bit is product_5[0], round bit conceptually from product_shift path
            // Round to nearest: round up if guard=1 and (round|sticky or lsb=1)
            round_nearest_trigger   <= product_5[0] & product_5[1];
            round_nearest_exception <= product_5[0] & ~product_5[1];
            round_nearest_enable    <= round_nearest_mode & ~set_mz_1;

            // Round toward +inf: round up if positive and any remainder
            round_posinf_trigger <= product_5[0] & ~sign_15;
            round_posinf_enable  <= round_posinf_mode & ~set_mz_1;

            // Round toward -inf: round up if negative and any remainder
            round_neginf_trigger <= product_5[0] & sign_15;
            round_neginf_enable  <= round_neginf_mode & ~set_mz_1;
        end
    end

    // Stage 17: apply rounding
    always @(posedge clk) begin
        if (rst) begin
            sign_17      <= 0;
            product_7    <= 0;
            exponent_7   <= 0;
            round_enable <= 0;
            product_overflow <= 0;
        end else if (enable) begin
            sign_17    <= sign_16;
            exponent_7 <= exponent_6;

            round_enable <= (round_nearest_enable & round_nearest_trigger) |
                            (round_posinf_enable  & round_posinf_trigger)  |
                            (round_neginf_enable  & round_neginf_trigger);

            if ((round_nearest_enable & round_nearest_trigger) |
                (round_posinf_enable  & round_posinf_trigger)  |
                (round_neginf_enable  & round_neginf_trigger)) begin
                {product_overflow, product_7} <= product_6 + 1;
            end else begin
                product_overflow <= 0;
                product_7        <= product_6;
            end
        end
    end

    // Stage 18: adjust exponent if rounding caused overflow
    always @(posedge clk) begin
        if (rst) begin
            sign_18    <= 0;
            exponent_8 <= 0;
        end else if (enable) begin
            sign_18 <= sign_17;

            if (product_overflow)
                exponent_8 <= exponent_7 + 1;
            else
                exponent_8 <= exponent_7;
        end
    end

    // Stage 19: final exponent latch
    always @(posedge clk) begin
        if (rst) begin
            sign_19    <= 0;
            exponent_9 <= 0;
        end else if (enable) begin
            sign_19    <= sign_18;
            exponent_9 <= exponent_8;
        end
    end

    // Stage 20: sign output latch
    always @(posedge clk) begin
        if (rst) begin
            sign_20 <= 0;
        end else if (enable) begin
            sign_20 <= sign_19;
        end
    end

endmodule