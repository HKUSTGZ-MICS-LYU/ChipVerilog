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

reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg [51:0] mantissa_a;
reg [51:0] mantissa_b;

reg expa_gt_expb;
reg expa_et_expb;
reg mana_gtet_manb;
reg a_gtet_b;

reg [10:0] exponent_large;
reg [51:0] mantissa_large;
reg [10:0] exponent_small;
reg [51:0] mantissa_small;

reg small_is_denorm;
reg large_is_denorm;
reg large_norm_small_denorm;
reg [10:0] exponent_diff;

reg [54:0] minuend;
reg [54:0] subtrahend;
reg small_is_nonzero;

wire [54:0] subtra_shift;
wire subtra_shift_nonzero;
wire subtra_fraction_enable;
wire [54:0] subtra_shift_2;
reg [54:0] subtra_shift_3;

reg [54:0] diff;
reg [5:0] diff_shift;
reg [5:0] diff_shift_2;

reg diffshift_gt_exponent;
reg diffshift_et_55;
reg [54:0] diff_1;
reg [10:0] exponent;

wire in_norm_out_denorm;

assign subtra_shift = subtrahend >> exponent_diff;
assign subtra_shift_nonzero = |subtra_shift;
assign subtra_fraction_enable = small_is_nonzero & !subtra_shift_nonzero;
assign subtra_shift_2 = {54'b0, 1'b1};
assign in_norm_out_denorm = (exponent_large > 11'd0) & (exponent == 11'd0);

always @(*) begin
    diff_shift = 6'd55;
    casex (1'b1)
        diff[54]: diff_shift = 6'd0;
        diff[53]: diff_shift = 6'd1;
        diff[52]: diff_shift = 6'd2;
        diff[51]: diff_shift = 6'd3;
        diff[50]: diff_shift = 6'd4;
        diff[49]: diff_shift = 6'd5;
        diff[48]: diff_shift = 6'd6;
        diff[47]: diff_shift = 6'd7;
        diff[46]: diff_shift = 6'd8;
        diff[45]: diff_shift = 6'd9;
        diff[44]: diff_shift = 6'd10;
        diff[43]: diff_shift = 6'd11;
        diff[42]: diff_shift = 6'd12;
        diff[41]: diff_shift = 6'd13;
        diff[40]: diff_shift = 6'd14;
        diff[39]: diff_shift = 6'd15;
        diff[38]: diff_shift = 6'd16;
        diff[37]: diff_shift = 6'd17;
        diff[36]: diff_shift = 6'd18;
        diff[35]: diff_shift = 6'd19;
        diff[34]: diff_shift = 6'd20;
        diff[33]: diff_shift = 6'd21;
        diff[32]: diff_shift = 6'd22;
        diff[31]: diff_shift = 6'd23;
        diff[30]: diff_shift = 6'd24;
        diff[29]: diff_shift = 6'd25;
        diff[28]: diff_shift = 6'd26;
        diff[27]: diff_shift = 6'd27;
        diff[26]: diff_shift = 6'd28;
        diff[25]: diff_shift = 6'd29;
        diff[24]: diff_shift = 6'd30;
        diff[23]: diff_shift = 6'd31;
        diff[22]: diff_shift = 6'd32;
        diff[21]: diff_shift = 6'd33;
        diff[20]: diff_shift = 6'd34;
        diff[19]: diff_shift = 6'd35;
        diff[18]: diff_shift = 6'd36;
        diff[17]: diff_shift = 6'd37;
        diff[16]: diff_shift = 6'd38;
        diff[15]: diff_shift = 6'd39;
        diff[14]: diff_shift = 6'd40;
        diff[13]: diff_shift = 6'd41;
        diff[12]: diff_shift = 6'd42;
        diff[11]: diff_shift = 6'd43;
        diff[10]: diff_shift = 6'd44;
        diff[9]:  diff_shift = 6'd45;
        diff[8]:  diff_shift = 6'd46;
        diff[7]:  diff_shift = 6'd47;
        diff[6]:  diff_shift = 6'd48;
        diff[5]:  diff_shift = 6'd49;
        diff[4]:  diff_shift = 6'd50;
        diff[3]:  diff_shift = 6'd51;
        diff[2]:  diff_shift = 6'd52;
        diff[1]:  diff_shift = 6'd53;
        diff[0]:  diff_shift = 6'd54;
        default:  diff_shift = 6'd55;
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        sign <= 1'b0;
        diff_2 <= 56'd0;
        exponent_2 <= 11'd0;

        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        mantissa_a <= 52'd0;
        mantissa_b <= 52'd0;

        expa_gt_expb <= 1'b0;
        expa_et_expb <= 1'b0;
        mana_gtet_manb <= 1'b0;
        a_gtet_b <= 1'b0;

        exponent_large <= 11'd0;
        mantissa_large <= 52'd0;
        exponent_small <= 11'd0;
        mantissa_small <= 52'd0;

        small_is_denorm <= 1'b0;
        large_is_denorm <= 1'b0;
        large_norm_small_denorm <= 1'b0;
        exponent_diff <= 11'd0;

        minuend <= 55'd0;
        subtrahend <= 55'd0;
        small_is_nonzero <= 1'b0;
        subtra_shift_3 <= 55'd0;

        diff <= 55'd0;
        diff_shift_2 <= 6'd0;

        diffshift_gt_exponent <= 1'b0;
        diffshift_et_55 <= 1'b0;
        diff_1 <= 55'd0;
        exponent <= 11'd0;
    end else if (enable) begin
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];

        expa_gt_expb <= (exponent_a > exponent_b);
        expa_et_expb <= (exponent_a == exponent_b);
        mana_gtet_manb <= (mantissa_a >= mantissa_b);
        a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);

        if (a_gtet_b) begin
            sign <= opa[63];
            exponent_large <= exponent_a;
            mantissa_large <= mantissa_a;
            exponent_small <= exponent_b;
            mantissa_small <= mantissa_b;
        end else begin
            sign <= (!opb[63]) ^ (fpu_op == 3'b000);
            exponent_large <= exponent_b;
            mantissa_large <= mantissa_b;
            exponent_small <= exponent_a;
            mantissa_small <= mantissa_a;
        end

        small_is_denorm <= (exponent_small == 11'd0);
        large_is_denorm <= (exponent_large == 11'd0);
        large_norm_small_denorm <= (exponent_small == 11'd0) & (exponent_large != 11'd0);
        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;

        minuend <= {~large_is_denorm, mantissa_large, 2'b00};
        subtrahend <= {~small_is_denorm, mantissa_small, 2'b00};
        small_is_nonzero <= |{exponent_small, mantissa_small};

        subtra_shift_3 <= subtra_fraction_enable ? subtra_shift_2 : subtra_shift;

        diff <= minuend - subtra_shift_3;

        diff_shift_2 <= diff_shift;
        diffshift_gt_exponent <= (diff_shift_2 > exponent_large);
        diffshift_et_55 <= (diff_shift_2 == 6'd55);

        if (diffshift_gt_exponent) begin
            diff_1 <= diff << exponent_large;
            exponent <= 11'd0;
        end else begin
            diff_1 <= diff << diff_shift_2;
            exponent <= exponent_large - diff_shift_2;
        end

        if (diffshift_et_55) begin
            exponent_2 <= 11'd0;
        end else begin
            exponent_2 <= exponent;
        end

        if (in_norm_out_denorm) begin
            diff_2 <= {1'b0, (diff_1 >> 1)};
        end else begin
            diff_2 <= {1'b0, diff_1};
        end
    end
end

endmodule
