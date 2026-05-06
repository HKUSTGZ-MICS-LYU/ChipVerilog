// =============================================================================
// cordic.v
// Configurable first-quadrant CORDIC core
// Supports PIPELINE, ITERATE, and COMBINATORIAL architectures
// Supports ROTATE and VECTOR modes
// Supports RADIAN_16 and DEGREE_8_8 angle formats
//
// Default (active) configuration:
//   `define PIPELINE
//   `define ROTATE
//   `define RADIAN_16
//   XY_BITS    = 16  -> 17-bit signed x/y
//   THETA_BITS = 16  -> 17-bit signed theta
//   ITERATIONS = 16  -> 15 rotator stages (generate i < ITERATIONS-1)
// =============================================================================

`ifndef XY_BITS
  `define XY_BITS    16
`endif

`ifndef THETA_BITS
  `define THETA_BITS 16
`endif

`ifndef ITERATIONS
  `define ITERATIONS 16
`endif

`ifndef ITERATION_BITS
  `define ITERATION_BITS 4
`endif

// Active compile-time configuration
`define PIPELINE
`define ROTATE
`define RADIAN_16

// CORDIC gain and inverse-gain constants (17-bit signed, RADIAN_16 format)
// CORDIC gain K ~= 1.6467602 for 16 iterations
// CORDIC_1 = round(1/K * 2^15) = round(0.60725 * 32768) ~= 19898
`define CORDIC_GAIN  32'sd54016   // K * 2^15, informational
`define CORDIC_1     17'sd19898   // 1/K * 2^15, used to pre-scale x_i

// =============================================================================
// rotator submodule
// Performs one CORDIC micro-rotation stage.
// =============================================================================
module rotator #(
    parameter XY_BITS    = 16,
    parameter THETA_BITS = 16
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire [3:0]                    iteration,     // stage index (shift amount)
    input  wire signed [THETA_BITS:0]    atan_val,      // precomputed arctan table value
    input  wire signed [XY_BITS:0]       x_i,
    input  wire signed [XY_BITS:0]       y_i,
    input  wire signed [THETA_BITS:0]    z_i,
    output reg  signed [XY_BITS:0]       x_1,
    output reg  signed [XY_BITS:0]       y_1,
    output reg  signed [THETA_BITS:0]    z_1
);

    // Shifted values: divide by 2^iteration (arithmetic right shift)
    wire signed [XY_BITS:0] x_shift;
    wire signed [XY_BITS:0] y_shift;

    assign x_shift = x_i >>> iteration;
    assign y_shift = y_i >>> iteration;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_1 <= {(XY_BITS+1){1'b0}};
            y_1 <= {(XY_BITS+1){1'b0}};
            z_1 <= {(THETA_BITS+1){1'b0}};
        end else begin
`ifdef ROTATE
            // ROTATE mode: direction determined by sign of angle accumulator z_i
            if (z_i[THETA_BITS]) begin
                // z_i < 0: rotate in negative direction
                x_1 <= x_i + y_shift;
                y_1 <= y_i - x_shift;
                z_1 <= z_i + atan_val;
            end else begin
                // z_i >= 0: rotate in positive direction
                x_1 <= x_i - y_shift;
                y_1 <= y_i + x_shift;
                z_1 <= z_i - atan_val;
            end
`elsif VECTOR
            // VECTOR mode: direction determined by sign of y_i
            if (y_i[XY_BITS]) begin
                // y_i < 0: rotate to increase y
                x_1 <= x_i + y_shift;
                y_1 <= y_i - x_shift;
                z_1 <= z_i + atan_val;
            end else begin
                // y_i >= 0: rotate to decrease y
                x_1 <= x_i - y_shift;
                y_1 <= y_i + x_shift;
                z_1 <= z_i - atan_val;
            end
`else
            // Default to ROTATE if neither is defined
            if (z_i[THETA_BITS]) begin
                x_1 <= x_i + y_shift;
                y_1 <= y_i - x_shift;
                z_1 <= z_i + atan_val;
            end else begin
                x_1 <= x_i - y_shift;
                y_1 <= y_i + x_shift;
                z_1 <= z_i - atan_val;
            end
`endif
        end
    end

endmodule


// =============================================================================
// cordic top module
// =============================================================================
module cordic (
    input  wire clk,
    input  wire rst,
`ifdef ITERATE
    input  wire init,
`endif
    input  wire signed [`XY_BITS:0]    x_i,
    input  wire signed [`XY_BITS:0]    y_i,
    input  wire signed [`THETA_BITS:0] theta_i,

    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] theta_o
