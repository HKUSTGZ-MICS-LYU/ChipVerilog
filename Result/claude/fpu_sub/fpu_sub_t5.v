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
    reg in_norm_out_denorm;

    wire subtra_shift_nonzero;
    wire subtra_fraction_enable;
    wire [54:0] subtra_shift_2;

    assign subtra_shift_nonzero = |subtra_shift[54:0];
    assign subtra_fraction_enable = small_is_nonzero & !subtra_shift_nonzero;
    assign subtra_shift_2 = { 54'b0, 1'b1 };

    always @(posedge clk) begin
        if (rst) begin
            exponent_a <= 11'b0;
            exponent_b <= 11'b0;
            mantissa_a <= 52'b0;
            mantissa_b <= 52'b0;
            expa_gt_expb <= 1'b0;
            expa_et_expb <= 1'b0;
            mana_gtet_manb <= 1'b0;
            a_gtet_b <= 1'b0;
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
            subtra_shift <= 55'b0;
            subtra_shift_3 <= 55'b0;
            diff <= 55'b0;
            diffshift_gt_exponent <= 1'b0;
            diffshift_et_55 <= 1'b0;
            diff_1 <= 55'b0;
            exponent <= 11'b0;
            in_norm_out_denorm <= 1'b0;
            sign <= 1'b0;
            diff_2 <= 56'b0;
            exponent_2 <= 11'b0;
            diff_shift <= 7'b0;
            diff_shift_2 <= 7'b0;
        end
        else if (enable) begin
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];
            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            
            expa_gt_expb <= (opa[62:52] > opb[62:52]);
            expa_et_expb <= (opa[62:52] == opb[62:52]);
            mana_gtet_manb <= (opa[51:0] >= opb[51:0]);
            
            a_gtet_b <= (opa[62:52] > opb[62:52]) | ((opa[62:52] == opb[62:52]) & (opa[51:0] >= opb[51:0]));
            
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
            
            small_is_denorm <= (exponent_small == 11'b0);
            large_is_denorm <= (exponent_large == 11'b0);
            large_norm_small_denorm <= ((exponent_large != 11'b0) & (exponent_small == 11'b0));
            small_is_nonzero <= (exponent_small > 0) | |mantissa_small[51:0];
            
            exponent_diff <= exponent_large - exponent_small - {10'b0, large_norm_small_denorm};
            
            minuend <= {!large_is_denorm, mantissa_large, 2'b00};
            subtrahend <= {!small_is_denorm, mantissa_small, 2'b00};
            
            if (exponent_diff < 11'd55) begin
                subtra_shift <= subtrahend >> exponent_diff;
            end else begin
                subtra_shift <= 55'b0;
            end
            
            subtra_shift_3 <= subtra_fraction_enable ? subtra_shift_2 : subtra_shift;
            
            diff <= minuend - subtra_shift_3;
            
            if (diff == 55'b0) begin
                diff_shift <= 7'd55;
            end
            else if (diff[54]) begin
                diff_shift <= 7'd0;
            end
            else if (diff[53]) begin
                diff_shift <= 7'd1;
            end
            else begin
                diff_shift <= 7'd2;
            end
            
            diff_shift_2 <= diff_shift;
            
            diffshift_gt_exponent <= (diff_shift_2 > exponent_large);
            diffshift_et_55 <= (diff_shift_2 == 7'd55);
            
            if (diffshift_gt_exponent) begin
                diff_1 <= diff << exponent_large;
                exponent <= 11'b0;
            end else begin
                diff_1 <= diff << diff_shift_2;
                exponent <= exponent_large - diff_shift_2;
            end
            
            in_norm_out_denorm <= (exponent_large > 0) & (exponent == 11'b0);
            
            if (diffshift_et_55) begin
                exponent_2 <= 11'b0;
            end else begin
                exponent_2 <= exponent;
            end
            
            if (in_norm_out_denorm) begin
                diff_2 <= {1'b0, (diff_1 >> 1)};
            end else begin
                diff_2 <= {1'b0, diff_1};
            end
            
            if (a_gtet_b) begin
                sign <= opa[63];
            end else if (fpu_op == 3'b000) begin
                sign <= !opb[63];
            end else begin
                sign <= opb[63];
            end
        end
    end

endmodule
