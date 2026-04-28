`timescale 1ns / 100ps

module fpu_sub (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input [2:0]  fpu_op,
    output reg        sign,
    output reg [55:0] diff_2,
    output reg [10:0] exponent_2
);

    //--------------------------------------------------------------------------
    // Stage 0: Extract fields
    //--------------------------------------------------------------------------
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;

    //--------------------------------------------------------------------------
    // Stage 1: Comparisons (use previous exponent_a/b, mantissa_a/b)
    //--------------------------------------------------------------------------
    reg expa_gt_expb;
    reg expa_et_expb;
    reg mana_gtet_manb;

    //--------------------------------------------------------------------------
    // Stage 2: Magnitude flag (use previous comparison regs)
    //--------------------------------------------------------------------------
    reg a_gtet_b;

    //--------------------------------------------------------------------------
    // Stage 3: Large/small operand selection + sign
    //--------------------------------------------------------------------------
    reg [10:0] exponent_large, exponent_small;
    reg [51:0] mantissa_large, mantissa_small;
    reg        large_is_denorm, small_is_denorm;
    reg        large_norm_small_denorm;

    //--------------------------------------------------------------------------
    // Stage 4: Exponent diff + extended significands
    //--------------------------------------------------------------------------
    reg [10:0] exponent_diff;
    reg [54:0] minuend;       // 55-bit: hidden + 52b frac + 2 guard
    reg [54:0] subtra;        // subtrahend before shift
    reg        small_is_nonzero;
    reg [10:0] exponent_large_r;

    //--------------------------------------------------------------------------
    // Stage 5: Aligned subtrahend + sticky
    //--------------------------------------------------------------------------
    reg [54:0] subtra_shift;

    // Combinational helpers
    wire       subtra_shift_nonzero = |subtra_shift;
    wire       subtra_fraction_enable = small_is_nonzero & ~subtra_shift_nonzero;
    wire [54:0] subtra_shift_2 = {54'b0, 1'b1};

    reg [54:0] subtra_shift_3;
    reg [54:0] minuend_r;
    reg [10:0] exponent_large_r2;

    //--------------------------------------------------------------------------
    // Stage 6: Subtraction
    //--------------------------------------------------------------------------
    reg [54:0] diff;
    reg [10:0] exponent_large_r3;

    //--------------------------------------------------------------------------
    // Combinational leading-zero encoder on diff
    //--------------------------------------------------------------------------
    reg [5:0] diff_shift;

    always @(*) begin
        casex (diff)
            55'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd0;
            55'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd1;
            55'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd2;
            55'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd3;
            55'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd4;
            55'b000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd5;
            55'b0000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd6;
            55'b00000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd7;
            55'b000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd8;
            55'b0000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd9;
            55'b00000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd10;
            55'b000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd11;
            55'b0000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd12;
            55'b00000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd13;
            55'b000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd14;
            55'b0000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd15;
            55'b00000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd16;
            55'b000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd17;
            55'b0000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd18;
            55'b00000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd19;
            55'b000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd20;
            55'b0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd21;
            55'b00000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd22;
            55'b000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd23;
            55'b0000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd24;
            55'b00000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd25;
            55'b000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd26;
            55'b0000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd27;
            55'b00000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd28;
            55'b000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd29;
            55'b0000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd30;
            55'b00000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd31;
            55'b000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd32;
            55'b0000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd33;
            55'b00000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxx: diff_shift = 6'd34;
            55'b000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxx: diff_shift = 6'd35;
            55'b0000000000000000000000000000000000001xxxxxxxxxxxxxxxxxx: diff_shift = 6'd36;
            55'b00000000000000000000000000000000000001xxxxxxxxxxxxxxxxx: diff_shift = 6'd37;
            55'b000000000000000000000000000000000000001xxxxxxxxxxxxxxxx: diff_shift = 6'd38;
            55'b0000000000000000000000000000000000000001xxxxxxxxxxxxxxx: diff_shift = 6'd39;
            55'b00000000000000000000000000000000000000001xxxxxxxxxxxxxx: diff_shift = 6'd40;
            55'b000000000000000000000000000000000000000001xxxxxxxxxxxxx: diff_shift = 6'd41;
            55'b0000000000000000000000000000000000000000001xxxxxxxxxxxx: diff_shift = 6'd42;
            55'b00000000000000000000000000000000000000000001xxxxxxxxxxx: diff_shift = 6'd43;
            55'b000000000000000000000000000000000000000000001xxxxxxxxxx: diff_shift = 6'd44;
            55'b0000000000000000000000000000000000000000000001xxxxxxxxx: diff_shift = 6'd45;
            55'b00000000000000000000000000000000000000000000001xxxxxxxx: diff_shift = 6'd46;
            55'b000000000000000000000000000000000000000000000001xxxxxxx: diff_shift = 6'd47;
            55'b0000000000000000000000000000000000000000000000001xxxxxx: diff_shift = 6'd48;
            55'b00000000000000000000000000000000000000000000000001xxxxx: diff_shift = 6'd49;
            55'b000000000000000000000000000000000000000000000000001xxxx: diff_shift = 6'd50;
            55'b0000000000000000000000000000000000000000000000000001xxx: diff_shift = 6'd51;
            55'b00000000000000000000000000000000000000000000000000001xx: diff_shift = 6'd52;
            55'b000000000000000000000000000000000000000000000000000001x: diff_shift = 6'd53;
            55'b0000000000000000000000000000000000000000000000000000001: diff_shift = 6'd54;
            default:                                                     diff_shift = 6'd55; // zero
        endcase
    end

    //--------------------------------------------------------------------------
    // Stage 7: Normalisation control registers
    //--------------------------------------------------------------------------
    reg [5:0]  diff_shift_2;
    reg        diffshift_gt_exponent;
    reg        diffshift_et_55;
    reg [54:0] diff_r;
    reg [10:0] exponent_large_r4;

    //--------------------------------------------------------------------------
    // Stage 8: Normalised diff_1 + exponent
    //--------------------------------------------------------------------------
    reg [54:0] diff_1;
    reg [10:0] exponent;

    // Combinational: denorm boundary correction
    wire in_norm_out_denorm = (exponent_large_r4 > 11'd0) & (exponent == 11'd0);

    //--------------------------------------------------------------------------
    // Sequential pipeline
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Stage 0
            exponent_a <= 0; exponent_b <= 0;
            mantissa_a <= 0; mantissa_b <= 0;
            // Stage 1
            expa_gt_expb <= 0; expa_et_expb <= 0; mana_gtet_manb <= 0;
            // Stage 2
            a_gtet_b <= 0;
            // Stage 3
            sign <= 0;
            exponent_large <= 0; exponent_small <= 0;
            mantissa_large <= 0; mantissa_small <= 0;
            large_is_denorm <= 0; small_is_denorm <= 0;
            large_norm_small_denorm <= 0;
            // Stage 4
            exponent_diff <= 0;
            minuend <= 0; subtra <= 0;
            small_is_nonzero <= 0;
            exponent_large_r <= 0;
            // Stage 5
            subtra_shift <= 0;
            subtra_shift_3 <= 0;
            minuend_r <= 0;
            exponent_large_r2 <= 0;
            // Stage 6
            diff <= 0;
            exponent_large_r3 <= 0;
            // Stage 7
            diff_shift_2 <= 0;
            diffshift_gt_exponent <= 0;
            diffshift_et_55 <= 0;
            diff_r <= 0;
            exponent_large_r4 <= 0;
            // Stage 8
            diff_1 <= 0; exponent <= 0;
            // Outputs
            diff_2 <= 0; exponent_2 <= 0;
        end else if (enable) begin

            //------------------------------------------------------------------
            // Cycle 0: Register input fields
            //------------------------------------------------------------------
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];

            //------------------------------------------------------------------
            // Cycle 1: Comparisons from registered fields
            //------------------------------------------------------------------
            expa_gt_expb   <= (exponent_a > exponent_b);
            expa_et_expb   <= (exponent_a == exponent_b);
            mana_gtet_manb <= (mantissa_a >= mantissa_b);

            //------------------------------------------------------------------
            // Cycle 2: Magnitude flag
            //------------------------------------------------------------------
            // a >= b if expa > expb, or equal exponents and mana >= manb
            a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);

            //------------------------------------------------------------------
            // Cycle 3: Select large/small operands, compute sign
            //------------------------------------------------------------------
            if (a_gtet_b) begin
                // A is larger
                exponent_large <= exponent_a;
                exponent_small <= exponent_b;
                mantissa_large <= mantissa_a;
                mantissa_small <= mantissa_b;
                sign           <= opa[63];
            end else begin
                // B is larger
                exponent_large <= exponent_b;
                exponent_small <= exponent_a;
                mantissa_large <= mantissa_b;
                mantissa_small <= mantissa_a;
                sign           <= (~opb[63]) ^ (fpu_op == 3'b000);
            end

            large_is_denorm         <= (a_gtet_b ? exponent_a : exponent_b) == 11'd0;
            small_is_denorm         <= (a_gtet_b ? exponent_b : exponent_a) == 11'd0;
            large_norm_small_denorm <= ((a_gtet_b ? exponent_a : exponent_b) != 11'd0) &
                                       ((a_gtet_b ? exponent_b : exponent_a) == 11'd0);

            //------------------------------------------------------------------
            // Cycle 4: Exponent diff and extended significands
            //------------------------------------------------------------------
            exponent_diff    <= exponent_large - exponent_small - {10'd0, large_norm_small_denorm};
            // Hidden bit: 1 for normalized, 0 for denorm; append 2 guard zeros
            minuend          <= large_is_denorm ? {1'b0, mantissa_large, 2'b00}
                                                : {1'b1, mantissa_large, 2'b00};
            subtra           <= small_is_denorm ? {1'b0, mantissa_small, 2'b00}
                                                : {1'b1, mantissa_small, 2'b00};
            small_is_nonzero <= (mantissa_small != 52'd0) | ~small_is_denorm;
            exponent_large_r <= exponent_large;

            //------------------------------------------------------------------
            // Cycle 5: Align subtrahend + sticky preservation
            //------------------------------------------------------------------
            subtra_shift <= (exponent_diff > 11'd54) ? 55'd0
                                                     : (subtra >> exponent_diff);
            minuend_r        <= minuend;
            exponent_large_r2 <= exponent_large_r;

            // Sticky: if small was nonzero but shifted entirely to zero, force LSB=1
            subtra_shift_3 <= subtra_fraction_enable ? subtra_shift_2 : subtra_shift;

            //------------------------------------------------------------------
            // Cycle 6: Subtract
            //------------------------------------------------------------------
            diff             <= minuend_r - subtra_shift_3;
            exponent_large_r3 <= exponent_large_r2;

            //------------------------------------------------------------------
            // Cycle 7: Register LZC and normalisation control
            //------------------------------------------------------------------
            diff_shift_2          <= diff_shift;
            diffshift_gt_exponent <= ({5'b0, diff_shift} > {0, exponent_large_r3});
            diffshift_et_55       <= (diff_shift == 6'd55);
            diff_r                <= diff;
            exponent_large_r4     <= exponent_large_r3;

            //------------------------------------------------------------------
            // Cycle 8: Normalise diff → diff_1, compute exponent
            //------------------------------------------------------------------
            if (diffshift_gt_exponent) begin
                // Shift limited to available exponent; clamp exp to zero
                diff_1   <= diff_r << exponent_large_r4;
                exponent <= 11'd0;
            end else begin
                diff_1   <= diff_r << diff_shift_2;
                exponent <= exponent_large_r4 - {5'b0, diff_shift_2};
            end

            //------------------------------------------------------------------
            // Cycle 9: Output diff_2 and exponent_2
            //------------------------------------------------------------------
            // in_norm_out_denorm: combinational from current exponent_large_r4 / exponent
            exponent_2 <= diffshift_et_55 ? 11'd0 : exponent;

            // Prepend reserved zero; apply denorm boundary right-shift if needed
            if (in_norm_out_denorm)
                diff_2 <= {1'b0, diff_1 >> 1};
            else
                diff_2 <= {1'b0, diff_1};

        end // enable
    end // always

endmodule