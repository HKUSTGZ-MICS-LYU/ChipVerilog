// ============================================================================
// fpu_addsub — Pipelined IEEE-754 double-precision floating-point add / sub
//
// Pipeline depth : 20 clock cycles (enable-gated)
// Latency        : ready asserts 20 enabled edges after the first input
// ============================================================================
module fpu_addsub(
    input             clk,
    input             rst,
    input             enable,
    input             fpu_op,       // 0 = add, 1 = subtract
    input  [1:0]      rmode,        // 00=nearest, 01=zero, 10=+inf, 11=-inf
    input  [63:0]     opa, opb,
    output reg [63:0] out,
    output reg        ready
);

// ============================================================================
// Register / wire declarations
// ============================================================================
reg [63:0] outfp;

// Rounding-mode pipeline (positions 1–16)
reg [1:0] rm_1,  rm_2,  rm_3,  rm_4,  rm_5,  rm_6,  rm_7,  rm_8;
reg [1:0] rm_9,  rm_10, rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;

// Sign registers
reg sign;
reg sign_a,  sign_b;
reg sign_a2, sign_a3;
reg sign_b2, sign_b3;
reg sign_2,  sign_3,  sign_4,  sign_5,  sign_6,  sign_7,  sign_8;
reg sign_9,  sign_10, sign_11, sign_12, sign_13, sign_14;
reg sign_15, sign_16, sign_17, sign_18, sign_19;

// FPU operation pipeline
reg fpu_op_1, fpu_op_2, fpu_op_3;
reg fpu_op_final;

// Pipeline-valid chain
reg fpuf_2,  fpuf_3,  fpuf_4,  fpuf_5,  fpuf_6,  fpuf_7;
reg fpuf_8,  fpuf_9,  fpuf_10, fpuf_11, fpuf_12, fpuf_13;
reg fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18, fpuf_19;
reg fpuf_20, fpuf_21;

// Exponent / mantissa
reg [10:0] exponent_a, exponent_b;
reg [10:0] expa_2, expb_2, expa_3, expb_3;
reg [51:0] mantissa_a, mantissa_b;
reg [51:0] mana_2, mana_3, manb_2, manb_3;

// Infinity flags
reg expa_et_inf, expb_et_inf, input_is_inf;
reg in_inf2,  in_inf3,  in_inf4,  in_inf5,  in_inf6,  in_inf7;
reg in_inf8,  in_inf9,  in_inf10, in_inf11, in_inf12, in_inf13;
reg in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19;
reg in_inf20, in_inf21;

// Comparison flags
reg expa_gt_expb, expa_et_expb, mana_gtet_manb, a_gtet_b;

// Selected operands
reg [10:0] exponent_small, exponent_large;
reg [10:0] expl_2,  expl_3,  expl_4,  expl_5,  expl_6;
reg [10:0] expl_7,  expl_8,  expl_9,  expl_10, expl_11;
reg [51:0] mantissa_small, mantissa_large;
reg [51:0] mantissa_small_2, mantissa_large_2;
reg [51:0] mantissa_small_3, mantissa_large_3;
reg exp_small_et0, exp_large_et0;
reg exp_small_et0_2, exp_large_et0_2;

// Exponent difference
reg [10:0] exponent_diff, exponent_diff_2, exponent_diff_3;

// Alignment shift
reg [107:0] bits_shifted_out, bits_shifted_out_2;
reg bits_shifted;

// 56-bit addends  {carry, implicit, mantissa[51:0], guard, round}
reg [55:0] large_add, large_add_2, large_add_3, large_add_4, large_add_5;
reg [55:0] small_add;
reg [55:0] small_shift, small_shift_2, small_shift_3, small_shift_4;
reg small_shift_nonzero;
reg small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
reg small_fraction_enable;

wire [55:0] small_shift_LSB = {55'b0, 1'b1};

// Sum path
reg [55:0] sum, sum_2, sum_3, sum_4, sum_5, sum_6;
reg [55:0] sum_7, sum_8, sum_9, sum_10, sum_11;
reg sum_overflow;
reg sumround_overflow;
reg sum_lsb, sum_lsb_2;