`ifdef VALID_FLAG
    ,input  wire valid_in,
     output reg  valid_out
`endif
);

    // -------------------------------------------------------------------------
    // Arctangent lookup table function (RADIAN_16, 17-bit signed)
    // atan(2^-i) in Q1.15 fixed-point radian format (scaled by 2^15 / (pi/2))
    // Values are scaled so that pi/2 = 2^15 = 32768 (full first-quadrant range)
    //
    //  i |  atan(2^-i) radians  |  * 32768 / (pi/2)  |  rounded integer
    // ---+---------------------+--------------------+-----------------
    //  0 |  0.785398 (pi/4)    |  16384             |  16384
    //  1 |  0.463648           |   9672             |   9672  <- Q0.15
    //
    // NOTE: The scaling convention used here is atan value * 2^15,
    // where pi radians = 2^16 (full circle), so pi/2 = 2^14.
    // Using the natural radian representation: atan(2^-0) = pi/4,
    // stored as round(pi/4 * 2^15 / pi * 2) = round(2^14) = 16384.
    // Alternatively, full radian values scaled by 2^13 (to fit signed 17-bit
    // with pi/2 ~= 12868):
    //
    // The spec states theta is 17-bit signed with THETA_BITS=16.
    // Range: [-65536, 65535]. For RADIAN_16 the full angle space maps
    // pi radians to approximately 2^16, so pi/2 ~= 32768 = 2^15.
    // Table values below use this convention: atan(2^-i) * 2^15 / (pi/2).
    // -------------------------------------------------------------------------
    function automatic signed [`THETA_BITS:0] tanangle;
        input integer i;
        begin
`ifdef RADIAN_16
            // atan(2^-i) scaled so that pi/2 corresponds to 2^15 = 32768
            // atan(2^-0)  = pi/4        -> round(pi/4  / (pi/2) * 32768) = 16384
            // atan(2^-1)  = 0.46365 rad -> round(0.46365 / 1.5708 * 32768) = 9672
            // atan(2^-2)  = 0.24498 rad -> round(...) = 5110
            // atan(2^-3)  = 0.12436 rad -> round(...) = 2594
            // atan(2^-4)  = 0.06242 rad -> round(...) = 1302
            // atan(2^-5)  = 0.03124 rad -> round(...) =  652
            // atan(2^-6)  = 0.01562 rad -> round(...) =  326
            // atan(2^-7)  = 0.00781 rad -> round(...) =  163
            // atan(2^-8)  = 0.00391 rad -> round(...) =   81
            // atan(2^-9)  = 0.00195 rad -> round(...) =   41
            // atan(2^-10) = 0.000977 rad-> round(...) =   20
            // atan(2^-11) = 0.000488 rad-> round(...) =   10
            // atan(2^-12) = 0.000244 rad-> round(...) =    5
            // atan(2^-13) = 0.000122 rad-> round(...) =    3
            // atan(2^-14) = 0.0000610   -> round(...) =    1
            // atan(2^-15) = 0.0000305   -> round(...) =    1
            case (i)
                0:  tanangle = 17'sd16384;
                1:  tanangle = 17'sd9672;
                2:  tanangle = 17'sd5110;
                3:  tanangle = 17'sd2594;
                4:  tanangle = 17'sd1302;
                5:  tanangle = 17'sd652;
                6:  tanangle = 17'sd326;
                7:  tanangle = 17'sd163;
                8:  tanangle = 17'sd81;
                9:  tanangle = 17'sd41;
                10: tanangle = 17'sd20;
                11: tanangle = 17'sd10;
                12: tanangle = 17'sd5;
                13: tanangle = 17'sd3;
                14: tanangle = 17'sd1;
                15: tanangle = 17'sd1;
                default: tanangle = 17'sd0;
            endcase
`elsif DEGREE_8_8
            // Degree format Q8.8 (angle values scaled by 256)
            // atan(2^-0)  = 45.000 deg -> 45   * 256 = 11520
            // atan(2^-1)  = 26.565 deg -> 26.565*256 =  6801
            // atan(2^-2)  = 14.036 deg -> round(...) =  3593
            // atan(2^-3)  =  7.125 deg -> round(...) =  1824
            // atan(2^-4)  =  3.576 deg -> round(...) =   915
            // atan(2^-5)  =  1.789 deg -> round(...) =   458
            // atan(2^-6)  =  0.895 deg -> round(...) =   229
            // atan(2^-7)  =  0.448 deg -> round(...) =   115
            // atan(2^-8)  =  0.224 deg -> round(...) =    57
            // atan(2^-9)  =  0.112 deg -> round(...) =    29
            // atan(2^-10) =  0.056 deg -> round(...) =    14
            // atan(2^-11) =  0.028 deg -> round(...) =     7
            // atan(2^-12) =  0.014 deg -> round(...) =     4
            // atan(2^-13) =  0.007 deg -> round(...) =     2
            // atan(2^-14) =  0.0034 deg-> round(...) =     1
            // atan(2^-15) =  0.0017 deg-> round(...) =     0
            case (i)
                0:  tanangle = 17'sd11520;
                1:  tanangle = 17'sd6801;
                2:  tanangle = 17'sd3593;
                3:  tanangle = 17'sd1824;
                4:  tanangle = 17'sd915;
                5:  tanangle = 17'sd458;
                6:  tanangle = 17'sd229;
                7:  tanangle = 17'sd115;
                8:  tanangle = 17'sd57;
                9:  tanangle = 17'sd29;
                10: tanangle = 17'sd14;
                11: tanangle = 17'sd7;
                12: tanangle = 17'sd4;
                13: tanangle = 17'sd2;
                14: tanangle = 17'sd1;
                15: tanangle = 17'sd0;
                default: tanangle = 17'sd0;
            endcase
`else
            tanangle = 17'sd0;
`endif
        end
    endfunction


`ifdef PIPELINE
    // =========================================================================
    // PIPELINED architecture
    // ITERATIONS=16 -> 15 rotator stages instantiated (i < ITERATIONS-1)
    // Pipeline latency = ITERATIONS-1 = 15 clock cycles
    // x[0]/y[0]/z[0] are the inputs; x[ITERATIONS-1]/y[ITERATIONS-1]/z[ITERATIONS-1]
    // are the outputs.
    // =========================================================================

    // Per-stage datapath arrays
    wire signed [`XY_BITS:0]    x [`ITERATIONS-1:0];
    wire signed [`XY_BITS:0]    y [`ITERATIONS-1:0];
    wire signed [`THETA_BITS:0] z [`ITERATIONS-1:0];

    // Stage 0: wire inputs directly to first stage nodes
    assign x[0] = x_i;
    assign y[0] = y_i;
    assign z[0] = theta_i;

    // Generate rotator stages i = 0 to ITERATIONS-2
    // NOTE: This creates ITERATIONS-1 = 15 stages per spec
    genvar i;
    generate
        for (i = 0; i < `ITERATIONS-1; i = i + 1) begin : stage
            rotator #(
                .XY_BITS    (`XY_BITS),
                .THETA_BITS (`THETA_BITS)
            ) rot_inst (
                .clk      (clk),
                .rst      (rst),
                .iteration(i[3:0]),
                .atan_val (tanangle(i)),
                .x_i      (x[i]),
                .y_i      (y[i]),
                .z_i      (z[i]),
                .x_1      (x[i+1]),
                .y_1      (y[i+1]),
                .z_1      (z[i+1])
            );
        end
    endgenerate

    // Output: final pipeline stage
    assign x_o     = x[`ITERATIONS-1];
    assign y_o     = y[`ITERATIONS-1];
    assign theta_o = z[`ITERATIONS-1];

`ifdef VALID_FLAG
    // -------------------------------------------------------------------------
    // Valid flag pipeline
    // Shift valid_in through ITERATIONS-1 register stages to align valid_out
    // with the corresponding pipeline output data.
    // -------------------------------------------------------------------------
    reg valid_pipe [`ITERATIONS-2:0];
    integer v;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (v = 0; v < `ITERATIONS-1; v = v + 1)
                valid_pipe[v] <= 1'b0;
        end else begin
            valid_pipe[0] <= valid_in;
            for (v = 1; v < `ITERATIONS-1; v = v + 1)
                valid_pipe[v] <= valid_pipe[v-1];
        end
    end
    always @(*) valid_out = valid_pipe[`ITERATIONS-2];
`endif // VALID_FLAG


`elsif ITERATE
    // =========================================================================
    // ITERATIVE architecture
    // Single rotator reused over ITERATIONS clock cycles.
    // init loads x_i, y_i, theta_i and resets iteration counter.
    //
    // NOTE per spec: z feedback is declared with XY_BITS width even though it
    // represents the theta accumulator. This is harmless when XY_BITS ==
    // THETA_BITS (both 16 in the default configuration).
    // =========================================================================

    reg [`ITERATION_BITS-1:0] iter_cnt;
    reg signed [`XY_BITS:0]   x_reg;
    reg signed [`XY_BITS:0]   y_reg;
    reg signed [`XY_BITS:0]   z_reg;    // XY_BITS wide per spec (not THETA_BITS)
    reg                       running;

    // Combinational micro-rotation for current iteration
    wire signed [`XY_BITS:0]    x_shift_iter = x_reg >>> iter_cnt;
    wire signed [`XY_BITS:0]    y_shift_iter = y_reg >>> iter_cnt;
    wire signed [`THETA_BITS:0] atan_iter     = tanangle(iter_cnt);

    wire signed [`XY_BITS:0]    x_rot_out;
    wire signed [`XY_BITS:0]    y_rot_out;
    wire signed [`XY_BITS:0]    z_rot_out;

`ifdef ROTATE
    assign x_rot_out = z_reg[`XY_BITS] ? (x_reg + y_shift_iter) : (x_reg - y_shift_iter);
    assign y_rot_out = z_reg[`XY_BITS] ? (y_reg - x_shift_iter) : (y_reg + x_shift_iter);
    assign z_rot_out = z_reg[`XY_BITS] ? (z_reg + atan_iter[`XY_BITS:0]) :
                                          (z_reg - atan_iter[`XY_BITS:0]);
`elsif VECTOR
    assign x_rot_out = y_reg[`XY_BITS] ? (x_reg + y_shift_iter) : (x_reg - y_shift_iter);
    assign y_rot_out = y_reg[`XY_BITS] ? (y_reg - x_shift_iter) : (y_reg + x_shift_iter);
    assign z_rot_out = y_reg[`XY_BITS] ? (z_reg + atan_iter[`XY_BITS:0]) :
                                          (z_reg - atan_iter[`XY_BITS:0]);
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_reg    <= {(`XY_BITS+1){1'b0}};
            y_reg    <= {(`XY_BITS+1){1'b0}};
            z_reg    <= {(`XY_BITS+1){1'b0}};
            iter_cnt <= {`ITERATION_BITS{1'b0}};
            running  <= 1'b0;
        end else if (init) begin
            x_reg    <= x_i;
            y_reg    <= y_i;
            z_reg    <= theta_i[`XY_BITS:0];   // truncate theta to XY_BITS+1 per spec
            iter_cnt <= {`ITERATION_BITS{1'b0}};
            running  <= 1'b1;
        end else if (running) begin
            x_reg    <= x_rot_out;
            y_reg    <= y_rot_out;
            z_reg    <= z_rot_out;
            if (iter_cnt == `ITERATIONS-1) begin
                running  <= 1'b0;
                iter_cnt <= {`ITERATION_BITS{1'b0}};
            end else begin
                iter_cnt <= iter_cnt + 1'b1;
            end
        end
    end

    // Sign-extend z_reg (XY_BITS+1 wide) back to THETA_BITS+1 for theta_o
    assign x_o     = x_reg;
    assign y_o     = y_reg;
    assign theta_o = {{(`THETA_BITS-`XY_BITS){z_reg[`XY_BITS]}}, z_reg};


`else
    // =========================================================================
    // COMBINATORIAL architecture
    // CORDIC stages connected as pure combinational cascade (no registers).
    // Computes all ITERATIONS stages in a single clock cycle.
    // =========================================================================

    wire signed [`XY_BITS:0]    xc [`ITERATIONS:0];
    wire signed [`XY_BITS:0]    yc [`ITERATIONS:0];
    wire signed [`THETA_BITS:0] zc [`ITERATIONS:0];

    // Connect inputs to stage 0
    assign xc[0] = x_i;
    assign yc[0] = y_i;
    assign zc[0] = theta_i;

    genvar j;
    generate
        for (j = 0; j < `ITERATIONS; j = j + 1) begin : comb_stage
            wire signed [`XY_BITS:0]    xs = xc[j] >>> j;
            wire signed [`XY_BITS:0]    ys = yc[j] >>> j;
            wire signed [`THETA_BITS:0] av = tanangle(j);
`ifdef ROTATE
            assign xc[j+1] = zc[j][`THETA_BITS] ? (xc[j] + ys) : (xc[j] - ys);
            assign yc[j+1] = zc[j][`THETA_BITS] ? (yc[j] - xs) : (yc[j] + xs);
            assign zc[j+1] = zc[j][`THETA_BITS] ? (zc[j] + av) : (zc[j] - av);
`elsif VECTOR
            assign xc[j+1] = yc[j][`XY_BITS] ? (xc[j] + ys) : (xc[j] - ys);
            assign yc[j+1] = yc[j][`XY_BITS] ? (yc[j] - xs) : (yc[j] + xs);
            assign zc[j+1] = yc[j][`XY_BITS] ? (zc[j] + av) : (zc[j] - av);
`endif
        end
    endgenerate

    assign x_o     = xc[`ITERATIONS];
    assign y_o     = yc[`ITERATIONS];
    assign theta_o = zc[`ITERATIONS];

`endif // architecture select

endmodule
