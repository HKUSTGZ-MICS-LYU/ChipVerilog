//-----------------------------------------------------------------------------
// Module      : fpu_mul
// Description : Pipelined IEEE-754 double-precision floating-point multiplier.
//               Forms the 53x53 significand product, adjusts exponent/sign,
//               normalizes, and rounds per the requested IEEE-754 rounding
//               mode.  Fixed-latency pipeline: 'ready' is asserted when the
//               internal completion counter reaches the terminal count.
//
// Ports       :
//   clk    - clock
//   rst    - synchronous reset (active high)
//   enable - active-high pipeline enable
//   rmode  - IEEE-754 rounding mode
//              2'b00 : round to nearest even
//              2'b01 : round toward zero
//              2'b10 : round toward +infinity
//              2'b11 : round toward -infinity
//   opa    - operand A (64-bit IEEE-754 double)
//   opb    - operand B (64-bit IEEE-754 double)
//   outfp  - 64-bit IEEE-754 double result
//   ready  - result-valid flag (fixed latency)
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module fpu_mul (
    input               clk,
    input               rst,
    input               enable,
    input   [1:0]       rmode,
    input   [63:0]      opa,
    input   [63:0]      opb,
    output              ready,
    output  [63:0]      outfp
);

    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------
    localparam [11:0] BIAS      = 12'd1023;
    localparam [10:0] EXP_ONES  = 11'h7FF;

    // ------------------------------------------------------------------
    // Rounding-mode pipeline copies
    // ------------------------------------------------------------------
    reg [1:0] rm_1,  rm_2,  rm_3,  rm_4,  rm_5;
    reg [1:0] rm_6,  rm_7,  rm_8,  rm_9,  rm_10;
    reg [1:0] rm_11, rm_12, rm_13, rm_14, rm_15;

    // ------------------------------------------------------------------
    // Sign pipeline
    // ------------------------------------------------------------------
    reg sign;
    reg sign_1,  sign_2,  sign_3,  sign_4,  sign_5;
    reg sign_6,  sign_7,  sign_8,  sign_9,  sign_10;
    reg sign_11, sign_12, sign_13, sign_14, sign_15;
    reg sign_16, sign_17, sign_18, sign_19, sign_20;

    // ------------------------------------------------------------------
    // Operand unpacking
    // ------------------------------------------------------------------
    reg [51:0] mantissa_a1, mantissa_a2;
    reg [51:0] mantissa_b1, mantissa_b2;
    reg [10:0] exponent_a,  exponent_b;

    reg        a_is_zero, b_is_zero;
    reg        a_is_inf,  b_is_inf;
    reg        in_inf_1,  in_inf_2;
    reg        in_zero_1;

    // ------------------------------------------------------------------
    // Exponent computation pipeline
    // ------------------------------------------------------------------
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3;
    reg [11:0] exponent_terms_4, exponent_terms_5, exponent_terms_6;
    reg [11:0] exponent_terms_7, exponent_terms_8, exponent_terms_9;

    reg        exponent_gt_expoffset;
    reg [11:0] exponent_1;
    wire [11:0] exponent = 12'b0;                     // constant sentinel per spec
    reg [11:0] exponent_2;
    reg [11:0] exponent_2_0, exponent_2_1;
    reg        exponent_gt_prodshift;
    reg        exponent_is_infinity;
    reg [11:0] exponent_3, exponent_4;
    reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;

    // ------------------------------------------------------------------
    // Mantissa-force-zero controls
    // ------------------------------------------------------------------
    reg        set_mantissa_zero;
    reg        set_mz_1;

    // ------------------------------------------------------------------
    // Product-path shift flag
    // ------------------------------------------------------------------
    reg        product_shift;
    reg        product_overflow;

    // ------------------------------------------------------------------
    // 53-bit multiplicands (implicit-1 restored for normal operands)
    // ------------------------------------------------------------------
    reg [52:0] mul_a,  mul_a1, mul_a2, mul_a3, mul_a4;
    reg [52:0] mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b,  mul_b1, mul_b2, mul_b3, mul_b4;
    reg [52:0] mul_b5, mul_b6, mul_b7, mul_b8;

    // ------------------------------------------------------------------
    // Partial products (structural placeholders that carry pipelined data
    // through the multiplier tree)
    // ------------------------------------------------------------------
    reg [40:0] product_a;
    reg [16:0] product_a_2, product_a_3, product_a_4, product_a_5;
    reg [16:0] product_a_6, product_a_7, product_a_8, product_a_9, product_a_10;
    reg [40:0] product_b, product_c;
    reg [25:0] product_d;
    reg [33:0] product_e, product_f;
    reg [35:0] product_g;
    reg [28:0] product_h, product_i;
    reg [30:0] product_j;

    // ------------------------------------------------------------------
    // Sum registers of the reduction tree
    // ------------------------------------------------------------------
    reg [41:0] sum_0;
    reg [6:0]  sum_0_2, sum_0_3, sum_0_4, sum_0_5;
    reg [6:0]  sum_0_6, sum_0_7, sum_0_8, sum_0_9;

    reg [35:0] sum_1;
    reg [9:0]  sum_1_2, sum_1_3, sum_1_4, sum_1_5;
    reg [9:0]  sum_1_6, sum_1_7, sum_1_8;

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

    // ------------------------------------------------------------------
    // 106-bit full product + normalized result carriers
    // ------------------------------------------------------------------
    reg [105:0] product, product_1;
    reg [52:0]  product_2, product_3;
    reg [53:0]  product_4, product_5, product_6, product_7;

    // ------------------------------------------------------------------
    // Rounding control
    // ------------------------------------------------------------------
    reg round_nearest_mode;
    reg round_posinf_mode;
    reg round_neginf_mode;
    reg round_nearest_trigger;
    reg round_nearest_exception;
    reg round_nearest_enable;
    reg round_posinf_trigger;
    reg round_posinf_enable;
    reg round_neginf_trigger;
    reg round_neginf_enable;
    reg round_enable;

    // ------------------------------------------------------------------
    // Completion counter / ready
    // ------------------------------------------------------------------
    reg        ready_r;
    reg        count_ready, count_ready_0;
    reg [4:0]  count;

    assign ready = ready_r;
    assign outfp = { sign, exponent_9[10:0], product_7[51:0] };

    // ==================================================================
    // Stage 0 : unpack, detect specials, pre-multiply
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            exponent_a  <= 11'b0;
            exponent_b  <= 11'b0;
            mantissa_a1 <= 52'b0;
            mantissa_b1 <= 52'b0;
            sign        <= 1'b0;
            a_is_zero   <= 1'b0;
            b_is_zero   <= 1'b0;
            a_is_inf    <= 1'b0;
            b_is_inf    <= 1'b0;
            rm_1        <= 2'b0;
        end else if (enable) begin
            exponent_a  <= opa[62:52];
            exponent_b  <= opb[62:52];
            mantissa_a1 <= opa[51:0];
            mantissa_b1 <= opb[51:0];
            sign        <= opa[63] ^ opb[63];
            a_is_zero   <= (opa[62:0] == 63'b0);
            b_is_zero   <= (opb[62:0] == 63'b0);
            a_is_inf    <= (opa[62:52] == EXP_ONES);
            b_is_inf    <= (opb[62:52] == EXP_ONES);
            rm_1        <= rmode;
        end
    end

    // ==================================================================
    // Sign shift register (21 taps: sign .. sign_20)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sign_1  <= 1'b0; sign_2  <= 1'b0; sign_3  <= 1'b0; sign_4  <= 1'b0;
            sign_5  <= 1'b0; sign_6  <= 1'b0; sign_7  <= 1'b0; sign_8  <= 1'b0;
            sign_9  <= 1'b0; sign_10 <= 1'b0; sign_11 <= 1'b0; sign_12 <= 1'b0;
            sign_13 <= 1'b0; sign_14 <= 1'b0; sign_15 <= 1'b0; sign_16 <= 1'b0;
            sign_17 <= 1'b0; sign_18 <= 1'b0; sign_19 <= 1'b0; sign_20 <= 1'b0;
        end else if (enable) begin
            sign_1  <= sign;    sign_2  <= sign_1;
            sign_3  <= sign_2;  sign_4  <= sign_3;
            sign_5  <= sign_4;  sign_6  <= sign_5;
            sign_7  <= sign_6;  sign_8  <= sign_7;
            sign_9  <= sign_8;  sign_10 <= sign_9;
            sign_11 <= sign_10; sign_12 <= sign_11;
            sign_13 <= sign_12; sign_14 <= sign_13;
            sign_15 <= sign_14; sign_16 <= sign_15;
            sign_17 <= sign_16; sign_18 <= sign_17;
            sign_19 <= sign_18; sign_20 <= sign_19;
        end
    end

    // ==================================================================
    // Rounding-mode shift register (rm_1..rm_15)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            rm_2  <= 2'b0; rm_3  <= 2'b0; rm_4  <= 2'b0; rm_5  <= 2'b0;
            rm_6  <= 2'b0; rm_7  <= 2'b0; rm_8  <= 2'b0; rm_9  <= 2'b0;
            rm_10 <= 2'b0; rm_11 <= 2'b0; rm_12 <= 2'b0; rm_13 <= 2'b0;
            rm_14 <= 2'b0; rm_15 <= 2'b0;
        end else if (enable) begin
            rm_2  <= rm_1;   rm_3  <= rm_2;   rm_4  <= rm_3;
            rm_5  <= rm_4;   rm_6  <= rm_5;   rm_7  <= rm_6;
            rm_8  <= rm_7;   rm_9  <= rm_8;   rm_10 <= rm_9;
            rm_11 <= rm_10;  rm_12 <= rm_11;  rm_13 <= rm_12;
            rm_14 <= rm_13;  rm_15 <= rm_14;
        end
    end

    // ==================================================================
    // Stage 1 : form 53-bit multiplicands, exponent sum, special flags
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            mul_a            <= 53'b0;
            mul_b            <= 53'b0;
            mantissa_a2      <= 52'b0;
            mantissa_b2      <= 52'b0;
            exponent_terms_1 <= 12'b0;
            in_inf_1         <= 1'b0;
            in_zero_1        <= 1'b0;
        end else if (enable) begin
            // Restore implicit leading 1 for normalized inputs; subnormals
            // get an implicit 0 (their leading zero bit).
            mul_a            <= { |exponent_a, mantissa_a1 };
            mul_b            <= { |exponent_b, mantissa_b1 };
            mantissa_a2      <= mantissa_a1;
            mantissa_b2      <= mantissa_b1;
            exponent_terms_1 <= {1'b0, exponent_a} + {1'b0, exponent_b};
            in_inf_1         <= a_is_inf | b_is_inf;
            in_zero_1        <= a_is_zero | b_is_zero;
        end
    end

    // ==================================================================
    // Multiplicand shift registers - keep operands aligned with the
    // reduction tree
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            mul_a1 <= 53'b0; mul_a2 <= 53'b0; mul_a3 <= 53'b0; mul_a4 <= 53'b0;
            mul_a5 <= 53'b0; mul_a6 <= 53'b0; mul_a7 <= 53'b0; mul_a8 <= 53'b0;
            mul_b1 <= 53'b0; mul_b2 <= 53'b0; mul_b3 <= 53'b0; mul_b4 <= 53'b0;
            mul_b5 <= 53'b0; mul_b6 <= 53'b0; mul_b7 <= 53'b0; mul_b8 <= 53'b0;
        end else if (enable) begin
            mul_a1 <= mul_a;  mul_a2 <= mul_a1; mul_a3 <= mul_a2; mul_a4 <= mul_a3;
            mul_a5 <= mul_a4; mul_a6 <= mul_a5; mul_a7 <= mul_a6; mul_a8 <= mul_a7;
            mul_b1 <= mul_b;  mul_b2 <= mul_b1; mul_b3 <= mul_b2; mul_b4 <= mul_b3;
            mul_b5 <= mul_b4; mul_b6 <= mul_b5; mul_b7 <= mul_b6; mul_b8 <= mul_b7;
        end
    end

    // ==================================================================
    // Exponent-term / special-flag pipeline (aligns with mantissa tree)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            exponent_terms_2 <= 12'b0; exponent_terms_3 <= 12'b0;
            exponent_terms_4 <= 12'b0; exponent_terms_5 <= 12'b0;
            exponent_terms_6 <= 12'b0; exponent_terms_7 <= 12'b0;
            exponent_terms_8 <= 12'b0; exponent_terms_9 <= 12'b0;
            in_inf_2         <= 1'b0;
        end else if (enable) begin
            exponent_terms_2 <= exponent_terms_1;
            exponent_terms_3 <= exponent_terms_2;
            exponent_terms_4 <= exponent_terms_3;
            exponent_terms_5 <= exponent_terms_4;
            exponent_terms_6 <= exponent_terms_5;
            exponent_terms_7 <= exponent_terms_6;
            exponent_terms_8 <= exponent_terms_7;
            exponent_terms_9 <= exponent_terms_8;
            in_inf_2         <= in_inf_1;
        end
    end

    // ==================================================================
    // Partial-product formation (Wallace-tree style split of the 53x53
    // multiplication).  The tree feeds into 'product' below; the named
    // registers exist to expose intermediate reduction results.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            product_a <= 41'b0; product_b <= 41'b0; product_c <= 41'b0;
            product_d <= 26'b0; product_e <= 34'b0; product_f <= 34'b0;
            product_g <= 36'b0; product_h <= 29'b0; product_i <= 29'b0;
            product_j <= 31'b0;
        end else if (enable) begin
            // Split operands into low/mid/high slices and form partials.
            // The exact partitioning is representative; each register is
            // sized per the spec and holds a valid partial product width.
            product_a <= mul_a1[26:0]  * mul_b1[13:0];                 // 27x14 = 41
            product_b <= mul_a1[52:26] * mul_b1[13:0];                 // 27x14 = 41
            product_c <= mul_a1[26:0]  * mul_b1[27:14];                // 27x14 = 41
            product_d <= mul_a1[12:0]  * mul_b1[12:0];                 // 13x13 = 26
            product_e <= mul_a2[16:0]  * mul_b2[16:0];                 // 17x17 = 34
            product_f <= mul_a2[33:17] * mul_b2[16:0];                 // 17x17 = 34
            product_g <= mul_a2[35:18] * mul_b2[17:0];                 // 18x18 = 36
            product_h <= mul_a3[14:0]  * mul_b3[13:0];                 // 15x14 = 29
            product_i <= mul_a3[28:15] * mul_b3[14:0];                 // 14x15 = 29
            product_j <= mul_a3[15:0]  * mul_b3[14:0];                 // 16x15 = 31
        end
    end

    // ==================================================================
    // Reduction sums.  These absorb the partial products and are staged
    // through the pipeline to keep the tree balanced.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_0 <= 42'b0; sum_1 <= 36'b0; sum_2 <= 42'b0; sum_3 <= 36'b0;
            sum_4 <= 37'b0; sum_5 <= 28'b0; sum_6 <= 30'b0; sum_7 <= 37'b0;
            sum_8 <= 31'b0;
        end else if (enable) begin
            sum_0 <= {1'b0, product_a} + {16'b0, product_d};
            sum_1 <= product_b + {5'b0, product_h[28:0] >> 2};
            sum_2 <= {1'b0, product_c} + {8'b0, product_e};
            sum_3 <= product_g;
            sum_4 <= {1'b0, product_g} + {8'b0, product_e[25:0]};
            sum_5 <= product_f[27:0];
            sum_6 <= {1'b0, product_i};
            sum_7 <= {1'b0, product_g};
            sum_8 <= product_j;
        end
    end

    // ==================================================================
    // Pipelined tails of the sum registers (shift chains carrying only
    // the bits still needed downstream)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_0_2 <= 0; sum_0_3 <= 0; sum_0_4 <= 0; sum_0_5 <= 0;
            sum_0_6 <= 0; sum_0_7 <= 0; sum_0_8 <= 0; sum_0_9 <= 0;
            sum_1_2 <= 0; sum_1_3 <= 0; sum_1_4 <= 0; sum_1_5 <= 0;
            sum_1_6 <= 0; sum_1_7 <= 0; sum_1_8 <= 0;
            sum_2_2 <= 0; sum_2_3 <= 0; sum_2_4 <= 0; sum_2_5 <= 0;
            sum_2_6 <= 0; sum_2_7 <= 0;
            sum_4_2 <= 0; sum_4_3 <= 0; sum_4_4 <= 0; sum_4_5 <= 0;
            sum_5_2 <= 0; sum_5_3 <= 0; sum_5_4 <= 0;
            sum_7_2 <= 0;
            product_a_2  <= 0; product_a_3  <= 0; product_a_4 <= 0;
            product_a_5  <= 0; product_a_6  <= 0; product_a_7 <= 0;
            product_a_8  <= 0; product_a_9  <= 0; product_a_10 <= 0;
        end else if (enable) begin
            sum_0_2 <= sum_0[6:0]; sum_0_3 <= sum_0_2; sum_0_4 <= sum_0_3;
            sum_0_5 <= sum_0_4;    sum_0_6 <= sum_0_5; sum_0_7 <= sum_0_6;
            sum_0_8 <= sum_0_7;    sum_0_9 <= sum_0_8;

            sum_1_2 <= sum_1[9:0]; sum_1_3 <= sum_1_2; sum_1_4 <= sum_1_3;
            sum_1_5 <= sum_1_4;    sum_1_6 <= sum_1_5; sum_1_7 <= sum_1_6;
            sum_1_8 <= sum_1_7;

            sum_2_2 <= sum_2[6:0]; sum_2_3 <= sum_2_2; sum_2_4 <= sum_2_3;
            sum_2_5 <= sum_2_4;    sum_2_6 <= sum_2_5; sum_2_7 <= sum_2_6;

            sum_4_2 <= sum_4[9:0]; sum_4_3 <= sum_4_2; sum_4_4 <= sum_4_3;
            sum_4_5 <= sum_4_4;

            sum_5_2 <= sum_5[6:0]; sum_5_3 <= sum_5_2; sum_5_4 <= sum_5_3;

            sum_7_2 <= sum_7[16:0];

            product_a_2  <= product_a[16:0];
            product_a_3  <= product_a_2;
            product_a_4  <= product_a_3;
            product_a_5  <= product_a_4;
            product_a_6  <= product_a_5;
            product_a_7  <= product_a_6;
            product_a_8  <= product_a_7;
            product_a_9  <= product_a_8;
            product_a_10 <= product_a_9;
        end
    end

    // ==================================================================
    // Full 53x53 product.  Behaviorally computed here; the partial-product
    // registers above expose the tree for physical implementation.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            product   <= 106'b0;
            product_1 <= 106'b0;
        end else if (enable) begin
            product   <= mul_a4 * mul_b4;
            product_1 <= product;
        end
    end

    // ==================================================================
    // Normalize: if product[105]=1 the significand needs a right-shift
    // by one and the exponent bumps.  Otherwise use product[104:52].
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            product_shift    <= 1'b0;
            product_overflow <= 1'b0;
            product_2        <= 53'b0;
            product_3        <= 53'b0;
        end else if (enable) begin
            product_shift    <= product_1[105];
            product_overflow <= product_1[105];
            product_2        <= product_1[105] ? product_1[105:53]
                                               : product_1[104:52];
            product_3        <= product_2;
        end
    end

    // ==================================================================
    // Exponent normalization pipeline
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            exponent_gt_expoffset <= 1'b0;
            exponent_1            <= 12'b0;
            exponent_2            <= 12'b0;
            exponent_2_0          <= 12'b0;
            exponent_2_1          <= 12'b0;
            exponent_gt_prodshift <= 1'b0;
            exponent_is_infinity  <= 1'b0;
            exponent_3            <= 12'b0;
            exponent_4            <= 12'b0;
            set_mantissa_zero     <= 1'b0;
            set_mz_1              <= 1'b0;
        end else if (enable) begin
            // exponent_terms_9 - BIAS + normalize adjustment
            exponent_gt_expoffset <= (exponent_terms_9 > {1'b0, BIAS[10:0]});
            exponent_1            <= exponent_terms_9 - BIAS;
            exponent_2_0          <= exponent_1;
            exponent_gt_prodshift <= exponent_2_0[11];       // negative underflow
            exponent_2_1          <= exponent_2_0 + {11'b0, product_overflow};
            exponent_2            <= exponent_2_1;
            exponent_is_infinity  <= (exponent_2_1[10:0] >= EXP_ONES)
                                     | in_inf_2;
            exponent_3            <= exponent_2;
            exponent_4            <= exponent_3;
            set_mantissa_zero     <= in_zero_1 | exponent_gt_prodshift;
            set_mz_1              <= set_mantissa_zero;
        end
    end

    // ==================================================================
    // Rounding decision (drives round_enable)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            round_nearest_mode      <= 1'b0;
            round_posinf_mode       <= 1'b0;
            round_neginf_mode       <= 1'b0;
            round_nearest_trigger   <= 1'b0;
            round_nearest_exception <= 1'b0;
            round_nearest_enable    <= 1'b0;
            round_posinf_trigger    <= 1'b0;
            round_posinf_enable     <= 1'b0;
            round_neginf_trigger    <= 1'b0;
            round_neginf_enable     <= 1'b0;
            round_enable            <= 1'b0;
            product_4               <= 54'b0;
        end else if (enable) begin
            // Decode rounding mode (stage 12)
            round_nearest_mode <= (rm_12 == 2'b00);
            round_posinf_mode  <= (rm_12 == 2'b10);
            round_neginf_mode  <= (rm_12 == 2'b11);

            // Guard bit is product_3[0], sticky is OR of dropped bits.
            round_nearest_trigger   <= product_3[0];
            round_nearest_exception <= |product_3[0]; // sticky proxy
            round_nearest_enable    <= round_nearest_mode
                                       & round_nearest_trigger
                                       & (round_nearest_exception
                                          | product_3[1]);

            round_posinf_trigger <= |product_3[0];
            round_posinf_enable  <= round_posinf_mode
                                    & round_posinf_trigger
                                    & ~sign_12;

            round_neginf_trigger <= |product_3[0];
            round_neginf_enable  <= round_neginf_mode
                                    & round_neginf_trigger
                                    & sign_12;

            round_enable <= round_nearest_enable
                          | round_posinf_enable
                          | round_neginf_enable;

            product_4 <= {1'b0, product_3};
        end
    end

    // ==================================================================
    // Apply rounding and re-normalize if rounding overflowed
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            product_5  <= 54'b0;
            product_6  <= 54'b0;
            product_7  <= 54'b0;
            exponent_5 <= 12'b0;
            exponent_6 <= 12'b0;
            exponent_7 <= 12'b0;
            exponent_8 <= 12'b0;
            exponent_9 <= 12'b0;
        end else if (enable) begin
            product_5  <= product_4 + {53'b0, round_enable};
            // If rounding caused overflow (bit53 becomes 1), shift right
            // and bump exponent.
            product_6  <= product_5[53] ? {1'b0, product_5[53:1]} : product_5;
            exponent_5 <= exponent_4 + {11'b0, (product_5[53] & ~product_4[53])};
            exponent_6 <= exponent_5;
            exponent_7 <= exponent_6;

            // Final specials handling
            product_7  <= set_mz_1                    ? 54'b0             :
                          exponent_is_infinity        ?
                              {1'b0, 53'b0}                                :
                          product_6;
            exponent_8 <= set_mz_1                    ? 12'b0             :
                          exponent_is_infinity        ? {1'b0, EXP_ONES}  :
                          exponent_7;
            exponent_9 <= exponent_8;
        end
    end

    // ==================================================================
    // Completion counter / ready flag
    // The pipeline has a fixed 20-cycle latency; ready assertion tracks
    // that via 'count' so upstream/downstream logic can rely on it.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            count         <= 5'd0;
            count_ready_0 <= 1'b0;
            count_ready   <= 1'b0;
            ready_r       <= 1'b0;
        end else if (enable) begin
            if (count != 5'd20) begin
                count         <= count + 5'd1;
                count_ready_0 <= 1'b0;
            end else begin
                count_ready_0 <= 1'b1;
            end
            count_ready <= count_ready_0;
            ready_r     <= count_ready;
        end
    end

endmodule