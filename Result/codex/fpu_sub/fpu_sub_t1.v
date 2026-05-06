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
reg a_gtet_b;
reg [10:0] exponent_large;
reg [10:0] exponent_small;
reg [51:0] mantissa_large;
reg [51:0] mantissa_small;
reg small_is_nonzero;
reg [10:0] exponent_diff;
reg [54:0] subtra_shift_3;
reg [54:0] diff;
reg [5:0] diff_shift;
reg [5:0] diff_shift_2;
reg diffshift_gt_exponent;
reg diffshift_et_55;
reg [54:0] diff_1;
reg [10:0] exponent;

wire expa_gt_expb;
wire expa_et_expb;
wire mana_gtet_manb;
wire small_is_denorm;
wire large_is_denorm;
wire large_norm_small_denorm;
wire [54:0] minuend;
wire [54:0] subtrahend;
wire [54:0] subtra_shift;
wire subtra_shift_nonzero;
wire subtra_fraction_enable;
wire [54:0] subtra_shift_2;
wire in_norm_out_denorm;

integer i;

assign expa_gt_expb = (exponent_a > exponent_b);
assign expa_et_expb = (exponent_a == exponent_b);
assign mana_gtet_manb = (mantissa_a >= mantissa_b);

assign small_is_denorm = (exponent_small == 11'd0);
assign large_is_denorm = (exponent_large == 11'd0);
assign large_norm_small_denorm = small_is_denorm & ~large_is_denorm;

assign minuend = {large_is_denorm ? 1'b0 : 1'b1, mantissa_large, 2'b00};
assign subtrahend = {small_is_denorm ? 1'b0 : 1'b1, mantissa_small, 2'b00};
assign subtra_shift = subtrahend >> exponent_diff;
assign subtra_shift_nonzero = |subtra_shift;
assign subtra_fraction_enable = small_is_nonzero & !subtra_shift_nonzero;
assign subtra_shift_2 = {54'b0, 1'b1};

assign in_norm_out_denorm = (exponent_large > 11'd0) & (exponent == 11'd0);

always @(*) begin
    diff_shift = 6'd55;
    for (i = 54; i >= 0; i = i - 1) begin
        if (diff[i] && (diff_shift == 6'd55)) begin
            diff_shift = 6'd54 - i;
        end
    end
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
        a_gtet_b <= 1'b0;
        exponent_large <= 11'd0;
        exponent_small <= 11'd0;
        mantissa_large <= 52'd0;
        mantissa_small <= 52'd0;
        small_is_nonzero <= 1'b0;
        exponent_diff <= 11'd0;
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

        a_gtet_b <= expa_gt_expb | (expa_et_expb & mana_gtet_manb);

        if (a_gtet_b) begin
            sign <= opa[63];
            exponent_large <= opa[62:52];
            mantissa_large <= opa[51:0];
            exponent_small <= opb[62:52];
            mantissa_small <= opb[51:0];
            small_is_nonzero <= |opb[62:0];
        end else begin
            sign <= ((!opb[63]) ^ (fpu_op == 3'b000));
            exponent_large <= opb[62:52];
            mantissa_large <= opb[51:0];
            exponent_small <= opa[62:52];
            mantissa_small <= opa[51:0];
            small_is_nonzero <= |opa[62:0];
        end

        exponent_diff <= exponent_large - exponent_small - large_norm_small_denorm;

        if (subtra_fraction_enable) begin
            subtra_shift_3 <= subtra_shift_2;
        end else begin
            subtra_shift_3 <= subtra_shift;
        end

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
