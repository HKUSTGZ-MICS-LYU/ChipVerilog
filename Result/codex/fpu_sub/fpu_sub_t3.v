module fpu_sub (
    input              clk,
    input              rst,
    input              enable,
    input      [63:0]  opa,
    input      [63:0]  opb,
    input      [2:0]   fpu_op,
    output reg         sign,
    output reg [55:0]  diff_2,
    output reg [10:0]  exponent_2
);

    /*
     * Front-end registered fields
     */
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;

    /*
     * Magnitude comparison pipeline
     */
    reg expa_gt_expb;
    reg expa_et_expb;
    reg mana_gtet_manb;
    reg a_gtet_b;

    /*
     * Selected large / small operand fields
     */
    reg [10:0] exponent_large;
    reg [10:0] exponent_small;
    reg [51:0] mantissa_large;
    reg [51:0] mantissa_small;

    /*
     * Denormal and exponent-difference pipeline
     */
    reg small_is_denorm;
    reg large_is_denorm;
    reg large_norm_small_denorm;
    reg [10:0] exponent_diff;

    /*
     * Extended subtraction datapath
     *
     * [54]    : hidden/integer bit
     * [53:2]  : 52-bit fraction field
     * [1:0]   : low-order extension bits
     */
    reg [54:0] minuend;
    reg [54:0] subtrahend;
    reg [54:0] subtra_shift_3;
    reg [54:0] diff;
    reg [54:0] diff_1;

    /*
     * Normalization pipeline
     */
    reg [5:0]  diff_shift_2;
    reg        diffshift_gt_exponent;
    reg        diffshift_et_55;
    reg [10:0] exponent;

    /*
     * Combinational helper signals
     */
    wire [54:0] subtra_shift;
    wire        subtra_shift_nonzero;
    wire        subtra_fraction_enable;
    wire [54:0] subtra_shift_2;
    wire        small_is_nonzero;
    wire        in_norm_out_denorm;

    /*
     * Combinational leading-zero count from registered diff
     */
    reg [5:0] diff_shift;

    assign subtra_shift         = subtrahend >> exponent_diff;
    assign subtra_shift_nonzero = |subtra_shift;
    assign small_is_nonzero     = |{exponent_small, mantissa_small};

    assign subtra_fraction_enable =
        small_is_nonzero & ~subtra_shift_nonzero;

    assign subtra_shift_2 = {54'b0, 1'b1};

    assign in_norm_out_denorm =
        (exponent_large > 11'd0) & (exponent == 11'd0);

    /*
     * Leading-zero priority encoder.
     *
     * diff_shift = 0  when diff[54] is 1
     * diff_shift = 1  when diff[53] is the leading 1
     * ...
     * diff_shift = 54 when diff[0] is the only 1
     * diff_shift = 55 when diff is zero
     */
    integer i;
    always @(*) begin
        diff_shift = 6'd55;

        for (i = 54; i >= 0; i = i - 1) begin
            if (diff[i] && (diff_shift == 6'd55)) begin
                diff_shift = 6'd54 - i[5:0];
            end
        end
    end

    /*
     * Main pipelined datapath.
     *
     * Synchronous active-high reset.
     * All datapath state advances only when enable is asserted.
     */
    always @(posedge clk) begin
        if (rst) begin
            exponent_a               <= 11'd0;
            exponent_b               <= 11'd0;
            mantissa_a               <= 52'd0;
            mantissa_b               <= 52'd0;

            expa_gt_expb             <= 1'b0;
            expa_et_expb             <= 1'b0;
            mana_gtet_manb           <= 1'b0;
            a_gtet_b                 <= 1'b0;

            exponent_large           <= 11'd0;
            exponent_small           <= 11'd0;
            mantissa_large           <= 52'd0;
            mantissa_small           <= 52'd0;

            small_is_denorm          <= 1'b0;
            large_is_denorm          <= 1'b0;
            large_norm_small_denorm  <= 1'b0;
            exponent_diff            <= 11'd0;

            minuend                  <= 55'd0;
            subtrahend               <= 55'd0;
            subtra_shift_3           <= 55'd0;

            diff                     <= 55'd0;
            diff_1                   <= 55'd0;

            diff_shift_2             <= 6'd0;
            diffshift_gt_exponent    <= 1'b0;
            diffshift_et_55          <= 1'b0;

            exponent                 <= 11'd0;
            exponent_2               <= 11'd0;

            sign                     <= 1'b0;
            diff_2                   <= 56'd0;
        end else if (enable) begin
            /*
             * Stage 0: register raw IEEE-754 fields
             */
            exponent_a     <= opa[62:52];
            exponent_b     <= opb[62:52];
            mantissa_a     <= opa[51:0];
            mantissa_b     <= opb[51:0];

            /*
             * Stage 1: compare registered exponent/fraction fields
             */
            expa_gt_expb   <= exponent_a > exponent_b;
            expa_et_expb   <= exponent_a == exponent_b;
            mana_gtet_manb <= mantissa_a >= mantissa_b;

            /*
             * Stage 2: register magnitude relation
             */
            a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);

            /*
             * Stage 3: select larger and smaller magnitude operands.
             *
             * This intentionally uses the registered a_gtet_b flag,
             * not a recomparison of current opa/opb.
             */
            if (a_gtet_b) begin
                exponent_large <= exponent_a;
                mantissa_large <= mantissa_a;
                exponent_small <= exponent_b;
                mantissa_small <= mantissa_b;

                sign <= opa[63];
            end else begin
                exponent_large <= exponent_b;
                mantissa_large <= mantissa_b;
                exponent_small <= exponent_a;
                mantissa_small <= mantissa_a;

                sign <= (~opb[63]) ^ (fpu_op == 3'b000);
            end

            /*
             * Stage 4: denormal detection and effective exponent difference
             */
            small_is_denorm         <= exponent_small == 11'd0;
            large_is_denorm         <= exponent_large == 11'd0;
            large_norm_small_denorm <= (exponent_small == 11'd0) &
                                       (exponent_large != 11'd0);

            exponent_diff <= exponent_large
                           - exponent_small
                           - large_norm_small_denorm;

            /*
             * Stage 5: build 55-bit extended significands.
             *
             * Normalized operand:   {1'b1, fraction, 2'b00}
             * Denormalized operand: {1'b0, fraction, 2'b00}
             */
            minuend <= {
                ~large_is_denorm,
                mantissa_large,
                2'b00
            };

            subtrahend <= {
                ~small_is_denorm,
                mantissa_small,
                2'b00
            };

            /*
             * Stage 6: preserve minimal sticky information when the aligned
             * smaller operand is shifted completely to zero.
             */
            if (subtra_fraction_enable) begin
                subtra_shift_3 <= subtra_shift_2;
            end else begin
                subtra_shift_3 <= subtra_shift;
            end

            /*
             * Stage 7: subtract smaller magnitude from larger magnitude
             */
            diff <= minuend - subtra_shift_3;

            /*
             * Stage 8: register leading-zero count
             */
            diff_shift_2 <= diff_shift;

            /*
             * Stage 9: determine normalization shift behavior
             */
            diffshift_gt_exponent <= diff_shift_2 > exponent_large;
            diffshift_et_55       <= diff_shift_2 == 6'd55;

            /*
             * Stage 10: normalize.
             *
             * Because these are nonblocking assignments, this logic uses the
             * previously registered diffshift_gt_exponent value.
             */
            if (diffshift_gt_exponent) begin
                diff_1   <= diff << exponent_large;
                exponent <= 11'd0;
            end else begin
                diff_1   <= diff << diff_shift_2;
                exponent <= exponent_large - diff_shift_2;
            end

            /*
             * Stage 11: output exponent.
             *
             * Exact cancellation forces exponent_2 to zero.
             */
            if (diffshift_et_55) begin
                exponent_2 <= 11'd0;
            end else begin
                exponent_2 <= exponent;
            end

            /*
             * Stage 12: output extended mantissa bundle.
             *
             * bit [55] is reserved zero.
             */
            if (in_norm_out_denorm) begin
                diff_2 <= {1'b0, 1'b0, diff_1[54:1]};
            end else begin
                diff_2 <= {1'b0, diff_1};
            end
        end
    end

endmodule