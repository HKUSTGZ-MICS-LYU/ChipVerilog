// rotator.v
// CORDIC micro-rotation stage submodule.
// Performs one CORDIC iteration using shift-add arithmetic.
// Supports ROTATE mode (z-driven) and VECTOR mode (y-driven).

`timescale 1ns/1ps

module rotator #(
    parameter XY_BITS    = 16,   // x/y datapath word is XY_BITS+1 bits wide
    parameter THETA_BITS = 16    // theta word is THETA_BITS+1 bits wide
)(
    input  wire                       clk,
    input  wire                       rst,
    input  wire [3:0]                 iteration,          // current CORDIC stage index (0..N-1)
    input  wire signed [XY_BITS:0]    x_i,
    input  wire signed [XY_BITS:0]    y_i,
    input  wire signed [THETA_BITS:0] z_i,
    input  wire signed [THETA_BITS:0] atan_val,           // precomputed atan(2^-iteration)
    output reg  signed [XY_BITS:0]    x_1,
    output reg  signed [XY_BITS:0]    y_1,
    output reg  signed [THETA_BITS:0] z_1
);

    // Arithmetic right-shifted versions of x and y
    wire signed [XY_BITS:0] x_shift;
    wire signed [XY_BITS:0] y_shift;

    assign x_shift = x_i >>> iteration;
    assign y_shift = y_i >>> iteration;

    // direction: 1 = counter-clockwise, 0 = clockwise
`ifdef ROTATE
    wire direction = z_i[THETA_BITS];   // sign bit: negative z_i => rotate CCW
`elsif VECTOR
    wire direction = ~y_i[XY_BITS];     // drive y toward zero: positive y => rotate CW
`else
    // Default to ROTATE if neither macro defined
    wire direction = z_i[THETA_BITS];
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_1 <= {(XY_BITS+1){1'b0}};
            y_1 <= {(XY_BITS+1){1'b0}};
            z_1 <= {(THETA_BITS+1){1'b0}};
        end else begin
            if (direction) begin
                // Rotate counter-clockwise
                x_1 <= x_i + y_shift;
                y_1 <= y_i - x_shift;
                z_1 <= z_i + atan_val;
            end else begin
                // Rotate clockwise
                x_1 <= x_i - y_shift;
                y_1 <= y_i + x_shift;
                z_1 <= z_i - atan_val;
            end
        end
    end

endmodule
