module fpu_mul (
    input              clk,
    input              rst,
    input              enable,
    input      [63:0]  opa,
    input      [63:0]  opb,
    output reg         sign,
    output     [55:0]  product_7,
    output reg [11:0]  exponent_5
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
    reg in_zero_1;
    reg in_zero_2;
    reg in_zero_3;
    reg in_zero_4;
    reg in_zero_5;

    reg [11:0] exponent_terms;
    reg        exponent_gt_expoffset;
    reg [11:0] exponent_under;

    reg [11:0] exponent_1;
    wire [11:0] exponent;
    reg [11:0] exponent_2;
    reg        exponent_gt_prodshift;
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

    reg [11:0] exponent_5_pre;

    assign exponent  = 12'd0;
    assign product_7 = {1'b0, product_6[105:52], product_lsb};

    function [5:0] leading_shift_106;
        input [105:0] value;
        integer i;
        reg found;
        begin
            leading_shift_106 = 6'd53;
            found = 1'b0;

            for (i = 105; i >= 52; i = i - 1) begin
                if (!found && value[i]) begin
                    leading_shift_106 = 105 - i;
                    found = 1'b1;
                end
            end
        end
    endfunction

    function [105:0] shr_sticky;
        input [105:0] value;
        input [11:0]  shift;
        reg sticky;
        integer k;
        begin
            if (shift == 12'd0) begin
                shr_sticky = value;
            end else if (shift >= 12'd106) begin
                shr_sticky = 106'd0;
                shr_sticky[0] = |value;
            end else begin
                sticky = 1'b0;

                for (k = 0; k < 106; k = k + 1) begin
                    if (k < shift)
                        sticky = sticky | value[k];
                end

                shr_sticky = value >> shift;
                shr_sticky[0] = shr_sticky[0] | sticky;
            end
        end
    endfunction

    wire [105:0] pp_a = {65'd0, product_a} << 65; // 24 x 17
    wire [105:0] pp_b = {65'd0, product_b} << 48; // 24 x 17
    wire [105:0] pp_c = {65'd0, product_c} << 29; // 24 x 17
    wire [105:0] pp_d = {80'd0, product_d} << 46; // 24 x 2

    wire [105:0] pp_e = {72'd0, product_e} << 48; // 17 x 17
    wire [105:0] pp_f = {72'd0, product_f} << 12; // 17 x 17
    wire [105:0] pp_g = {70'd0, product_g} << 29; // 17 x 19

    wire [105:0] pp_h = {77'd0, product_h} << 36; // 12 x 17
    wire [105:0] pp_i = {77'd0, product_i};       // 12 x 17
    wire [105:0] pp_j = {75'd0, product_j} << 17; // 12 x 19

    wire [105:0] product_sum =
        pp_a + pp_b + pp_c + pp_d +
        pp_e + pp_f + pp_g +
        pp_h + pp_i + pp_j;

    wire [105:0] product_under =
        (exponent_under != 12'd0) ? shr_sticky(product, exponent_under) : product;

    wire [105:0] product_norm_left =
        product_2 << product_shift_2;

    wire [105:0] product_norm_denorm =
        (exponent_4 == 12'd0) ? shr_sticky(product_2, 12'd1) :
        (exponent_4 > product_shift_2) ? product_norm_left :
        shr_sticky(product_2, product_shift_2 - exponent_4 + 12'd1);

    wire [11:0] exponent_norm =
        (exponent_4 > product_shift_2) ? 
        (exponent_4 - product_shift_2) :
        12'd0;

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
            in_zero_1 <= 1'b0;
            in_zero_2 <= 1'b0;
            in_zero_3 <= 1'b0;
            in_zero_4 <= 1'b0;
            in_zero_5 <= 1'b0;

            exponent_terms <= 12'd0;
            exponent_gt_expoffset <= 1'b0;
            exponent_under <= 12'd0;

            exponent_1 <= 12'd0;
            exponent_2 <= 12'd0;
            exponent_3 <= 12'd0;
            exponent_4 <= 12'd0;
            exponent_5 <= 12'd0;
            exponent_5_pre <= 12'd0;

            exponent_gt_prodshift <= 1'b0;
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

            product_shift <= 6'd0;
            product_shift_2 <= 6'd0;
            product_lsb <= 1'b0;
        end else if (enable) begin
            // Stage 0: input decode.
            sign <= opa[63] ^ opb[63];

            mantissa_a <= opa[51:0];
            mantissa_b <= opb[51:0];
            exponent_a <= opa[62:52];
            exponent_b <= opb[62:52];

            a_is_norm <= |opa[62:52];
            b_is_norm <= |opb[62:52];

            a_is_zero <= ~(|opa[62:52]) && ~(|opa[51:0]);
            b_is_zero <= ~(|opb[62:52]) && ~(|opb[51:0]);

            in_zero <= 
                (~(|opa[62:52]) && ~(|opa[51:0])) ||
                (~(|opb[62:52]) && ~(|opb[51:0]));

            // Stage 1: form significands and exponent term.
            mul_a <= {a_is_norm, mantissa_a};
            mul_b <= {b_is_norm, mantissa_b};

            exponent_terms <=
                {1'b0, exponent_a} +
                {1'b0, exponent_b} +
                {11'd0, ~a_is_norm} +
                {11'd0, ~b_is_norm};

            exponent_gt_expoffset <=
                (
                    {1'b0, exponent_a} +
                    {1'b0, exponent_b} +
                    {11'd0, ~a_is_norm} +
                    {11'd0, ~b_is_norm}
                ) > 12'd1021;

            exponent_under <=
                (
                    (
                        {1'b0, exponent_a} +
                        {1'b0, exponent_b} +
                        {11'd0, ~a_is_norm} +
                        {11'd0, ~b_is_norm}
                    ) > 12'd1021
                ) ? 12'd0 :
                (
                    12'd1022 -
                    (
                        {1'b0, exponent_a} +
                        {1'b0, exponent_b} +
                        {11'd0, ~a_is_norm} +
                        {11'd0, ~b_is_norm}
                    )
                );

            exponent_1 <=
                (
                    (
                        {1'b0, exponent_a} +
                        {1'b0, exponent_b} +
                        {11'd0, ~a_is_norm} +
                        {11'd0, ~b_is_norm}
                    ) > 12'd1021
                ) ?
                (
                    (
                        {1'b0, exponent_a} +
                        {1'b0, exponent_b} +
                        {11'd0, ~a_is_norm} +
                        {11'd0, ~b_is_norm}
                    ) - 12'd1022
                ) :
                12'd0;

            in_zero_1 <= in_zero;

            // Stage 2: decomposed partial products.
            product_a <= mul_a[52:29] * mul_b[52:36]; // 24 x 17
            product_b <= mul_a[52:29] * mul_b[35:19]; // 24 x 17
            product_c <= mul_a[52:29] * mul_b[16:0];  // 24 x 17
            product_d <= mul_a[52:29] * mul_b[18:17]; // 24 x 2

            product_e <= mul_a[28:12] * mul_b[52:36]; // 17 x 17
            product_f <= mul_a[28:12] * mul_b[16:0];  // 17 x 17
            product_g <= mul_a[28:12] * mul_b[35:17]; // 17 x 19

            product_h <= mul_a[11:0] * mul_b[52:36];  // 12 x 17
            product_i <= mul_a[11:0] * mul_b[16:0];   // 12 x 17
            product_j <= mul_a[11:0] * mul_b[35:17];  // 12 x 19

            exponent_2 <= exponent_1;
            in_zero_2 <= in_zero_1;

            // Stage 3: registered sum helpers.
            sum_0 <= {1'b0, product_a} + {1'b0, product_b};
            sum_1 <= {10'd0, product_d};
            sum_2 <= {8'd0, product_e} + {6'd0, product_g};
            sum_3 <= {2'd0, product_f};
            sum_4 <= {8'd0, product_h};
            sum_5 <= product_i[27:0];
            sum_6 <= {1'b0, product_j[28:0]};
            sum_7 <= {1'b0, product_g};
            sum_8 <= product_j;

            product <= product_sum;

            exponent_3 <= exponent_2;
            in_zero_3 <= in_zero_2;

            // Stage 4: underflow pre-shift and leading-zero shift detection.
            product_1 <= product_under;
            product_shift <= leading_shift_106(product_under);

            exponent_4 <= exponent_3;
            exponent_et_zero <= exponent_3 == 12'd0;

            in_zero_4 <= in_zero_3;

            // Stage 5: align product shift with exponent.
            product_2 <= product_1;
            product_shift_2 <= product_shift;

            exponent_gt_prodshift <= exponent_4 > product_shift;
            exponent_5_pre <= exponent_4;

            in_zero_5 <= in_zero_4;

            // Stage 6: normalize or denormalize.
            product_3 <= product_norm_denorm;
            exponent_5 <= in_zero_5 ? 12'd0 : exponent_norm;

            // Additional product delay stages to match product_6 naming.
            product_4 <= product_3;
            product_5 <= product_4;
            product_6 <= product_5;

            product_lsb <= |product_5[51:0];
        end
    end

endmodule