module fpu_sub( clk, rst, enable, opa, opb, fpu_op, sign, diff_2, exponent_2);

input clk;
input rst;
input enable;
input [63:0] opa;
input [63:0] opb;
input [2:0] fpu_op;
output reg sign;
output reg [55:0] diff_2;
output reg [10:0] exponent_2;

reg [6:0] diff_shift;
reg [6:0] diff_shift_2;
reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg [51:0] mantissa_a;
reg [51:0] mantissa_b;
reg expa_gt_expb;
reg expa_et_expb;
reg mana_gtet_manb;
reg a_gtet_b;
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
reg [54:0] subtra_shift;
reg [54:0] subtra_shift_3;
reg [54:0] diff;
reg diffshift_gt_exponent;
reg diffshift_et_55;
reg [54:0] diff_1;
reg [10:0] exponent;

wire subtra_shift_nonzero;
wire subtra_fraction_enable;
wire [54:0] subtra_shift_2;
wire in_norm_out_denorm;

integer diff_index;

assign subtra_shift_nonzero = |subtra_shift[54:0];
assign subtra_fraction_enable = small_is_nonzero & !subtra_shift_nonzero;
assign subtra_shift_2 = {54'b0, 1'b1};
assign in_norm_out_denorm = (exponent_large > 11'd0) & (exponent == 11'd0);

always @(diff) begin
    diff_shift = 7'd55;
    for (diff_index = 54; diff_index >= 0; diff_index = diff_index - 1) begin
        if (diff[diff_index] && (diff_shift == 7'd55)) begin
            diff_shift = 54 - diff_index;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        diff_shift_2 <= 7'd0;
        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        mantissa_a <= 52'd0;
        mantissa_b <= 52'd0;
        expa_gt_expb <= 1'b0;
        expa_et_expb <= 1'b0;
        mana_gtet_manb <= 1'b0;
        a_gtet_b <= 1'b0;
        sign <= 1'b0;
        exponent_small <= 11'd0;
        exponent_large <= 11'd0;
        mantissa_small <= 52'd0;
        mantissa_large <= 52'd0;
        small_is_denorm <= 1'b0;
        large_is_denorm <= 1'b0;
        large_norm_small_denorm <= 1'b0;
        small_is_nonzero <= 1'b0;
        exponent_diff <= 11'd0;
        minuend <= 55'd0;
        subtrahend <= 55'd0;
        subtra_shift <= 55'd0;
        subtra_shift_3 <= 55'd0;
        diff <= 55'd0;
        diffshift_gt_exponent <= 1'b0;
        diffshift_et_55 <= 1'b0;
        diff_1 <= 55'd0;
        exponent <= 11'd0;
        diff_2 <= 56'd0;
        exponent_2 <= 11'd0;
    end else if (enable) begin
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        expa_gt_expb <= exponent_a > exponent_b;
        expa_et_expb <= exponent_a == exponent_b;
        mana_gtet_manb <= mantissa_a >= mantissa_b;
        a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);
        sign <= a_gtet_b ? opa[63] : ((!opb[63]) ^ (fpu_op == 3'b000));

        if (a_gtet_b) begin
            exponent_large <= exponent_a;
            exponent_small <= exponent_b;
            mantissa_large <= mantissa_a;
            mantissa_small <= mantissa_b;
        end else begin
            exponent_large <= exponent_b;
            exponent_small <= exponent_a;
            mantissa_large <= mantissa_b;
            mantissa_small <= mantissa_a;
        end

        small_is_denorm <= exponent_small == 11'd0;
        large_is_denorm <= exponent_large == 11'd0;
        large_norm_small_denorm <= (exponent_large != 11'd0) & (exponent_small == 11'd0);
        small_is_nonzero <= (exponent_small > 11'd0) | (|mantissa_small[51:0]);
        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;
        minuend <= {!large_is_denorm, mantissa_large, 2'b00};
        subtrahend <= {!small_is_denorm, mantissa_small, 2'b00};
        subtra_shift <= subtrahend >> exponent_diff;
        subtra_shift_3 <= subtra_fraction_enable ? subtra_shift_2 : subtra_shift;
        diff <= minuend - subtra_shift_3;

        diff_shift_2 <= diff_shift;
        diffshift_gt_exponent <= diff_shift_2 > {3'b000, exponent_large};
        diffshift_et_55 <= diff_shift_2 == 7'd55;
        diff_1 <= diffshift_gt_exponent ? (diff << exponent_large) : (diff << diff_shift_2);
        exponent <= diffshift_gt_exponent ? 11'd0 : (exponent_large - diff_shift_2[10:0]);
        exponent_2 <= diffshift_et_55 ? 11'd0 : exponent;
        diff_2 <= in_norm_out_denorm ? {1'b0, (diff_1 >> 1)} : {1'b0, diff_1};
    end
end

endmodule
