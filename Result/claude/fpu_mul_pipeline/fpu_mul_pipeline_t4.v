//---------------------------------------------------------------------------
// fpu_mul.v — IEEE-754 double-precision floating-point multiplier
//
// Pipeline latency : 20 cycles (enable must be held high)
// Rounding modes   : nearest-even (00), toward-zero (01), +inf (10), -inf (11)
//---------------------------------------------------------------------------
module fpu_mul(
    input             clk,
    input             rst,
    input             enable,
    input      [1:0]  rmode,
    input      [63:0] opa,
    input      [63:0] opb,
    output            ready,
    output     [63:0] outfp
);

// -------------------------------------------------------------------------
//  Internal registers / wires (per specification)
// -------------------------------------------------------------------------

reg product_shift;

// Rounding-mode pipeline (stages 1-15)
reg [1:0] rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8;
reg [1:0] rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15;

// Sign pipeline (stages 0-20)
reg sign;
reg sign_1,  sign_2,  sign_3,  sign_4,  sign_5;
reg sign_6,  sign_7,  sign_8,  sign_9,  sign_10;
reg sign_11, sign_12, sign_13, sign_14, sign_15;
reg sign_16, sign_17, sign_18, sign_19, sign_20;

// Mantissa pipelines (stages 1-2)
reg [51:0] mantissa_a1, mantissa_a2;
reg [51:0] mantissa_b1, mantissa_b2;

// Exponents
reg [10:0] exponent_a, exponent_b;

// Ready / count
reg        count_ready;
reg        count_ready_0;
reg [4:0]  count;

// Special-case flags
reg a_is_zero, b_is_zero;
reg a_is_inf,  b_is_inf;
reg in_inf_1,  in_inf_2;
reg in_zero_1;
reg a_is_nan, b_is_nan;
reg in_nan_1, in_nan_2;

// Pipeline for result-is-zero flag (need it at output stage)
reg result_zero_1, result_zero_2, result_zero_3, result_zero_4;
reg result_zero_5, result_zero_6, result_zero_7, result_zero_8;
reg result_zero_9, result_zero_10;

// Pipeline for result-is-inf flag
reg result_inf_1, result_inf_2, result_inf_3, result_inf_4;
reg result_inf_5, result_inf_6, result_inf_7, result_inf_8;
reg result_inf_9, result_inf_10;

// Pipeline for result-is-nan flag
reg result_nan_1, result_nan_2, result_nan_3, result_nan_4;
reg result_nan_5, result_nan_6, result_nan_7, result_nan_8;
reg result_nan_9, result_nan_10;

// Exponent-term pipeline
reg [11:0] exponent_terms_1, exponent_terms_2, exponent_terms_3;
reg [11:0] exponent_terms_4, exponent_terms_5, exponent_terms_6;
reg [11:0] exponent_terms_7, exponent_terms_8, exponent_terms_9;

// Exponent flags
reg        exponent_gt_expoffset;
wire [11:0] exponent = 12'b0;
reg [11:0] exponent_1;
reg [11:0] exponent_2;
reg [11:0] exponent_2_0, exponent_2_1;
reg        exponent_gt_prodshift;
reg        exponent_is_infinity;
reg [11:0] exponent_3, exponent_4, exponent_5;
reg [11:0] exponent_6, exponent_7, exponent_8, exponent_9;

// Mantissa-zero flags
reg set_mantissa_zero;
reg set_mz_1;

// 53-bit significands (1.mantissa) and their pipeline copies
reg [52:0] mul_a, mul_b;
reg [52:0] mul_a1, mul_a2, mul_a3, mul_a4;
reg [52:0] mul_a5, mul_a6, mul_a7, mul_a8;
reg [52:0] mul_b1, mul_b2, mul_b3, mul_b4;
reg [52:0] mul_b5, mul_b6, mul_b7, mul_b8;

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

