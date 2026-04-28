`timescale 1ns / 100ps

module fpu_mul (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg        sign,
    output     [55:0] product_7,
    output reg [11:0] exponent_5
);

    //--------------------------------------------------------------------------
    // Stage 0 registers: field extraction
    //--------------------------------------------------------------------------
    reg [51:0] mantissa_a, mantissa_b;
    reg [10:0] exponent_a, exponent_b;
    reg        a_is_norm, b_is_norm;
    reg        a_is_zero, b_is_zero;
    reg        in_zero;

    //--------------------------------------------------------------------------
    // Significand registers
    //--------------------------------------------------------------------------
    reg [52:0] mul_a, mul_b;

    //--------------------------------------------------------------------------
    // Partial product registers
    // Decompose mul_a[52:0] and mul_b[52:0] into slices:
    //   mul_a: [52:29]=24b  [28:12]=17b  [11:0]=12b
    //   mul_b: [52:36]=17b  [35:34]=2b   [33:17]=17b  [16:0] split:
    //          [16:0] → use as 17b or [16:2]=15b + extend to 19b? 
    // Per spec: 24×17, 24×2, 17×17, 17×19, 12×17, 12×19
    //   mul_b slices: [52:36]=17b  [35:34]=2b  [33:17]=17b  [16:0]=17b+pad→19b
    //--------------------------------------------------------------------------
    reg [40:0] product_a;   // mul_a[52:29](24) × mul_b[52:36](17)  = 41b
    reg [25:0] product_d;   // mul_a[52:29](24) × mul_b[35:34](2)   = 26b
    reg [33:0] product_e;   // mul_a[28:12](17) × mul_b[52:36](17)  = 34b
    reg [35:0] product_g;   // mul_a[28:12](17) × mul_b[33:17](17+2pad→19) = 36b
    reg [28:0] product_h;   // mul_a[11:0](12)  × mul_b[52:36](17)  = 29b
    reg [30:0] product_j;   // mul_a[11:0](12)  × mul_b[33:17](17+2pad→19) = 31b

    // Additional cross terms to complete 106b
    reg [40:0] product_b;   // mul_a[52:29](24) × mul_b[33:17](17)  = 41b
    reg [40:0] product_c;   // mul_a[52:29](24) × {2'b0,mul_b[16:0]}(19) = 43b→41b trimmed
    reg [33:0] product_f;   // mul_a[28:12](17) × {2'b0,mul_b[16:0]}(19) = 36b→34b
    reg [28:0] product_i;   // mul_a[11:0](12)  × {2'b0,mul_b[16:0]}(19) = 31b→29b

    //--------------------------------------------------------------------------
    // Intermediate sums
    //--------------------------------------------------------------------------
    reg [41:0] sum_0;
    reg [35:0] sum_1;
    reg [41:0] sum_2;
    reg [35:0] sum_3;
    reg [36:0] sum_4;
    reg [27:0] sum_5;
    reg [29:0] sum_6;
    reg [36:0] sum_7;
    reg [30:0] sum_8;

    //--------------------------------------------------------------------------
    // Product pipeline
    //--------------------------------------------------------------------------
    reg [105:0] product;
    reg [105:0] product_1, product_2, product_3, product_4, product_5, product_6;
    reg         product_lsb;

    //--------------------------------------------------------------------------
    // Exponent pipeline
    //--------------------------------------------------------------------------
    reg [11:0] exponent_terms;
    reg        exponent_gt_expoffset;
    reg [11:0] exponent_under;
    reg [11:0] exponent_1;
    wire[11:0] exponent = 12'd0;   // placeholder wire per spec
    reg [11:0] exponent_2;
    reg        exponent_gt_prodshift;
    reg [11:0] exponent_3, exponent_4;
    reg        exponent_et_zero;

    //--------------------------------------------------------------------------
    // Normalization shift
    //--------------------------------------------------------------------------
    reg [5:0] product_shift;
    reg [5:0] product_shift_2;

    //--------------------------------------------------------------------------
    // Zero flag pipeline (must align with product_6 / exponent_5 output)
    //--------------------------------------------------------------------------
    reg in_zero_1, in_zero_2, in_zero_3, in_zero_4, in_zero_5, in_zero_6;

    //--------------------------------------------------------------------------
    // Output wire
    //--------------------------------------------------------------------------
    assign product_7 = {1'b0, product_6[105:52], product_lsb};

    //==========================================================================
    // Sequential logic
    //==========================================================================
    always @(posedge clk) begin
        if (rst) begin
            // Stage 0
            sign           <= 0;
            mantissa_a     <= 0; mantissa_b     <= 0;
            exponent_a     <= 0; exponent_b     <= 0;
            a_is_norm      <= 0; b_is_norm      <= 0;
            a_is_zero      <= 0; b_is_zero      <= 0;
            in_zero        <= 0;
            // Significands
            mul_a <= 0; mul_b <= 0;
            // Partial products
            product_a<=0; product_b<=0; product_c<=0; product_d<=0;
            product_e<=0; product_f<=0; product_g<=0;
            product_h<=0; product_i<=0; product_j<=0;
            // Sums
            sum_0<=0; sum_1<=0; sum_2<=0; sum_3<=0; sum_4<=0;
            sum_5<=0; sum_6<=0; sum_7<=0; sum_8<=0;
            // Products
            product<=0; product_1<=0; product_2<=0; product_3<=0;
            product_4<=0; product_5<=0; product_6<=0;
            product_lsb <= 0;
            product_shift<=0; product_shift_2<=0;
            // Exponents
            exponent_terms<=0; exponent_gt_expoffset<=0; exponent_under<=0;
            exponent_1<=0; exponent_2<=0; exponent_3<=0; exponent_4<=0;
            exponent_gt_prodshift<=0; exponent_et_zero<=0;
            exponent_5 <= 0;
            // Zero pipeline
            in_zero_1<=0; in_zero_2<=0; in_zero_3<=0;
            in_zero_4<=0; in_zero_5<=0; in_zero_6<=0;
        end else if (enable) begin

            //------------------------------------------------------------------
            // Cycle 0: Extract fields, compute sign
            //------------------------------------------------------------------
            sign       <= opa[63] ^ opb[63];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            a_is_norm  <= (opa[62:52] != 11'd0);
            b_is_norm  <= (opb[62:52] != 11'd0);
            a_is_zero  <= (opa[62:0] == 63'd0);
            b_is_zero  <= (opb[62:0] == 63'd0);
            in_zero    <= (opa[62:0] == 63'd0) | (opb[62:0] == 63'd0);

            //------------------------------------------------------------------
            // Cycle 1: Form significands and compute partial products
            //------------------------------------------------------------------
            mul_a <= {a_is_norm, mantissa_a};
            mul_b <= {b_is_norm, mantissa_b};

            // Exponent terms
            exponent_terms      <= exponent_a + exponent_b
                                   + {11'd0, ~a_is_norm}
                                   + {11'd0, ~b_is_norm};
            exponent_gt_expoffset <= (exponent_a + exponent_b
                                      + {11'd0,~a_is_norm}
                                      + {11'd0,~b_is_norm}) > 12'd1021;
            exponent_under      <= 12'd1022 - (exponent_a + exponent_b
                                               + {11'd0,~a_is_norm}
                                               + {11'd0,~b_is_norm});
            in_zero_1 <= in_zero;

            // Partial products
            // mul_a slices: [52:29]=24b  [28:12]=17b  [11:0]=12b
            // mul_b slices: [52:36]=17b  [35:34]=2b   [33:17]=17b  [16:0]=17b→{2'b0,mul_b[16:0]}=19b
            product_a <= mul_a[52:29] * mul_b[52:36];                    // 24×17=41b
            product_b <= mul_a[52:29] * mul_b[33:17];                    // 24×17=41b
            product_c <= mul_a[52:29] * {2'b0, mul_b[16:0]};            // 24×19→43b, keep[40:0]
            product_d <= mul_a[52:29] * mul_b[35:34];                    // 24×2=26b
            product_e <= mul_a[28:12] * mul_b[52:36];                    // 17×17=34b
            product_f <= mul_a[28:12] * {2'b0, mul_b[16:0]};            // 17×19→36b, keep[33:0]
            product_g <= mul_a[28:12] * {2'b0, mul_b[33:17]};           // 17×19=36b
            product_h <= mul_a[11:0]  * mul_b[52:36];                    // 12×17=29b
            product_i <= mul_a[11:0]  * {2'b0, mul_b[16:0]};            // 12×19→31b, keep[28:0]
            product_j <= mul_a[11:0]  * {2'b0, mul_b[33:17]};           // 12×19→31b

            //------------------------------------------------------------------
            // Cycle 2: First level sums
            //------------------------------------------------------------------
            // Reconstruct 106-bit product by aligning partial products
            // Bit positions (LSB of each partial product):
            //   product_a: mul_a[52:29] * mul_b[52:36] → bits [105:65] (pos 65)
            //   product_b: mul_a[52:29] * mul_b[33:17] → bits [88:48]  (pos 48)  [wait: 29+17=46? recalc]
            //   product_c: mul_a[52:29] * mul_b[16:0]  → bits [69:29]  (pos 29)
            //   product_d: mul_a[52:29] * mul_b[35:34] → bits [87:64]  (pos 63)
            //   product_e: mul_a[28:12] * mul_b[52:36] → bits [81:48]  (pos 48)
            //   product_f: mul_a[28:12] * mul_b[16:0]  → bits [50:17]  (pos 17)
            //   product_g: mul_a[28:12] * mul_b[33:17] → bits [63:29]  (pos 29) [wait 12+17=29]
            //   product_h: mul_a[11:0]  * mul_b[52:36] → bits [64:36]  (pos 36)
            //   product_i: mul_a[11:0]  * mul_b[16:0]  → bits [28:0]   (pos 0)
            //   product_j: mul_a[11:0]  * mul_b[33:17] → bits [46:17]  (pos 17)
            // Assemble into 106b product using shifted additions
            sum_0 <= {1'b0, product_a} + {15'b0, product_d};             // ~[105:64] group
            sum_1 <= {2'b0, product_e} + {1'b0, product_b[33:0]};        // ~[81:48] group
            sum_2 <= {1'b0, product_b[40:34], product_c[33:0]} +
                     {7'b0, product_g[35:0]};                             // mid group
            sum_3 <= {2'b0, product_f} + {6'b0, product_j[29:0]};        // ~[50:17] group
            sum_4 <= {8'b0, product_h};                                   // [64:36]
            sum_5 <= product_i[27:0];                                     // [27:0]

            exponent_1  <= exponent_terms - 12'd1022;
            in_zero_2   <= in_zero_1;
            product_shift_2 <= product_shift;

            //------------------------------------------------------------------
            // Cycle 3: Assemble 106-bit product
            //------------------------------------------------------------------
            product <= ( {64'b0, sum_0[41:0]}                 << 64 ) +
                       ( {74'b0, sum_1[31:0]}                 << 48 ) +
                       ( {64'b0, sum_2[41:0]}                 << 29 ) +
                       ( {72'b0, sum_3[33:0]}                 << 17 ) +
                       ( {70'b0, sum_4[35:0]}                 << 36 ) +
                       ( {78'b0, sum_5[27:0]}                        ) ;

            exponent_2  <= exponent_1;
            in_zero_3   <= in_zero_2;

            //------------------------------------------------------------------
            // Cycle 4: Pipeline product
            //------------------------------------------------------------------
            product_1 <= product;
            exponent_3 <= exponent_2;
            in_zero_4  <= in_zero_3;

            //------------------------------------------------------------------
            // Cycle 5: Compute product_shift (leading-zero normalization)
            //------------------------------------------------------------------
            product_2 <= product_1;
            exponent_4 <= exponent_3;
            in_zero_5  <= in_zero_4;

            // Leading-zero based normalization shift (search up to 53)
            casex (product_1[105:52])
                54'b1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd0;
                54'b01xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd1;
                54'b001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd2;
                54'b0001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd3;
                54'b00001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd4;
                54'b000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd5;
                54'b0000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd6;
                54'b00000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd7;
                54'b000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd8;
                54'b0000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd9;
                54'b00000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd10;
                54'b000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd11;
                54'b0000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd12;
                54'b00000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd13;
                54'b000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd14;
                54'b0000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd15;
                54'b00000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd16;
                54'b000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd17;
                54'b0000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd18;
                54'b00000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd19;
                54'b000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd20;
                54'b0000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd21;
                54'b00000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd22;
                54'b000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd23;
                54'b0000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd24;
                54'b00000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd25;
                54'b000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd26;
                54'b0000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd27;
                54'b00000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd28;
                54'b000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd29;
                54'b0000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd30;
                54'b00000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd31;
                54'b000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd32;
                54'b0000000000000000000000000000000001xxxxxxxxxxxxxxxxxxxx: product_shift <= 6'd33;
                54'b00000000000000000000000000000000001xxxxxxxxxxxxxxxxxxx: product_shift <= 6'd34;
                54'b000000000000000000000000000000000001xxxxxxxxxxxxxxxxxx: product_shift <= 6'd35;
                54'b0000000000000000000000000000000000001xxxxxxxxxxxxxxxxx: product_shift <= 6'd36;
                54'b00000000000000000000000000000000000001xxxxxxxxxxxxxxxx: product_shift <= 6'd37;
                54'b000000000000000000000000000000000000001xxxxxxxxxxxxxxx: product_shift <= 6'd38;
                54'b0000000000000000000000000000000000000001xxxxxxxxxxxxxx: product_shift <= 6'd39;
                54'b00000000000000000000000000000000000000001xxxxxxxxxxxxx: product_shift <= 6'd40;
                54'b000000000000000000000000000000000000000001xxxxxxxxxxxx: product_shift <= 6'd41;
                54'b0000000000000000000000000000000000000000001xxxxxxxxxxx: product_shift <= 6'd42;
                54'b00000000000000000000000000000000000000000001xxxxxxxxxx: product_shift <= 6'd43;
                54'b000000000000000000000000000000000000000000001xxxxxxxxx: product_shift <= 6'd44;
                54'b0000000000000000000000000000000000000000000001xxxxxxxx: product_shift <= 6'd45;
                54'b00000000000000000000000000000000000000000000001xxxxxxx: product_shift <= 6'd46;
                54'b000000000000000000000000000000000000000000000001xxxxxx: product_shift <= 6'd47;
                54'b0000000000000000000000000000000000000000000000001xxxxx: product_shift <= 6'd48;
                54'b00000000000000000000000000000000000000000000000001xxxx: product_shift <= 6'd49;
                54'b000000000000000000000000000000000000000000000000001xxx: product_shift <= 6'd50;
                54'b0000000000000000000000000000000000000000000000000001xx: product_shift <= 6'd51;
                54'b00000000000000000000000000000000000000000000000000001x: product_shift <= 6'd52;
                54'b000000000000000000000000000000000000000000000000000001: product_shift <= 6'd53;
                default:                                                    product_shift <= 6'd53;
            endcase

            //------------------------------------------------------------------
            // Cycle 6: Normalization shift and exponent adjustment
            //------------------------------------------------------------------
            product_3 <= product_2;
            exponent_gt_prodshift <= (exponent_4 >= {6'b0, product_shift});
            exponent_et_zero      <= (exponent_4 == 12'd0);
            in_zero_6  <= in_zero_5;

            //------------------------------------------------------------------
            // Cycle 7: Apply normalization
            //------------------------------------------------------------------
            begin
                reg [105:0] prod_shifted;
                reg [11:0]  exp_adjusted;

                if (exponent_gt_prodshift) begin
                    // Exponent large enough: left-shift product, reduce exponent
                    prod_shifted = product_3 << product_shift_2;
                    exp_adjusted = exponent_4 - {6'b0, product_shift_2};
                end else begin
                    // Exponent too small: shift by remaining exponent (denorm)
                    prod_shifted = product_3 << exponent_4;
                    exp_adjusted = 12'd0;
                end

                // If adjusted exponent is zero, shift right by 1 more
                if (exp_adjusted == 12'd0)
                    product_4 <= prod_shifted >> 1;
                else
                    product_4 <= prod_shifted;

                exponent_5 <= in_zero_6 ? 12'd0 : exp_adjusted;
            end

            //------------------------------------------------------------------
            // Cycle 8-9: Pipeline to align with output
            //------------------------------------------------------------------
            product_5   <= product_4;
            product_6   <= product_5;
            product_lsb <= |product_5[51:0];   // sticky: OR of discarded low bits

        end // enable
    end // always

endmodule