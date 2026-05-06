module fpu_sub (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    input [2:0] fpu_op,
    output reg sign,
    output reg [55:0] diff_2,
    output reg [10:0] exponent_2
);

    // Internal registers
    reg [10:0] exponent_a, exponent_b;
    reg [51:0] mantissa_a, mantissa_b;
    reg expa_gt_expb, expa_et_expb, mana_gtet_manb;
    reg a_gtet_b;
    reg [10:0] exponent_large, exponent_small;
    reg [51:0] mantissa_large, mantissa_small;
    reg small_is_denorm, large_is_denorm, large_norm_small_denorm;
    reg [10:0] exponent_diff;
    reg [54:0] minuend, subtrahend;
    reg [54:0] subtra_shift;
    reg small_is_nonzero;
    reg subtra_fraction_enable_reg;
    reg [54:0] subtra_shift_3;
    reg [54:0] diff;
    reg [5:0] diff_shift;
    reg [5:0] diff_shift_2;
    reg diffshift_gt_exponent;
    reg diffshift_et_55;
    reg [54:0] diff_1;
    reg [10:0] exponent;
    wire subtra_shift_nonzero;
    wire subtra_fraction_enable;
    wire [54:0] subtra_shift_2;
    wire in_norm_out_denorm;

    // Pipeline register updates
    always @(posedge clk) begin
        if (rst) begin
            exponent_a <= 11'd0;
            exponent_b <= 11'd0;
            mantissa_a <= 52'd0;
            mantissa_b <= 52'd0;
            expa_gt_expb <= 1'b0;
            expa_et_expb <= 1'b0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b <= 1'b0;
            exponent_large <= 11'd0;
            exponent_small <= 11'd0;
            mantissa_large <= 52'd0;
            mantissa_small <= 52'd0;
            small_is_denorm <= 1'b0;
            large_is_denorm <= 1'b0;
            large_norm_small_denorm <= 1'b0;
            exponent_diff <= 11'd0;
            minuend <= 55'd0;
            subtrahend <= 55'd0;
            subtra_shift <= 55'd0;
            small_is_nonzero <= 1'b0;
            subtra_fraction_enable_reg <= 1'b0;
            subtra_shift_3 <= 55'd0;
            diff <= 55'd0;
            diff_shift <= 6'd0;
            diff_shift_2 <= 6'd0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
            diff_1 <= 55'd0;
            exponent <= 11'd0;
            sign <= 1'b0;
            diff_2 <= 56'd0;
            exponent_2 <= 11'd0;
        end else if (enable) begin
            // Stage 1: register input fields
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];

            // Stage 2: comparison logic
            expa_gt_expb <= (exponent_a > exponent_b);
            expa_et_expb <= (exponent_a == exponent_b);
            mana_gtet_manb <= (mantissa_a >= mantissa_b);

            // Stage 3: magnitude flag
            a_gtet_b <= expa_gt_expb || (expa_et_expb && mana_gtet_manb);

            // Stage 4: operand selection
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
                sign <= (!opb[63]) ^ (fpu_op == 3'b000);
            end

            // Stage 5: denormal detection and exponent diff
            small_is_denorm <= (exponent_small == 11'd0);
            large_is_denorm <= (exponent_large == 11'd0);
            large_norm_small_denorm <= (exponent_small == 11'd0) && (exponent_large != 11'd0);
            exponent_diff <= exponent_large - exponent_small - ((exponent_small == 11'd0) && (exponent_large != 11'd0));

            // Stage 6: significand construction
            minuend <= {(exponent_large != 11'd0), mantissa_large, 2'b00};
            subtrahend <= {(exponent_small != 11'd0), mantissa_small, 2'b00};
            small_is_nonzero <= (exponent_small != 11'd0) || (mantissa_small != 52'd0);

            // Stage 7: alignment shift
            subtra_shift <= subtrahend >> exponent_diff;

            // Stage 8: force sticky
            subtra_fraction_enable_reg <= subtra_fraction_enable;
            if (subtra_fraction_enable)
                subtra_shift_3 <= subtra_shift_2;
            else
                subtra_shift_3 <= subtra_shift;

            // Stage 9: subtraction
            diff <= minuend - subtra_shift_3;

            // Stage 10: leading zero count
            diff_shift <= diff_shift;

            // Stage 11: register shift amount
            diff_shift_2 <= diff_shift;
            diffshift_et_55 <= (diff_shift == 6'd55);

            // Stage 12: normalization shift and exponent adjustment
            diffshift_gt_exponent <= (diff_shift_2 > exponent_large);
            if (diffshift_gt_exponent) begin
                diff_1 <= diff << exponent_large;
                exponent <= 11'd0;
            end else begin
                diff_1 <= diff << diff_shift_2;
                exponent <= exponent_large - diff_shift_2;
            end

            // Stage 13: output registers
            if (diffshift_et_55)
                exponent_2 <= 11'd0;
            else
                exponent_2 <= exponent;

            if (in_norm_out_denorm)
                diff_2 <= {1'b0, diff_1[54:1], diff_1[0]};
            else
                diff_2 <= {1'b0, diff_1};
        end
    end

    // Combinational helper assignments
    assign subtra_shift_nonzero = |subtra_shift;
    assign subtra_fraction_enable = small_is_nonzero && !subtra_shift_nonzero;
    assign subtra_shift_2 = {54'b0, 1'b1};

    // Combinational leading-zero priority encoder
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
            default: diff_shift = 6'd55;
        endcase
    end

    assign in_norm_out_denorm = (exponent_large > 11'd0) && (exponent == 11'd0);

endmodule