// Exponent results
reg [10:0] exponent_add, exp_add_2, exp_add_3, exp_add_4, exp_add_5;
reg [10:0] exp_add_6, exp_add_7, exp_add_8, exp_add_9;
reg [10:0] exponent_sub, exp_sub_2, exp_sub_3, exp_sub_4, exp_sub_5;
reg [10:0] exp_sub_6, exp_sub_7, exp_sub_8;

// Diff path
reg [5:0]  diff_shift, diff_shift_2;
reg [55:0] diff, diff_2, diff_3, diff_4, diff_5, diff_6;
reg [55:0] diff_7, diff_8, diff_9, diff_10, diff_11;
reg diffshift_gt_exponent;
reg diffshift_et_55;
reg diffround_overflow;

// Rounding
reg round_nearest_mode, round_posinf_mode, round_neginf_mode;
reg round_nearest_trigger, round_nearest_exception, round_nearest_enable;
reg round_posinf_trigger, round_posinf_enable;
reg round_neginf_trigger, round_neginf_enable;
reg round_enable;

// Ready / count
reg count_ready, count_ready_0;
reg [4:0] count;

// Extra pipeline copies for alignment
reg fpu_op_final_2, fpu_op_final_3, fpu_op_final_4, fpu_op_final_5;
reg bits_shifted_2, bits_shifted_3, bits_shifted_4;
reg sum_overflow_2;
// Output pipeline (post-rounding)
reg [63:0] out_pipe_1, out_pipe_2, out_pipe_3, out_pipe_4, out_pipe_5;
reg [63:0] out_pipe_6, out_pipe_7, out_pipe_8, out_pipe_9, out_pipe_10;

// ============================================================================
// Leading-zero counter  (55-bit → 6-bit count)
// ============================================================================
function [5:0] count_l_zeros;
    input [54:0] data;
    integer i;
    begin
        count_l_zeros = 6'd55;
        for (i = 0; i <= 54; i = i + 1)
            if (data[i]) count_l_zeros = 54 - i;
    end
endfunction

