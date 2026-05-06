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
reg [6:0] zero_pipe;
reg [11:0] exponent_4_d1;
reg [11:0] exponent_4_d2;

wire a_is_norm_in;
wire b_is_norm_in;
wire a_is_zero_in;
wire b_is_zero_in;
wire in_zero_in;
wire [52:0] mul_a_in;
wire [52:0] mul_b_in;
wire [11:0] exponent_terms_calc;
wire exponent_gt_expoffset_calc;
wire [11:0] exponent_under_calc;
wire [105:0] pp_a;
wire [105:0] pp_b;
wire [105:0] pp_c;
wire [105:0] pp_d;
wire [105:0] pp_e;
wire [105:0] pp_f;
wire [105:0] pp_g;
wire [105:0] pp_h;
wire [105:0] pp_i;
wire [105:0] pp_j;
wire [105:0] product_raw;
wire [105:0] product_pre_norm;

assign a_is_norm_in = |opa[62:52];
assign b_is_norm_in = |opb[62:52];
assign a_is_zero_in = (opa[62:0] == 63'd0);
assign b_is_zero_in = (opb[62:0] == 63'd0);
assign in_zero_in = a_is_zero_in | b_is_zero_in;
assign mul_a_in = {a_is_norm_in, opa[51:0]};
assign mul_b_in = {b_is_norm_in, opb[51:0]};

assign exponent_terms_calc = {1'b0, exponent_a} + {1'b0, exponent_b} + {{11{1'b0}}, !a_is_norm} + {{11{1'b0}}, !b_is_norm};
assign exponent_gt_expoffset_calc = (exponent_terms_calc > 12'd1021);
assign exponent_under_calc = 12'd1022 - exponent_terms_calc;
assign exponent = exponent_gt_expoffset_calc ? (exponent_terms_calc - 12'd1022) : 12'd0;

assign pp_a = {65'd0, product_a};
assign pp_d = {63'd0, product_d, 17'd0};
assign pp_b = {46'd0, product_b, 19'd0};
assign pp_g = {46'd0, product_g, 24'd0};
assign pp_c = {29'd0, product_c, 36'd0};
assign pp_j = {34'd0, product_j, 41'd0};
assign pp_e = {29'd0, product_e, 43'd0};
assign pp_f = {12'd0, product_f, 60'd0};
assign pp_h = {17'd0, product_h, 60'd0};
assign pp_i = {product_i, 77'd0};
assign product_raw = pp_a + pp_d + pp_b + pp_g + pp_c + pp_j + pp_e + pp_f + pp_h + pp_i;
assign product_pre_norm = exponent_gt_expoffset_calc ? product_raw : (product_raw >> exponent_under_calc);
assign product_7 = {1'b0, product_6[105:52], product_lsb};

always @* begin
    casex (1'b1)
        product[105]: product_shift = 6'd0;
        product[104]: product_shift = 6'd1;
        product[103]: product_shift = 6'd2;
        product[102]: product_shift = 6'd3;
        product[101]: product_shift = 6'd4;
        product[100]: product_shift = 6'd5;
        product[99]: product_shift = 6'd6;
        product[98]: product_shift = 6'd7;
        product[97]: product_shift = 6'd8;
        product[96]: product_shift = 6'd9;
        product[95]: product_shift = 6'd10;
        product[94]: product_shift = 6'd11;
        product[93]: product_shift = 6'd12;
        product[92]: product_shift = 6'd13;
        product[91]: product_shift = 6'd14;
        product[90]: product_shift = 6'd15;
        product[89]: product_shift = 6'd16;
        product[88]: product_shift = 6'd17;
        product[87]: product_shift = 6'd18;
        product[86]: product_shift = 6'd19;
        product[85]: product_shift = 6'd20;
        product[84]: product_shift = 6'd21;
        product[83]: product_shift = 6'd22;
        product[82]: product_shift = 6'd23;
        product[81]: product_shift = 6'd24;
        product[80]: product_shift = 6'd25;
        product[79]: product_shift = 6'd26;
        product[78]: product_shift = 6'd27;
        product[77]: product_shift = 6'd28;
        product[76]: product_shift = 6'd29;
        product[75]: product_shift = 6'd30;
        product[74]: product_shift = 6'd31;
        product[73]: product_shift = 6'd32;
        product[72]: product_shift = 6'd33;
        product[71]: product_shift = 6'd34;
        product[70]: product_shift = 6'd35;
        product[69]: product_shift = 6'd36;
        product[68]: product_shift = 6'd37;
        product[67]: product_shift = 6'd38;
        product[66]: product_shift = 6'd39;
        product[65]: product_shift = 6'd40;
        product[64]: product_shift = 6'd41;
        product[63]: product_shift = 6'd42;
        product[62]: product_shift = 6'd43;
        product[61]: product_shift = 6'd44;
        product[60]: product_shift = 6'd45;
        product[59]: product_shift = 6'd46;
        product[58]: product_shift = 6'd47;
        product[57]: product_shift = 6'd48;
        product[56]: product_shift = 6'd49;
        product[55]: product_shift = 6'd50;
        product[54]: product_shift = 6'd51;
        product[53]: product_shift = 6'd52;
        product[52]: product_shift = 6'd53;
        default: product_shift = 6'd53;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sign <= 1'b0;
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
        product_shift_2 <= 6'd0;
        zero_pipe <= 7'd0;
        exponent_4_d1 <= 12'd0;
        exponent_4_d2 <= 12'd0;
        exponent_5 <= 12'd0;
    end else if (enable) begin
        sign <= opa[63] ^ opb[63];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        a_is_norm <= a_is_norm_in;
        b_is_norm <= b_is_norm_in;
        a_is_zero <= a_is_zero_in;
        b_is_zero <= b_is_zero_in;
        in_zero <= in_zero_in;
        mul_a <= mul_a_in;
        mul_b <= mul_b_in;
        product_a <= mul_a_in[23:0] * mul_b_in[16:0];
        product_b <= mul_a_in[23:0] * mul_b_in[35:19];
        product_c <= mul_a_in[23:0] * mul_b_in[52:36];
        product_d <= mul_a_in[23:0] * mul_b_in[18:17];
        product_e <= mul_a_in[40:24] * mul_b_in[35:19];
        product_f <= mul_a_in[40:24] * mul_b_in[52:36];
        product_g <= mul_a_in[40:24] * mul_b_in[18:0];
        product_h <= mul_a_in[52:41] * mul_b_in[35:19];
        product_i <= mul_a_in[52:41] * mul_b_in[52:36];
        product_j <= mul_a_in[52:41] * mul_b_in[18:0];
        zero_pipe[0] <= in_zero_in;

        exponent_terms <= exponent_terms_calc;
        exponent_gt_expoffset <= exponent_gt_expoffset_calc;
        exponent_under <= exponent_under_calc;
        exponent_1 <= exponent;
        sum_0 <= product_raw[41:0];
        sum_1 <= product_raw[59:24];
        sum_2 <= product_raw[60:19];
        sum_3 <= product_raw[78:43];
        sum_4 <= product_raw[79:43];
        sum_5 <= product_raw[68:41];
        sum_6 <= product_raw[70:41];
        sum_7 <= product_raw[96:60];
        sum_8 <= product_raw[90:60];
        product <= product_pre_norm;
        zero_pipe[1] <= zero_pipe[0];

        product_1 <= product;
        exponent_2 <= exponent_1;
        product_shift_2 <= product_shift;
        exponent_gt_prodshift <= (exponent_1 >= {6'd0, product_shift});
        zero_pipe[2] <= zero_pipe[1];

        if (exponent_2 == 12'd0) begin
            product_2 <= product_1;
            exponent_3 <= 12'd0;
            exponent_et_zero <= 1'b1;
        end else if (exponent_gt_prodshift) begin
            product_2 <= product_1 << product_shift_2;
            exponent_3 <= exponent_2 - {6'd0, product_shift_2};
            exponent_et_zero <= ((exponent_2 - {6'd0, product_shift_2}) == 12'd0);
        end else begin
            product_2 <= product_1 << (exponent_2 - 12'd1);
            exponent_3 <= 12'd0;
            exponent_et_zero <= 1'b1;
        end
        zero_pipe[3] <= zero_pipe[2];

        if (exponent_et_zero) begin
            product_3 <= product_2 >> 1;
        end else begin
            product_3 <= product_2;
        end
        exponent_4 <= exponent_3;
        zero_pipe[4] <= zero_pipe[3];

        product_4 <= product_3;
        exponent_4_d1 <= exponent_4;
        zero_pipe[5] <= zero_pipe[4];

        product_5 <= product_4;
        exponent_4_d2 <= exponent_4_d1;
        zero_pipe[6] <= zero_pipe[5];

        product_6 <= product_5;
        product_lsb <= |product_5[51:0];
        exponent_5 <= zero_pipe[6] ? 12'd0 : exponent_4_d2;
    end
end

endmodule
