module fpu_mul (
    input clk,
    input rst,
    input enable,
    input [63:0] opa,
    input [63:0] opb,
    output reg sign,
    output [55:0] product_7,
    output reg [11:0] exponent_5
);

reg [5:0] product_shift;
reg [5:0] product_shift_2;
reg [51:0] mantissa_a;
reg [51:0] mantissa_b;
reg [10:0] exponent_a;
reg [10:0] exponent_b;
reg a_is_norm;
reg b_is_norm;
reg a_is_zero;
reg b_is_zero;
reg in_zero;
reg [11:0] exponent_terms;
reg exponent_gt_expoffset;
reg [11:0] exponent_under;
reg [11:0] exponent_1;
wire [11:0] exponent;
reg [11:0] exponent_2;
reg exponent_gt_prodshift;
reg [11:0] exponent_3;
reg [11:0] exponent_4;
reg exponent_et_zero;
reg [52:0] mul_a;
reg [52:0] mul_b;
reg [40:0] product_a;
reg [40:0] product_b;
reg [40:0] product_c;
reg [25:0] product_d;
reg [33:0] product_e;
reg [33:0] product_f;
reg [35:0] product_g;
reg [28:0] product_h;
reg [28:0] product_i;
reg [30:0] product_j;
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
reg product_lsb;
reg [105:0] product_next;
reg [5:0] shift_amt;