// Partial sums
reg [41:0] sum_0;
reg [6:0]  sum_0_2, sum_0_3, sum_0_4, sum_0_5;
reg [6:0]  sum_0_6, sum_0_7, sum_0_8, sum_0_9;
reg [35:0] sum_1;
reg [9:0]  sum_1_2, sum_1_3, sum_1_4, sum_1_5;
reg [9:0]  sum_1_6, sum_1_7, sum_1_8;
reg [41:0] sum_2;
reg [6:0]  sum_2_2, sum_2_3, sum_2_4, sum_2_5;
reg [6:0]  sum_2_6, sum_2_7;
reg [35:0] sum_3;
reg [36:0] sum_4;
reg [9:0]  sum_4_2, sum_4_3, sum_4_4, sum_4_5;
reg [27:0] sum_5;
reg [6:0]  sum_5_2, sum_5_3, sum_5_4;
reg [29:0] sum_6;
reg [36:0] sum_7;
reg [16:0] sum_7_2;
reg [30:0] sum_8;

// Full product and its pipeline
reg [105:0] product_reg;
reg [105:0] product_1;
reg [52:0]  product_2, product_3;
reg [53:0]  product_4, product_5, product_6, product_7;
reg         product_overflow;

// Rounding signals
reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
reg round_posinf_trigger,  round_posinf_enable;
reg round_neginf_trigger,  round_neginf_enable;
reg round_enable;

// -------------------------------------------------------------------------
//  Output assignments
// -------------------------------------------------------------------------
assign ready = count_ready_0;
assign outfp = {sign_20, exponent_9[10:0], product_7[51:0]};