// ============================================================================
// Pipeline
// ============================================================================
always @(posedge clk) begin
if (rst) begin
    ready          <= 0;  out            <= 64'd0;
    count          <= 0;  count_ready    <= 0;  count_ready_0 <= 0;
    outfp          <= 0;
    sign_a <= 0; sign_b <= 0; sign <= 0;
    sign_a2 <= 0; sign_a3 <= 0; sign_b2 <= 0; sign_b3 <= 0;
    sign_2  <= 0; sign_3  <= 0; sign_4  <= 0; sign_5  <= 0;
    sign_6  <= 0; sign_7  <= 0; sign_8  <= 0; sign_9  <= 0;
    sign_10 <= 0; sign_11 <= 0; sign_12 <= 0; sign_13 <= 0;
    sign_14 <= 0; sign_15 <= 0; sign_16 <= 0; sign_17 <= 0;
    sign_18 <= 0; sign_19 <= 0;
    fpu_op_1 <= 0; fpu_op_2 <= 0; fpu_op_3 <= 0; fpu_op_final <= 0;
    fpu_op_final_2 <= 0; fpu_op_final_3 <= 0;
    fpu_op_final_4 <= 0; fpu_op_final_5 <= 0;
    {fpuf_2, fpuf_3, fpuf_4, fpuf_5, fpuf_6, fpuf_7, fpuf_8,
     fpuf_9, fpuf_10,fpuf_11,fpuf_12,fpuf_13,fpuf_14,
     fpuf_15,fpuf_16,fpuf_17,fpuf_18,fpuf_19,fpuf_20,fpuf_21} <= 20'd0;
    exponent_a <= 0; exponent_b <= 0;
    expa_2 <= 0; expb_2 <= 0; expa_3 <= 0; expb_3 <= 0;
    mantissa_a <= 0; mantissa_b <= 0;
    mana_2 <= 0; mana_3 <= 0; manb_2 <= 0; manb_3 <= 0;
    expa_et_inf <= 0; expb_et_inf <= 0; input_is_inf <= 0;
    in_inf2  <= 0; in_inf3  <= 0; in_inf4  <= 0; in_inf5  <= 0;
    in_inf6  <= 0; in_inf7  <= 0; in_inf8  <= 0; in_inf9  <= 0;
    in_inf10 <= 0; in_inf11 <= 0; in_inf12 <= 0; in_inf13 <= 0;
    in_inf14 <= 0; in_inf15 <= 0; in_inf16 <= 0; in_inf17 <= 0;
    in_inf18 <= 0; in_inf19 <= 0; in_inf20 <= 0; in_inf21 <= 0;
    expa_gt_expb <= 0; expa_et_expb <= 0;
    mana_gtet_manb <= 0; a_gtet_b <= 0;
    exponent_small <= 0; exponent_large <= 0;
    expl_2 <= 0; expl_3 <= 0; expl_4 <= 0; expl_5 <= 0;
    expl_6 <= 0; expl_7 <= 0; expl_8 <= 0; expl_9 <= 0;
    expl_10 <= 0; expl_11 <= 0;
    mantissa_small <= 0; mantissa_large <= 0;
    mantissa_small_2 <= 0; mantissa_large_2 <= 0;
    mantissa_small_3 <= 0; mantissa_large_3 <= 0;
    exp_small_et0 <= 0; exp_large_et0 <= 0;
    exp_small_et0_2 <= 0; exp_large_et0_2 <= 0;
    exponent_diff <= 0; exponent_diff_2 <= 0; exponent_diff_3 <= 0;
    bits_shifted_out <= 0; bits_shifted_out_2 <= 0;
    bits_shifted <= 0; bits_shifted_2 <= 0;
    bits_shifted_3 <= 0; bits_shifted_4 <= 0;
    large_add <= 0; large_add_2 <= 0; large_add_3 <= 0;
    large_add_4 <= 0; large_add_5 <= 0;
    small_add <= 0;
    small_shift <= 0; small_shift_2 <= 0;
    small_shift_3 <= 0; small_shift_4 <= 0;
    small_shift_nonzero <= 0;
    small_is_nonzero <= 0; small_is_nonzero_2 <= 0;
    small_is_nonzero_3 <= 0;
    small_fraction_enable <= 0;
    sum <= 0; sum_2 <= 0; sum_3 <= 0; sum_4 <= 0; sum_5 <= 0;
    sum_6 <= 0; sum_7 <= 0; sum_8 <= 0; sum_9 <= 0;
    sum_10 <= 0; sum_11 <= 0;
    sum_overflow <= 0; sumround_overflow <= 0;
    sum_lsb <= 0; sum_lsb_2 <= 0;
    sum_overflow_2 <= 0;
    exponent_add <= 0; exp_add_2 <= 0; exp_add_3 <= 0;
    exp_add_4 <= 0; exp_add_5 <= 0; exp_add_6 <= 0;
    exp_add_7 <= 0; exp_add_8 <= 0; exp_add_9 <= 0;
    exponent_sub <= 0; exp_sub_2 <= 0; exp_sub_3 <= 0;
    exp_sub_4 <= 0; exp_sub_5 <= 0; exp_sub_6 <= 0;
    exp_sub_7 <= 0; exp_sub_8 <= 0;
    diff_shift <= 0; diff_shift_2 <= 0;
    diff <= 0; diff_2 <= 0; diff_3 <= 0; diff_4 <= 0;
    diff_5 <= 0; diff_6 <= 0; diff_7 <= 0; diff_8 <= 0;
    diff_9 <= 0; diff_10 <= 0; diff_11 <= 0;
    diffshift_gt_exponent <= 0; diffshift_et_55 <= 0;
    diffround_overflow <= 0;
    round_nearest_mode <= 0; round_posinf_mode <= 0; round_neginf_mode <= 0;
    round_nearest_trigger <= 0; round_nearest_exception <= 0;
    round_nearest_enable <= 0;
    round_posinf_trigger <= 0; round_posinf_enable <= 0;
    round_neginf_trigger <= 0; round_neginf_enable <= 0;
    round_enable <= 0;
    {rm_1,rm_2,rm_3,rm_4,rm_5,rm_6,rm_7,rm_8} <= 16'd0;
    {rm_9,rm_10,rm_11,rm_12,rm_13,rm_14,rm_15,rm_16} <= 16'd0;
    out_pipe_1 <= 0; out_pipe_2 <= 0; out_pipe_3 <= 0;
    out_pipe_4 <= 0; out_pipe_5 <= 0; out_pipe_6 <= 0;
    out_pipe_7 <= 0; out_pipe_8 <= 0; out_pipe_9 <= 0;
    out_pipe_10<= 0;
