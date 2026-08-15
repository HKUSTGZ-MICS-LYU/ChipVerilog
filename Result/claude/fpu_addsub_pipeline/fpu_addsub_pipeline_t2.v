//-----------------------------------------------------------------------------
// fpu_addsub
//
// Pipelined double-precision IEEE-754 floating-point add / subtract unit.
//
//   fpu_op = 0 -> add,   fpu_op = 1 -> subtract
//   rmode  = 00 nearest, 01 zero, 10 +inf, 11 -inf
//
// The datapath is broken into ~20 pipeline stages.  Every state element
// updates only when `enable` is high; `rst` returns the machine to a known
// state.  `ready` pulses when the first result reaches the output.
//-----------------------------------------------------------------------------
module fpu_addsub (
    input               clk,
    input               rst,
    input               enable,
    input               fpu_op,
    input       [1:0]   rmode,
    input       [63:0]  opa,
    input       [63:0]  opb,
    output reg  [63:0]  out,
    output reg          ready
);

    //-------------------------------------------------------------------------
    // Local storage
    //-------------------------------------------------------------------------
    reg  [63:0] outfp;

    // rounding-mode pipeline
    reg  [1:0]  rm_1, rm_2, rm_3, rm_4, rm_5, rm_6, rm_7, rm_8;
    reg  [1:0]  rm_9, rm_10, rm_11, rm_12, rm_13, rm_14, rm_15, rm_16;

    // sign registers
    reg         sign;
    reg         sign_a,  sign_b;
    reg         sign_a2, sign_a3, sign_b2, sign_b3;
    reg         sign_2,  sign_3,  sign_4,  sign_5,  sign_6,  sign_7;
    reg         sign_8,  sign_9,  sign_10, sign_11, sign_12, sign_13;
    reg         sign_14, sign_15, sign_16, sign_17, sign_18, sign_19;

    // operation pipeline
    reg         fpu_op_1, fpu_op_2, fpu_op_3;
    reg         fpu_op_final;

    // "valid" pipeline (fpuf_N asserted when stage N holds a valid beat)
    reg         fpuf_2,  fpuf_3,  fpuf_4,  fpuf_5,  fpuf_6,  fpuf_7;
    reg         fpuf_8,  fpuf_9,  fpuf_10, fpuf_11, fpuf_12, fpuf_13;
    reg         fpuf_14, fpuf_15, fpuf_16, fpuf_17, fpuf_18, fpuf_19;
    reg         fpuf_20, fpuf_21;

    // raw exponent / mantissa fields and their staging copies
    reg  [10:0] exponent_a, exponent_b;
    reg  [10:0] expa_2,  expb_2,  expa_3,  expb_3;
    reg  [51:0] mantissa_a, mantissa_b;
    reg  [51:0] mana_2,  mana_3,  manb_2,  manb_3;

    // infinity detection
    reg         expa_et_inf, expb_et_inf, input_is_inf;
    reg         in_inf2,  in_inf3,  in_inf4,  in_inf5,  in_inf6,  in_inf7;
    reg         in_inf8,  in_inf9,  in_inf10, in_inf11, in_inf12, in_inf13;
    reg         in_inf14, in_inf15, in_inf16, in_inf17, in_inf18, in_inf19;
    reg         in_inf20, in_inf21;

    // comparison outputs
    reg         expa_gt_expb, expa_et_expb, mana_gtet_manb, a_gtet_b;

    // large / small operand selection
    reg  [10:0] exponent_small, exponent_large;
    reg  [10:0] expl_2, expl_3, expl_4, expl_5, expl_6;
    reg  [10:0] expl_7, expl_8, expl_9, expl_10, expl_11;
    reg  [51:0] mantissa_small, mantissa_large;
    reg  [51:0] mantissa_small_2, mantissa_large_2;
    reg  [51:0] mantissa_small_3, mantissa_large_3;

    reg         exp_small_et0, exp_large_et0;
    reg         exp_small_et0_2, exp_large_et0_2;

    // exponent difference used to right-align the smaller mantissa
    reg  [10:0] exponent_diff, exponent_diff_2, exponent_diff_3;

    // alignment shifter
    reg  [107:0] bits_shifted_out, bits_shifted_out_2;
    reg          bits_shifted;

    // pre-adder operands
    reg  [55:0] large_add, large_add_2, large_add_3, large_add_4, large_add_5;
    reg  [55:0] small_add;
    reg  [55:0] small_shift, small_shift_2, small_shift_3, small_shift_4;

    reg         small_shift_nonzero;
    reg         small_is_nonzero, small_is_nonzero_2, small_is_nonzero_3;
    reg         small_fraction_enable;
    wire [55:0] small_shift_LSB = {55'b0, 1'b1};

    // effective-add datapath
    reg  [55:0] sum, sum_2, sum_3, sum_4, sum_5, sum_6;
    reg  [55:0] sum_7, sum_8, sum_9, sum_10, sum_11;
    reg         sum_overflow, sumround_overflow;
    reg         sum_lsb, sum_lsb_2;

    // exponent add-side and sub-side pipelines
    reg  [10:0] exponent_add;
    reg  [10:0] exp_add_2, exp_add_3, exp_add_4, exp_add_5;
    reg  [10:0] exp_add_6, exp_add_7, exp_add_8, exp_add_9;
    reg  [10:0] exponent_sub;
    reg  [10:0] exp_sub_2, exp_sub_3, exp_sub_4, exp_sub_5;
    reg  [10:0] exp_sub_6, exp_sub_7, exp_sub_8;

    // effective-sub datapath
    reg  [5:0]  diff_shift, diff_shift_2;
    reg  [55:0] diff, diff_2, diff_3, diff_4, diff_5, diff_6;
    reg  [55:0] diff_7, diff_8, diff_9, diff_10, diff_11;
    reg         diffshift_gt_exponent, diffshift_et_55, diffround_overflow;

    // rounding
    reg         round_nearest_mode, round_posinf_mode, round_neginf_mode;
    reg         round_nearest_trigger, round_nearest_exception;
    reg         round_nearest_enable;
    reg         round_posinf_trigger, round_posinf_enable;
    reg         round_neginf_trigger, round_neginf_enable;
    reg         round_enable;

    // ready generation
    reg         count_ready, count_ready_0;
    reg  [4:0]  count;

    // helper: leading-zero count of a 56-bit vector (0..55) - used for
    // normalization of the effective-subtract result.
    function [5:0] lzc56;
        input [55:0] v;
        integer i;
        begin
            lzc56 = 6'd56;
            for (i = 55; i >= 0; i = i - 1)
                if (v[i] && lzc56 == 6'd56)
                    lzc56 = 6'd55 - i[5:0];
        end
    endfunction

    //=========================================================================
    // Stage 1 : latch inputs, compute effective operation, detect infinities
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_a       <= 1'b0;
            sign_b       <= 1'b0;
            exponent_a   <= 11'b0;
            exponent_b   <= 11'b0;
            mantissa_a   <= 52'b0;
            mantissa_b   <= 52'b0;
            fpu_op_1     <= 1'b0;
            rm_1         <= 2'b0;
            fpu_op_final <= 1'b0;
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
            fpu_op_final <= fpu_op ^ (opa[63] ^ opb[63]);
            expa_et_inf  <= &opa[62:52];
            expb_et_inf  <= &opb[62:52];
            input_is_inf <= (&opa[62:52]) | (&opb[62:52]);
        end
    end

    //=========================================================================
    // Stage 2 : compare exponents and mantissas
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rm_2           <= 2'b0;
            fpu_op_2       <= 1'b0;
            fpuf_2         <= 1'b0;
            sign_a2        <= 1'b0;
            sign_b2        <= 1'b0;
            expa_2         <= 11'b0;
            expb_2         <= 11'b0;
            mana_2         <= 52'b0;
            manb_2         <= 52'b0;
            in_inf2        <= 1'b0;
            expa_gt_expb   <= 1'b0;
            expa_et_expb   <= 1'b0;
            mana_gtet_manb <= 1'b0;
        end else if (enable) begin
            rm_2           <= rm_1;
            fpu_op_2       <= fpu_op_1;
            fpuf_2         <= 1'b1;
            sign_a2        <= sign_a;
            sign_b2        <= sign_b;
            expa_2         <= exponent_a;
            expb_2         <= exponent_b;
            mana_2         <= mantissa_a;
            manb_2         <= mantissa_b;
            in_inf2        <= input_is_inf;
            expa_gt_expb   <= exponent_a >  exponent_b;
            expa_et_expb   <= exponent_a == exponent_b;
            mana_gtet_manb <= mantissa_a >= mantissa_b;
        end
    end

    //=========================================================================
    // Stage 3 : pick larger / smaller operand and result sign
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rm_3            <= 2'b0;
            fpu_op_3        <= 1'b0;
            fpuf_3          <= 1'b0;
            sign_a3         <= 1'b0;
            sign_b3         <= 1'b0;
            expa_3          <= 11'b0;
            expb_3          <= 11'b0;
            mana_3          <= 52'b0;
            manb_3          <= 52'b0;
            in_inf3         <= 1'b0;
            a_gtet_b        <= 1'b0;
            sign_3          <= 1'b0;
            exponent_small  <= 11'b0;
            exponent_large  <= 11'b0;
            mantissa_small  <= 52'b0;
            mantissa_large  <= 52'b0;
            exp_small_et0   <= 1'b0;
            exp_large_et0   <= 1'b0;
        end else if (enable) begin
            rm_3            <= rm_2;
            fpu_op_3        <= fpu_op_2;
            fpuf_3          <= fpuf_2;
            sign_a3         <= sign_a2;
            sign_b3         <= sign_b2;
            expa_3          <= expa_2;
            expb_3          <= expb_2;
            mana_3          <= mana_2;
            manb_3          <= manb_2;
            in_inf3         <= in_inf2;
            a_gtet_b        <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);
            // sign of the result:
            //   effective add: sign = sign_a
            //   effective sub: sign follows larger magnitude; if b is larger
            //                  it flips relative to sign_a (op ^ sign_a2)
            sign_3          <= (expa_gt_expb | (expa_et_expb & mana_gtet_manb))
                               ? sign_a2
                               : (sign_b2 ^ fpu_op_2);
            if (expa_gt_expb | (expa_et_expb & mana_gtet_manb)) begin
                exponent_large <= expa_2;
                exponent_small <= expb_2;
                mantissa_large <= mana_2;
                mantissa_small <= manb_2;
                exp_large_et0  <= (expa_2 == 11'b0);
                exp_small_et0  <= (expb_2 == 11'b0);
            end else begin
                exponent_large <= expb_2;
                exponent_small <= expa_2;
                mantissa_large <= manb_2;
                mantissa_small <= mana_2;
                exp_large_et0  <= (expb_2 == 11'b0);
                exp_small_et0  <= (expa_2 == 11'b0);
            end
        end
    end

    //=========================================================================
    // Stage 4 : exponent difference; forward exp_large
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rm_4               <= 2'b0;
            fpuf_4             <= 1'b0;
            sign_4             <= 1'b0;
            in_inf4            <= 1'b0;
            mantissa_small_2   <= 52'b0;
            mantissa_large_2   <= 52'b0;
            exp_small_et0_2    <= 1'b0;
            exp_large_et0_2    <= 1'b0;
            expl_2             <= 11'b0;
            exponent_diff      <= 11'b0;
        end else if (enable) begin
            rm_4               <= rm_3;
            fpuf_4             <= fpuf_3;
            sign_4             <= sign_3;
            in_inf4            <= in_inf3;
            mantissa_small_2   <= mantissa_small;
            mantissa_large_2   <= mantissa_large;
            exp_small_et0_2    <= exp_small_et0;
            exp_large_et0_2    <= exp_large_et0;
            expl_2             <= exponent_large;
            exponent_diff      <= exponent_large - exponent_small;
        end
    end

    //=========================================================================
    // Stage 5 : saturate diff shift to 55 and build aligned operands
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rm_5             <= 2'b0;
            fpuf_5           <= 1'b0;
            sign_5           <= 1'b0;
            in_inf5          <= 1'b0;
            mantissa_small_3 <= 52'b0;
            mantissa_large_3 <= 52'b0;
            expl_3           <= 11'b0;
            exponent_diff_2  <= 11'b0;
            diff_shift       <= 6'b0;
            diffshift_gt_exponent <= 1'b0;
            large_add        <= 56'b0;
            small_add        <= 56'b0;
        end else if (enable) begin
            rm_5             <= rm_4;
            fpuf_5           <= fpuf_4;
            sign_5           <= sign_4;
            in_inf5          <= in_inf4;
            mantissa_small_3 <= mantissa_small_2;
            mantissa_large_3 <= mantissa_large_2;
            expl_3           <= expl_2;
            exponent_diff_2  <= exponent_diff;
            diffshift_gt_exponent <= (exponent_diff > 11'd55);
            diff_shift       <= (exponent_diff > 11'd55) ? 6'd55
                                                         : exponent_diff[5:0];
            // Assemble 56-bit operands: {implicit_1, mantissa, guard(3)}
            large_add        <= {~exp_large_et0_2, mantissa_large_2, 3'b000};
            small_add        <= {~exp_small_et0_2, mantissa_small_2, 3'b000};
        end
    end

    //=========================================================================
    // Stage 6 : right-shift the smaller operand; capture sticky bits
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        integer sh;
        reg [107:0] wide;
        if (rst) begin
            rm_6              <= 2'b0;
            fpuf_6            <= 1'b0;
            sign_6            <= 1'b0;
            in_inf6           <= 1'b0;
            expl_4            <= 11'b0;
            exponent_diff_3   <= 11'b0;
            diff_shift_2      <= 6'b0;
            diffshift_et_55   <= 1'b0;
            large_add_2       <= 56'b0;
            small_shift       <= 56'b0;
            bits_shifted_out  <= 108'b0;
            bits_shifted      <= 1'b0;
            small_is_nonzero  <= 1'b0;
        end else if (enable) begin
            rm_6              <= rm_5;
            fpuf_6            <= fpuf_5;
            sign_6            <= sign_5;
            in_inf6           <= in_inf5;
            expl_4            <= expl_3;
            exponent_diff_3   <= exponent_diff_2;
            diff_shift_2      <= diff_shift;
            diffshift_et_55   <= (diff_shift == 6'd55);
            large_add_2       <= large_add;
            // Wide right-shift so that no bits are lost silently.
            wide  = {small_add, 52'b0};
            sh    = diff_shift;
            small_shift       <= wide[107:52] >> sh;
            bits_shifted_out  <= (wide >> sh);
            bits_shifted      <= |(wide & ((108'd1 << sh) - 108'd1));
            small_is_nonzero  <= |small_add;
        end
    end

    //=========================================================================
    // Stage 7 : stage forwarding (extra latency slot)
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rm_7                 <= 2'b0;
            fpuf_7               <= 1'b0;
            sign_7               <= 1'b0;
            in_inf7              <= 1'b0;
            expl_5               <= 11'b0;
            large_add_3          <= 56'b0;
            small_shift_2        <= 56'b0;
            bits_shifted_out_2   <= 108'b0;
            small_is_nonzero_2   <= 1'b0;
            small_shift_nonzero  <= 1'b0;
            small_fraction_enable<= 1'b0;
        end else if (enable) begin
            rm_7                 <= rm_6;
            fpuf_7               <= fpuf_6;
            sign_7               <= sign_6;
            in_inf7              <= in_inf6;
            expl_5               <= expl_4;
            large_add_3          <= large_add_2;
            small_shift_2        <= small_shift;
            bits_shifted_out_2   <= bits_shifted_out;
            small_is_nonzero_2   <= small_is_nonzero;
            small_shift_nonzero  <= |small_shift;
            // If shift discarded any bits keep a sticky-1 in the LSB.
            small_fraction_enable<= bits_shifted;
        end
    end

    //=========================================================================
    // Stage 8 : compute sum and difference in parallel
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        reg [55:0] shift_final;
        if (rst) begin
            rm_8               <= 2'b0;
            fpuf_8             <= 1'b0;
            sign_8             <= 1'b0;
            in_inf8            <= 1'b0;
            expl_6             <= 11'b0;
            small_shift_3      <= 56'b0;
            large_add_4        <= 56'b0;
            sum                <= 56'b0;
            diff               <= 56'b0;
            sum_overflow       <= 1'b0;
            small_is_nonzero_3 <= 1'b0;
            sum_lsb            <= 1'b0;
            exponent_add       <= 11'b0;
            exponent_sub       <= 11'b0;
        end else if (enable) begin
            shift_final = small_fraction_enable
                          ? (small_shift_2 | small_shift_LSB)
                          :  small_shift_2;
            rm_8               <= rm_7;
            fpuf_8             <= fpuf_7;
            sign_8             <= sign_7;
            in_inf8            <= in_inf7;
            expl_6             <= expl_5;
            small_shift_3      <= shift_final;
            large_add_4        <= large_add_3;
            {sum_overflow, sum}<= {1'b0, large_add_3} + {1'b0, shift_final};
            diff               <= large_add_3 - shift_final;
            small_is_nonzero_3 <= small_is_nonzero_2;
            sum_lsb            <= shift_final[0];
            exponent_add       <= expl_5;
            exponent_sub       <= expl_5;
        end
    end

    //=========================================================================
    // Stages 9..11 : normalize the ADD path; leading-zero-shift the SUB path
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        reg [5:0] lz;
        if (rst) begin
            rm_9        <= 2'b0;
            fpuf_9      <= 1'b0;
            sign_9      <= 1'b0;
            in_inf9     <= 1'b0;
            expl_7      <= 11'b0;
            sum_2       <= 56'b0;
            diff_2      <= 56'b0;
            small_shift_4 <= 56'b0;
            large_add_5 <= 56'b0;
            exp_add_2   <= 11'b0;
            exp_sub_2   <= 11'b0;
            sum_lsb_2   <= 1'b0;
        end else if (enable) begin
            rm_9      <= rm_8;
            fpuf_9    <= fpuf_8;
            sign_9    <= sign_8;
            in_inf9   <= in_inf8;
            expl_7    <= expl_6;
            small_shift_4 <= small_shift_3;
            large_add_5   <= large_add_4;
            sum_lsb_2 <= sum_lsb;
            // Effective-add normalization: on overflow shift right 1, exp+1
            if (sum_overflow) begin
                sum_2     <= {1'b1, sum[55:1]};
                exp_add_2 <= exponent_add + 11'd1;
            end else begin
                sum_2     <= sum;
                exp_add_2 <= exponent_add;
            end
            // Effective-sub normalization: leading-zero shift
            lz = lzc56(diff);
            if (diff == 56'b0) begin
                diff_2    <= 56'b0;
                exp_sub_2 <= 11'b0;
            end else if (lz <= exponent_sub[5:0]) begin
                diff_2    <= diff << lz;
                exp_sub_2 <= exponent_sub - {5'b0, lz};
            end else begin
                // exponent would underflow -> denormal / zero
                diff_2    <= diff << exponent_sub[5:0];
                exp_sub_2 <= 11'b0;
            end
        end
    end

    // Stages 10..15 : straight pipeline forwarding for both paths
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            {rm_10, rm_11, rm_12, rm_13, rm_14, rm_15}          <= {6{2'b0}};
            {fpuf_10, fpuf_11, fpuf_12, fpuf_13, fpuf_14, fpuf_15} <= 6'b0;
            {sign_10, sign_11, sign_12, sign_13, sign_14, sign_15} <= 6'b0;
            {in_inf10, in_inf11, in_inf12, in_inf13, in_inf14, in_inf15} <= 6'b0;
            expl_8  <= 0; expl_9  <= 0; expl_10 <= 0; expl_11 <= 0;
            sum_3  <= 0; sum_4  <= 0; sum_5  <= 0;
            sum_6  <= 0; sum_7  <= 0; sum_8  <= 0;
            diff_3 <= 0; diff_4 <= 0; diff_5 <= 0;
            diff_6 <= 0; diff_7 <= 0; diff_8 <= 0;
            exp_add_3 <= 0; exp_add_4 <= 0; exp_add_5 <= 0;
            exp_add_6 <= 0; exp_add_7 <= 0; exp_add_8 <= 0;
            exp_sub_3 <= 0; exp_sub_4 <= 0; exp_sub_5 <= 0;
            exp_sub_6 <= 0; exp_sub_7 <= 0; exp_sub_8 <= 0;
        end else if (enable) begin
            rm_10 <= rm_9;   rm_11 <= rm_10; rm_12 <= rm_11;
            rm_13 <= rm_12;  rm_14 <= rm_13; rm_15 <= rm_14;
            fpuf_10 <= fpuf_9;   fpuf_11 <= fpuf_10; fpuf_12 <= fpuf_11;
            fpuf_13 <= fpuf_12;  fpuf_14 <= fpuf_13; fpuf_15 <= fpuf_14;
            sign_10 <= sign_9;   sign_11 <= sign_10; sign_12 <= sign_11;
            sign_13 <= sign_12;  sign_14 <= sign_13; sign_15 <= sign_14;
            in_inf10 <= in_inf9;   in_inf11 <= in_inf10; in_inf12 <= in_inf11;
            in_inf13 <= in_inf12;  in_inf14 <= in_inf13; in_inf15 <= in_inf14;
            expl_8  <= expl_7;  expl_9  <= expl_8;
            expl_10 <= expl_9;  expl_11 <= expl_10;
            sum_3  <= sum_2;  sum_4  <= sum_3;  sum_5  <= sum_4;
            sum_6  <= sum_5;  sum_7  <= sum_6;  sum_8  <= sum_7;
            diff_3 <= diff_2; diff_4 <= diff_3; diff_5 <= diff_4;
            diff_6 <= diff_5; diff_7 <= diff_6; diff_8 <= diff_7;
            exp_add_3 <= exp_add_2; exp_add_4 <= exp_add_3; exp_add_5 <= exp_add_4;
            exp_add_6 <= exp_add_5; exp_add_7 <= exp_add_6; exp_add_8 <= exp_add_7;
            exp_sub_3 <= exp_sub_2; exp_sub_4 <= exp_sub_3; exp_sub_5 <= exp_sub_4;
            exp_sub_6 <= exp_sub_5; exp_sub_7 <= exp_sub_6; exp_sub_8 <= exp_sub_7;
        end
    end

    //=========================================================================
    // Stage 16 : rounding decision
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        reg [55:0] chosen;
        reg [10:0] chosen_exp;
        reg        guard, roundb, sticky, lsb;
        reg        rn_up, rp_up, rm_up;
        if (rst) begin
            rm_16        <= 2'b0;
            fpuf_16      <= 1'b0;
            sign_16      <= 1'b0;
            in_inf16     <= 1'b0;
            sum_9        <= 56'b0;
            diff_9       <= 56'b0;
            exp_add_9    <= 11'b0;
            round_nearest_mode  <= 1'b0;
            round_posinf_mode   <= 1'b0;
            round_neginf_mode   <= 1'b0;
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
            rm_16     <= rm_15;
            fpuf_16   <= fpuf_15;
            sign_16   <= sign_15;
            in_inf16  <= in_inf15;
            sum_9     <= sum_8;
            diff_9    <= diff_8;
            exp_add_9 <= exp_add_8;
            // Determine rounding hint from the SUM path (SUB path uses same logic)
            chosen     = fpu_op_final ? diff_8 : sum_8;
            chosen_exp = fpu_op_final ? exp_sub_8 : exp_add_8;
            guard  = chosen[2];
            roundb = chosen[1];
            sticky = chosen[0];
            lsb    = chosen[3];
            round_nearest_mode <= (rm_15 == 2'b00);
            round_posinf_mode  <= (rm_15 == 2'b10);
            round_neginf_mode  <= (rm_15 == 2'b11);
            rn_up = guard & (roundb | sticky | lsb);
            rp_up = (guard | roundb | sticky) & ~sign_15;
            rm_up = (guard | roundb | sticky) &  sign_15;
            round_nearest_trigger   <= rn_up;
            round_nearest_exception <= guard & ~(roundb | sticky);
            round_nearest_enable    <= (rm_15 == 2'b00) & rn_up;
            round_posinf_trigger    <= rp_up;
            round_posinf_enable     <= (rm_15 == 2'b10) & rp_up;
            round_neginf_trigger    <= rm_up;
            round_neginf_enable     <= (rm_15 == 2'b11) & rm_up;
            round_enable            <= ((rm_15 == 2'b00) & rn_up)
                                       | ((rm_15 == 2'b10) & rp_up)
                                       | ((rm_15 == 2'b11) & rm_up);
            sumround_overflow  <= (sum_8[55:3]  == 53'h1FFFFFFFFFFFFF);
            diffround_overflow <= (diff_8[55:3] == 53'h1FFFFFFFFFFFFF);
        end
    end

    //=========================================================================
    // Stages 17..19 : apply rounding, forward
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        reg [55:0] rounded_sum, rounded_diff;
        reg [10:0] adj_exp_add, adj_exp_sub;
        if (rst) begin
            fpuf_17 <= 0; fpuf_18 <= 0; fpuf_19 <= 0;
            sign_17 <= 0; sign_18 <= 0; sign_19 <= 0;
            in_inf17 <= 0; in_inf18 <= 0; in_inf19 <= 0;
            sum_10 <= 0; sum_11 <= 0;
            diff_10 <= 0; diff_11 <= 0;
        end else if (enable) begin
            rounded_sum  = round_enable ? (sum_9  + 56'h8) : sum_9;
            rounded_diff = round_enable ? (diff_9 + 56'h8) : diff_9;
            fpuf_17 <= fpuf_16; fpuf_18 <= fpuf_17; fpuf_19 <= fpuf_18;
            sign_17 <= sign_16; sign_18 <= sign_17; sign_19 <= sign_18;
            in_inf17 <= in_inf16; in_inf18 <= in_inf17; in_inf19 <= in_inf18;
            sum_10  <= rounded_sum;
            sum_11  <= sum_10;
            diff_10 <= rounded_diff;
            diff_11 <= diff_10;
        end
    end

    //=========================================================================
    // Stages 20..21 : pick add/sub result, pack into IEEE-754 double
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        reg [55:0] mres;
        reg [10:0] eres;
        reg        sres;
        if (rst) begin
            fpuf_20  <= 1'b0;
            fpuf_21  <= 1'b0;
            in_inf20 <= 1'b0;
            in_inf21 <= 1'b0;
            outfp    <= 64'b0;
            out      <= 64'b0;
        end else if (enable) begin
            fpuf_20  <= fpuf_19;
            fpuf_21  <= fpuf_20;
            in_inf20 <= in_inf19;
            in_inf21 <= in_inf20;
            if (fpu_op_final) begin
                mres = diff_11;
                eres = exp_sub_8; // last stage available for sub-exp
            end else begin
                mres = sum_11;
                eres = exp_add_9;
            end
            sres = sign_19;
            if (in_inf20) begin
                // Preserve infinity semantics
                outfp <= {sres, 11'h7FF, 52'b0};
            end else if (mres[55]) begin
                // Overflow bit -> renormalize once more (add case handled earlier)
                outfp <= {sres, eres + 11'd1, mres[54:3]};
            end else begin
                outfp <= {sres, eres, mres[54:3]};
            end
            out <= outfp;
        end
    end

    //=========================================================================
    // Ready generation - fixed-latency counter after first enabled beat
    //=========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count         <= 5'd0;
            count_ready_0 <= 1'b0;
            count_ready   <= 1'b0;
            ready         <= 1'b0;
        end else if (enable) begin
            count_ready_0 <= 1'b1;
            if (count == 5'd21) begin
                count_ready <= 1'b1;
                ready       <= 1'b1;
            end else begin
                count       <= count + 5'd1;
                ready       <= 1'b0;
                count_ready <= 1'b0;
            end
        end
    end

    // 'sign' latch mirrors the final result sign for observability
    always @(posedge clk or posedge rst) begin
        if (rst)          sign <= 1'b0;
        else if (enable)  sign <= sign_19;
    end

endmodule