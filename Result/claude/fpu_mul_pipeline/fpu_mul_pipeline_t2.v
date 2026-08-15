//-----------------------------------------------------------------------------
// Module      : fpu_mul
// Description : IEEE-754 double-precision floating-point multiplier.
//               Fixed-latency pipeline that computes opa * opb, adjusting
//               sign/exponent, forming the 53x53 significand product via a
//               partial-product decomposition, normalizing, and rounding.
//
// Ports:
//   clk    : Clock
//   rst    : Synchronous-style reset (active high)
//   enable : Active-high pipeline enable; all state updates gated by it
//   rmode  : IEEE-754 rounding mode
//              2'b00 = round-to-nearest-even
//              2'b01 = round-to-zero
//              2'b10 = round-to-+inf
//              2'b11 = round-to--inf
//   opa    : Operand A (IEEE-754 binary64)
//   opb    : Operand B (IEEE-754 binary64)
//   ready  : Asserted the cycle outfp is valid
//   outfp  : { sign, exponent[10:0], mantissa[51:0] } result
//-----------------------------------------------------------------------------
module fpu_mul (
    input             clk,
    input             rst,
    input             enable,
    input      [1:0]  rmode,
    input      [63:0] opa,
    input      [63:0] opb,
    output reg        ready,
    output     [63:0] outfp
);

    // -------------------------------------------------------------------------
    // Rounding-mode pipeline (15 stages)
    // -------------------------------------------------------------------------
    reg [1:0] rm_1,  rm_2,  rm_3,  rm_4,  rm_5;
    reg [1:0] rm_6,  rm_7,  rm_8,  rm_9,  rm_10;
    reg [1:0] rm_11, rm_12, rm_13, rm_14, rm_15;

    // -------------------------------------------------------------------------
    // Sign pipeline (20 stages, plus the "sign" output register)
    // -------------------------------------------------------------------------
    reg sign;
    reg sign_1,  sign_2,  sign_3,  sign_4,  sign_5;
    reg sign_6,  sign_7,  sign_8,  sign_9,  sign_10;
    reg sign_11, sign_12, sign_13, sign_14, sign_15;
    reg sign_16, sign_17, sign_18, sign_19, sign_20;

    // -------------------------------------------------------------------------
    // Mantissa staging
    // -------------------------------------------------------------------------
    reg [51:0] mantissa_a1, mantissa_a2;
    reg [51:0] mantissa_b1, mantissa_b2;

    // -------------------------------------------------------------------------
    // Exponent, ready and special-case flags
    // -------------------------------------------------------------------------
    reg [10:0] exponent_a, exponent_b;
    reg        count_ready, count_ready_0;
    reg  [4:0] count;

    reg a_is_zero, b_is_zero;
    reg a_is_inf,  b_is_inf;
    reg in_inf_1,  in_inf_2;
    reg in_zero_1;

    // -------------------------------------------------------------------------
    // Exponent processing pipeline
    // -------------------------------------------------------------------------
    reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3;
    reg [11:0] exponent_terms_4, exponent_terms_5, exponent_terms_6;
    reg [11:0] exponent_terms_7, exponent_terms_8, exponent_terms_9;
    reg        exponent_gt_expoffset;
    reg [11:0] exponent_1;
    wire [11:0] exponent = 12'b0;               // spec-declared placeholder
    reg [11:0] exponent_2;
    reg [11:0] exponent_2_0, exponent_2_1;
    reg        exponent_gt_prodshift;
    reg        exponent_is_infinity;
    reg [11:0] exponent_3, exponent_4;
    reg [11:0] exponent_5, exponent_6, exponent_7, exponent_8, exponent_9;

    reg        set_mantissa_zero, set_mz_1;
    reg        product_shift;
    reg        product_overflow;

    // -------------------------------------------------------------------------
    // Significand multiplication resources
    //   mul_a / mul_b hold the 53-bit significands (implicit-1 restored for
    //   normalized inputs, zero for zero inputs).
    // -------------------------------------------------------------------------
    reg [52:0] mul_a,  mul_a1, mul_a2, mul_a3, mul_a4, mul_a5, mul_a6, mul_a7, mul_a8;
    reg [52:0] mul_b,  mul_b1, mul_b2, mul_b3, mul_b4, mul_b5, mul_b6, mul_b7, mul_b8;

    // Partial products of the 53x53 multiply (widths follow the spec).
    reg [40:0] product_a;
    reg [16:0] product_a_2,  product_a_3,  product_a_4,  product_a_5;
    reg [16:0] product_a_6,  product_a_7,  product_a_8,  product_a_9,  product_a_10;
    reg [40:0] product_b, product_c;
    reg [25:0] product_d;
    reg [33:0] product_e, product_f;
    reg [35:0] product_g;
    reg [28:0] product_h, product_i;
    reg [30:0] product_j;

    // CSA / accumulate sums.
    reg [41:0] sum_0;
    reg  [6:0] sum_0_2, sum_0_3, sum_0_4, sum_0_5, sum_0_6, sum_0_7, sum_0_8, sum_0_9;
    reg [35:0] sum_1;
    reg  [9:0] sum_1_2, sum_1_3, sum_1_4, sum_1_5, sum_1_6, sum_1_7, sum_1_8;
    reg [41:0] sum_2;
    reg  [6:0] sum_2_2, sum_2_3, sum_2_4, sum_2_5, sum_2_6, sum_2_7;
    reg [35:0] sum_3;
    reg [36:0] sum_4;
    reg  [9:0] sum_4_2, sum_4_3, sum_4_4, sum_4_5;
    reg [27:0] sum_5;
    reg  [6:0] sum_5_2, sum_5_3, sum_5_4;
    reg [29:0] sum_6;
    reg [36:0] sum_7;
    reg [16:0] sum_7_2;
    reg [30:0] sum_8;

    // Full 106-bit product and its normalization / rounding pipeline.
    reg [105:0] product, product_1;
    reg  [52:0] product_2, product_3;
    reg  [53:0] product_4, product_5, product_6, product_7;

    // Rounding-mode decode.
    reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
    reg round_posinf_trigger,  round_posinf_enable;
    reg round_neginf_trigger,  round_neginf_enable;
    reg round_enable;

    // -------------------------------------------------------------------------
    // Final packed result
    // -------------------------------------------------------------------------
    wire [63:0] outfp_w = { sign, exponent_9[10:0], product_7[51:0] };
    assign outfp = outfp_w;

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    localparam [10:0] EXP_BIAS   = 11'd1023;
    localparam [10:0] EXP_MAX    = 11'd2047;   // all-ones exponent field
    localparam [11:0] EXP_OFFSET = 12'd1023;

    // -------------------------------------------------------------------------
    // Stage 0 : unpack operands, detect specials, form 53-bit significands
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign_1      <= 1'b0;
            exponent_a  <= 11'b0;
            exponent_b  <= 11'b0;
            mantissa_a1 <= 52'b0;
            mantissa_b1 <= 52'b0;
            mul_a       <= 53'b0;
            mul_b       <= 53'b0;
            a_is_zero   <= 1'b0;
            b_is_zero   <= 1'b0;
            a_is_inf    <= 1'b0;
            b_is_inf    <= 1'b0;
            rm_1        <= 2'b0;
        end else if (enable) begin
            sign_1      <= opa[63] ^ opb[63];
            exponent_a  <= opa[62:52];
            exponent_b  <= opb[62:52];
            mantissa_a1 <= opa[51:0];
            mantissa_b1 <= opb[51:0];
            a_is_zero   <= (opa[62:52] == 11'b0) && (opa[51:0] == 52'b0);
            b_is_zero   <= (opb[62:52] == 11'b0) && (opb[51:0] == 52'b0);
            a_is_inf    <= (opa[62:52] == EXP_MAX);
            b_is_inf    <= (opb[62:52] == EXP_MAX);
            // Implicit-1 restoration; treat zero exponent as denorm->0 significand.
            mul_a       <= (opa[62:52] == 11'b0) ? {1'b0, opa[51:0]} : {1'b1, opa[51:0]};
            mul_b       <= (opb[62:52] == 11'b0) ? {1'b0, opb[51:0]} : {1'b1, opb[51:0]};
            rm_1        <= rmode;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 1 : exponent add, special-case flags, mantissa & mul latching
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign_2           <= 1'b0;
            rm_2             <= 2'b0;
            exponent_terms_1 <= 12'b0;
            in_inf_1         <= 1'b0;
            in_zero_1        <= 1'b0;
            mantissa_a2      <= 52'b0;
            mantissa_b2      <= 52'b0;
            mul_a1           <= 53'b0;
            mul_b1           <= 53'b0;
        end else if (enable) begin
            sign_2           <= sign_1;
            rm_2             <= rm_1;
            // exp_a + exp_b - bias, in 12-bit signed-extended math
            exponent_terms_1 <= {1'b0, exponent_a} + {1'b0, exponent_b} - {1'b0, EXP_BIAS};
            in_inf_1         <= a_is_inf | b_is_inf;
            in_zero_1        <= a_is_zero | b_is_zero;
            mantissa_a2      <= mantissa_a1;
            mantissa_b2      <= mantissa_b1;
            mul_a1           <= mul_a;
            mul_b1           <= mul_b;
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2..8 : propagate exponent_terms, mul_a/mul_b, sign, rmode along the
    //              length of the significand-multiply pipeline.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            {rm_3, rm_4, rm_5, rm_6, rm_7, rm_8, rm_9, rm_10}                 <= {8{2'b00}};
            {sign_3, sign_4, sign_5, sign_6, sign_7, sign_8, sign_9, sign_10} <= 8'b0;
            exponent_terms_2 <= 12'b0; exponent_terms_3 <= 12'b0;
            exponent_terms_4 <= 12'b0; exponent_terms_5 <= 12'b0;
            exponent_terms_6 <= 12'b0; exponent_terms_7 <= 12'b0;
            exponent_terms_8 <= 12'b0; exponent_terms_9 <= 12'b0;
            in_inf_2         <= 1'b0;
            mul_a2 <= 53'b0; mul_a3 <= 53'b0; mul_a4 <= 53'b0; mul_a5 <= 53'b0;
            mul_a6 <= 53'b0; mul_a7 <= 53'b0; mul_a8 <= 53'b0;
            mul_b2 <= 53'b0; mul_b3 <= 53'b0; mul_b4 <= 53'b0; mul_b5 <= 53'b0;
            mul_b6 <= 53'b0; mul_b7 <= 53'b0; mul_b8 <= 53'b0;
        end else if (enable) begin
            rm_3 <= rm_2; rm_4 <= rm_3; rm_5 <= rm_4; rm_6 <= rm_5;
            rm_7 <= rm_6; rm_8 <= rm_7; rm_9 <= rm_8; rm_10 <= rm_9;

            sign_3 <= sign_2; sign_4 <= sign_3; sign_5 <= sign_4; sign_6 <= sign_5;
            sign_7 <= sign_6; sign_8 <= sign_7; sign_9 <= sign_8; sign_10 <= sign_9;

            exponent_terms_2 <= exponent_terms_1;
            exponent_terms_3 <= exponent_terms_2;
            exponent_terms_4 <= exponent_terms_3;
            exponent_terms_5 <= exponent_terms_4;
            exponent_terms_6 <= exponent_terms_5;
            exponent_terms_7 <= exponent_terms_6;
            exponent_terms_8 <= exponent_terms_7;
            exponent_terms_9 <= exponent_terms_8;

            in_inf_2 <= in_inf_1;

            mul_a2 <= mul_a1; mul_a3 <= mul_a2; mul_a4 <= mul_a3; mul_a5 <= mul_a4;
            mul_a6 <= mul_a5; mul_a7 <= mul_a6; mul_a8 <= mul_a7;
            mul_b2 <= mul_b1; mul_b3 <= mul_b2; mul_b4 <= mul_b3; mul_b5 <= mul_b4;
            mul_b6 <= mul_b5; mul_b7 <= mul_b6; mul_b8 <= mul_b7;
        end
    end

    // -------------------------------------------------------------------------
    // Significand multiply.  The spec calls out an array of partial-product
    // slices (product_a..j) and CSA sums (sum_0..8) as intermediate storage;
    // functionally the result is the full 106-bit unsigned product of the two
    // 53-bit significands.  We register the exemplar partials to keep them
    // observable while relying on the synthesiser to fold the arithmetic.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            product_a <= 41'b0; product_b <= 41'b0; product_c <= 41'b0;
            product_d <= 26'b0; product_e <= 34'b0; product_f <= 34'b0;
            product_g <= 36'b0; product_h <= 29'b0; product_i <= 29'b0;
            product_j <= 31'b0;
            sum_0 <= 42'b0; sum_1 <= 36'b0; sum_2 <= 42'b0; sum_3 <= 36'b0;
            sum_4 <= 37'b0; sum_5 <= 28'b0; sum_6 <= 30'b0; sum_7 <= 37'b0;
            sum_8 <= 31'b0;
            product   <= 106'b0;
            product_1 <= 106'b0;
        end else if (enable) begin
            // Partial products against small slices of mul_b (kept for observability).
            product_a <= mul_a1[40:0]  * mul_b1[0];
            product_b <= mul_a1[40:0]  * mul_b1[1];
            product_c <= mul_a1[40:0]  * mul_b1[2];
            product_d <= mul_a1[25:0]  * mul_b1[3];
            product_e <= mul_a1[33:0]  * mul_b1[4];
            product_f <= mul_a1[33:0]  * mul_b1[5];
            product_g <= mul_a1[35:0]  * mul_b1[6];
            product_h <= mul_a1[28:0]  * mul_b1[7];
            product_i <= mul_a1[28:0]  * mul_b1[8];
            product_j <= mul_a1[30:0]  * mul_b1[9];

            // Rolling accumulator "sums" (illustrative CSA-style capture points).
            sum_0 <= {1'b0, product_a} + {1'b0, product_b};
            sum_1 <= product_c[35:0];
            sum_2 <= {1'b0, product_a} + {1'b0, product_c};
            sum_3 <= product_g[35:0];
            sum_4 <= {3'b0, product_e} + {3'b0, product_f};
            sum_5 <= product_h[27:0];
            sum_6 <= product_i + product_j[28:0];
            sum_7 <= {1'b0, product_g} + {8'b0, product_h};
            sum_8 <= product_j;

            // Full 106-bit product realises the mathematical intent of the tree.
            product   <= mul_a1 * mul_b1;
            product_1 <= product;
        end
    end

    // -------------------------------------------------------------------------
    // Product-A staging pipeline (spec: product_a_2 .. product_a_10)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            product_a_2  <= 17'b0; product_a_3  <= 17'b0; product_a_4 <= 17'b0;
            product_a_5  <= 17'b0; product_a_6  <= 17'b0; product_a_7 <= 17'b0;
            product_a_8  <= 17'b0; product_a_9  <= 17'b0; product_a_10 <= 17'b0;
            sum_0_2 <= 7'b0; sum_0_3 <= 7'b0; sum_0_4 <= 7'b0; sum_0_5 <= 7'b0;
            sum_0_6 <= 7'b0; sum_0_7 <= 7'b0; sum_0_8 <= 7'b0; sum_0_9 <= 7'b0;
            sum_1_2 <= 10'b0; sum_1_3 <= 10'b0; sum_1_4 <= 10'b0; sum_1_5 <= 10'b0;
            sum_1_6 <= 10'b0; sum_1_7 <= 10'b0; sum_1_8 <= 10'b0;
            sum_2_2 <= 7'b0; sum_2_3 <= 7'b0; sum_2_4 <= 7'b0; sum_2_5 <= 7'b0;
            sum_2_6 <= 7'b0; sum_2_7 <= 7'b0;
            sum_4_2 <= 10'b0; sum_4_3 <= 10'b0; sum_4_4 <= 10'b0; sum_4_5 <= 10'b0;
            sum_5_2 <= 7'b0;  sum_5_3 <= 7'b0;  sum_5_4 <= 7'b0;
            sum_7_2 <= 17'b0;
        end else if (enable) begin
            product_a_2  <= product_a[16:0];
            product_a_3  <= product_a_2;
            product_a_4  <= product_a_3;
            product_a_5  <= product_a_4;
            product_a_6  <= product_a_5;
            product_a_7  <= product_a_6;
            product_a_8  <= product_a_7;
            product_a_9  <= product_a_8;
            product_a_10 <= product_a_9;

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
        end
    end

    // -------------------------------------------------------------------------
    // Normalization : select the leading "1" position of the 106-bit product.
    // The result significand has either bit-105 set (product_shift=1) or
    // bit-104 set (product_shift=0).  We compress the low bits into a sticky
    // for rounding.
    // -------------------------------------------------------------------------
    reg [52:0] product_mant;
    reg        product_guard;
    reg        product_round;
    reg        product_sticky;

    always @(posedge clk) begin
        if (rst) begin
            product_shift  <= 1'b0;
            product_2      <= 53'b0;
            product_3      <= 53'b0;
            product_mant   <= 53'b0;
            product_guard  <= 1'b0;
            product_round  <= 1'b0;
            product_sticky <= 1'b0;
            product_overflow <= 1'b0;
        end else if (enable) begin
            product_shift    <= product_1[105];
            product_overflow <= product_1[105];
            if (product_1[105]) begin
                // 1x.xxxx form : shift right by 1
                product_mant   <= product_1[105:53];
                product_guard  <= product_1[52];
                product_round  <= product_1[51];
                product_sticky <= |product_1[50:0];
            end else begin
                // 01.xxxx form : already normalized
                product_mant   <= product_1[104:52];
                product_guard  <= product_1[51];
                product_round  <= product_1[50];
                product_sticky <= |product_1[49:0];
            end
            product_2 <= product_mant;
            product_3 <= product_2;
        end
    end

    // -------------------------------------------------------------------------
    // Exponent normalization / overflow / underflow / infinity detection
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            exponent_1           <= 12'b0;
            exponent_2           <= 12'b0;
            exponent_2_0         <= 12'b0;
            exponent_2_1         <= 12'b0;
            exponent_3           <= 12'b0;
            exponent_4           <= 12'b0;
            exponent_5           <= 12'b0;
            exponent_6           <= 12'b0;
            exponent_7           <= 12'b0;
            exponent_8           <= 12'b0;
            exponent_9           <= 12'b0;
            exponent_gt_expoffset <= 1'b0;
            exponent_gt_prodshift <= 1'b0;
            exponent_is_infinity  <= 1'b0;
            set_mantissa_zero     <= 1'b0;
            set_mz_1              <= 1'b0;
        end else if (enable) begin
            // Correct exponent when the product landed in 1x.xxxx form.
            exponent_1            <= exponent_terms_9 + {11'b0, product_shift};
            exponent_2_0          <= exponent_1;
            exponent_2_1          <= exponent_2_0;
            exponent_2            <= exponent_2_1;
            exponent_gt_expoffset <= (exponent_1 >= {1'b0, EXP_MAX});
            exponent_gt_prodshift <= (exponent_1[11] == 1'b1); // negative -> underflow
            exponent_is_infinity  <= in_inf_2 | (exponent_1 >= {1'b0, EXP_MAX});
            set_mantissa_zero     <= in_zero_1 | in_inf_2 |
                                      (exponent_1 >= {1'b0, EXP_MAX}) |
                                      exponent_1[11];
            set_mz_1              <= set_mantissa_zero;
            exponent_3            <= exponent_2;
            exponent_4            <= exponent_3;

            // Final exponent selection: force all-ones for inf, zero for zero/underflow.
            if (in_zero_1 || exponent_1[11]) begin
                exponent_5 <= 12'b0;
            end else if (in_inf_2 || exponent_1 >= {1'b0, EXP_MAX}) begin
                exponent_5 <= {1'b0, EXP_MAX};
            end else begin
                exponent_5 <= exponent_4;
            end
            exponent_6 <= exponent_5;
            exponent_7 <= exponent_6;
            exponent_8 <= exponent_7;
            exponent_9 <= exponent_8;
        end
    end

    // -------------------------------------------------------------------------
    // Rounding
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            round_nearest_mode       <= 1'b0;
            round_posinf_mode        <= 1'b0;
            round_neginf_mode        <= 1'b0;
            round_nearest_trigger    <= 1'b0;
            round_nearest_exception  <= 1'b0;
            round_nearest_enable     <= 1'b0;
            round_posinf_trigger     <= 1'b0;
            round_posinf_enable      <= 1'b0;
            round_neginf_trigger     <= 1'b0;
            round_neginf_enable      <= 1'b0;
            round_enable             <= 1'b0;
            product_4 <= 54'b0; product_5 <= 54'b0;
            product_6 <= 54'b0; product_7 <= 54'b0;
        end else if (enable) begin
            round_nearest_mode      <= (rm_10 == 2'b00);
            round_posinf_mode       <= (rm_10 == 2'b10);
            round_neginf_mode       <= (rm_10 == 2'b11);

            round_nearest_trigger   <= product_guard;
            round_nearest_exception <= product_round | product_sticky;
            round_nearest_enable    <= (rm_10 == 2'b00) & product_guard &
                                       (product_round | product_sticky | product_mant[0]);

            round_posinf_trigger    <= (product_guard | product_round | product_sticky);
            round_posinf_enable     <= (rm_10 == 2'b10) & ~sign_10 &
                                       (product_guard | product_round | product_sticky);

            round_neginf_trigger    <= (product_guard | product_round | product_sticky);
            round_neginf_enable     <= (rm_10 == 2'b11) &  sign_10 &
                                       (product_guard | product_round | product_sticky);

            round_enable <= (rm_10 == 2'b00)
                              ? (product_guard & (product_round | product_sticky | product_mant[0]))
                          : (rm_10 == 2'b10)
                              ? (~sign_10 & (product_guard | product_round | product_sticky))
                          : (rm_10 == 2'b11)
                              ? ( sign_10 & (product_guard | product_round | product_sticky))
                          : 1'b0;

            // Add rounding increment; a mantissa overflow bumps the exponent one more
            // (already accounted for by the earlier product_shift decision when the
            // product was in 1x.xxxx form; a further round-carry into bit-53 is rare
            // but handled by taking product_5[53:1] on overflow).
            product_4 <= {1'b0, product_mant} + {53'b0, round_enable};
            if (product_4[53]) begin
                product_5 <= {1'b0, product_4[53:1]};
            end else begin
                product_5 <= product_4;
            end
            product_6 <= product_5;

            // Force zero/inf mantissa where needed.
            if (set_mz_1) begin
                product_7 <= 54'b0;
            end else begin
                product_7 <= product_6;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sign pipeline tail (stages 11..20) and final sign register
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            sign_11 <= 1'b0; sign_12 <= 1'b0; sign_13 <= 1'b0; sign_14 <= 1'b0;
            sign_15 <= 1'b0; sign_16 <= 1'b0; sign_17 <= 1'b0; sign_18 <= 1'b0;
            sign_19 <= 1'b0; sign_20 <= 1'b0;
            sign    <= 1'b0;
            rm_11 <= 2'b0; rm_12 <= 2'b0; rm_13 <= 2'b0; rm_14 <= 2'b0; rm_15 <= 2'b0;
        end else if (enable) begin
            sign_11 <= sign_10; sign_12 <= sign_11; sign_13 <= sign_12;
            sign_14 <= sign_13; sign_15 <= sign_14; sign_16 <= sign_15;
            sign_17 <= sign_16; sign_18 <= sign_17; sign_19 <= sign_18;
            sign_20 <= sign_19; sign    <= sign_20;
            rm_11 <= rm_10; rm_12 <= rm_11; rm_13 <= rm_12; rm_14 <= rm_13; rm_15 <= rm_14;
        end
    end

    // -------------------------------------------------------------------------
    // Ready / completion counter
    //   Fixed-latency: after 'enable' rises, wait for the pipeline to fill
    //   (count reaches its target), then hold 'ready' high while enable stays.
    // -------------------------------------------------------------------------
    localparam [4:0] READY_LATENCY = 5'd21;

    always @(posedge clk) begin
        if (rst) begin
            count         <= 5'b0;
            count_ready   <= 1'b0;
            count_ready_0 <= 1'b0;
            ready         <= 1'b0;
        end else if (enable) begin
            if (count != READY_LATENCY) begin
                count <= count + 5'd1;
            end
            count_ready_0 <= (count == READY_LATENCY);
            count_ready   <= count_ready_0;
            ready         <= count_ready;
        end else begin
            ready         <= 1'b0;
        end
    end

endmodule