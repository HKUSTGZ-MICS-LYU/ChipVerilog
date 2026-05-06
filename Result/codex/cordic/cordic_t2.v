module cordic_rotator #(
    parameter integer XY_BITS = 16,
    parameter integer THETA_BITS = 16,
    parameter integer ITERATION = 0,
    parameter signed [THETA_BITS:0] ANGLE = { (THETA_BITS+1){1'b0} }
) (
    input  wire                          clk,
    input  wire                          rst,
    input  wire signed [XY_BITS:0]       x_i,
    input  wire signed [XY_BITS:0]       y_i,
    input  wire signed [THETA_BITS:0]    z_i,
    output reg  signed [XY_BITS:0]       x_o,
    output reg  signed [XY_BITS:0]       y_o,
    output reg  signed [THETA_BITS:0]    z_o
);
    wire signed [XY_BITS:0] x_shift;
    wire signed [XY_BITS:0] y_shift;

    assign x_shift = x_i >>> ITERATION;
    assign y_shift = y_i >>> ITERATION;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_o <= { (XY_BITS+1){1'b0} };
            y_o <= { (XY_BITS+1){1'b0} };
            z_o <= { (THETA_BITS+1){1'b0} };
        end else if (z_i < 0) begin
            x_o <= x_i + y_shift;
            y_o <= y_i - x_shift;
            z_o <= z_i + ANGLE;
        end else begin
            x_o <= x_i - y_shift;
            y_o <= y_i + x_shift;
            z_o <= z_i - ANGLE;
        end
    end
endmodule

module cordic #(
    parameter integer XY_BITS = 16,
    parameter integer THETA_BITS = 16
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire signed [XY_BITS:0]    x_i,
    input  wire signed [XY_BITS:0]    y_i,
    input  wire signed [THETA_BITS:0] theta_i,
    output wire signed [XY_BITS:0]    x_o,
    output wire signed [XY_BITS:0]    y_o,
    output wire signed [THETA_BITS:0] theta_o
);
    localparam signed [THETA_BITS:0] ANGLE_0  = 17'sd25736;
    localparam signed [THETA_BITS:0] ANGLE_1  = 17'sd15193;
    localparam signed [THETA_BITS:0] ANGLE_2  = 17'sd8027;
    localparam signed [THETA_BITS:0] ANGLE_3  = 17'sd4075;
    localparam signed [THETA_BITS:0] ANGLE_4  = 17'sd2045;
    localparam signed [THETA_BITS:0] ANGLE_5  = 17'sd1024;
    localparam signed [THETA_BITS:0] ANGLE_6  = 17'sd512;
    localparam signed [THETA_BITS:0] ANGLE_7  = 17'sd256;
    localparam signed [THETA_BITS:0] ANGLE_8  = 17'sd128;
    localparam signed [THETA_BITS:0] ANGLE_9  = 17'sd64;
    localparam signed [THETA_BITS:0] ANGLE_10 = 17'sd32;
    localparam signed [THETA_BITS:0] ANGLE_11 = 17'sd16;
    localparam signed [THETA_BITS:0] ANGLE_12 = 17'sd8;
    localparam signed [THETA_BITS:0] ANGLE_13 = 17'sd4;
    localparam signed [THETA_BITS:0] ANGLE_14 = 17'sd2;
    localparam signed [THETA_BITS:0] ANGLE_15 = 17'sd1;

    wire signed [XY_BITS:0]    x_0;
    wire signed [XY_BITS:0]    y_0;
    wire signed [THETA_BITS:0] z_0;
    wire signed [XY_BITS:0]    x_1;
    wire signed [XY_BITS:0]    y_1;
    wire signed [THETA_BITS:0] z_1;
    wire signed [XY_BITS:0]    x_2;
    wire signed [XY_BITS:0]    y_2;
    wire signed [THETA_BITS:0] z_2;
    wire signed [XY_BITS:0]    x_3;
    wire signed [XY_BITS:0]    y_3;
    wire signed [THETA_BITS:0] z_3;
    wire signed [XY_BITS:0]    x_4;
    wire signed [XY_BITS:0]    y_4;
    wire signed [THETA_BITS:0] z_4;
    wire signed [XY_BITS:0]    x_5;
    wire signed [XY_BITS:0]    y_5;
    wire signed [THETA_BITS:0] z_5;
    wire signed [XY_BITS:0]    x_6;
    wire signed [XY_BITS:0]    y_6;
    wire signed [THETA_BITS:0] z_6;
    wire signed [XY_BITS:0]    x_7;
    wire signed [XY_BITS:0]    y_7;
    wire signed [THETA_BITS:0] z_7;
    wire signed [XY_BITS:0]    x_8;
    wire signed [XY_BITS:0]    y_8;
    wire signed [THETA_BITS:0] z_8;
    wire signed [XY_BITS:0]    x_9;
    wire signed [XY_BITS:0]    y_9;
    wire signed [THETA_BITS:0] z_9;
    wire signed [XY_BITS:0]    x_10;
    wire signed [XY_BITS:0]    y_10;
    wire signed [THETA_BITS:0] z_10;
    wire signed [XY_BITS:0]    x_11;
    wire signed [XY_BITS:0]    y_11;
    wire signed [THETA_BITS:0] z_11;
    wire signed [XY_BITS:0]    x_12;
    wire signed [XY_BITS:0]    y_12;
    wire signed [THETA_BITS:0] z_12;
    wire signed [XY_BITS:0]    x_13;
    wire signed [XY_BITS:0]    y_13;
    wire signed [THETA_BITS:0] z_13;
    wire signed [XY_BITS:0]    x_14;
    wire signed [XY_BITS:0]    y_14;
    wire signed [THETA_BITS:0] z_14;
    wire signed [XY_BITS:0]    x_15;
    wire signed [XY_BITS:0]    y_15;
    wire signed [THETA_BITS:0] z_15;
    wire signed [XY_BITS:0]    x_16;
    wire signed [XY_BITS:0]    y_16;
    wire signed [THETA_BITS:0] z_16;

    assign x_0 = x_i;
    assign y_0 = y_i;
    assign z_0 = theta_i;

    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(0),  .ANGLE(ANGLE_0))  stage_0  (.clk(clk), .rst(rst), .x_i(x_0),  .y_i(y_0),  .z_i(z_0),  .x_o(x_1),  .y_o(y_1),  .z_o(z_1));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(1),  .ANGLE(ANGLE_1))  stage_1  (.clk(clk), .rst(rst), .x_i(x_1),  .y_i(y_1),  .z_i(z_1),  .x_o(x_2),  .y_o(y_2),  .z_o(z_2));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(2),  .ANGLE(ANGLE_2))  stage_2  (.clk(clk), .rst(rst), .x_i(x_2),  .y_i(y_2),  .z_i(z_2),  .x_o(x_3),  .y_o(y_3),  .z_o(z_3));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(3),  .ANGLE(ANGLE_3))  stage_3  (.clk(clk), .rst(rst), .x_i(x_3),  .y_i(y_3),  .z_i(z_3),  .x_o(x_4),  .y_o(y_4),  .z_o(z_4));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(4),  .ANGLE(ANGLE_4))  stage_4  (.clk(clk), .rst(rst), .x_i(x_4),  .y_i(y_4),  .z_i(z_4),  .x_o(x_5),  .y_o(y_5),  .z_o(z_5));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(5),  .ANGLE(ANGLE_5))  stage_5  (.clk(clk), .rst(rst), .x_i(x_5),  .y_i(y_5),  .z_i(z_5),  .x_o(x_6),  .y_o(y_6),  .z_o(z_6));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(6),  .ANGLE(ANGLE_6))  stage_6  (.clk(clk), .rst(rst), .x_i(x_6),  .y_i(y_6),  .z_i(z_6),  .x_o(x_7),  .y_o(y_7),  .z_o(z_7));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(7),  .ANGLE(ANGLE_7))  stage_7  (.clk(clk), .rst(rst), .x_i(x_7),  .y_i(y_7),  .z_i(z_7),  .x_o(x_8),  .y_o(y_8),  .z_o(z_8));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(8),  .ANGLE(ANGLE_8))  stage_8  (.clk(clk), .rst(rst), .x_i(x_8),  .y_i(y_8),  .z_i(z_8),  .x_o(x_9),  .y_o(y_9),  .z_o(z_9));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(9),  .ANGLE(ANGLE_9))  stage_9  (.clk(clk), .rst(rst), .x_i(x_9),  .y_i(y_9),  .z_i(z_9),  .x_o(x_10), .y_o(y_10), .z_o(z_10));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(10), .ANGLE(ANGLE_10)) stage_10 (.clk(clk), .rst(rst), .x_i(x_10), .y_i(y_10), .z_i(z_10), .x_o(x_11), .y_o(y_11), .z_o(z_11));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(11), .ANGLE(ANGLE_11)) stage_11 (.clk(clk), .rst(rst), .x_i(x_11), .y_i(y_11), .z_i(z_11), .x_o(x_12), .y_o(y_12), .z_o(z_12));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(12), .ANGLE(ANGLE_12)) stage_12 (.clk(clk), .rst(rst), .x_i(x_12), .y_i(y_12), .z_i(z_12), .x_o(x_13), .y_o(y_13), .z_o(z_13));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(13), .ANGLE(ANGLE_13)) stage_13 (.clk(clk), .rst(rst), .x_i(x_13), .y_i(y_13), .z_i(z_13), .x_o(x_14), .y_o(y_14), .z_o(z_14));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(14), .ANGLE(ANGLE_14)) stage_14 (.clk(clk), .rst(rst), .x_i(x_14), .y_i(y_14), .z_i(z_14), .x_o(x_15), .y_o(y_15), .z_o(z_15));
    cordic_rotator #(.XY_BITS(XY_BITS), .THETA_BITS(THETA_BITS), .ITERATION(15), .ANGLE(ANGLE_15)) stage_15 (.clk(clk), .rst(rst), .x_i(x_15), .y_i(y_15), .z_i(z_15), .x_o(x_16), .y_o(y_16), .z_o(z_16));

    assign x_o = x_16;
    assign y_o = y_16;
    assign theta_o = z_16;
endmodule
