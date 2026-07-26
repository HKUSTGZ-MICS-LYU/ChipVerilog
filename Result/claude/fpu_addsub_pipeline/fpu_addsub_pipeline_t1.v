//-----------------------------------------------------------------------------
// fpu_addsub
//
// Pipelined IEEE-754 double-precision floating-point add/subtract unit.
//
// Latency: fixed pipeline; `ready` asserts when the completion counter has
//          walked all the way through the datapath.
//
// Ports:
//   clk     : rising-edge clock for all state
//   rst     : synchronous reset (active high)
//   enable  : pipeline enable; every state element is gated by this
//   fpu_op  : 0 = add, 1 = subtract
//   rmode   : IEEE-754 rounding mode
//             00 = round-to-nearest even
//             01 = round-toward-zero
//             10 = round-toward +inf
//             11 = round-toward -inf
//   opa/opb : operands
//   out     : normalized / rounded result
//   ready   : high for one cycle when the result is valid on `out`
//-----------------------------------------------------------------------------
module fpu_addsub (
    clk, rst, enable, fpu_op, rmode, opa, opb, out, ready
);

    input          clk;
    input          rst;
    input          enable;
    input          fpu_op;
    input  [1:0]   rmode;
    input  [63:0]  opa;
    input  [63:0]  opb;
    output [63:0]  out;
    output         ready;

    //---------------------------------------------------------------
    // Outputs (registered)
    //---------------------------------------------------------------
    reg  [63:0]  outfp;
    reg  [63:0]  out;
    reg          ready;

    //---------------------------------------------------------------
    // Rounding-mode pipeline copies
    //---------------------------------------------------------------
    reg  [1:0]   rm_1,  rm_2,  rm_3,  rm_4,  rm_5,  rm_6,  rm_7,  rm_8;
    reg  [1:0]   rm_9,  rm_10, rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;

    //---------------------------------------------------------------
    // Sign
    //---------------------------------------------------------------
    reg          sign;
    reg          sign_a,  sign_b;
    reg          sign_a2, sign_a3;
    reg          sign_b2, sign_b3;
    reg          sign_2,  sign_3,  sign_4,  sign_5,  sign_6;
    reg          sign_7,  sign_8,  sign_9,  sign_10, sign_11;
    reg          sign_12, sign_13, sign_14, sign_15, sign_16;
    reg          sign_17, sign_18, sign_19;

    //---------------------------------------------------------------
    // Operation
    //---------------------------------------------------------------
    reg          fpu_op_1, fpu_op_2, fpu_op_3;
    reg          fpu_op_final;   // effective add(0) / sub(1) after sign compression

    //---------------------------------------------------------------
    // Pipeline-valid flags (fpuf_N asserted at stage N when the datum was
    // launched with enable high N-1 cycles ago).
    //---------------------------------------------------------------
    reg          fpuf_2,  fpuf_3,  fpuf_4,  fpuf_5,  fpuf_6,  fpuf_7;
    reg          fpuf_8,  fpuf_9,  fpuf_10, fpuf_11, fpuf_12, fpuf_13;
    reg          fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18, fpuf_19;
    reg          fpuf_20, fpuf_21;

    //---------------------------------------------------------------
    // Exponents / mantissas from operand unpack
    //---------------------------------------------------------------
    reg  [10:0]  exponent_a, exponent_b;
    reg  [10:0]  expa_2, expb_2, expa_3, expb_3;
    reg  [51:0]  mantissa_a, mantissa_b;
    reg  [51:0]  mana_2, mana_3, manb_2, manb_3;

    //---------------------------------------------------------------
    // Infinity / special value flags
    //---------------------------------------------------------------
    reg          expa_et_inf, expb_et_inf, input_is_inf;
    reg          in_inf2,  in_inf3,  in_inf4,  in_inf5,  in_inf6,  in_inf7;
    reg          in_inf8,  in_inf9,  in_inf10, in_inf11, in_inf12, in_inf13;
    reg          in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19;
    reg          in_inf20, in_inf21;

    //---------------------------------------------------------------
    // Compare flags
    //---------------------------------------------------------------
    reg          expa_gt_expb, expa_et_expb, mana_gtet_manb, a_gtet_b;

    //---------------------------------------------------------------
    // Large / small selection
    //---------------------------------------------------------------
    reg  [10:0]  exponent_small, exponent_large;
    reg  [10:0]  expl_2, expl_3, expl_4, expl_5, expl_6, expl_7;
    reg  [10:0]  expl_8, expl_9, expl_10, expl_11;
    reg  [51:0]  mantissa_small, mantissa_large;
    reg  [51:0]  mantissa_small_2, mantissa_large_2;
    reg  [51:0]  mantissa_small_3, mantissa_large_3;
    reg          exp_small_et0,  exp_large_et0;
    reg          exp_small_et0_2, exp_large_et0_2;

    //---------------------------------------------------------------
    // Alignment (small mantissa right-shift)
    //---------------------------------------------------------------
    reg  [10:0]  exponent_diff, exponent_diff_2, exponent_diff_3;
    reg  [107:0] bits_shifted_out, bits_shifted_out_2;
    reg          bits_shifted;

    //---------------------------------------------------------------
    // Add / subtract path operands
    //---------------------------------------------------------------
    reg  [55:0]  large_add, large_add_2, large_add_3, large_add_4, large_add_5;
    reg  [55:0]  small_add;
    reg  [55:0]  small_shift, small_shift_2, small_shift_3, small_shift_4;
    reg          small_shift_nonzero;
    reg          small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
    reg          small_fraction_enable;
    wire [55:0]  small_shift_LSB = { 55'b0, 1'b1 };

    //---------------------------------------------------------------
    // Sum / difference
    //---------------------------------------------------------------
    reg  [55:0]  sum,  sum_2,  sum_3,  sum_4,  sum_5,  sum_6,  sum_7;
    reg  [55:0]  sum_8, sum_9, sum_10, sum_11;
    reg          sum_overflow, sumround_overflow;
    reg          sum_lsb, sum_lsb_2;

    //---------------------------------------------------------------
    // Exponent update
    //---------------------------------------------------------------
    reg  [10:0]  exponent_add, exp_add_2, exp_add_3, exp_add_4, exp_add_5;
    reg  [10:0]  exp_add_6, exp_add_7, exp_add_8, exp_add_9;
    reg  [10:0]  exponent_sub, exp_sub_2, exp_sub_3, exp_sub_4;
    reg  [10:0]  exp_sub_5, exp_sub_6, exp_sub_7, exp_sub_8;

    //---------------------------------------------------------------
    // Difference / normalization
    //---------------------------------------------------------------
    reg  [5:0]   diff_shift, diff_shift_2;
    reg  [55:0]  diff, diff_2, diff_3, diff_4, diff_5, diff_6, diff_7;
    reg  [55:0]  diff_8, diff_9, diff_10, diff_11;
    reg          diffshift_gt_exponent, diffshift_et_55;
    reg          diffround_overflow;

    //---------------------------------------------------------------
    // Rounding decoded controls
    //---------------------------------------------------------------
    reg          round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg          round_nearest_trigger, round_nearest_exception;
    reg          round_nearest_enable;
    reg          round_posinf_trigger,  round_posinf_enable;
    reg          round_neginf_trigger,  round_neginf_enable;
    reg          round_enable;

    //---------------------------------------------------------------
    // Ready generation
    //---------------------------------------------------------------
    reg          count_ready;
    reg          count_ready_0;
    reg  [4:0]   count;

    //---------------------------------------------------------------
    // Leading-zero count on a 56-bit value (bit-55 is the topmost;
    // returned value is the number of positions the value must be
    // shifted LEFT so bit-55 becomes 1).
    //---------------------------------------------------------------
    function [5:0] lzc56;
        input [55:0] v;
        integer i;
        reg     found;
        begin
            lzc56 = 6'd55;
            found = 1'b0;
            for (i = 55; i >= 0; i = i - 1) begin
                if (!found && v[i]) begin
                    lzc56 = 6'd55 - i[5:0];
                    found = 1'b1;
                end
            end
        end
    endfunction


    //===============================================================
    // Stage 1 : unpack operands
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sign_a       <= 1'b0;
            sign_b       <= 1'b0;
            exponent_a   <= 11'd0;
            exponent_b   <= 11'd0;
            mantissa_a   <= 52'd0;
            mantissa_b   <= 52'd0;
            fpu_op_1     <= 1'b0;
            rm_1         <= 2'd0;
            expa_et_inf  <= 1'b0;
            expb_et_inf  <= 1'b0;
            input_is_inf <= 1'b0;
        end else if (enable) begin
            sign_a       <= opa[63];
            sign_b       <= opb[63];
            exponent_a   <= opa[62:52];
            exponent_b   <= opb[62:52];
            mantissa_a   <= opa[51:0];
            mantissa_b   <= opb[51:0];
            fpu_op_1     <= fpu_op;
            rm_1         <= rmode;
            expa_et_inf  <= (opa[62:52] == 11'h7FF);
            expb_et_inf  <= (opb[62:52] == 11'h7FF);
            input_is_inf <= (opa[62:52] == 11'h7FF) | (opb[62:52] == 11'h7FF);
        end
    end


    //===============================================================
    // Stage 2 : compare operands, decide the result sign
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            expa_gt_expb   <= 1'b0;
            expa_et_expb   <= 1'b0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b       <= 1'b0;
            expa_2         <= 11'd0;
            expb_2         <= 11'd0;
            mana_2         <= 52'd0;
            manb_2         <= 52'd0;
            sign_a2        <= 1'b0;
            sign_b2        <= 1'b0;
            fpu_op_2       <= 1'b0;
            fpu_op_final   <= 1'b0;
            rm_2           <= 2'd0;
            in_inf2        <= 1'b0;
            fpuf_2         <= 1'b0;
            sign_2         <= 1'b0;
        end else if (enable) begin
            expa_gt_expb   <= (exponent_a >  exponent_b);
            expa_et_expb   <= (exponent_a == exponent_b);
            mana_gtet_manb <= (mantissa_a >= mantissa_b);
            a_gtet_b       <= (exponent_a >  exponent_b) |
                              ((exponent_a == exponent_b) &
                               (mantissa_a >= mantissa_b));

            expa_2   <= exponent_a;
            expb_2   <= exponent_b;
            mana_2   <= mantissa_a;
            manb_2   <= mantissa_b;
            sign_a2  <= sign_a;
            sign_b2  <= sign_b;
            fpu_op_2 <= fpu_op_1;
            rm_2     <= rm_1;
            in_inf2  <= input_is_inf;
            fpuf_2   <= 1'b1;

            // Effective operation:
            //   add(0)  and sign_a==sign_b -> magnitude add
            //   add(0)  and sign_a!=sign_b -> magnitude sub
            //   sub(1)  and sign_a==sign_b -> magnitude sub
            //   sub(1)  and sign_a!=sign_b -> magnitude add
            fpu_op_final <= fpu_op_1 ^ (sign_a ^ sign_b);

            // Result sign: the sign of the operand with larger magnitude.
            // For subtract, if opb wins, its sign is inverted first.
            if (fpu_op_1 == 1'b0)
                sign_2 <= ((exponent_a >  exponent_b) |
                          ((exponent_a == exponent_b) &
                           (mantissa_a >= mantissa_b))) ? sign_a : sign_b;
            else
                sign_2 <= ((exponent_a >  exponent_b) |
                          ((exponent_a == exponent_b) &
                           (mantissa_a >= mantissa_b))) ? sign_a : ~sign_b;
        end
    end


    //===============================================================
    // Stage 3 : split into (large, small), start the exponent diff
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            exponent_large  <= 11'd0;
            exponent_small  <= 11'd0;
            mantissa_large  <= 52'd0;
            mantissa_small  <= 52'd0;
            exp_large_et0   <= 1'b0;
            exp_small_et0   <= 1'b0;
            exponent_diff   <= 11'd0;
            expa_3          <= 11'd0;
            expb_3          <= 11'd0;
            mana_3          <= 52'd0;
            manb_3          <= 52'd0;
            sign_a3         <= 1'b0;
            sign_b3         <= 1'b0;
            fpu_op_3        <= 1'b0;
            rm_3            <= 2'd0;
            in_inf3         <= 1'b0;
            fpuf_3          <= 1'b0;
            sign_3          <= 1'b0;
        end else if (enable) begin
            if (a_gtet_b) begin
                exponent_large <= expa_2;
                exponent_small <= expb_2;
                mantissa_large <= mana_2;
                mantissa_small <= manb_2;
                exp_large_et0  <= (expa_2 == 11'd0);
                exp_small_et0  <= (expb_2 == 11'd0);
                exponent_diff  <= expa_2 - expb_2;
            end else begin
                exponent_large <= expb_2;
                exponent_small <= expa_2;
                mantissa_large <= manb_2;
                mantissa_small <= mana_2;
                exp_large_et0  <= (expb_2 == 11'd0);
                exp_small_et0  <= (expa_2 == 11'd0);
                exponent_diff  <= expb_2 - expa_2;
            end
            expa_3   <= expa_2;
            expb_3   <= expb_2;
            mana_3   <= mana_2;
            manb_3   <= manb_2;
            sign_a3  <= sign_a2;
            sign_b3  <= sign_b2;
            fpu_op_3 <= fpu_op_2;
            rm_3     <= rm_2;
            in_inf3  <= in_inf2;
            fpuf_3   <= fpuf_2;
            sign_3   <= sign_2;
        end
    end


    //===============================================================
    // Stage 4 : registered copies of stage-3 outputs, capture
    //           exponent_diff_2 and shift the small mantissa
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            mantissa_small_2 <= 52'd0;
            mantissa_large_2 <= 52'd0;
            expl_2           <= 11'd0;
            exp_small_et0_2  <= 1'b0;
            exp_large_et0_2  <= 1'b0;
            exponent_diff_2  <= 11'd0;
            bits_shifted_out <= 108'd0;
            small_is_nonzero <= 1'b0;
            rm_4             <= 2'd0;
            sign_4           <= 1'b0;
            in_inf4          <= 1'b0;
            fpuf_4           <= 1'b0;
        end else if (enable) begin
            mantissa_small_2 <= mantissa_small;
            mantissa_large_2 <= mantissa_large;
            expl_2           <= exponent_large;
            exp_small_et0_2  <= exp_small_et0;
            exp_large_et0_2  <= exp_large_et0;
            exponent_diff_2  <= exponent_diff;

            // Align the small mantissa: prepend the implicit 1 (if the
            // operand is normal) into a 108-bit vector so we can capture
            // every bit shifted off the right for use in rounding.
            //
            //   { 1|0, 52-bit mantissa, 55 guard bits } >> exponent_diff
            //
            // The upper 56 bits of the shifted vector are consumed as the
            // aligned small mantissa; the lower 52 bits collectively drive
            // the sticky decisions later.
            if (exponent_diff >= 11'd108)
                bits_shifted_out <= { {56{1'b0}},
                                      ~exp_small_et0,
                                      mantissa_small,
                                      3'b000 };
            else
                bits_shifted_out <=
                    ({ ~exp_small_et0, mantissa_small, {55{1'b0}} }
                     >> exponent_diff);

            small_is_nonzero <= (mantissa_small != 52'd0) | ~exp_small_et0;

            rm_4     <= rm_3;
            sign_4   <= sign_3;
            in_inf4  <= in_inf3;
            fpuf_4   <= fpuf_3;
        end
    end


    //===============================================================
    // Stage 5 : produce large_add / small_add halves, remember the
    //           sticky ("bits_shifted") information
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            large_add           <= 56'd0;
            small_add           <= 56'd0;
            small_shift         <= 56'd0;
            small_shift_nonzero <= 1'b0;
            small_is_nonzero_2  <= 1'b0;
            bits_shifted        <= 1'b0;
            bits_shifted_out_2  <= 108'd0;
            mantissa_small_3    <= 52'd0;
            mantissa_large_3    <= 52'd0;
            expl_3              <= 11'd0;
            exponent_diff_3     <= 11'd0;
            rm_5                <= 2'd0;
            sign_5              <= 1'b0;
            in_inf5             <= 1'b0;
            fpuf_5              <= 1'b0;
        end else if (enable) begin
            // "large" half: implicit-1 in bit 55, mantissa in [54:3], 3 zero
            // guard bits below.
            large_add <= { ~exp_large_et0_2, mantissa_large_2, 3'b000 };

            // "small" half: whatever survived the alignment shift.
            // The high 56 bits of bits_shifted_out become the aligned form.
            small_shift <= bits_shifted_out[107:52];
            small_add   <= bits_shifted_out[107:52];

            // Sticky: anything that got shifted below bit 52.
            bits_shifted <= |bits_shifted_out[51:0];

            small_shift_nonzero <= (bits_shifted_out[107:52] != 56'd0);
            small_is_nonzero_2  <= small_is_nonzero;
            bits_shifted_out_2  <= bits_shifted_out;
            mantissa_small_3    <= mantissa_small_2;
            mantissa_large_3    <= mantissa_large_2;
            expl_3              <= expl_2;
            exponent_diff_3     <= exponent_diff_2;
            rm_5                <= rm_4;
            sign_5              <= sign_4;
            in_inf5             <= in_inf4;
            fpuf_5              <= fpuf_4;
        end
    end


    //===============================================================
    // Stage 6 : perform the +/- combination
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum                   <= 56'd0;
            diff                  <= 56'd0;
            sum_overflow          <= 1'b0;
            sum_lsb               <= 1'b0;
            large_add_2           <= 56'd0;
            small_shift_2         <= 56'd0;
            small_is_nonzero_3    <= 1'b0;
            small_fraction_enable <= 1'b0;
            expl_4                <= 11'd0;
            rm_6                  <= 2'd0;
            sign_6                <= 1'b0;
            in_inf6               <= 1'b0;
            fpuf_6                <= 1'b0;
        end else if (enable) begin
            // Wide add gives us the carry bit for detecting mantissa overflow.
            {sum_overflow, sum} <= {1'b0, large_add} + {1'b0, small_add}
                                    + { 55'd0, bits_shifted };
            sum_lsb             <= (large_add[0] ^ small_add[0]) ^ bits_shifted;

            // Magnitude subtraction: large - small.  Because we chose "large"
            // to be the >= operand, the result never goes negative.
            diff <= large_add - small_add
                    - { 55'd0, bits_shifted };

            large_add_2           <= large_add;
            small_shift_2         <= small_shift;
            small_is_nonzero_3    <= small_is_nonzero_2;
            small_fraction_enable <= small_shift_nonzero | bits_shifted;
            expl_4                <= expl_3;
            rm_6                  <= rm_5;
            sign_6                <= sign_5;
            in_inf6               <= in_inf5;
            fpuf_6                <= fpuf_5;
        end
    end


    //===============================================================
    // Stage 7 : pre-normalization exponent bookkeeping
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_2         <= 56'd0;
            diff_2        <= 56'd0;
            sum_lsb_2     <= 1'b0;
            large_add_3   <= 56'd0;
            small_shift_3 <= 56'd0;
            exponent_add  <= 11'd0;
            exponent_sub  <= 11'd0;
            diff_shift    <= 6'd0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55       <= 1'b0;
            expl_5        <= 11'd0;
            rm_7          <= 2'd0;
            sign_7        <= 1'b0;
            in_inf7       <= 1'b0;
            fpuf_7        <= 1'b0;
        end else if (enable) begin
            sum_2         <= sum;
            diff_2        <= diff;
            sum_lsb_2     <= sum_lsb;
            large_add_3   <= large_add_2;
            small_shift_3 <= small_shift_2;

            // Add-path new exponent: same as large, +1 on carry-out.
            exponent_add <= expl_4 + { 10'd0, sum_overflow };

            // Sub-path leading-zero count against the top of `diff`.
            diff_shift            <= lzc56(diff);
            diffshift_gt_exponent <= ({5'd0, lzc56(diff)} > expl_4);
            diffshift_et_55       <= (lzc56(diff) == 6'd55);

            // Provisional sub-path exponent (may be forced to zero later).
            exponent_sub <= expl_4 - { 5'd0, lzc56(diff) };

            expl_5  <= expl_4;
            rm_7    <= rm_6;
            sign_7  <= sign_6;
            in_inf7 <= in_inf6;
            fpuf_7  <= fpuf_6;
        end
    end


    //===============================================================
    // Stage 8 : realign sum for a potential 1-bit right-shift
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_3          <= 56'd0;
            diff_3         <= 56'd0;
            diff_shift_2   <= 6'd0;
            exp_add_2      <= 11'd0;
            exp_sub_2      <= 11'd0;
            large_add_4    <= 56'd0;
            small_shift_4  <= 56'd0;
            expl_6         <= 11'd0;
            rm_8           <= 2'd0;
            sign_8         <= 1'b0;
            in_inf8        <= 1'b0;
            fpuf_8         <= 1'b0;
        end else if (enable) begin
            // Right-shift the sum by one when it overflowed the top bit.
            if (sum_overflow)
                sum_3 <= { 1'b0, sum_2[55:1] } | { 55'd0, sum_2[0] };
            else
                sum_3 <= sum_2;

            diff_3        <= diff_2;
            diff_shift_2  <= diff_shift;
            exp_add_2     <= exponent_add;
            exp_sub_2     <= exponent_sub;
            large_add_4   <= large_add_3;
            small_shift_4 <= small_shift_3;
            expl_6        <= expl_5;
            rm_8          <= rm_7;
            sign_8        <= sign_7;
            in_inf8       <= in_inf7;
            fpuf_8        <= fpuf_7;
        end
    end


    //===============================================================
    // Stage 9 : normalize the difference by shifting left
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_4      <= 56'd0;
            diff_4     <= 56'd0;
            exp_add_3  <= 11'd0;
            exp_sub_3  <= 11'd0;
            large_add_5<= 56'd0;
            expl_7     <= 11'd0;
            rm_9       <= 2'd0;
            sign_9     <= 1'b0;
            in_inf9    <= 1'b0;
            fpuf_9     <= 1'b0;
        end else if (enable) begin
            sum_4  <= sum_3;
            // Left-shift diff so bit 55 becomes 1, unless the diff is zero
            // (exact cancellation), in which case leave it alone.
            if (diff_3 == 56'd0)
                diff_4 <= 56'd0;
            else
                diff_4 <= diff_3 << diff_shift_2;

            exp_add_3   <= exp_add_2;
            exp_sub_3   <= exp_sub_2;
            large_add_5 <= large_add_4;
            expl_7      <= expl_6;
            rm_9        <= rm_8;
            sign_9      <= sign_8;
            in_inf9     <= in_inf8;
            fpuf_9      <= fpuf_8;
        end
    end


    //===============================================================
    // Stage 10 : decode rounding-mode controls
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            round_nearest_mode <= 1'b0;
            round_posinf_mode  <= 1'b0;
            round_neginf_mode  <= 1'b0;
            sum_5              <= 56'd0;
            diff_5             <= 56'd0;
            exp_add_4          <= 11'd0;
            exp_sub_4          <= 11'd0;
            expl_8             <= 11'd0;
            rm_10              <= 2'd0;
            sign_10            <= 1'b0;
            in_inf10           <= 1'b0;
            fpuf_10            <= 1'b0;
        end else if (enable) begin
            round_nearest_mode <= (rm_9 == 2'b00);
            round_posinf_mode  <= (rm_9 == 2'b10);
            round_neginf_mode  <= (rm_9 == 2'b11);

            sum_5     <= sum_4;
            diff_5    <= diff_4;
            exp_add_4 <= exp_add_3;
            exp_sub_4 <= exp_sub_3;
            expl_8    <= expl_7;
            rm_10     <= rm_9;
            sign_10   <= sign_9;
            in_inf10  <= in_inf9;
            fpuf_10   <= fpuf_9;
        end
    end


    //===============================================================
    // Stage 11 : compute per-mode rounding triggers
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            round_nearest_trigger    <= 1'b0;
            round_nearest_exception  <= 1'b0;
            round_posinf_trigger     <= 1'b0;
            round_neginf_trigger     <= 1'b0;
            sum_6                    <= 56'd0;
            diff_6                   <= 56'd0;
            exp_add_5                <= 11'd0;
            exp_sub_5                <= 11'd0;
            expl_9                   <= 11'd0;
            rm_11                    <= 2'd0;
            sign_11                  <= 1'b0;
            in_inf11                 <= 1'b0;
            fpuf_11                  <= 1'b0;
        end else if (enable) begin
            // Round-to-nearest even: fire when the guard bit is set.
            round_nearest_trigger   <= (sum_5[2] & (sum_5[1] | sum_5[0]));
            // Even-adjust: guard=1, sticky=0 -> round to even.
            round_nearest_exception <= (sum_5[2] & ~sum_5[1] & ~sum_5[0] & sum_5[3]);

            round_posinf_trigger <= (sum_5[2] | sum_5[1] | sum_5[0]);
            round_neginf_trigger <= (sum_5[2] | sum_5[1] | sum_5[0]);

            sum_6     <= sum_5;
            diff_6    <= diff_5;
            exp_add_5 <= exp_add_4;
            exp_sub_5 <= exp_sub_4;
            expl_9    <= expl_8;
            rm_11     <= rm_10;
            sign_11   <= sign_10;
            in_inf11  <= in_inf10;
            fpuf_11   <= fpuf_10;
        end
    end


    //===============================================================
    // Stage 12 : collapse mode+trigger into the round-enable signal
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            round_nearest_enable <= 1'b0;
            round_posinf_enable  <= 1'b0;
            round_neginf_enable  <= 1'b0;
            round_enable         <= 1'b0;
            sum_7                <= 56'd0;
            diff_7               <= 56'd0;
            exp_add_6            <= 11'd0;
            exp_sub_6            <= 11'd0;
            expl_10              <= 11'd0;
            rm_12                <= 2'd0;
            sign_12              <= 1'b0;
            in_inf12             <= 1'b0;
            fpuf_12              <= 1'b0;
        end else if (enable) begin
            round_nearest_enable <= round_nearest_mode &
                                    (round_nearest_trigger |
                                     round_nearest_exception);
            round_posinf_enable  <= round_posinf_mode  &
                                    round_posinf_trigger &
                                    ~sign_11;
            round_neginf_enable  <= round_neginf_mode  &
                                    round_neginf_trigger &
                                    sign_11;

            round_enable <= (round_nearest_mode &
                             (round_nearest_trigger | round_nearest_exception))
                          | (round_posinf_mode  & round_posinf_trigger & ~sign_11)
                          | (round_neginf_mode  & round_neginf_trigger & sign_11);

            sum_7     <= sum_6;
            diff_7    <= diff_6;
            exp_add_6 <= exp_add_5;
            exp_sub_6 <= exp_sub_5;
            expl_10   <= expl_9;
            rm_12     <= rm_11;
            sign_12   <= sign_11;
            in_inf12  <= in_inf11;
            fpuf_12   <= fpuf_11;
        end
    end


    //===============================================================
    // Stage 13 : apply the round-up increment on both paths
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_8              <= 56'd0;
            diff_8             <= 56'd0;
            sumround_overflow  <= 1'b0;
            diffround_overflow <= 1'b0;
            exp_add_7          <= 11'd0;
            exp_sub_7          <= 11'd0;
            expl_11            <= 11'd0;
            rm_13              <= 2'd0;
            sign_13            <= 1'b0;
            in_inf13           <= 1'b0;
            fpuf_13            <= 1'b0;
        end else if (enable) begin
            if (round_enable) begin
                // Increment at the LSB of the fraction (bit 3 in a 56-bit
                // vector holding {implicit,52-bit,GRS}).
                {sumround_overflow,  sum_8}  <=
                    {1'b0, sum_7}  + { 52'd0, 1'b1, 3'd0 };
                {diffround_overflow, diff_8} <=
                    {1'b0, diff_7} + { 52'd0, 1'b1, 3'd0 };
            end else begin
                sumround_overflow  <= 1'b0;
                diffround_overflow <= 1'b0;
                sum_8              <= sum_7;
                diff_8             <= diff_7;
            end

            exp_add_7 <= exp_add_6;
            exp_sub_7 <= exp_sub_6;
            expl_11   <= expl_10;
            rm_13     <= rm_12;
            sign_13   <= sign_12;
            in_inf13  <= in_inf12;
            fpuf_13   <= fpuf_12;
        end
    end


    //===============================================================
    // Stage 14 : right-shift the rounded sum on rounding overflow
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_9     <= 56'd0;
            diff_9    <= 56'd0;
            exp_add_8 <= 11'd0;
            exp_sub_8 <= 11'd0;
            rm_14     <= 2'd0;
            sign_14   <= 1'b0;
            in_inf14  <= 1'b0;
            fpuf_14   <= 1'b0;
        end else if (enable) begin
            // Rounding pushed the implicit-1 out the top -> shift.
            if (sumround_overflow)
                sum_9 <= { 1'b0, sum_8[55:1] };
            else
                sum_9 <= sum_8;

            if (diffround_overflow)
                diff_9 <= { 1'b0, diff_8[55:1] };
            else
                diff_9 <= diff_8;

            // Bump the exponent on rounding-overflow of the sum path.
            exp_add_8 <= exp_add_7 + { 10'd0, sumround_overflow };
            exp_sub_8 <= exp_sub_7 + { 10'd0, diffround_overflow };

            rm_14    <= rm_13;
            sign_14  <= sign_13;
            in_inf14 <= in_inf13;
            fpuf_14  <= fpuf_13;
        end
    end


    //===============================================================
    // Stage 15 : final per-path pipeline latch
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_10    <= 56'd0;
            diff_10   <= 56'd0;
            exp_add_9 <= 11'd0;
            rm_15     <= 2'd0;
            sign_15   <= 1'b0;
            in_inf15  <= 1'b0;
            fpuf_15   <= 1'b0;
        end else if (enable) begin
            sum_10    <= sum_9;
            diff_10   <= diff_9;
            exp_add_9 <= exp_add_8;
            rm_15     <= rm_14;
            sign_15   <= sign_14;
            in_inf15  <= in_inf14;
            fpuf_15   <= fpuf_14;
        end
    end


    //===============================================================
    // Stage 16 : final holding stage before result assembly
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sum_11   <= 56'd0;
            diff_11  <= 56'd0;
            rm_16    <= 2'd0;
            sign_16  <= 1'b0;
            in_inf16 <= 1'b0;
            fpuf_16  <= 1'b0;
        end else if (enable) begin
            sum_11   <= sum_10;
            diff_11  <= diff_10;
            rm_16    <= rm_15;
            sign_16  <= sign_15;
            in_inf16 <= in_inf15;
            fpuf_16  <= fpuf_15;
        end
    end


    //===============================================================
    // Stage 17 : choose add or sub path, drive `outfp`
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            outfp    <= 64'd0;
            sign     <= 1'b0;
            sign_17  <= 1'b0;
            in_inf17 <= 1'b0;
            fpuf_17  <= 1'b0;
        end else if (enable) begin
            sign_17  <= sign_16;
            in_inf17 <= in_inf16;
            fpuf_17  <= fpuf_16;
            sign     <= sign_16;

            if (in_inf16) begin
                // Any infinite operand -> return infinity of the result sign.
                outfp <= { sign_16, 11'h7FF, 52'd0 };
            end else if (fpu_op_final == 1'b0) begin
                // Add path result.
                outfp <= { sign_16, exp_add_9[10:0], sum_11[54:3] };
            end else begin
                // Sub path result.  Exact-cancellation returns +0.
                if (diffshift_et_55 & (diff_11 == 56'd0))
                    outfp <= 64'd0;
                else
                    outfp <= { sign_16, exp_sub_8[10:0], diff_11[54:3] };
            end
        end
    end


    //===============================================================
    // Stages 18..21 : hold outfp so its timing lines up with the
    //                 ready counter; then drive the module output.
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            sign_18  <= 1'b0;
            sign_19  <= 1'b0;
            in_inf18 <= 1'b0;
            in_inf19 <= 1'b0;
            in_inf20 <= 1'b0;
            in_inf21 <= 1'b0;
            fpuf_18  <= 1'b0;
            fpuf_19  <= 1'b0;
            fpuf_20  <= 1'b0;
            fpuf_21  <= 1'b0;
            out      <= 64'd0;
        end else if (enable) begin
            sign_18  <= sign_17;
            sign_19  <= sign_18;
            in_inf18 <= in_inf17;
            in_inf19 <= in_inf18;
            in_inf20 <= in_inf19;
            in_inf21 <= in_inf20;
            fpuf_18  <= fpuf_17;
            fpuf_19  <= fpuf_18;
            fpuf_20  <= fpuf_19;
            fpuf_21  <= fpuf_20;

            out      <= outfp;
        end
    end


    //===============================================================
    // Ready generation
    //
    // A free-running 5-bit counter is started when the pipeline is first
    // enabled; ready pulses high once it walks past the datapath depth.
    //===============================================================
    always @(posedge clk) begin
        if (rst) begin
            count         <= 5'd0;
            count_ready_0 <= 1'b0;
            count_ready   <= 1'b0;
            ready         <= 1'b0;
        end else if (enable) begin
            // Saturating counter (stops at 21 -> pipeline full).
            if (count != 5'd21)
                count <= count + 5'd1;

            count_ready_0 <= (count == 5'd20);
            count_ready   <= count_ready_0;
            ready         <= count_ready | fpuf_21;
        end
    end

endmodule