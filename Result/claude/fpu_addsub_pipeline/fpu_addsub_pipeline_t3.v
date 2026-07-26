//-----------------------------------------------------------------------------
// Module      : fpu_addsub
// Description : Pipelined IEEE-754 double-precision floating-point add/sub.
//               Effective operation is (fpu_op XOR sign_a XOR sign_b).
//                 - Effective ADD : significand sum path
//                 - Effective SUB : significand diff path (with LZD normalize)
//               Fixed-latency pipeline: 'ready' asserts via a completion
//               counter and result appears on 'out'.
//
// Ports       :
//   clk    - clock
//   rst    - synchronous reset (active high)
//   enable - active-high pipeline enable
//   fpu_op - 0 = add, 1 = subtract
//   rmode  - IEEE-754 rounding mode
//              2'b00 : round to nearest even
//              2'b01 : round toward zero
//              2'b10 : round toward +infinity
//              2'b11 : round toward -infinity
//   opa    - operand A (IEEE-754 double)
//   opb    - operand B (IEEE-754 double)
//   out    - 64-bit IEEE-754 double result
//   ready  - result-valid flag (fixed latency)
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module fpu_addsub (
    input               clk,
    input               rst,
    input               enable,
    input               fpu_op,
    input   [1:0]       rmode,
    input   [63:0]      opa,
    input   [63:0]      opb,
    output  [63:0]      out,
    output              ready
);

    // ------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------
    localparam [10:0] EXP_ONES = 11'h7FF;

    // ------------------------------------------------------------------
    // Output holders
    // ------------------------------------------------------------------
    reg [63:0] outfp;
    reg [63:0] out_r;
    assign out = out_r;

    // ------------------------------------------------------------------
    // Rounding-mode shift register (rm_1 .. rm_16)
    // ------------------------------------------------------------------
    reg [1:0] rm_1,  rm_2,  rm_3,  rm_4,  rm_5,  rm_6,  rm_7,  rm_8;
    reg [1:0] rm_9,  rm_10, rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;

    // ------------------------------------------------------------------
    // Sign registers
    // ------------------------------------------------------------------
    reg sign;
    reg sign_a,  sign_b;
    reg sign_a2, sign_a3;
    reg sign_b2, sign_b3;
    reg sign_2,  sign_3,  sign_4,  sign_5,  sign_6;
    reg sign_7,  sign_8,  sign_9,  sign_10, sign_11;
    reg sign_12, sign_13, sign_14, sign_15, sign_16;
    reg sign_17, sign_18, sign_19;

    // ------------------------------------------------------------------
    // Op pipeline
    // ------------------------------------------------------------------
    reg fpu_op_1, fpu_op_2, fpu_op_3;
    reg fpu_op_final;

    // Pipeline-valid shift register
    reg fpuf_2,  fpuf_3,  fpuf_4,  fpuf_5,  fpuf_6,  fpuf_7;
    reg fpuf_8,  fpuf_9,  fpuf_10, fpuf_11, fpuf_12, fpuf_13;
    reg fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18, fpuf_19;
    reg fpuf_20, fpuf_21;

    // ------------------------------------------------------------------
    // Unpacked operand pipeline
    // ------------------------------------------------------------------
    reg [10:0] exponent_a, exponent_b;
    reg [10:0] expa_2, expa_3;
    reg [10:0] expb_2, expb_3;
    reg [51:0] mantissa_a, mantissa_b;
    reg [51:0] mana_2, mana_3;
    reg [51:0] manb_2, manb_3;

    // ------------------------------------------------------------------
    // Specials
    // ------------------------------------------------------------------
    reg expa_et_inf, expb_et_inf;
    reg input_is_inf;
    reg in_inf2,  in_inf3,  in_inf4,  in_inf5,  in_inf6,  in_inf7;
    reg in_inf8,  in_inf9,  in_inf10, in_inf11, in_inf12, in_inf13;
    reg in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19;
    reg in_inf20, in_inf21;

    // ------------------------------------------------------------------
    // Magnitude comparison
    // ------------------------------------------------------------------
    reg expa_gt_expb;
    reg expa_et_expb;
    reg mana_gtet_manb;
    reg a_gtet_b;

    // ------------------------------------------------------------------
    // Large / small operand selection
    // ------------------------------------------------------------------
    reg [10:0] exponent_small, exponent_large;
    reg [10:0] expl_2, expl_3, expl_4, expl_5, expl_6;
    reg [10:0] expl_7, expl_8, expl_9, expl_10, expl_11;

    reg [51:0] mantissa_small, mantissa_large;
    reg [51:0] mantissa_small_2, mantissa_large_2;
    reg [51:0] mantissa_small_3, mantissa_large_3;

    reg exp_small_et0, exp_large_et0;
    reg exp_small_et0_2, exp_large_et0_2;

    reg [10:0] exponent_diff, exponent_diff_2, exponent_diff_3;

    // ------------------------------------------------------------------
    // Alignment / shift-out tracking
    // ------------------------------------------------------------------
    reg [107:0] bits_shifted_out, bits_shifted_out_2;
    reg         bits_shifted;

    // ------------------------------------------------------------------
    // Add / subtract datapath (56-bit: 1 hidden + 52 + guard + round + sticky)
    // ------------------------------------------------------------------
    reg [55:0] large_add, large_add_2, large_add_3, large_add_4, large_add_5;
    reg [55:0] small_add;
    reg [55:0] small_shift, small_shift_2, small_shift_3, small_shift_4;
    reg        small_shift_nonzero;
    reg        small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
    reg        small_fraction_enable;
    wire [55:0] small_shift_LSB = { 55'b0, 1'b1 };

    reg [55:0] sum, sum_2, sum_3, sum_4, sum_5, sum_6;
    reg [55:0] sum_7, sum_8, sum_9, sum_10, sum_11;
    reg        sum_overflow;
    reg        sumround_overflow;
    reg        sum_lsb, sum_lsb_2;

    reg [10:0] exponent_add, exp_add_2, exp_add_3, exp_add_4, exp_add_5;
    reg [10:0] exp_add_6, exp_add_7, exp_add_8, exp_add_9;
    reg [10:0] exponent_sub, exp_sub_2, exp_sub_3, exp_sub_4;
    reg [10:0] exp_sub_5, exp_sub_6, exp_sub_7, exp_sub_8;

    reg [5:0]  diff_shift, diff_shift_2;
    reg [55:0] diff, diff_2, diff_3, diff_4, diff_5, diff_6;
    reg [55:0] diff_7, diff_8, diff_9, diff_10, diff_11;
    reg        diffshift_gt_exponent;
    reg        diffshift_et_55;
    reg        diffround_overflow;

    // ------------------------------------------------------------------
    // Rounding controls
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
    reg ready_r;
    reg count_ready, count_ready_0;
    reg [4:0] count;
    assign ready = ready_r;

    // ==================================================================
    // Helper: count leading zeros of the 56-bit difference (LZD)
    // Returns 0..55.  Used to compute the normalization shift for the
    // effective-subtract path.
    // ==================================================================
    function [5:0] lzd56;
        input [55:0] v;
        integer i;
        begin
            lzd56 = 6'd56;
            for (i = 55; i >= 0; i = i - 1)
                if (v[i] && (lzd56 == 6'd56))
                    lzd56 = 6'd55 - i[5:0];
        end
    endfunction

    // ==================================================================
    // Stage 0 : unpack, detect infinity, seed op/rm pipelines
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sign_a      <= 1'b0;
            sign_b      <= 1'b0;
            exponent_a  <= 11'b0;
            exponent_b  <= 11'b0;
            mantissa_a  <= 52'b0;
            mantissa_b  <= 52'b0;
            expa_et_inf <= 1'b0;
            expb_et_inf <= 1'b0;
            rm_1        <= 2'b0;
            fpu_op_1    <= 1'b0;
        end else if (enable) begin
            sign_a      <= opa[63];
            sign_b      <= opb[63];
            exponent_a  <= opa[62:52];
            exponent_b  <= opb[62:52];
            mantissa_a  <= opa[51:0];
            mantissa_b  <= opb[51:0];
            expa_et_inf <= (opa[62:52] == EXP_ONES);
            expb_et_inf <= (opb[62:52] == EXP_ONES);
            rm_1        <= rmode;
            fpu_op_1    <= fpu_op;
        end
    end

    // ==================================================================
    // Rounding-mode shift register (rm_1..rm_16)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            rm_2  <= 2'b0; rm_3  <= 2'b0; rm_4  <= 2'b0; rm_5  <= 2'b0;
            rm_6  <= 2'b0; rm_7  <= 2'b0; rm_8  <= 2'b0; rm_9  <= 2'b0;
            rm_10 <= 2'b0; rm_11 <= 2'b0; rm_12 <= 2'b0; rm_13 <= 2'b0;
            rm_14 <= 2'b0; rm_15 <= 2'b0; rm_16 <= 2'b0;
        end else if (enable) begin
            rm_2  <= rm_1;   rm_3  <= rm_2;   rm_4  <= rm_3;
            rm_5  <= rm_4;   rm_6  <= rm_5;   rm_7  <= rm_6;
            rm_8  <= rm_7;   rm_9  <= rm_8;   rm_10 <= rm_9;
            rm_11 <= rm_10;  rm_12 <= rm_11;  rm_13 <= rm_12;
            rm_14 <= rm_13;  rm_15 <= rm_14;  rm_16 <= rm_15;
        end
    end

    // ==================================================================
    // Pipeline-valid shift register (fpuf_2..fpuf_21)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            fpuf_2  <= 1'b0; fpuf_3  <= 1'b0; fpuf_4  <= 1'b0; fpuf_5  <= 1'b0;
            fpuf_6  <= 1'b0; fpuf_7  <= 1'b0; fpuf_8  <= 1'b0; fpuf_9  <= 1'b0;
            fpuf_10 <= 1'b0; fpuf_11 <= 1'b0; fpuf_12 <= 1'b0; fpuf_13 <= 1'b0;
            fpuf_14 <= 1'b0; fpuf_15 <= 1'b0; fpuf_16 <= 1'b0; fpuf_17 <= 1'b0;
            fpuf_18 <= 1'b0; fpuf_19 <= 1'b0; fpuf_20 <= 1'b0; fpuf_21 <= 1'b0;
        end else if (enable) begin
            fpuf_2  <= enable;  fpuf_3  <= fpuf_2;
            fpuf_4  <= fpuf_3;  fpuf_5  <= fpuf_4;
            fpuf_6  <= fpuf_5;  fpuf_7  <= fpuf_6;
            fpuf_8  <= fpuf_7;  fpuf_9  <= fpuf_8;
            fpuf_10 <= fpuf_9;  fpuf_11 <= fpuf_10;
            fpuf_12 <= fpuf_11; fpuf_13 <= fpuf_12;
            fpuf_14 <= fpuf_13; fpuf_15 <= fpuf_14;
            fpuf_16 <= fpuf_15; fpuf_17 <= fpuf_16;
            fpuf_18 <= fpuf_17; fpuf_19 <= fpuf_18;
            fpuf_20 <= fpuf_19; fpuf_21 <= fpuf_20;
        end
    end

    // ==================================================================
    // Stage 1 : compare magnitudes, pipeline unpacked fields
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            expa_gt_expb   <= 1'b0;
            expa_et_expb   <= 1'b0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b       <= 1'b0;
            sign_a2        <= 1'b0; sign_b2 <= 1'b0;
            expa_2         <= 11'b0; expb_2 <= 11'b0;
            mana_2         <= 52'b0; manb_2 <= 52'b0;
            input_is_inf   <= 1'b0;
            fpu_op_2       <= 1'b0;
        end else if (enable) begin
            expa_gt_expb   <= (exponent_a > exponent_b);
            expa_et_expb   <= (exponent_a == exponent_b);
            mana_gtet_manb <= (mantissa_a >= mantissa_b);
            a_gtet_b       <= (exponent_a > exponent_b) |
                              ((exponent_a == exponent_b) &
                               (mantissa_a >= mantissa_b));
            sign_a2        <= sign_a;
            sign_b2        <= sign_b;
            expa_2         <= exponent_a;
            expb_2         <= exponent_b;
            mana_2         <= mantissa_a;
            manb_2         <= mantissa_b;
            input_is_inf   <= expa_et_inf | expb_et_inf;
            fpu_op_2       <= fpu_op_1;
        end
    end

    // ==================================================================
    // Stage 2 : pick large/small operands, compute exponent difference,
    // decide effective operation and result sign
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sign             <= 1'b0;
            fpu_op_final     <= 1'b0;
            fpu_op_3         <= 1'b0;
            sign_a3          <= 1'b0; sign_b3 <= 1'b0;
            expa_3           <= 11'b0; expb_3 <= 11'b0;
            mana_3           <= 52'b0; manb_3 <= 52'b0;
            exponent_small   <= 11'b0;
            exponent_large   <= 11'b0;
            mantissa_small   <= 52'b0;
            mantissa_large   <= 52'b0;
            exp_small_et0    <= 1'b0;
            exp_large_et0    <= 1'b0;
            exponent_diff    <= 11'b0;
            in_inf2          <= 1'b0;
        end else if (enable) begin
            // Effective op: swap add/sub when signs differ
            fpu_op_final   <= fpu_op_2 ^ (sign_a2 ^ sign_b2);
            fpu_op_3       <= fpu_op_2;

            // Result sign follows the larger-magnitude operand
            sign           <= a_gtet_b ? sign_a2 : (sign_b2 ^ fpu_op_2);

            sign_a3        <= sign_a2;
            sign_b3        <= sign_b2;
            expa_3         <= expa_2;   expb_3 <= expb_2;
            mana_3         <= mana_2;   manb_3 <= manb_2;

            exponent_large <= a_gtet_b ? expa_2 : expb_2;
            exponent_small <= a_gtet_b ? expb_2 : expa_2;
            mantissa_large <= a_gtet_b ? mana_2 : manb_2;
            mantissa_small <= a_gtet_b ? manb_2 : mana_2;
            exp_large_et0  <= a_gtet_b ? (expa_2 == 11'b0) : (expb_2 == 11'b0);
            exp_small_et0  <= a_gtet_b ? (expb_2 == 11'b0) : (expa_2 == 11'b0);

            exponent_diff  <= a_gtet_b ? (expa_2 - expb_2)
                                       : (expb_2 - expa_2);
            in_inf2        <= input_is_inf;
        end
    end

    // ==================================================================
    // Sign shift register (sign .. sign_19)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sign_2  <= 1'b0; sign_3  <= 1'b0; sign_4  <= 1'b0; sign_5  <= 1'b0;
            sign_6  <= 1'b0; sign_7  <= 1'b0; sign_8  <= 1'b0; sign_9  <= 1'b0;
            sign_10 <= 1'b0; sign_11 <= 1'b0; sign_12 <= 1'b0; sign_13 <= 1'b0;
            sign_14 <= 1'b0; sign_15 <= 1'b0; sign_16 <= 1'b0; sign_17 <= 1'b0;
            sign_18 <= 1'b0; sign_19 <= 1'b0;
        end else if (enable) begin
            sign_2  <= sign;    sign_3  <= sign_2;
            sign_4  <= sign_3;  sign_5  <= sign_4;
            sign_6  <= sign_5;  sign_7  <= sign_6;
            sign_8  <= sign_7;  sign_9  <= sign_8;
            sign_10 <= sign_9;  sign_11 <= sign_10;
            sign_12 <= sign_11; sign_13 <= sign_12;
            sign_14 <= sign_13; sign_15 <= sign_14;
            sign_16 <= sign_15; sign_17 <= sign_16;
            sign_18 <= sign_17; sign_19 <= sign_18;
        end
    end

    // ==================================================================
    // in_inf shift register (in_inf2 .. in_inf21)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            in_inf3  <= 1'b0; in_inf4  <= 1'b0; in_inf5  <= 1'b0;
            in_inf6  <= 1'b0; in_inf7  <= 1'b0; in_inf8  <= 1'b0;
            in_inf9  <= 1'b0; in_inf10 <= 1'b0; in_inf11 <= 1'b0;
            in_inf12 <= 1'b0; in_inf13 <= 1'b0; in_inf14 <= 1'b0;
            in_inf15 <= 1'b0; in_inf16 <= 1'b0; in_inf17 <= 1'b0;
            in_inf18 <= 1'b0; in_inf19 <= 1'b0; in_inf20 <= 1'b0;
            in_inf21 <= 1'b0;
        end else if (enable) begin
            in_inf3  <= in_inf2;  in_inf4  <= in_inf3;
            in_inf5  <= in_inf4;  in_inf6  <= in_inf5;
            in_inf7  <= in_inf6;  in_inf8  <= in_inf7;
            in_inf9  <= in_inf8;  in_inf10 <= in_inf9;
            in_inf11 <= in_inf10; in_inf12 <= in_inf11;
            in_inf13 <= in_inf12; in_inf14 <= in_inf13;
            in_inf15 <= in_inf14; in_inf16 <= in_inf15;
            in_inf17 <= in_inf16; in_inf18 <= in_inf17;
            in_inf19 <= in_inf18; in_inf20 <= in_inf19;
            in_inf21 <= in_inf20;
        end
    end

    // ==================================================================
    // Stage 3 : build 56-bit operands (hidden|52|GRS placeholder), pipeline
    // exponent_large and exponent_diff.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            expl_2            <= 11'b0;
            mantissa_small_2  <= 52'b0;
            mantissa_large_2  <= 52'b0;
            exp_small_et0_2   <= 1'b0;
            exp_large_et0_2   <= 1'b0;
            exponent_diff_2   <= 11'b0;
            large_add         <= 56'b0;
            small_add         <= 56'b0;
        end else if (enable) begin
            expl_2            <= exponent_large;
            mantissa_small_2  <= mantissa_small;
            mantissa_large_2  <= mantissa_large;
            exp_small_et0_2   <= exp_small_et0;
            exp_large_et0_2   <= exp_large_et0;
            exponent_diff_2   <= exponent_diff;

            // Prepend implicit-1 (0 for denorm) and pad three guard bits
            large_add <= { 1'b0, ~exp_large_et0, mantissa_large, 2'b00 };
            small_add <= { 1'b0, ~exp_small_et0, mantissa_small, 2'b00 };
        end
    end

    // ==================================================================
    // Stage 4 : align smaller mantissa (>> exponent_diff), capture the
    // bits shifted out for sticky calculation.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            expl_3           <= 11'b0;
            mantissa_small_3 <= 52'b0;
            mantissa_large_3 <= 52'b0;
            exponent_diff_3  <= 11'b0;
            small_shift      <= 56'b0;
            bits_shifted_out <= 108'b0;
            large_add_2      <= 56'b0;
        end else if (enable) begin
            expl_3           <= expl_2;
            mantissa_small_3 <= mantissa_small_2;
            mantissa_large_3 <= mantissa_large_2;
            exponent_diff_3  <= exponent_diff_2;
            large_add_2      <= large_add;

            // Perform the alignment shift.  Clamp shifts >= 56 to 56 so
            // the small operand is fully out; sticky captured below.
            if (exponent_diff_2 >= 11'd56)
                small_shift <= 56'b0;
            else
                small_shift <= small_add >> exponent_diff_2;

            // Track bits shifted out via a wide left/right window
            bits_shifted_out <= { small_add, 52'b0 } >> exponent_diff_2;
        end
    end

    // ==================================================================
    // Stage 5 : compute sticky, form sum and diff
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            small_shift_2      <= 56'b0;
            small_shift_3      <= 56'b0;
            small_shift_4      <= 56'b0;
            large_add_3        <= 56'b0;
            large_add_4        <= 56'b0;
            large_add_5        <= 56'b0;
            bits_shifted_out_2 <= 108'b0;
            bits_shifted       <= 1'b0;
            small_shift_nonzero<= 1'b0;
            small_is_nonzero   <= 1'b0;
            small_is_nonzero_2 <= 1'b0;
            small_is_nonzero_3 <= 1'b0;
            small_fraction_enable <= 1'b0;
            sum                <= 56'b0;
            diff               <= 56'b0;
            diff_shift         <= 6'b0;
            diff_shift_2       <= 6'b0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55    <= 1'b0;
        end else if (enable) begin
            // Pipeline forwards
            small_shift_2      <= small_shift;
            small_shift_3      <= small_shift_2;
            small_shift_4      <= small_shift_3;
            large_add_3        <= large_add_2;
            large_add_4        <= large_add_3;
            large_add_5        <= large_add_4;
            bits_shifted_out_2 <= bits_shifted_out;
            bits_shifted       <= |bits_shifted_out[51:0];

            small_is_nonzero   <= |small_shift;
            small_is_nonzero_2 <= small_is_nonzero;
            small_is_nonzero_3 <= small_is_nonzero_2;
            small_shift_nonzero<= |bits_shifted_out[51:0];
            small_fraction_enable <= |bits_shifted_out[51:0]
                                     & ~(|small_shift[1:0]);

            // Sum path: large + (small shifted) [+ sticky OR into LSB]
            sum  <= large_add_2 + (small_shift | (small_shift_nonzero ?
                                                  small_shift_LSB : 56'b0));
            // Diff path: large - (small shifted)
            diff <= large_add_2 - small_shift;

            // Compute leading-zero count of diff for renormalization
            diff_shift   <= lzd56(large_add_2 - small_shift);
            diff_shift_2 <= diff_shift;

            diffshift_gt_exponent <= (diff_shift > {5'b0, expl_2[5:0]});
            diffshift_et_55       <= (diff_shift == 6'd55);
        end
    end

    // ==================================================================
    // Sum / diff pipeline (sum_2..sum_11, diff_2..diff_11)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_2  <= 56'b0; sum_3  <= 56'b0; sum_4  <= 56'b0; sum_5  <= 56'b0;
            sum_6  <= 56'b0; sum_7  <= 56'b0; sum_8  <= 56'b0; sum_9  <= 56'b0;
            sum_10 <= 56'b0; sum_11 <= 56'b0;
            diff_2 <= 56'b0; diff_3 <= 56'b0; diff_4 <= 56'b0; diff_5 <= 56'b0;
            diff_6 <= 56'b0; diff_7 <= 56'b0; diff_8 <= 56'b0; diff_9 <= 56'b0;
            diff_10<= 56'b0; diff_11<= 56'b0;
        end else if (enable) begin
            sum_2  <= sum;    sum_3  <= sum_2;   sum_4  <= sum_3;
            sum_5  <= sum_4;  sum_6  <= sum_5;   sum_7  <= sum_6;
            sum_8  <= sum_7;  sum_9  <= sum_8;   sum_10 <= sum_9;
            sum_11 <= sum_10;

            diff_2 <= diff;    diff_3 <= diff_2; diff_4 <= diff_3;
            diff_5 <= diff_4;  diff_6 <= diff_5; diff_7 <= diff_6;
            diff_8 <= diff_7;  diff_9 <= diff_8; diff_10<= diff_9;
            diff_11<= diff_10;
        end
    end

    // ==================================================================
    // exponent_large pipeline (expl_4..expl_11)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            expl_4  <= 11'b0; expl_5  <= 11'b0; expl_6  <= 11'b0;
            expl_7  <= 11'b0; expl_8  <= 11'b0; expl_9  <= 11'b0;
            expl_10 <= 11'b0; expl_11 <= 11'b0;
        end else if (enable) begin
            expl_4  <= expl_3;   expl_5  <= expl_4;
            expl_6  <= expl_5;   expl_7  <= expl_6;
            expl_8  <= expl_7;   expl_9  <= expl_8;
            expl_10 <= expl_9;   expl_11 <= expl_10;
        end
    end

    // ==================================================================
    // Stage 6 : detect sum overflow and compute new exponent (add / sub
    // paths)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_overflow       <= 1'b0;
            sum_lsb            <= 1'b0;
            sum_lsb_2          <= 1'b0;
            exponent_add       <= 11'b0;
            exp_add_2          <= 11'b0;
            exponent_sub       <= 11'b0;
            exp_sub_2          <= 11'b0;
        end else if (enable) begin
            // Sum path overflow (bit 54 -> shift right, exp+1)
            sum_overflow <= sum_2[54];
            sum_lsb      <= sum_2[2];
            sum_lsb_2    <= sum_lsb;

            // Add-path exponent
            exponent_add <= expl_4 + {10'b0, sum_2[54]};
            exp_add_2    <= exponent_add;

            // Sub-path exponent
            exponent_sub <= (diff_shift_2 == 6'd0) ? expl_4
                                                   : (expl_4 - {5'b0, diff_shift_2});
            exp_sub_2    <= exponent_sub;
        end
    end

    // ==================================================================
    // Exponent pipelines (exp_add_3..9, exp_sub_3..8)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            exp_add_3 <= 11'b0; exp_add_4 <= 11'b0; exp_add_5 <= 11'b0;
            exp_add_6 <= 11'b0; exp_add_7 <= 11'b0; exp_add_8 <= 11'b0;
            exp_add_9 <= 11'b0;
            exp_sub_3 <= 11'b0; exp_sub_4 <= 11'b0; exp_sub_5 <= 11'b0;
            exp_sub_6 <= 11'b0; exp_sub_7 <= 11'b0; exp_sub_8 <= 11'b0;
        end else if (enable) begin
            exp_add_3 <= exp_add_2; exp_add_4 <= exp_add_3;
            exp_add_5 <= exp_add_4; exp_add_6 <= exp_add_5;
            exp_add_7 <= exp_add_6; exp_add_8 <= exp_add_7;
            exp_add_9 <= exp_add_8;

            exp_sub_3 <= exp_sub_2; exp_sub_4 <= exp_sub_3;
            exp_sub_5 <= exp_sub_4; exp_sub_6 <= exp_sub_5;
            exp_sub_7 <= exp_sub_6; exp_sub_8 <= exp_sub_7;
        end
    end

    // ==================================================================
    // Stage 7 : rounding decision, sum/diff post-round overflow detect
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
            sumround_overflow       <= 1'b0;
            diffround_overflow      <= 1'b0;
        end else if (enable) begin
            // Decode rounding mode
            round_nearest_mode <= (rm_15 == 2'b00);
            round_posinf_mode  <= (rm_15 == 2'b10);
            round_neginf_mode  <= (rm_15 == 2'b11);

            // Guard/round/sticky come from bits 1:0 of sum/diff after align.
            round_nearest_trigger   <= sum_11[1];
            round_nearest_exception <= |sum_11[0];
            round_nearest_enable    <= round_nearest_mode
                                       & round_nearest_trigger
                                       & (round_nearest_exception
                                          | sum_lsb_2);

            round_posinf_trigger <= |sum_11[1:0];
            round_posinf_enable  <= round_posinf_mode
                                    & round_posinf_trigger & ~sign_15;

            round_neginf_trigger <= |sum_11[1:0];
            round_neginf_enable  <= round_neginf_mode
                                    & round_neginf_trigger & sign_15;

            round_enable <= round_nearest_enable
                          | round_posinf_enable
                          | round_neginf_enable;

            // Overflow flags after rounding (rounding may push mantissa to
            // 1.0 * 2^(N+1)).
            sumround_overflow  <= &sum_11[54:2];
            diffround_overflow <= &diff_11[54:2];
        end
    end

    // ==================================================================
    // Stage 8 : final assembly.  Choose add-path vs sub-path based on
    // fpu_op_final; handle infinity/zero specials.
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            outfp <= 64'b0;
            out_r <= 64'b0;
        end else if (enable) begin : final_block
            reg [10:0] exp_out;
            reg [51:0] mant_out;
            reg        overflow_to_inf;

            if (fpu_op_final) begin
                // Effective subtract
                if (diffshift_et_55) begin
                    // Exact cancellation -> +0 (or -0 per rmode)
                    exp_out  = 11'b0;
                    mant_out = 52'b0;
                end else begin
                    exp_out  = exp_sub_8;
                    mant_out = diff_11[53:2];
                end
            end else begin
                // Effective add
                exp_out  = exp_add_9;
                mant_out = sum_overflow ? sum_11[54:3] : sum_11[53:2];
            end

            overflow_to_inf = in_inf21 | (exp_out == EXP_ONES);

            outfp <= overflow_to_inf ? { sign_19, EXP_ONES, 52'b0 }
                                     : { sign_19, exp_out, mant_out };
            out_r <= overflow_to_inf ? { sign_19, EXP_ONES, 52'b0 }
                                     : { sign_19, exp_out, mant_out };
        end
    end

    // ==================================================================
    // Completion counter / ready flag (21-cycle fixed latency)
    // ==================================================================
    always @(posedge clk) begin
        if (rst) begin
            count         <= 5'd0;
            count_ready_0 <= 1'b0;
            count_ready   <= 1'b0;
            ready_r       <= 1'b0;
        end else if (enable) begin
            if (count != 5'd21) begin
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