module cordic (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [16:0] x_i,
    input  wire signed [16:0] y_i,
    input  wire signed [16:0] theta_i,
    output wire signed [16:0] x_o,
    output wire signed [16:0] y_o,
    output wire signed [16:0] theta_o
);
    localparam integer ITERATIONS = 16;

    function signed [16:0] tanangle;
        input integer index;
        begin
            case (index)
                0:  tanangle = 17'sd8192;
                1:  tanangle = 17'sd4836;
                2:  tanangle = 17'sd2555;
                3:  tanangle = 17'sd1297;
                4:  tanangle = 17'sd651;
                5:  tanangle = 17'sd326;
                6:  tanangle = 17'sd163;
                7:  tanangle = 17'sd81;
                8:  tanangle = 17'sd41;
                9:  tanangle = 17'sd20;
                10: tanangle = 17'sd10;
                11: tanangle = 17'sd5;
                12: tanangle = 17'sd3;
                13: tanangle = 17'sd1;
                14: tanangle = 17'sd1;
                15: tanangle = 17'sd0;
                default: tanangle = 17'sd0;
            endcase
        end
    endfunction

    wire signed [16:0] x_stage [0:ITERATIONS];
    wire signed [16:0] y_stage [0:ITERATIONS];
    wire signed [16:0] z_stage [0:ITERATIONS];

    assign x_stage[0] = x_i;
    assign y_stage[0] = y_i;
    assign z_stage[0] = theta_i;

    genvar gi;
    generate
        for (gi = 0; gi < ITERATIONS; gi = gi + 1) begin : gen_rotator
            cordic_rotator #(
                .ITERATION(gi),
                .ANGLE(tanangle(gi))
            ) stage (
                .clk(clk),
                .rst(rst),
                .x_i(x_stage[gi]),
                .y_i(y_stage[gi]),
                .z_i(z_stage[gi]),
                .x_o(x_stage[gi+1]),
                .y_o(y_stage[gi+1]),
                .z_o(z_stage[gi+1])
            );
        end
    endgenerate

    assign x_o = x_stage[ITERATIONS];
    assign y_o = y_stage[ITERATIONS];
    assign theta_o = z_stage[ITERATIONS];
endmodule

module cordic_rotator #(
    parameter integer ITERATION = 0,
    parameter signed [16:0] ANGLE = 17'sd0
) (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [16:0] x_i,
    input  wire signed [16:0] y_i,
    input  wire signed [16:0] z_i,
    output reg  signed [16:0] x_o,
    output reg  signed [16:0] y_o,
    output reg  signed [16:0] z_o
);
    wire signed [16:0] x_shift;
    wire signed [16:0] y_shift;

    assign x_shift = x_i >>> ITERATION;
    assign y_shift = y_i >>> ITERATION;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_o <= 17'sd0;
            y_o <= 17'sd0;
            z_o <= 17'sd0;
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
