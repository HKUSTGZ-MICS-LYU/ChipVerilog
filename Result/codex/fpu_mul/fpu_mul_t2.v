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
wire [11:0] exponent = 12'd0;
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
reg [5:0] in_zero_pipe;

assign product_7 = {1'b0, product_6[105:52], product_lsb};

always @* begin
    casex (1'b1)
        product_1[105]: product_shift = 6'd0;
        product_1[104]: product_shift = 6'd1;
        product_1[103]: product_shift = 6'd2;
        product_1[102]: product_shift = 6'd3;
        product_1[101]: product_shift = 6'd4;
        product_1[100]: product_shift = 6'd5;
        product_1[99]:  product_shift = 6'd6;
        product_1[98]:  product_shift = 6'd7;
        product_1[97]:  product_shift = 6'd8;
        product_1[96]:  product_shift = 6'd9;
        product_1[95]:  product_shift = 6'd10;
        product_1[94]:  product_shift = 6'd11;
        product_1[93]:  product_shift = 6'd12;
        product_1[92]:  product_shift = 6'd13;
        product_1[91]:  product_shift = 6'd14;
        product_1[90]:  product_shift = 6'd15;
        product_1[89]:  product_shift = 6'd16;
        product_1[88]:  product_shift = 6'd17;
        product_1[87]:  product_shift = 6'd18;
        product_1[86]:  product_shift = 6'd19;
        product_1[85]:  product_shift = 6'd20;
        product_1[84]:  product_shift = 6'd21;
        product_1[83]:  product_shift = 6'd22;
        product_1[82]:  product_shift = 6'd23;
        product_1[81]:  product_shift = 6'd24;
        product_1[80]:  product_shift = 6'd25;
        product_1[79]:  product_shift = 6'd26;
        product_1[78]:  product_shift = 6'd27;
        product_1[77]:  product_shift = 6'd28;
        product_1[76]:  product_shift = 6'd29;
        product_1[75]:  product_shift = 6'd30;
        product_1[74]:  product_shift = 6'd31;
        product_1[73]:  product_shift = 6'd32;
        product_1[72]:  product_shift = 6'd33;
        product_1[71]:  product_shift = 6'd34;
        product_1[70]:  product_shift = 6'd35;
        product_1[69]:  product_shift = 6'd36;
        product_1[68]:  product_shift = 6'd37;
        product_1[67]:  product_shift = 6'd38;
        product_1[66]:  product_shift = 6'd39;
        product_1[65]:  product_shift = 6'd40;
        product_1[64]:  product_shift = 6'd41;
        product_1[63]:  product_shift = 6'd42;
        product_1[62]:  product_shift = 6'd43;
        product_1[61]:  product_shift = 6'd44;
        product_1[60]:  product_shift = 6'd45;
        product_1[59]:  product_shift = 6'd46;
        product_1[58]:  product_shift = 6'd47;
        product_1[57]:  product_shift = 6'd48;
        product_1[56]:  product_shift = 6'd49;
        product_1[55]:  product_shift = 6'd50;
        product_1[54]:  product_shift = 6'd51;
        product_1[53]:  product_shift = 6'd52;
        product_1[52]:  product_shift = 6'd53;
        default:        product_shift = 6'd53;
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
        product_shift_2 <= 6'd0;
        in_zero_pipe <= 6'd0;
    end else if (enable) begin
        sign <= opa[63] ^ opb[63];
        mantissa_a <= opa[51:0];
        mantissa_b <= opb[51:0];
        exponent_a <= opa[62:52];
        exponent_b <= opb[62:52];
        a_is_norm <= |opa[62:52];
        b_is_norm <= |opb[62:52];
        a_is_zero <= ~|opa[62:0];
        b_is_zero <= ~|opb[62:0];
        in_zero <= (~|opa[62:0]) | (~|opb[62:0]);

        in_zero_pipe[0] <= (~|opa[62:0]) | (~|opb[62:0]);
        in_zero_pipe[1] <= in_zero_pipe[0];
        in_zero_pipe[2] <= in_zero_pipe[1];
        in_zero_pipe[3] <= in_zero_pipe[2];
        in_zero_pipe[4] <= in_zero_pipe[3];
        in_zero_pipe[5] <= in_zero_pipe[4];

        mul_a <= {(|opa[62:52]), opa[51:0]};
        mul_b <= {(|opb[62:52]), opb[51:0]};

        exponent_terms <= {1'b0, exponent_a} + {1'b0, exponent_b} + (!a_is_norm) + (!b_is_norm);
        exponent_gt_expoffset <= ({1'b0, exponent_a} + {1'b0, exponent_b} + (!a_is_norm) + (!b_is_norm)) > 12'd1021;
        exponent_under <= 12'd1022 - ({1'b0, exponent_a} + {1'b0, exponent_b} + (!a_is_norm) + (!b_is_norm));
        exponent_1 <= (({1'b0, exponent_a} + {1'b0, exponent_b} + (!a_is_norm) + (!b_is_norm)) > 12'd1021) ?
                      (({1'b0, exponent_a} + {1'b0, exponent_b} + (!a_is_norm) + (!b_is_norm)) - 12'd1022) :
                      exponent;

        product_a <= mul_a[52:29] * mul_b[52:36];
        product_b <= mul_a[52:29] * mul_b[35:19];
        product_c <= mul_a[52:29] * mul_b[16:0];
        product_d <= mul_a[52:29] * mul_b[18:17];
        product_e <= mul_a[28:12] * mul_b[52:36];
        product_f <= mul_a[28:12] * mul_b[35:19];
        product_g <= mul_a[28:12] * mul_b[18:0];
        product_h <= mul_a[11:0] * mul_b[52:36];
        product_i <= mul_a[11:0] * mul_b[35:19];
        product_j <= mul_a[11:0] * mul_b[18:0];

        sum_0 <= {1'b0, product_b} + {1'b0, product_e, 7'd0};
        sum_1 <= product_g;
        sum_2 <= {1'b0, product_c} + {16'd0, product_d};
        sum_3 <= {2'd0, product_f} + {7'd0, product_i};
        sum_4 <= {1'b0, sum_1} + {1'b0, sum_3};
        sum_5 <= product_h[27:0] + product_j[27:0];
        sum_6 <= {2'd0, product_j[30:3]};
        sum_7 <= sum_4 + {9'd0, sum_5};
        sum_8 <= {1'b0, sum_6};

        product <=
            {product_a, 65'd0} +
            {17'd0, product_b, 48'd0} +
            {36'd0, product_c, 29'd0} +
            {34'd0, product_d, 46'd0} +
            {24'd0, product_e, 48'd0} +
            {41'd0, product_f, 31'd0} +
            {58'd0, product_g, 12'd0} +
            {41'd0, product_h, 36'd0} +
            {58'd0, product_i, 19'd0} +
            {75'd0, product_j};

        if (exponent_gt_expoffset) begin
            product_1 <= product;
        end else if (exponent_under >= 12'd106) begin
            product_1 <= 106'd0;
        end else begin
            product_1 <= product >> exponent_under[6:0];
        end

        exponent_2 <= exponent_1;
        product_shift_2 <= product_shift;
        exponent_gt_prodshift <= exponent_2 > {6'd0, product_shift_2};

        if (exponent_gt_prodshift) begin
            product_2 <= product_1 << product_shift_2;
            exponent_3 <= exponent_2 - {6'd0, product_shift_2};
        end else begin
            if (exponent_2 != 12'd0) begin
                product_2 <= product_1 << exponent_2[5:0];
            end else begin
                product_2 <= product_1;
            end
            exponent_3 <= 12'd0;
        end

        exponent_et_zero <= (exponent_3 == 12'd0);
        if (exponent_et_zero) begin
            product_3 <= product_2 >> 1;
        end else begin
            product_3 <= product_2;
        end

        product_4 <= product_3;
        product_5 <= product_4;
        product_6 <= product_5;
        product_lsb <= |product_5[51:0];

        exponent_4 <= exponent_3;
        if (in_zero_pipe[5]) begin
            exponent_5 <= 12'd0;
        end else begin
            exponent_5 <= exponent_4;
        end
    end
end

endmodule
