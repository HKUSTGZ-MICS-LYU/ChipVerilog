module fpu_mul (
    input         clk,
    input         rst,
    input         enable,
    input  [63:0] opa,
    input  [63:0] opb,
    output reg    sign,
    output [55:0] product_7,
    output reg [11:0] exponent_5
);

    // ------------------------------------------------------------------------
    // Input field pipeline
    // ------------------------------------------------------------------------
    reg [51:0] mantissa_a;
    reg [51:0] mantissa_b;
    reg [10:0] exponent_a;
    reg [10:0] exponent_b;
    reg        a_is_norm;
    reg        b_is_norm;
    reg        a_is_zero;
    reg        b_is_zero;
    reg        in_zero;

    reg [52:0] mul_a;
    reg [52:0] mul_b;

    // ------------------------------------------------------------------------
    // Exponent pipeline
    // ------------------------------------------------------------------------
    reg [11:0] exponent_terms;
    reg        exponent_gt_expoffset;
    reg [11:0] exponent_under;
    reg [11:0] exponent_1;
    wire [11:0] exponent;
    reg [11:0] exponent_2;
    reg        exponent_gt_prodshift;
    reg [11:0] exponent_3;
    reg [11:0] exponent_4;
    reg        exponent_et_zero;

    reg        in_zero_1;
    reg        in_zero_2;
    reg        in_zero_3;
    reg        in_zero_4;
    reg        in_zero_5;

    // ------------------------------------------------------------------------
    // Partial products.  The 53-bit operands are split as:
    //   A = {a2[11:0], a1[16:0], a0[23:0]}
    //   B = {b3[1:0], b2[16:0], b1[16:0], b0[16:0]}
    // B[52:34] is also used as a 19-bit high slice.
    // ------------------------------------------------------------------------
    reg [40:0] product_a;  // 24 x 17 : a0 * b0
    reg [40:0] product_b;  // 24 x 17 : a0 * b1
    reg [40:0] product_c;  // 24 x 17 : a0 * b2
    reg [25:0] product_d;  // 24 x  2 : a0 * b3
    reg [33:0] product_e;  // 17 x 17 : a1 * b0
    reg [33:0] product_f;  // 17 x 17 : a1 * b1
    reg [35:0] product_g;  // 17 x 19 : a1 * B[52:34]
    reg [28:0] product_h;  // 12 x 17 : a2 * b0
    reg [28:0] product_i;  // 12 x 17 : a2 * b1
    reg [30:0] product_j;  // 12 x 19 : a2 * B[52:34]

    // Staged sums used to rebuild the full 106-bit product.
    reg [41:0] sum_0;
    reg [35:0] sum_1;
    reg [41:0] sum_2;
    reg [35:0] sum_3;
    reg [36:0] sum_4;
    reg [27:0] sum_5;
    reg [29:0] sum_6;
    reg [36:0] sum_7;
    reg [30:0] sum_8;

    reg [105:0] product;
    reg [105:0] product_1;
    reg [105:0] product_2;
    reg [105:0] product_3;
    reg [105:0] product_4;
    reg [105:0] product_5;
    reg [105:0] product_6;
    reg         product_lsb;

    reg [5:0] product_shift;
    reg [5:0] product_shift_2;

    // product_7 is intentionally a combinational output bundle, not a register.
    assign product_7 = {1'b0, product_6[105:52], product_lsb};

    // Candidate biased intermediate exponent after subtracting the double bias
    // convention used by this intermediate datapath.
    assign exponent = exponent_gt_expoffset ? (exponent_terms - 12'd1022) : 12'd0;

    // ------------------------------------------------------------------------
    // Leading-zero based product normalization shift.
    // Search is limited to shifts 0..53.  Larger shifts are clamped to 53.
    // ------------------------------------------------------------------------
    always @* begin
        casex (product_1[105:52])
            54'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd0;
            54'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd1;
            54'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd2;
            54'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd3;
            54'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd4;
            54'b000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd5;
            54'b0000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd6;
            54'b00000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd7;
            54'b000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd8;
            54'b0000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd9;
            54'b00000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd10;
            54'b000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd11;
            54'b0000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd12;
            54'b00000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd13;
            54'b000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd14;
            54'b0000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd15;
            54'b00000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd16;
            54'b000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd17;
            54'b0000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd18;
            54'b00000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd19;
            54'b000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd20;
            54'b0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd21;
            54'b00000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd22;
            54'b000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd23;
            54'b0000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd24;
            54'b00000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd25;
            54'b000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd26;
            54'b0000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd27;
            54'b00000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd28;
            54'b000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd29;
            54'b0000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd30;
            54'b00000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd31;
            54'b000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxx: product_shift = 6'd32;
            54'b0000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxx: product_shift = 6'd33;
            54'b00000000000000000000000000000000001xxxxxxxxxxxxxxxxxxx: product_shift = 6'd34;
            54'b000000000000000000000000000000000001xxxxxxxxxxxxxxxxxx: product_shift = 6'd35;
            54'b0000000000000000000000000000000000001xxxxxxxxxxxxxxxxx: product_shift = 6'd36;
            54'b00000000000000000000000000000000000001xxxxxxxxxxxxxxxx: product_shift = 6'd37;
            54'b000000000000000000000000000000000000001xxxxxxxxxxxxxxx: product_shift = 6'd38;
            54'b0000000000000000000000000000000000000001xxxxxxxxxxxxxx: product_shift = 6'd39;
            54'b00000000000000000000000000000000000000001xxxxxxxxxxxxx: product_shift = 6'd40;
            54'b000000000000000000000000000000000000000001xxxxxxxxxxxx: product_shift = 6'd41;
            54'b0000000000000000000000000000000000000000001xxxxxxxxxxx: product_shift = 6'd42;
            54'b00000000000000000000000000000000000000000001xxxxxxxxxx: product_shift = 6'd43;
            54'b000000000000000000000000000000000000000000001xxxxxxxxx: product_shift = 6'd44;
            54'b0000000000000000000000000000000000000000000001xxxxxxxx: product_shift = 6'd45;
            54'b00000000000000000000000000000000000000000000001xxxxxxx: product_shift = 6'd46;
            54'b000000000000000000000000000000000000000000000001xxxxxx: product_shift = 6'd47;
            54'b0000000000000000000000000000000000000000000000001xxxxx: product_shift = 6'd48;
            54'b00000000000000000000000000000000000000000000000001xxxx: product_shift = 6'd49;
            54'b000000000000000000000000000000000000000000000000001xxx: product_shift = 6'd50;
            54'b0000000000000000000000000000000000000000000000000001xx: product_shift = 6'd51;
            54'b00000000000000000000000000000000000000000000000000001x: product_shift = 6'd52;
            54'b000000000000000000000000000000000000000000000000000001: product_shift = 6'd53;
            default:                                                     product_shift = 6'd53;
        endcase
    end

    // ------------------------------------------------------------------------
    // Sequential pipeline
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign                  <= 1'b0;
            mantissa_a            <= 52'd0;
            mantissa_b            <= 52'd0;
            exponent_a            <= 11'd0;
            exponent_b            <= 11'd0;
            a_is_norm             <= 1'b0;
            b_is_norm             <= 1'b0;
            a_is_zero             <= 1'b0;
            b_is_zero             <= 1'b0;
            in_zero               <= 1'b0;
            exponent_terms        <= 12'd0;
            exponent_gt_expoffset <= 1'b0;
            exponent_under        <= 12'd0;
            exponent_1            <= 12'd0;
            exponent_2            <= 12'd0;
            exponent_gt_prodshift <= 1'b0;
            exponent_3            <= 12'd0;
            exponent_4            <= 12'd0;
            exponent_et_zero      <= 1'b0;
            exponent_5            <= 12'd0;
            in_zero_1             <= 1'b0;
            in_zero_2             <= 1'b0;
            in_zero_3             <= 1'b0;
            in_zero_4             <= 1'b0;
            in_zero_5             <= 1'b0;
            mul_a                 <= 53'd0;
            mul_b                 <= 53'd0;
            product_a             <= 41'd0;
            product_b             <= 41'd0;
            product_c             <= 41'd0;
            product_d             <= 26'd0;
            product_e             <= 34'd0;
            product_f             <= 34'd0;
            product_g             <= 36'd0;
            product_h             <= 29'd0;
            product_i             <= 29'd0;
            product_j             <= 31'd0;
            sum_0                 <= 42'd0;
            sum_1                 <= 36'd0;
            sum_2                 <= 42'd0;
            sum_3                 <= 36'd0;
            sum_4                 <= 37'd0;
            sum_5                 <= 28'd0;
            sum_6                 <= 30'd0;
            sum_7                 <= 37'd0;
            sum_8                 <= 31'd0;
            product               <= 106'd0;
            product_1             <= 106'd0;
            product_2             <= 106'd0;
            product_3             <= 106'd0;
            product_4             <= 106'd0;
            product_5             <= 106'd0;
            product_6             <= 106'd0;
            product_lsb           <= 1'b0;
            product_shift_2       <= 6'd0;
        end else if (enable) begin
            // Stage 0: register input fields and form 53-bit significands.
            // The sign is intentionally generated from the current operands here;
            // add an explicit sign delay chain if the consuming stage requires
            // cycle alignment with product_7/exponent_5.
            sign       <= opa[63] ^ opb[63];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            a_is_norm  <= |opa[62:52];
            b_is_norm  <= |opb[62:52];
            a_is_zero  <= (opa[62:0] == 63'd0);
            b_is_zero  <= (opb[62:0] == 63'd0);
            in_zero    <= (opa[62:0] == 63'd0) | (opb[62:0] == 63'd0);
            mul_a      <= {|opa[62:52], opa[51:0]};
            mul_b      <= {|opb[62:52], opb[51:0]};

            exponent_terms        <= {1'b0, opa[62:52]} + {1'b0, opb[62:52]} +
                                     (|opa[62:52] ? 12'd0 : 12'd1) +
                                     (|opb[62:52] ? 12'd0 : 12'd1);
            exponent_gt_expoffset <= ({1'b0, opa[62:52]} + {1'b0, opb[62:52]} +
                                      (|opa[62:52] ? 12'd0 : 12'd1) +
                                      (|opb[62:52] ? 12'd0 : 12'd1)) > 12'd1021;
            exponent_under        <= 12'd1022 - ({1'b0, opa[62:52]} + {1'b0, opb[62:52]} +
                                      (|opa[62:52] ? 12'd0 : 12'd1) +
                                      (|opb[62:52] ? 12'd0 : 12'd1));

            // Stage 1: decomposed 53 x 53 multiply partial products.
            product_a <= mul_a[23:0]  * mul_b[16:0];
            product_b <= mul_a[23:0]  * mul_b[33:17];
            product_c <= mul_a[23:0]  * mul_b[50:34];
            product_d <= mul_a[23:0]  * mul_b[52:51];
            product_e <= mul_a[40:24] * mul_b[16:0];
            product_f <= mul_a[40:24] * mul_b[33:17];
            product_g <= mul_a[40:24] * mul_b[52:34];
            product_h <= mul_a[52:41] * mul_b[16:0];
            product_i <= mul_a[52:41] * mul_b[33:17];
            product_j <= mul_a[52:41] * mul_b[52:34];

            exponent_1 <= exponent;
            in_zero_1  <= in_zero;

            // Stage 2: small local sums.  These are kept as registered staging
            // points; the full-width reconstruction below uses the same partials.
            sum_0 <= {1'b0, product_a};
            sum_1 <= product_e + product_f[33:0];
            sum_2 <= {1'b0, product_b} + {1'b0, product_c};
            sum_3 <= product_g;
            sum_4 <= {8'd0, product_h} + {8'd0, product_i};
            sum_5 <= product_d[25:0] + 28'd0;
            sum_6 <= {1'b0, product_h};
            sum_7 <= {1'b0, product_g};
            sum_8 <= product_j;

            product <= ({65'd0, product_a}) +
                       ({48'd0, product_b, 17'd0}) +
                       ({31'd0, product_c, 34'd0}) +
                       ({29'd0, product_d, 51'd0}) +
                       ({48'd0, product_e, 24'd0}) +
                       ({31'd0, product_f, 41'd0}) +
                       ({12'd0, product_g, 58'd0}) +
                       ({36'd0, product_h, 41'd0}) +
                       ({19'd0, product_i, 58'd0}) +
                       ({product_j, 75'd0});

            exponent_2 <= exponent_1;
            in_zero_2  <= in_zero_1;

            // Stage 3: latch raw product and latch normalization shift.
            product_1       <= product;
            product_shift_2 <= product_shift;
            exponent_3      <= exponent_2;
            in_zero_3       <= in_zero_2;

            // Stage 4: normalize or create a denormalized intermediate product.
            exponent_gt_prodshift <= (exponent_3 > {6'd0, product_shift_2});
            if (exponent_3 > {6'd0, product_shift_2}) begin
                product_2  <= product_1 << product_shift_2;
                exponent_4 <= exponent_3 - {6'd0, product_shift_2};
            end else begin
                product_2  <= product_1 << exponent_3[5:0];
                exponent_4 <= 12'd0;
            end
            in_zero_4 <= in_zero_3;

            // Stage 5: if the adjusted exponent is zero, shift right by one more
            // bit before taking guard/sticky information.
            exponent_et_zero <= (exponent_4 == 12'd0);
            product_3        <= (exponent_4 == 12'd0) ? {1'b0, product_2[105:1]} : product_2;
            in_zero_5        <= in_zero_4;

            // Stages 6..8: final product pipe and sticky generation.
            product_4 <= product_3;
            product_5 <= product_4;
            product_6 <= product_5;

            product_lsb <= |product_5[51:0];

            if (in_zero_5) begin
                exponent_5 <= 12'd0;
            end else begin
                exponent_5 <= exponent_4;
            end
        end
    end

endmodule
