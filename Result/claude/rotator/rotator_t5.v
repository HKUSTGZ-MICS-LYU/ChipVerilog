//-----------------------------------------------------------------------------
// Module      : rotator
// Description : Implements one CORDIC micro-rotation step. This is the basic
//               computational stage used by the top-level cordic module.
//               For each iteration, the module receives the current x, y, and
//               angle accumulator values, performs one shift-add CORDIC update,
//               and outputs the updated x, y, and z values.
//
// Configurations:
//   PIPELINE      - Registered output, fixed iteration/tangle parameters,
//                   one instance per CORDIC stage.
//   ITERATE       - Registered output, dynamic iteration/tangle inputs,
//                   single instance reused across cycles, supports init load.
//   COMBINATORIAL - Combinational output, fixed iteration/tangle parameters.
//
// Function modes:
//   ROTATE - Drives z toward zero (used for sine/cosine).
//   VECTOR - Drives y toward zero (used for arctangent / magnitude).
//-----------------------------------------------------------------------------

`include "cordic.vh"

module rotator (
    input  wire                        clk,
    input  wire                        rst,
`ifdef ITERATE
    input  wire                        init,
    input  wire [`ITERATION_BITS:0]    iteration,
    input  wire signed [`THETA_BITS:0] tangle,
`endif
    input  wire signed [`XY_BITS:0]    x_i,
    input  wire signed [`XY_BITS:0]    y_i,
    input  wire signed [`THETA_BITS:0] z_i,
    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] z_o
    );

`ifndef ITERATE
    // In PIPELINE / COMBINATORIAL modes, iteration index and arctangent value
    // are fixed at elaboration time and provided as module parameters.
    parameter iteration = 0;
    parameter signed [`THETA_BITS:0] tangle = 0;
`endif

    //-------------------------------------------------------------------------
    // Internal result registers/signals
    //-------------------------------------------------------------------------
    reg signed [`XY_BITS:0]    x_1;
    reg signed [`XY_BITS:0]    y_1;
    reg signed [`THETA_BITS:0] z_1;

    // Shifted versions of x_i and y_i (arithmetic right shift by iteration)
    wire signed [`XY_BITS:0] x_i_shifted;
    wire signed [`XY_BITS:0] y_i_shifted;

    //-------------------------------------------------------------------------
    // Signed arithmetic shifters: implement the CORDIC factor 1/(2^iteration)
    //-------------------------------------------------------------------------
    signed_shifter #(
        .WIDTH(`XY_BITS + 1)
    ) x_shifter (
        .shift (iteration),
        .in    (x_i),
        .out   (x_i_shifted)
    );

    signed_shifter #(
        .WIDTH(`XY_BITS + 1)
    ) y_shifter (
        .shift (iteration),
        .in    (y_i),
        .out   (y_i_shifted)
    );

    //-------------------------------------------------------------------------
    // CORDIC micro-rotation update
    //
    // ROTATE mode : direction selected by sign of z_i (drives z -> 0)
    //   z_i < 0  : x_o = x_i + y_i_shifted
    //              y_o = y_i - x_i_shifted
    //              z_o = z_i + tangle
    //   z_i >= 0 : x_o = x_i - y_i_shifted
    //              y_o = y_i + x_i_shifted
    //              z_o = z_i - tangle
    //
    // VECTOR mode : direction selected by sign of y_i (drives y -> 0)
    //   y_i > 0  : x_o = x_i + y_i_shifted
    //              y_o = y_i - x_i_shifted
    //              z_o = z_i + tangle
    //   y_i <= 0 : x_o = x_i - y_i_shifted
    //              y_o = y_i + x_i_shifted
    //              z_o = z_i - tangle
    //-------------------------------------------------------------------------

`ifdef COMBINATORIAL
    //-------------------------------------------------------------------------
    // COMBINATORIAL configuration: update implemented as combinational logic.
    // The reset branch is still present for consistency with clocked configs.
    //-------------------------------------------------------------------------
    always @(*) begin
        if (rst) begin
            x_1 = {(`XY_BITS + 1){1'b0}};
            y_1 = {(`XY_BITS + 1){1'b0}};
            z_1 = {(`THETA_BITS + 1){1'b0}};
        end
        else begin
    `ifdef ROTATE
            if (z_i < 0) begin
                x_1 = x_i + y_i_shifted;
                y_1 = y_i - x_i_shifted;
                z_1 = z_i + tangle;
            end
            else begin
                x_1 = x_i - y_i_shifted;
                y_1 = y_i + x_i_shifted;
                z_1 = z_i - tangle;
            end
    `endif
    `ifdef VECTOR
            if (y_i > 0) begin
                x_1 = x_i + y_i_shifted;
                y_1 = y_i - x_i_shifted;
                z_1 = z_i + tangle;
            end
            else begin
                x_1 = x_i - y_i_shifted;
                y_1 = y_i + x_i_shifted;
                z_1 = z_i - tangle;
            end
    `endif
        end
    end

`else // PIPELINE or ITERATE configuration: registered update on rising edge of clk
    always @(posedge clk) begin
        if (rst) begin
            x_1 <= {(`XY_BITS + 1){1'b0}};
            y_1 <= {(`XY_BITS + 1){1'b0}};
            z_1 <= {(`THETA_BITS + 1){1'b0}};
        end
    `ifdef ITERATE
        // In ITERATE mode, init bypasses the CORDIC update and loads the
        // initial values directly into the internal registers.
        else if (init) begin
            x_1 <= x_i;
            y_1 <= y_i;
            z_1 <= z_i;
        end
    `endif
        else begin
    `ifdef ROTATE
            if (z_i < 0) begin
                x_1 <= x_i + y_i_shifted;
                y_1 <= y_i - x_i_shifted;
                z_1 <= z_i + tangle;
            end
            else begin
                x_1 <= x_i - y_i_shifted;
                y_1 <= y_i + x_i_shifted;
                z_1 <= z_i - tangle;
            end
    `endif
    `ifdef VECTOR
            if (y_i > 0) begin
                x_1 <= x_i + y_i_shifted;
                y_1 <= y_i - x_i_shifted;
                z_1 <= z_i + tangle;
            end
            else begin
                x_1 <= x_i - y_i_shifted;
                y_1 <= y_i + x_i_shifted;
                z_1 <= z_i - tangle;
            end
    `endif
        end
    end
`endif

    //-------------------------------------------------------------------------
    // Output assignments: continuously drive outputs from internal registers
    //-------------------------------------------------------------------------
    assign x_o = x_1;
    assign y_o = y_1;
    assign z_o = z_1;

endmodule