// -------------------------------------------------------------------------
//  Pipeline always-block
// -------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        count          <= 5'b0;
        count_ready    <= 1'b0;
        count_ready_0  <= 1'b0;
        sign           <= 1'b0;
        exponent_a     <= 11'b0;
        exponent_b     <= 11'b0;
        a_is_zero      <= 1'b0;
        b_is_zero      <= 1'b0;
        a_is_inf       <= 1'b0;
        b_is_inf       <= 1'b0;
        a_is_nan       <= 1'b0;
        b_is_nan       <= 1'b0;
        mul_a          <= 53'b0;
        mul_b          <= 53'b0;
        product_shift  <= 1'b0;
    end
    else if (enable) begin

        // ==============================================================
        //  Counter / Ready logic
        // ==============================================================
        if (count < 5'd20)
            count <= count + 5'd1;

        count_ready   <= (count == 5'd19);
        count_ready_0 <= count_ready;

        // ==============================================================
        //  Stage 0 — Input decode
        // ==============================================================
        sign       <= opa[63] ^ opb[63];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];

        a_is_zero  <= (opa[62:52] == 11'b0) && (opa[51:0] == 52'b0);
        b_is_zero  <= (opb[62:52] == 11'b0) && (opb[51:0] == 52'b0);
        a_is_inf   <= (opa[62:52] == 11'h7FF) && (opa[51:0] == 52'b0);
        b_is_inf   <= (opb[62:52] == 11'h7FF) && (opb[51:0] == 52'b0);
        a_is_nan   <= (opa[62:52] == 11'h7FF) && (opa[51:0] != 52'b0);
        b_is_nan   <= (opb[62:52] == 11'h7FF) && (opb[51:0] != 52'b0);

        // Form 53-bit significands: leading 1 if exponent nonzero (normalized)
        mul_a      <= {|opa[62:52], opa[51:0]};
        mul_b      <= {|opb[62:52], opb[51:0]};

        // ==============================================================
        //  Stage 1 — Exponent sum, special-case pipe, partial products
        // ==============================================================
        sign_1           <= sign;
        rm_1             <= rmode;
        mantissa_a1      <= opa[51:0];
        mantissa_b1      <= opb[51:0];
        exponent_terms_1 <= {1'b0, exponent_a} + {1'b0, exponent_b};
        in_inf_1         <= a_is_inf | b_is_inf;
        in_nan_1         <= a_is_nan | b_is_nan;
        in_zero_1        <= a_is_zero | b_is_zero;
        result_zero_1    <= a_is_zero | b_is_zero;
        result_inf_1     <= (a_is_inf | b_is_inf) && !(a_is_nan | b_is_nan);
        result_nan_1     <= (a_is_nan | b_is_nan) ||
                            ((a_is_inf && b_is_zero) || (b_is_inf && a_is_zero));

        mul_a1           <= mul_a;
        mul_b1           <= mul_b;

        // Partial product: a[16:0] * b[16:0]
        product_a        <= mul_a[16:0] * mul_b[16:0];

        // ==============================================================
        //  Stage 2
        // ==============================================================
        sign_2           <= sign_1;
        rm_2             <= rm_1;
        mantissa_a2      <= mantissa_a1;
        mantissa_b2      <= mantissa_b1;
        exponent_terms_2 <= exponent_terms_1;
        in_inf_2         <= in_inf_1;
        in_nan_2         <= in_nan_1;
        result_zero_2    <= result_zero_1;
        result_inf_2     <= result_inf_1;
        result_nan_2     <= result_nan_1;

        mul_a2           <= mul_a1;
        mul_b2           <= mul_b1;

        product_b        <= mul_a1[16:0] * mul_b1[33:17];
        product_c        <= mul_a1[33:17] * mul_b1[16:0];

        sum_0            <= product_a;
        product_a_2      <= product_a[16:0];

        // ==============================================================
        //  Stage 3
        // ==============================================================
        sign_3           <= sign_2;
        rm_3             <= rm_2;
        exponent_terms_3 <= exponent_terms_2;
        result_zero_3    <= result_zero_2;
        result_inf_3     <= result_inf_2;
        result_nan_3     <= result_nan_2;

        mul_a3           <= mul_a2;
        mul_b3           <= mul_b2;

        product_d        <= mul_a2[16:0] * mul_b2[25:17];
        product_e        <= mul_a2[33:17] * mul_b2[33:17];

        sum_1            <= product_b + product_c;
        sum_0_2          <= sum_0[6:0];
        product_a_3      <= product_a_2;

        // ==============================================================
        //  Stage 4
        // ==============================================================
        sign_4           <= sign_3;
        rm_4             <= rm_3;
        exponent_terms_4 <= exponent_terms_3;
        result_zero_4    <= result_zero_3;
        result_inf_4     <= result_inf_3;
        result_nan_4     <= result_nan_3;

        mul_a4           <= mul_a3;
        mul_b4           <= mul_b3;

        product_f        <= mul_a3[25:17] * mul_b3[16:0];
        product_g        <= mul_a3[33:17] * mul_b3[52:34];

        sum_2            <= {6'b0, sum_1} + {product_d, 17'b0};
        sum_1_2          <= sum_1[9:0];
        sum_0_3          <= sum_0_2;
        product_a_4      <= product_a_3;

        // ==============================================================
        //  Stage 5
        // ==============================================================
        sign_5           <= sign_4;
        rm_5             <= rm_4;
        exponent_terms_5 <= exponent_terms_4;
        result_zero_5    <= result_zero_4;
        result_inf_5     <= result_inf_4;
        result_nan_5     <= result_nan_4;

        mul_a5           <= mul_a4;
        mul_b5           <= mul_b4;

        product_h        <= mul_a4[52:34] * mul_b4[16:0];
        product_i        <= mul_a4[16:0]  * mul_b4[52:34];

        sum_3            <= product_e + product_f;
        sum_4            <= {1'b0, sum_2[35:0]} + {product_g, 17'b0};
        sum_2_2          <= sum_2[6:0];
        sum_1_3          <= sum_1_2;
        sum_0_4          <= sum_0_3;
        product_a_5      <= product_a_4;

        // ==============================================================
        //  Stage 6
        // ==============================================================
        sign_6           <= sign_5;
        rm_6             <= rm_5;
        exponent_terms_6 <= exponent_terms_5;
        result_zero_6    <= result_zero_5;
        result_inf_6     <= result_inf_5;
        result_nan_6     <= result_nan_5;

        mul_a6           <= mul_a5;
        mul_b6           <= mul_b5;

        product_j        <= mul_a5[52:34] * mul_b5[33:17];

        sum_5            <= product_h + product_i;
        sum_4_2          <= sum_4[9:0];
        sum_2_3          <= sum_2_2;
        sum_1_4          <= sum_1_3;
        sum_0_5          <= sum_0_4;
        product_a_6      <= product_a_5;

        // ==============================================================
        //  Stage 7
        // ==============================================================
        sign_7           <= sign_6;
        rm_7             <= rm_6;
        exponent_terms_7 <= exponent_terms_6;
        result_zero_7    <= result_zero_6;
        result_inf_7     <= result_inf_6;
        result_nan_7     <= result_nan_6;

        mul_a7           <= mul_a6;
        mul_b7           <= mul_b6;

        sum_6            <= sum_3[29:0] + sum_5[27:0];
        sum_7            <= sum_4[36:0];
        sum_5_2          <= sum_5[6:0];
        sum_4_3          <= sum_4_2;
        sum_2_4          <= sum_2_3;
        sum_1_5          <= sum_1_4;
        sum_0_6          <= sum_0_5;
        product_a_7      <= product_a_6;

        // ==============================================================
        //  Stage 8
        // ==============================================================
        sign_8           <= sign_7;
        rm_8             <= rm_7;
        exponent_terms_8 <= exponent_terms_7;
        result_zero_8    <= result_zero_7;
        result_inf_8     <= result_inf_7;
        result_nan_8     <= result_nan_7;

        mul_a8           <= mul_a7;
        mul_b8           <= mul_b7;

        sum_8            <= product_j + mul_a7[52:34] * mul_b7[52:34];
        sum_7_2          <= sum_7[16:0];
        sum_5_3          <= sum_5_2;
        sum_4_4          <= sum_4_3;
        sum_2_5          <= sum_2_4;
        sum_1_6          <= sum_1_5;
        sum_0_7          <= sum_0_6;
        product_a_8      <= product_a_7;

        // ==============================================================
        //  Stage 9 — Assemble the full 106-bit product
        //  Also compute exponent with bias removal
        // ==============================================================
        sign_9           <= sign_8;
        rm_9             <= rm_8;
        exponent_terms_9 <= exponent_terms_8;
        result_zero_9    <= result_zero_8;
        result_inf_9     <= result_inf_8;
        result_nan_9     <= result_nan_8;

        // Full product assembly using retained operands
        product_reg      <= mul_a8 * mul_b8;

        sum_5_4          <= sum_5_3;
        sum_4_5          <= sum_4_4;
        sum_2_6          <= sum_2_5;
        sum_1_7          <= sum_1_6;
        sum_0_8          <= sum_0_7;
        product_a_9      <= product_a_8;

        // Exponent: subtract bias (1023)
        exponent_gt_expoffset <= (exponent_terms_8 >= 12'd1023);

        if (exponent_terms_8 >= 12'd1023)
            exponent_1 <= exponent_terms_8 - 12'd1023;
        else
            exponent_1 <= 12'b0;

        // ==============================================================
        //  Stage 10 — Normalization decision
        // ==============================================================
        sign_10          <= sign_9;
        rm_10            <= rm_9;
        result_zero_10   <= result_zero_9;
        result_inf_10    <= result_inf_9;
        result_nan_10    <= result_nan_9;

        product_1        <= product_reg;

        sum_0_9          <= sum_0_8;
        product_a_10     <= product_a_9;

        // Check if MSB of 106-bit product is set
        product_shift    <= product_reg[105];
        exponent_2       <= exponent_1;
        exponent_2_0     <= exponent_1;

        set_mantissa_zero <= (!exponent_gt_expoffset) ||
                             (result_inf_9) || (result_nan_9) ||
                             (result_zero_9);

        // ==============================================================
        //  Stage 11 — Normalize product, adjust exponent
        // ==============================================================
        sign_11          <= sign_10;
        rm_11            <= rm_10;

        // Select the 53-bit mantissa from the 106-bit product
        if (product_shift)
            product_2 <= product_1[105:53];
        else
            product_2 <= product_1[104:52];

        exponent_gt_prodshift <= (exponent_2 >= 12'd1);
        exponent_2_1     <= exponent_2;

        if (product_shift)
            exponent_3 <= exponent_2 + 12'd1;
        else
            exponent_3 <= exponent_2;

        set_mz_1         <= set_mantissa_zero;

        // ==============================================================
        //  Stage 12 — Exponent overflow / infinity check
        // ==============================================================
        sign_12          <= sign_11;
        rm_12            <= rm_11;
        product_3        <= product_2;

        exponent_is_infinity <= (exponent_3 >= 12'd2047);

        if (exponent_3 >= 12'd2047)
            exponent_4 <= 12'h7FF;
        else
            exponent_4 <= exponent_3;

        // ==============================================================
        //  Stage 13 — Rounding mode decode and guard/round/sticky
        // ==============================================================
        sign_13          <= sign_12;
        rm_13            <= rm_12;

        round_nearest_mode <= (rm_12 == 2'b00);
        round_posinf_mode  <= (rm_12 == 2'b10);
        round_neginf_mode  <= (rm_12 == 2'b11);

        if (product_shift) begin
            round_nearest_trigger   <= product_1[52];
            round_nearest_exception <= (product_1[51:0] == 52'b0) && !product_1[53];
        end else begin
            round_nearest_trigger   <= product_1[51];
            round_nearest_exception <= (product_1[50:0] == 51'b0) && !product_1[52];
        end

        round_posinf_trigger <= (product_shift) ?
            |product_1[52:0] : |product_1[51:0];
        round_neginf_trigger <= (product_shift) ?
            |product_1[52:0] : |product_1[51:0];

        exponent_5 <= exponent_4;

        // Mantissa with zero override for special cases
        if (set_mz_1)
            product_4 <= 54'b0;
        else
            product_4 <= {1'b0, product_3};

        // ==============================================================
        //  Stage 14 — Rounding enable computation
        // ==============================================================
        sign_14          <= sign_13;
        rm_14            <= rm_13;

        round_nearest_enable <= round_nearest_mode && round_nearest_trigger &&
                                !round_nearest_exception;
        round_posinf_enable  <= round_posinf_mode  && round_posinf_trigger && !sign_13;
        round_neginf_enable  <= round_neginf_mode  && round_neginf_trigger &&  sign_13;

        exponent_6 <= exponent_5;
        product_5  <= product_4;

        // ==============================================================
        //  Stage 15 — Apply rounding
        // ==============================================================
        sign_15          <= sign_14;
        rm_15            <= rm_14;

        round_enable     <= round_nearest_enable | round_posinf_enable | round_neginf_enable;

        exponent_7       <= exponent_6;

        if (round_nearest_enable | round_posinf_enable | round_neginf_enable)
            product_6 <= product_5 + 54'd1;
        else
            product_6 <= product_5;

        // ==============================================================
        //  Stage 16 — Rounding overflow check
        // ==============================================================
        sign_16          <= sign_15;

        product_overflow <= product_6[53];

        if (product_6[53])
            exponent_8 <= exponent_7 + 12'd1;
        else
            exponent_8 <= exponent_7;

        product_7 <= product_6;

        // ==============================================================
        //  Stage 17 — Special-case overrides on exponent & mantissa
        //  Zero → exp=0, mant=0.  Inf → exp=7FF, mant=0.
        //  NaN  → exp=7FF, mant={1,0...0} (quiet NaN).
        // ==============================================================
        sign_17          <= sign_16;

        if (result_nan_10) begin
            exponent_9      <= 12'h7FF;
            product_7[51:0] <= {1'b1, 51'b0}; // quiet NaN
        end else if (result_inf_10) begin
            exponent_9      <= 12'h7FF;
            product_7[51:0] <= 52'b0;
        end else if (result_zero_10) begin
            exponent_9      <= 12'b0;
            product_7[51:0] <= 52'b0;
        end else if (exponent_is_infinity) begin
            exponent_9      <= 12'h7FF;
            product_7[51:0] <= 52'b0;
        end else begin
            exponent_9 <= exponent_8;
        end

        // ==============================================================
        //  Stage 18-20 — Final sign pipeline
        // ==============================================================
        sign_18 <= sign_17;
        sign_19 <= sign_18;
        sign_20 <= sign_19;

    end // enable
end // always

endmodule