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
reg [7:0] in_zero_pipe;
reg [11:0] exponent_terms;
reg exponent_gt_expoffset;
reg [11:0] exponent_under;
reg [11:0] exponent_1;
wire [11:0] exponent;
reg [11:0] exponent_2;
reg exponent_gt_prodshift;
reg [11:0] exponent_3;
reg [11:0] exponent_4;
reg [11:0] exponent_pipe_0;
reg [11:0] exponent_pipe_1;
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

function [105:0] assemble_product;
    input [40:0] pa;
    input [40:0] pb;
    input [40:0] pc;
    input [25:0] pd;
    input [33:0] pe;
    input [33:0] pf;
    input [35:0] pg;
    input [28:0] ph;
    input [28:0] pi;
    input [30:0] pj;
    reg [105:0] acc;
    begin
        acc = 106'd0;
        acc = acc + ({{65{1'b0}}, pa} << 65);
        acc = acc + ({{65{1'b0}}, pb} << 46);
        acc = acc + ({{65{1'b0}}, pc} << 29);
        acc = acc + ({{80{1'b0}}, pd} << 63);
        acc = acc + ({{72{1'b0}}, pe} << 48);
        acc = acc + ({{72{1'b0}}, pf} << 12);
        acc = acc + ({{70{1'b0}}, pg} << 29);
        acc = acc + ({{77{1'b0}}, ph} << 36);
        acc = acc + {{77{1'b0}}, pi};
        acc = acc + ({{75{1'b0}}, pj} << 17);
        assemble_product = acc;
    end
endfunction

function [5:0] leading_shift;
    input [105:0] value;
    integer idx;
    reg found;
    begin
        leading_shift = 6'd53;
        found = 1'b0;
        for (idx = 0; idx <= 53; idx = idx + 1) begin
            if (!found && value[105 - idx]) begin
                leading_shift = idx[5:0];
                found = 1'b1;
            end
        end
    end
endfunction

function [105:0] rshift_cap;
    input [105:0] value;
    input [11:0] shamt;
    begin
        if (shamt >= 12'd106) begin
            rshift_cap = 106'd0;
        end else begin
            rshift_cap = value >> shamt[6:0];
        end
    end
endfunction

function [105:0] lshift_cap;
    input [105:0] value;
    input [11:0] shamt;
    begin
        if (shamt >= 12'd106) begin
            lshift_cap = 106'd0;
        end else begin
            lshift_cap = value << shamt[6:0];
        end
    end
endfunction

wire [11:0] exponent_terms_next;
wire [105:0] assembled_product_w;
wire [105:0] product_pre_norm_w;
wire [5:0] product_shift_next_w;

assign exponent_terms_next = {1'b0, exponent_a} +
                             {1'b0, exponent_b} +
                             (a_is_norm ? 12'd0 : 12'd1) +
                             (b_is_norm ? 12'd0 : 12'd1);
assign exponent = exponent_gt_expoffset ? (exponent_terms - 12'd1022) : 12'd0;
assign assembled_product_w = assemble_product(
    product_a,
    product_b,
    product_c,
    product_d,
    product_e,
    product_f,
    product_g,
    product_h,
    product_i,
    product_j
);
assign product_pre_norm_w = exponent_gt_expoffset ? product : rshift_cap(product, exponent_under);
assign product_shift_next_w = leading_shift(product_pre_norm_w);
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
        in_zero_pipe <= 8'd0;
        exponent_terms <= 12'd0;
        exponent_gt_expoffset <= 1'b0;
        exponent_under <= 12'd0;
        exponent_1 <= 12'd0;
        exponent_2 <= 12'd0;
        exponent_gt_prodshift <= 1'b0;
        exponent_3 <= 12'd0;
        exponent_4 <= 12'd0;
        exponent_pipe_0 <= 12'd0;
        exponent_pipe_1 <= 12'd0;
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
        exponent_5 <= 12'd0;
    end else if (enable) begin
        sign <= opa[63] ^ opb[63];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        a_is_norm <= |opa[62:52];
        b_is_norm <= |opb[62:52];
        a_is_zero <= (opa[62:0] == 63'd0);
        b_is_zero <= (opb[62:0] == 63'd0);
        in_zero <= (opa[62:0] == 63'd0) || (opb[62:0] == 63'd0);
        in_zero_pipe <= {in_zero_pipe[6:0], ((opa[62:0] == 63'd0) || (opb[62:0] == 63'd0))};

        mul_a <= {a_is_norm, mantissa_a};
        mul_b <= {b_is_norm, mantissa_b};

        exponent_terms <= exponent_terms_next;
        exponent_gt_expoffset <= (exponent_terms_next > 12'd1021);
        exponent_under <= 12'd1022 - exponent_terms_next;

        product_a <= mul_a[52:29] * mul_b[52:36];
        product_b <= mul_a[52:29] * mul_b[33:17];
        product_c <= mul_a[52:29] * mul_b[16:0];
        product_d <= mul_a[52:29] * mul_b[35:34];
        product_e <= mul_a[28:12] * mul_b[52:36];
        product_f <= mul_a[28:12] * mul_b[16:0];
        product_g <= mul_a[28:12] * mul_b[35:17];
        product_h <= mul_a[11:0] * mul_b[52:36];
        product_i <= mul_a[11:0] * mul_b[16:0];
        product_j <= mul_a[11:0] * mul_b[35:17];

        sum_0 <= {1'b0, product_a} + {1'b0, product_b};
        sum_1 <= {2'b0, product_e} + {2'b0, product_f};
        sum_2 <= {1'b0, product_c} + {16'd0, product_d};
        sum_3 <= product_g[35:0];
        sum_4 <= {8'd0, product_h} + {8'd0, product_i};
        sum_5 <= product_i[27:0];
        sum_6 <= {1'b0, product_h} + {1'b0, product_i};
        sum_7 <= {1'b0, sum_4[35:0]};
        sum_8 <= product_j;
        product <= assembled_product_w;
        exponent_1 <= exponent;

        product_1 <= product_pre_norm_w;
        exponent_2 <= exponent_1;
        product_shift <= product_shift_next_w;

        product_shift_2 <= product_shift;
        exponent_gt_prodshift <= (exponent_2 > {6'd0, product_shift});
        if (exponent_2 > {6'd0, product_shift}) begin
            product_2 <= lshift_cap(product_1, {6'd0, product_shift});
            exponent_3 <= exponent_2 - {6'd0, product_shift};
        end else begin
            product_2 <= lshift_cap(product_1, exponent_2);
            exponent_3 <= 12'd0;
        end

        exponent_et_zero <= (exponent_3 == 12'd0);
        if (exponent_3 == 12'd0) begin
            product_3 <= product_2 >> 1;
        end else begin
            product_3 <= product_2;
        end
        exponent_4 <= exponent_3;

        product_4 <= product_3;
        exponent_pipe_0 <= exponent_4;

        product_5 <= product_4;
        exponent_pipe_1 <= exponent_pipe_0;

        product_6 <= product_5;
        product_lsb <= |product_5[51:0];
        if (in_zero_pipe[7]) begin
            exponent_5 <= 12'd0;
        end else begin
            exponent_5 <= exponent_pipe_1;
        end
    end
end

endmodule