wire [10:0] opa_exp = opa[62:52];
wire [10:0] opb_exp = opb[62:52];
wire [11:0] exponent_terms_w = {1'b0, opa_exp} + {1'b0, opb_exp} + (opa_exp == 11'd0) + (opb_exp == 11'd0);
wire exponent_gt_expoffset_w = (exponent_terms_w > 12'd1021);
wire [11:0] exponent_under_w = 12'd1022 - exponent_terms_w;
wire in_zero_w = (opa[62:0] == 63'd0) | (opb[62:0] == 63'd0);

function [5:0] leading_shift;
    input [105:0] value;
    integer idx;
    begin
        leading_shift = 6'd54;
        for (idx = 0; idx <= 53; idx = idx + 1) begin
            if ((leading_shift == 6'd54) && value[105 - idx]) begin
                leading_shift = idx[5:0];
            end
        end
    end
endfunction

assign exponent = exponent_4;
assign product_7 = {1'b0, product_6[105:52], product_lsb};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sign <= 1'b0;
        product_shift <= 6'd0;
        product_shift_2 <= 6'd0;
        mantissa_a <= 52'd0;
        mantissa_b <= 52'd0;
        exponent_a <= 11'd0;
        exponent_b <= 11'd0;
        a_is_norm <= 1'b0;
        b_is_norm <= 1'b0;
        a_is_zero <= 1'b0;
        b_is_zero <= 1'b0;
        in_zero <= 1'b0;
        exponent_terms <= 12'd0;
        exponent_gt_expoffset <= 1'b0;
        exponent_under <= 12'd0;
        exponent_1 <= 12'd0;
        exponent_2 <= 12'd0;
        exponent_gt_prodshift <= 1'b0;
        exponent_3 <= 12'd0;
        exponent_4 <= 12'd0;
        exponent_5 <= 12'd0;
        exponent_et_zero <= 1'b0;
        mul_a <= 53'd0;
        mul_b <= 53'd0;
        product_a <= 41'd0;
        product_b <= 41'd0;
        product_c <= 41'd0;
        product_d <= 26'd0;
        product_e <= 34'd0;
        product_f <= 34'd0;
        product_g <= 36'd0;
        product_h <= 29'd0;
        product_i <= 29'd0;
        product_j <= 31'd0;
        sum_0 <= 42'd0;
        sum_1 <= 36'd0;
        sum_2 <= 42'd0;
        sum_3 <= 36'd0;
        sum_4 <= 37'd0;
        sum_5 <= 28'd0;
        sum_6 <= 30'd0;
        sum_7 <= 37'd0;
        sum_8 <= 31'd0;
        product <= 106'd0;
        product_1 <= 106'd0;
        product_2 <= 106'd0;
        product_3 <= 106'd0;
        product_4 <= 106'd0;
        product_5 <= 106'd0;
        product_6 <= 106'd0;
        product_lsb <= 1'b0;
        product_next <= 106'd0;
        shift_amt <= 6'd0;
    end else if (enable) begin
        sign <= opa[63] ^ opb[63];

        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        exponent_a <= opa_exp;
        exponent_b <= opb_exp;
        a_is_norm <= (opa_exp != 11'd0);
        b_is_norm <= (opb_exp != 11'd0);
        a_is_zero <= (opa[62:0] == 63'd0);
        b_is_zero <= (opb[62:0] == 63'd0);
        in_zero <= in_zero_w;

        exponent_terms <= exponent_terms_w;
        exponent_gt_expoffset <= exponent_gt_expoffset_w;
        exponent_under <= exponent_under_w;

        mul_a <= {(opa_exp != 11'd0), opa[51:0]};
        mul_b <= {(opb_exp != 11'd0), opb[51:0]};

        product_a <= mul_a[52:29] * mul_b[52:36];
        product_b <= mul_a[52:29] * mul_b[35:19];
        product_c <= mul_a[52:29] * mul_b[18:2];
        product_d <= mul_a[52:29] * mul_b[1:0];
        product_e <= mul_a[28:12] * mul_b[52:36];
        product_f <= mul_a[28:12] * mul_b[35:19];
        product_g <= mul_a[28:12] * mul_b[18:0];
        product_h <= mul_a[11:0]  * mul_b[52:36];
        product_i <= mul_a[11:0]  * mul_b[35:19];
        product_j <= mul_a[11:0]  * mul_b[18:0];

        sum_0 <= {1'b0, product_a} + {1'b0, product_b};
        sum_1 <= {2'b0, product_e} + {2'b0, product_f};
        sum_2 <= sum_0 + {1'b0, product_c};
        sum_3 <= {2'b0, product_h} + {2'b0, product_i};
        sum_4 <= {1'b0, sum_1} + {1'b0, product_g};
        sum_5 <= product_d + product_j[27:0];
        sum_6 <= {2'b0, product_j[30:3]} + {2'b0, product_d[25:1]};
        sum_7 <= {1'b0, sum_3} + {6'd0, product_j};
        sum_8 <= product_j;

        product_next =
            ({65'd0, product_a} << 65) +
            ({65'd0, product_b} << 48) +
            ({65'd0, product_c} << 31) +
            ({80'd0, product_d} << 29) +
            ({72'd0, product_e} << 48) +
            ({72'd0, product_f} << 31) +
            ({70'd0, product_g} << 12) +
            ({77'd0, product_h} << 36) +
            ({77'd0, product_i} << 19) +
            ({75'd0, product_j});

        if (exponent_gt_expoffset_w) begin
            product <= product_next;
            exponent_1 <= exponent_terms_w - 12'd1022;
        end else begin
            if (exponent_under_w >= 12'd106) begin
                product <= 106'd0;
            end else begin
                product <= product_next >> exponent_under_w[6:0];
            end
            exponent_1 <= 12'd0;
        end

        product_1 <= product;
        product_shift <= leading_shift(product_1);
        product_shift_2 <= product_shift;

        exponent_2 <= exponent_1;
        exponent_gt_prodshift <= (exponent_2 > {6'd0, product_shift_2});

        product_2 <= product_1;
        if (exponent_2 > {6'd0, product_shift_2}) begin
            shift_amt = product_shift_2;
            exponent_3 <= exponent_2 - {6'd0, product_shift_2};
            product_3 <= product_2 << shift_amt;
        end else if (exponent_2 != 12'd0) begin
            shift_amt = exponent_2[5:0] - 6'd1;
            exponent_3 <= 12'd0;
            product_3 <= product_2 << shift_amt;
        end else begin
            exponent_3 <= 12'd0;
            product_3 <= product_2;
        end

        exponent_et_zero <= (exponent_3 == 12'd0);
        exponent_4 <= exponent_3;

        if (exponent_et_zero) begin
            product_4 <= product_3 >> 1;
        end else begin
            product_4 <= product_3;
        end

        product_5 <= product_4;
        product_6 <= product_5;

        product_lsb <= |product_6[51:0];

        if (in_zero) begin
            exponent_5 <= 12'd0;
        end else begin
            exponent_5 <= exponent_4;
        end
    end
end

endmodule
