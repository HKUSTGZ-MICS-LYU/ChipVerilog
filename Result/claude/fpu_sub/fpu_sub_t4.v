module fpu_sub(
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

    // Cycle 0: Extract fields and compare magnitudes
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg expa_gt_expb;
    reg expa_et_expb;
    reg mana_gtet_manb;
    reg a_gtet_b;

    // Cycle 1: Operand ordering and alignment setup
    reg [10:0] exponent_small;
    reg [10:0] exponent_large;
    reg [51:0] mantissa_small;
    reg [51:0] mantissa_large;
    reg small_is_denorm;
    reg large_is_denorm;
    reg large_norm_small_denorm;
    reg small_is_nonzero;
    reg [10:0] exponent_diff;
    reg [54:0] minuend;
    reg [54:0] subtrahend;

    // Cycle 2: Alignment shift
    reg [54:0] subtra_shift;
    reg [54:0] subtra_shift_3;
    reg [54:0] diff;

    // Cycle 3: Leading-zero normalization
    reg [6:0] diff_shift_2;
    reg diffshift_gt_exponent;
    reg diffshift_et_55;
    reg [54:0] diff_1;
    reg [10:0] exponent;

    // Combinational leading-zero priority encoder
    reg [6:0] diff_shift;
    always @(*) begin
        casex (diff)
            55'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd0;
            55'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd1;
            55'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd2;
            55'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd3;
            55'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd4;
            55'b000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd5;
            55'b0000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd6;
            55'b00000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd7;
            55'b000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd8;
            55'b0000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd9;
            55'b00000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd10;
            55'b000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd11;
            55'b0000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd12;
            55'b00000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd13;
            55'b000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd14;
            55'b0000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd15;
            55'b00000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd16;
            55'b000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd17;
            55'b0000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd18;
            55'b00000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd19;
            55'b000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd20;
            55'b0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd21;
            55'b00000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd22;
            55'b000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd23;
            55'b0000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd24;
            55'b00000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd25;
            55'b000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd26;
            55'b0000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd27;
            55'b00000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd28;
            55'b000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd29;
            55'b0000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd30;
            55'b00000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd31;
            55'b000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd32;
            55'b0000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd33;
            55'b00000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxx: diff_shift = 7'd34;
            55'b000000000000000000000000000000000001xxxxxxxxxxxxxxxxxxx: diff_shift = 7'd35;
            55'b0000000000000000000000000000000000001xxxxxxxxxxxxxxxxxx: diff_shift = 7'd36;
            55'b00000000000000000000000000000000000001xxxxxxxxxxxxxxxxx: diff_shift = 7'd37;
            55'b000000000000000000000000000000000000001xxxxxxxxxxxxxxxx: diff_shift = 7'd38;
            55'b0000000000000000000000000000000000000001xxxxxxxxxxxxxxx: diff_shift = 7'd39;
            55'b00000000000000000000000000000000000000001xxxxxxxxxxxxxx: diff_shift = 7'd40;
            55'b000000000000000000000000000000000000000001xxxxxxxxxxxxx: diff_shift = 7'd41;
            55'b0000000000000000000000000000000000000000001xxxxxxxxxxxx: diff_shift = 7'd42;
            55'b00000000000000000000000000000000000000000001xxxxxxxxxxx: diff_shift = 7'd43;
            55'b000000000000000000000000000000000000000000001xxxxxxxxxx: diff_shift = 7'd44;
            55'b0000000000000000000000000000000000000000000001xxxxxxxxx: diff_shift = 7'd45;
            55'b00000000000000000000000000000000000000000000001xxxxxxxx: diff_shift = 7'd46;
            55'b000000000000000000000000000000000000000000000001xxxxxxx: diff_shift = 7'd47;
            55'b0000000000000000000000000000000000000000000000001xxxxxx: diff_shift = 7'd48;
            55'b00000000000000000000000000000000000000000000000001xxxxx: diff_shift = 7'd49;
            55'b000000000000000000000000000000000000000000000000001xxxx: diff_shift = 7'd50;
            55'b0000000000000000000000000000000000000000000000000001xxx: diff_shift = 7'd51;
            55'b00000000000000000000000000000000000000000000000000001xx: diff_shift = 7'd52;
            55'b000000000000000000000000000000000000000000000000000001x: diff_shift = 7'd53;
            55'b0000000000000000000000000000000000000000000000000000001: diff_shift = 7'd54;
            default: diff_shift = 7'd55;
        endcase
    end

    // Main clocked pipeline
    always @(posedge clk) begin
        if (rst) begin
            // Cycle 0 registers
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            expa_gt_expb <= 1'b0;
            expa_et_expb <= 1'b0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b <= 1'b0;

            // Cycle 1 registers
            exponent_small <= 11'b0;
            exponent_large <= 11'b0;
            mantissa_small <= 52'b0;
            mantissa_large <= 52'b0;
            small_is_denorm <= 1'b0;
            large_is_denorm <= 1'b0;
            large_norm_small_denorm <= 1'b0;
            small_is_nonzero <= 1'b0;
            exponent_diff <= 11'b0;
            minuend <= 55'b0;
            subtrahend <= 55'b0;
            sign <= 1'b0;

            // Cycle 2 registers
            subtra_shift <= 55'b0;
            subtra_shift_3 <= 55'b0;
            diff <= 55'b0;

            // Cycle 3 registers
            diff_shift_2 <= 7'b0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
            diff_1 <= 55'b0;
            exponent <= 11'b0;

            // Output registers
            exponent_2 <= 11'b0;
            diff_2 <= 56'b0;
        end
        else if (enable) begin
            // Cycle 0: Extract fields and compare magnitudes
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            expa_gt_expb <= opa[62:52] > opb[62:52];
            expa_et_expb <= opa[62:52] == opb[62:52];
            mana_gtet_manb <= opa[51:0] >= opb[51:0];
            a_gtet_b <= (opa[62:52] > opb[62:52]) | ((opa[62:52] == opb[62:52]) & (opa[51:0] >= opb[51:0]));

            // Cycle 1: Operand ordering and alignment setup
            if (a_gtet_b) begin
                exponent_large <= exponent_a;
                exponent_small <= exponent_b;
                mantissa_large <= mantissa_a;
                mantissa_small <= mantissa_b;
                sign <= opa[63];
            end
            else begin
                exponent_large <= exponent_b;
                exponent_small <= exponent_a;
                mantissa_large <= mantissa_b;
                mantissa_small <= mantissa_a;
                sign <= (!opb[63]) ^ (fpu_op == 3'b000);
            end

            small_is_denorm <= a_gtet_b ? (exponent_b == 11'b0) : (exponent_a == 11'b0);
            large_is_denorm <= a_gtet_b ? (exponent_a == 11'b0) : (exponent_b == 11'b0);

            large_norm_small_denorm <= (a_gtet_b ? (exponent_a != 11'b0) : (exponent_b != 11'b0)) &
                                      (a_gtet_b ? (exponent_b == 11'b0) : (exponent_a == 11'b0));

            small_is_nonzero <= a_gtet_b ? ((exponent_b != 11'b0) | (mantissa_b != 52'b0))
                                         : ((exponent_a != 11'b0) | (mantissa_a != 52'b0));

            exponent_diff <= (a_gtet_b ? exponent_a : exponent_b) - (a_gtet_b ? exponent_b : exponent_a) -
                             ((a_gtet_b ? (exponent_a != 11'b0) : (exponent_b != 11'b0)) & 
                              (a_gtet_b ? (exponent_b == 11'b0) : (exponent_a == 11'b0)) ? 11'd1 : 11'd0);

            minuend <= {!(a_gtet_b ? (exponent_a == 11'b0) : (exponent_b == 11'b0)),
                        a_gtet_b ? mantissa_a : mantissa_b, 2'b00};
            subtrahend <= {!(a_gtet_b ? (exponent_b == 11'b0) : (exponent_a == 11'b0)),
                           a_gtet_b ? mantissa_b : mantissa_a, 2'b00};

            // Cycle 2: Alignment shift and subtraction
            subtra_shift <= subtrahend >> exponent_diff;
            if (small_is_nonzero & ~|(subtrahend >> exponent_diff))
                subtra_shift_3 <= 55'b1;
            else
                subtra_shift_3 <= (subtrahend >> exponent_diff);
            diff <= minuend - ((small_is_nonzero & ~|(subtrahend >> exponent_diff)) ? 55'b1 : (subtrahend >> exponent_diff));

            // Cycle 3: Leading-zero normalization and exponent update
            diff_shift_2 <= diff_shift;
            diffshift_gt_exponent <= diff_shift > exponent_large;
            diffshift_et_55 <= diff_shift == 7'd55;

            if (diff_shift > exponent_large)
                diff_1 <= diff << exponent_large;
            else
                diff_1 <= diff << diff_shift;

            if (diff_shift > exponent_large)
                exponent <= 11'b0;
            else
                exponent <= exponent_large - diff_shift;

            // Cycle 4: Output formatting
            if (diffshift_et_55)
                exponent_2 <= 11'b0;
            else
                exponent_2 <= exponent;

            if ((exponent_large > 11'b0) & (exponent == 11'b0))
                diff_2 <= {1'b0, diff_1 >> 1};
            else
                diff_2 <= {1'b0, diff_1};
        end
    end

endmodule