end
else if (enable) begin

    // ================================================================
    // STAGE 1  →  capture inputs  (position 1)
    // ================================================================
    sign_a          <= opa[63];
    sign_b          <= opb[63];
    exponent_a      <= opa[62:52];
    exponent_b      <= opb[62:52];
    mantissa_a      <= opa[51:0];
    mantissa_b      <= opb[51:0];
    fpu_op_1        <= fpu_op;
    rm_1            <= rmode;

    expa_et_inf     <= (opa[62:52] == 11'h7FF);
    expb_et_inf     <= (opb[62:52] == 11'h7FF);
    input_is_inf    <= (opa[62:52] == 11'h7FF) | (opb[62:52] == 11'h7FF);

    expa_gt_expb    <= (opa[62:52] >  opb[62:52]);
    expa_et_expb    <= (opa[62:52] == opb[62:52]);
    mana_gtet_manb  <= (opa[51:0]  >= opb[51:0]);
    a_gtet_b        <= (opa[62:52] >  opb[62:52]) |
                       ((opa[62:52] == opb[62:52]) & (opa[51:0] >= opb[51:0]));

    fpuf_2          <= 1'b1;

    // ================================================================
    // STAGE 2  →  operand selection, effective op  (position 2)
    // ================================================================
    fpu_op_2        <= fpu_op_1;
    rm_2            <= rm_1;
    sign_a2         <= sign_a;
    sign_b2         <= sign_b;
    expa_2          <= exponent_a;
    expb_2          <= exponent_b;
    mana_2          <= mantissa_a;
    manb_2          <= mantissa_b;

    fpu_op_final    <= fpu_op_1 ^ (sign_a ^ sign_b);

    if (a_gtet_b) begin
        exponent_large <= exponent_a;
        exponent_small <= exponent_b;
        mantissa_large <= mantissa_a;
        mantissa_small <= mantissa_b;
        sign           <= sign_a;
    end else begin
        exponent_large <= exponent_b;
        exponent_small <= exponent_a;
        mantissa_large <= mantissa_b;
        mantissa_small <= mantissa_a;
        sign           <= fpu_op_1 ^ sign_b;
    end

    exponent_diff   <= a_gtet_b ? (exponent_a - exponent_b)
                                : (exponent_b - exponent_a);
    exp_small_et0   <= a_gtet_b ? (exponent_b == 11'd0)
                                : (exponent_a == 11'd0);
    exp_large_et0   <= a_gtet_b ? (exponent_a == 11'd0)
                                : (exponent_b == 11'd0);

    in_inf2         <= input_is_inf;
    sign_2          <= a_gtet_b ? sign_a : (fpu_op_1 ^ sign_b);
    fpuf_3          <= fpuf_2;

    // ================================================================
    // STAGE 3  →  form 56-bit addends, 108-bit alignment shift  (pos 3)
    // ================================================================
    fpu_op_3        <= fpu_op_final;
    rm_3            <= rm_2;
    sign_a3         <= sign_a2;
    sign_b3         <= sign_b2;
    sign_3          <= sign_2;
    expa_3          <= expa_2;
    expb_3          <= expb_2;
    mana_3          <= mana_2;
    manb_3          <= manb_2;

    large_add       <= {1'b0, ~exp_large_et0, mantissa_large, 2'b00};
    small_add       <= {1'b0, ~exp_small_et0, mantissa_small, 2'b00};

    bits_shifted_out <= ({1'b0, ~exp_small_et0, mantissa_small, 2'b00, 52'b0})
                         >> exponent_diff;

    expl_2           <= exponent_large;
    mantissa_large_2 <= mantissa_large;
    mantissa_small_2 <= mantissa_small;
    exponent_diff_2  <= exponent_diff;
    exp_small_et0_2  <= exp_small_et0;
    exp_large_et0_2  <= exp_large_et0;
    small_is_nonzero <= (|mantissa_small) | (~exp_small_et0);

    in_inf3          <= in_inf2;
    fpuf_4           <= fpuf_3;

    // ================================================================
    // STAGE 4  →  extract aligned small operand, sticky  (pos 4)
    // ================================================================
    fpu_op_final_2     <= fpu_op_3;
    rm_4               <= rm_3;
    sign_4             <= sign_3;
    expl_3             <= expl_2;
    large_add_2        <= large_add;
    exponent_diff_3    <= exponent_diff_2;
    mantissa_large_3   <= mantissa_large_2;
    mantissa_small_3   <= mantissa_small_2;
    bits_shifted_out_2 <= bits_shifted_out;
    small_is_nonzero_2 <= small_is_nonzero;

    small_shift        <= bits_shifted_out[107:52];
    small_shift_nonzero<= |bits_shifted_out[107:52];
    bits_shifted       <= |bits_shifted_out[51:0] |
                          ((exponent_diff_2 > 11'd52) & small_is_nonzero);
    small_fraction_enable <= |bits_shifted_out[51:0] |
                             ((exponent_diff_2 > 11'd52) & small_is_nonzero);

    in_inf4            <= in_inf3;
    fpuf_5             <= fpuf_4;

    // ================================================================
    // STAGE 5  →  add / subtract  (pos 5)
    // ================================================================
    fpu_op_final_3     <= fpu_op_final_2;
    rm_5               <= rm_4;
    sign_5             <= sign_4;
    expl_4             <= expl_3;
    large_add_3        <= large_add_2;
    small_shift_2      <= small_shift;
    small_is_nonzero_3 <= small_is_nonzero_2;
    bits_shifted_2     <= bits_shifted;

    sum  <= large_add_2 + small_shift;
    diff <= small_fraction_enable
              ? (large_add_2 - small_shift - small_shift_LSB)
              : (large_add_2 - small_shift);

    in_inf5  <= in_inf4;
    fpuf_6   <= fpuf_5;

    // ================================================================
    // STAGE 6  →  overflow / leading-zero detect  (pos 6)
    // ================================================================
    fpu_op_final_4  <= fpu_op_final_3;
    rm_6            <= rm_5;
    sign_6          <= sign_5;
    expl_5          <= expl_4;
    bits_shifted_3  <= bits_shifted_2;

    sum_2           <= sum;
    diff_2          <= diff;

    sum_overflow    <= sum[55];
    sum_lsb         <= sum[0];

    exponent_add    <= expl_4 + {10'd0, sum[55]};
    diff_shift      <= count_l_zeros(diff[54:0]);

    in_inf6  <= in_inf5;
    fpuf_7   <= fpuf_6;

    // ================================================================
    // STAGE 7  →  normalise diff, compute sub exponent  (pos 7)
    // ================================================================
    fpu_op_final_5  <= fpu_op_final_4;
    rm_7            <= rm_6;
    sign_7          <= sign_6;
    expl_6          <= expl_5;
    bits_shifted_4  <= bits_shifted_3;
    sum_overflow_2  <= sum_overflow;
    sum_lsb_2       <= sum_lsb;
    diff_shift_2    <= diff_shift;

    sum_3           <= sum_2;
    diff_3          <= diff_2 << diff_shift;   // normalised diff

    exp_add_2       <= exponent_add;
    exponent_sub    <= expl_5 - {5'd0, diff_shift};

    diffshift_gt_exponent <= ({5'b0, diff_shift} > expl_5);
    diffshift_et_55       <= (diff_shift == 6'd55);

    in_inf7  <= in_inf6;
    fpuf_8   <= fpuf_7;

    // ================================================================
    // STAGE 8  →  PATH SELECT + FULL ROUNDING  (pos 8)
    //   Reads from position 7: sum_3, diff_3, sum_overflow_2,
    //     exp_add_2, exponent_sub, fpu_op_final_5, bits_shifted_4,
    //     rm_7, sign_7, diffshift_gt_exponent, diffshift_et_55.
    //   Produces the fully rounded IEEE-754 result in outfp.
    // ================================================================
    begin : rounding_stage
        reg [51:0] mant_raw;
        reg        guard_bit, round_bit, sticky_bit;
        reg [10:0] exp_raw;
        reg        do_round;
        reg [52:0] mant_inc;
        reg        r_sign;

        r_sign = sign_7;

        // ---- path selection ----
        if (fpu_op_final_5) begin
            // effective subtraction
            mant_raw   = diff_3[53:2];
            guard_bit  = diff_3[1];
            round_bit  = diff_3[0];
            sticky_bit = 1'b0;
            exp_raw    = exponent_sub;
            if (diffshift_gt_exponent)
                exp_raw = 11'd0;
            if (diffshift_et_55 && diff_3 == 56'd0)
                exp_raw = 11'd0;
        end else begin
            // effective addition
            if (sum_overflow_2) begin
                mant_raw   = sum_3[54:3];
                guard_bit  = sum_3[2];
                round_bit  = sum_3[1];
                sticky_bit = sum_3[0] | bits_shifted_4;
            end else begin
                mant_raw   = sum_3[53:2];
                guard_bit  = sum_3[1];
                round_bit  = sum_3[0];
                sticky_bit = bits_shifted_4;
            end
            exp_raw = exp_add_2;
        end

        // ---- rounding decision ----
        case (rm_7)
            2'b00: // round to nearest, ties to even
                do_round = guard_bit & ((round_bit | sticky_bit) | mant_raw[0]);
            2'b01: // round toward zero (truncate)
                do_round = 1'b0;
            2'b10: // round toward +inf
                do_round = ~r_sign & (guard_bit | round_bit | sticky_bit);
            2'b11: // round toward -inf
                do_round =  r_sign & (guard_bit | round_bit | sticky_bit);
            default: do_round = 1'b0;
        endcase

        // ---- register rounding flags (spec registers) ----
        round_nearest_mode    <= (rm_7 == 2'b00);
        round_posinf_mode     <= (rm_7 == 2'b10);
        round_neginf_mode     <= (rm_7 == 2'b11);
        round_nearest_trigger   <= guard_bit & (round_bit | sticky_bit);
        round_nearest_exception <= guard_bit & ~round_bit & ~sticky_bit;
        round_nearest_enable    <= (rm_7 == 2'b00) &
                                    guard_bit & ((round_bit | sticky_bit) | mant_raw[0]);
        round_posinf_trigger    <= ~r_sign & (guard_bit | round_bit | sticky_bit);
        round_posinf_enable     <= (rm_7 == 2'b10) &
                                    ~r_sign & (guard_bit | round_bit | sticky_bit);
        round_neginf_trigger    <=  r_sign & (guard_bit | round_bit | sticky_bit);
        round_neginf_enable     <= (rm_7 == 2'b11) &
                                    r_sign & (guard_bit | round_bit | sticky_bit);
        round_enable            <= do_round;

        // ---- apply rounding ----
        if (do_round) begin
            mant_inc = {1'b0, mant_raw} + 53'd1;
            sumround_overflow  <= mant_inc[52] & ~fpu_op_final_5;
            diffround_overflow <= mant_inc[52] &  fpu_op_final_5;
            if (mant_inc[52])
                outfp <= {r_sign, exp_raw + 11'd1, mant_inc[52:1]};
            else
                outfp <= {r_sign, exp_raw, mant_inc[51:0]};
        end else begin
            sumround_overflow  <= 1'b0;
            diffround_overflow <= 1'b0;
            outfp <= {r_sign, exp_raw, mant_raw};
        end
    end

    rm_8    <= rm_7;
    sign_8  <= sign_7;

    // Pipeline copies kept for spec completeness
    sum_4       <= sum_3;
    diff_4      <= diff_3;
    exp_add_3   <= exp_add_2;
    exp_sub_2   <= exponent_sub;
    expl_7      <= expl_6;
    small_shift_3 <= small_shift_2;
    large_add_4 <= large_add_3;

    in_inf8  <= in_inf7;
    fpuf_9   <= fpuf_8;

    // ================================================================
    // STAGE 9  →  begin output pipeline  (pos 9)
    //   outfp now holds the rounded result.  Pipeline it.
    // ================================================================
    rm_9    <= rm_8;    sign_9  <= sign_8;
    out_pipe_1 <= outfp;
    sum_5       <= sum_4;    diff_5   <= diff_4;
    exp_add_4   <= exp_add_3; exp_sub_3 <= exp_sub_2;
    expl_8      <= expl_7;
    small_shift_4 <= small_shift_3;
    large_add_5 <= large_add_4;
    in_inf9  <= in_inf8;  fpuf_10 <= fpuf_9;

    // ================================================================
    // STAGES 10–18  →  output pipeline delays
    // ================================================================
    // Stage 10
    rm_10 <= rm_9;    sign_10 <= sign_9;
    out_pipe_2 <= out_pipe_1;
    sum_6  <= sum_5;   diff_6  <= diff_5;
    exp_add_5 <= exp_add_4; exp_sub_4 <= exp_sub_3;
    expl_9 <= expl_8;
    in_inf10 <= in_inf9;  fpuf_11 <= fpuf_10;

    // Stage 11
    rm_11 <= rm_10;   sign_11 <= sign_10;
    out_pipe_3 <= out_pipe_2;
    sum_7  <= sum_6;   diff_7  <= diff_6;
    exp_add_6 <= exp_add_5; exp_sub_5 <= exp_sub_4;
    expl_10 <= expl_9;
    in_inf11 <= in_inf10; fpuf_12 <= fpuf_11;

    // Stage 12
    rm_12 <= rm_11;   sign_12 <= sign_11;
    out_pipe_4 <= out_pipe_3;
    sum_8  <= sum_7;   diff_8  <= diff_7;
    exp_add_7 <= exp_add_6; exp_sub_6 <= exp_sub_5;
    expl_11 <= expl_10;
    in_inf12 <= in_inf11; fpuf_13 <= fpuf_12;

    // Stage 13
    rm_13 <= rm_12;   sign_13 <= sign_12;
    out_pipe_5 <= out_pipe_4;
    sum_9  <= sum_8;   diff_9  <= diff_8;
    exp_add_8 <= exp_add_7; exp_sub_7 <= exp_sub_6;
    in_inf13 <= in_inf12; fpuf_14 <= fpuf_13;

    // Stage 14
    rm_14 <= rm_13;   sign_14 <= sign_13;
    out_pipe_6 <= out_pipe_5;
    sum_10 <= sum_9;   diff_10 <= diff_9;
    exp_add_9 <= exp_add_8; exp_sub_8 <= exp_sub_7;
    in_inf14 <= in_inf13; fpuf_15 <= fpuf_14;

    // Stage 15
    rm_15 <= rm_14;   sign_15 <= sign_14;
    out_pipe_7 <= out_pipe_6;
    sum_11 <= sum_10;  diff_11 <= diff_10;
    in_inf15 <= in_inf14; fpuf_16 <= fpuf_15;

    // Stage 16
    rm_16 <= rm_15;   sign_16 <= sign_15;
    out_pipe_8 <= out_pipe_7;
    in_inf16 <= in_inf15; fpuf_17 <= fpuf_16;

    // Stage 17
    sign_17 <= sign_16;
    out_pipe_9 <= out_pipe_8;
    in_inf17 <= in_inf16; fpuf_18 <= fpuf_17;

    // Stage 18
    sign_18 <= sign_17;
    out_pipe_10 <= out_pipe_9;
    in_inf18 <= in_inf17; fpuf_19 <= fpuf_18;

    // ================================================================
    // STAGE 19  →  special-case override & final output  (pos 19)
    // ================================================================
    sign_19  <= sign_18;
    in_inf19 <= in_inf18;

    if (in_inf18)
        out <= {out_pipe_10[63], 11'h7FF, 52'b0};  // infinity
    else if (out_pipe_10[62:52] == 11'd0 && out_pipe_10[51:0] == 52'd0)
        out <= {out_pipe_10[63], 63'd0};             // signed zero
    else
        out <= out_pipe_10;

    fpuf_20  <= fpuf_19;

    // ================================================================
    // STAGE 20  →  ready
    // ================================================================
    in_inf20 <= in_inf19;
    in_inf21 <= in_inf20;
    fpuf_21  <= fpuf_20;

    // ---- completion counter ----
    if (count < 5'd20)
        count <= count + 5'd1;
    count_ready   <= (count >= 5'd17);
    count_ready_0 <= count_ready;
    ready         <= count_ready_0;

end // enable
end // always

endmodule