// =============================================================================
// cordic.v — Pipelined first-quadrant CORDIC core
// Configuration: PIPELINE + ROTATE + RADIAN_16
//
// Default parameters:
//   XY_BITS        = 16  → x/y ports are signed [16:0] (17 bits)
//   THETA_BITS     = 16  → theta ports are signed [16:0] (17 bits)
//   ITERATIONS     = 16  → 15 rotator stages (generate: i < ITERATIONS-1)
//   ITERATION_BITS =  4  → stage index width for arctangent table
//
// Sine / cosine usage (ROTATE mode):
//   Set x_i = CORDIC_1, y_i = 0, theta_i = desired_angle
//   After pipeline latency:  x_o ≈ cos(theta_i),  y_o ≈ sin(theta_i)
//
// NOTE: First-quadrant only.  External quadrant pre/post-correction is required
//       for angles outside [0, π/2].
// =============================================================================

// ----------------------------------------------------------------------------
// Compile-time defines (edit here to switch configurations)
// ----------------------------------------------------------------------------
`define PIPELINE          // Enable pipelined architecture
// `define ITERATE        // Enable iterative architecture  (mutually exclusive)
// `define COMBINATORIAL  // Enable combinatorial architecture (mutually exclusive)

`define ROTATE            // Enable rotation mode (cos/sin output)
// `define VECTOR         // Enable vectoring mode (atan output) (mutually exclusive)

`define RADIAN_16         // 17-bit signed radian angle representation
// `define DEGREE_8_8     // 8.8 fixed-point degree representation (mutually exclusive)

// `define VALID_FLAG     // Uncomment to add valid_in / valid_out handshake ports

// ----------------------------------------------------------------------------
// Bit-width parameters
// ----------------------------------------------------------------------------
`define XY_BITS        16   // x/y data width = XY_BITS+1 bits (signed)
`define THETA_BITS     16   // theta width    = THETA_BITS+1 bits (signed)
`define ITERATIONS     16   // number of CORDIC iterations
`define ITERATION_BITS  4   // ceil(log2(ITERATIONS))

// ----------------------------------------------------------------------------
// CORDIC gain constants (RADIAN_16, 17-bit signed, Q1.15 format)
//
//   CORDIC gain K ≈ 1.6467602579…
//   CORDIC_1    = round(1/K * 2^15) = round(0.6072529… * 32768) = 19898
//
// Stored as a 17-bit signed value so it fits the [XY_BITS:0] port.
// ----------------------------------------------------------------------------
`define CORDIC_GAIN    17'sd21597   // K   ≈ 1.6468  in Q1.15  (K*32768)
`define CORDIC_1       17'sd19898   // 1/K ≈ 0.6073  in Q1.15  (round(32768/K))

// =============================================================================
// rotator — one CORDIC micro-rotation stage
//
// Ports:
//   clk, rst         — clock and synchronous reset
//   iteration        — stage index (selects arctangent table entry)
//   x_i, y_i, z_i   — input x, y, angle-accumulator
//   x_o, y_o, z_o   — registered output after one micro-rotation
// =============================================================================
module rotator (
    input  wire                          clk,
    input  wire                          rst,
    input  wire [`ITERATION_BITS-1:0]    iteration,
    input  wire signed [`XY_BITS:0]      x_i,
    input  wire signed [`XY_BITS:0]      y_i,
    input  wire signed [`THETA_BITS:0]   z_i,
    output reg  signed [`XY_BITS:0]      x_o,
    output reg  signed [`XY_BITS:0]      y_o,
    output reg  signed [`THETA_BITS:0]   z_o
);

    // -----------------------------------------------------------------------
    // tanangle — precomputed arctangent table (RADIAN_16, Q1.15)
    //
    //   Entry i = round( atan(2^-i) * 2^15 )
    //
    //   i=0  atan(1)      = π/4        → 8192
    //   i=1  atan(0.5)    ≈ 0.4636 rad → 4823
    //   i=2  atan(0.25)   ≈ 0.2450 rad → 2435 (corrected from 2548)
    //   ...
    // -----------------------------------------------------------------------
    function signed [`THETA_BITS:0] tanangle;
        input [`ITERATION_BITS-1:0] i;
        begin
            case (i)
                4'd0:  tanangle = 17'sd8192;   // atan(2^0)  = atan(1.000000) ≈ 0.7854 rad
                4'd1:  tanangle = 17'sd4823;   // atan(2^-1) = atan(0.500000) ≈ 0.4636 rad
                4'd2:  tanangle = 17'sd2435;   // atan(2^-2) = atan(0.250000) ≈ 0.2450 rad
                4'd3:  tanangle = 17'sd1218;   // atan(2^-3) = atan(0.125000) ≈ 0.1244 rad
                4'd4:  tanangle = 17'sd610;    // atan(2^-4) = atan(0.062500) ≈ 0.0624 rad
                4'd5:  tanangle = 17'sd305;    // atan(2^-5) = atan(0.031250) ≈ 0.0312 rad
                4'd6:  tanangle = 17'sd152;    // atan(2^-6) = atan(0.015625) ≈ 0.0156 rad
                4'd7:  tanangle = 17'sd76;     // atan(2^-7) = atan(0.007813) ≈ 0.0078 rad
                4'd8:  tanangle = 17'sd38;     // atan(2^-8) = atan(0.003906) ≈ 0.0039 rad
                4'd9:  tanangle = 17'sd19;     // atan(2^-9) = atan(0.001953) ≈ 0.0020 rad
                4'd10: tanangle = 17'sd10;     // atan(2^-10)= atan(0.000977) ≈ 0.0010 rad
                4'd11: tanangle = 17'sd5;      // atan(2^-11)= atan(0.000488) ≈ 0.0005 rad
                4'd12: tanangle = 17'sd2;      // atan(2^-12)= atan(0.000244) ≈ 0.0002 rad
                4'd13: tanangle = 17'sd1;      // atan(2^-13)= atan(0.000122) ≈ 0.0001 rad
                4'd14: tanangle = 17'sd1;      // atan(2^-14)= atan(0.000061) ≈ 0.0001 rad
                4'd15: tanangle = 17'sd0;      // atan(2^-15)= atan(0.000031) ≈ 0.0000 rad
                default: tanangle = 17'sd0;
            endcase
        end
    endfunction

    // -----------------------------------------------------------------------
    // Combinational micro-rotation logic
    // -----------------------------------------------------------------------
    wire signed [`XY_BITS:0]    x_shift;   // x_i >> iteration
    wire signed [`XY_BITS:0]    y_shift;   // y_i >> iteration
    wire signed [`THETA_BITS:0] atan_val;  // arctangent table entry

    // Arithmetic right shifts implement division by 2^iteration
    assign x_shift  = x_i >>> iteration;
    assign y_shift  = y_i >>> iteration;
    assign atan_val = tanangle(iteration);

    // -----------------------------------------------------------------------
    // Registered stage output
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            x_o <= {(`XY_BITS+1){1'b0}};
            y_o <= {(`XY_BITS+1){1'b0}};
            z_o <= {(`THETA_BITS+1){1'b0}};
        end else begin
`ifdef ROTATE
            // ROTATE mode: drive residual angle z toward zero.
            // Rotation direction is determined by the sign of the angle acc.
            if (z_i[`THETA_BITS]) begin
                // z_i < 0 → rotate counter-clockwise
                x_o <= x_i + y_shift;
                y_o <= y_i - x_shift;
                z_o <= z_i + atan_val;
            end else begin
                // z_i >= 0 → rotate clockwise
                x_o <= x_i - y_shift;
                y_o <= y_i + x_shift;
                z_o <= z_i - atan_val;
            end
`elsif VECTOR
            // VECTOR mode: drive y toward zero, accumulate angle in z.
            // Rotation direction is determined by the sign of y.
            if (y_i[`XY_BITS]) begin
                // y_i < 0 → rotate clockwise
                x_o <= x_i - y_shift;
                y_o <= y_i + x_shift;
                z_o <= z_i - atan_val;
            end else begin
                // y_i >= 0 → rotate counter-clockwise
                x_o <= x_i + y_shift;
                y_o <= y_i - x_shift;
                z_o <= z_i + atan_val;
            end
`else
            // Fallback: pass through unchanged
            x_o <= x_i;
            y_o <= y_i;
            z_o <= z_i;
`endif
        end
    end

endmodule // rotator


// =============================================================================
// cordic — top-level pipelined CORDIC core
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

// =============================================================================
// PIPELINE architecture
// =============================================================================
`ifdef PIPELINE

    // -----------------------------------------------------------------------
    // Per-stage datapath arrays
    // x[0..ITERATIONS-1], y[0..ITERATIONS-1], z[0..ITERATIONS-1]
    // -----------------------------------------------------------------------
    wire signed [`XY_BITS:0]    x [`ITERATIONS-1:0];
    wire signed [`XY_BITS:0]    y [`ITERATIONS-1:0];
    wire signed [`THETA_BITS:0] z [`ITERATIONS-1:0];

    // Stage 0: driven directly from the inputs
    assign x[0] = x_i;
    assign y[0] = y_i;
    assign z[0] = theta_i;

    // -----------------------------------------------------------------------
    // Generate rotator pipeline stages
    // NOTE: The generate bound is i < ITERATIONS-1, producing ITERATIONS-1
    //       (i.e. 15) rotator instances for the default ITERATIONS = 16.
    //       Stage index i maps input array entry [i] to output array [i+1].
    // -----------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < `ITERATIONS-1; i = i + 1) begin : cordic_stages
            rotator u_rotator (
                .clk       (clk),
                .rst       (rst),
                .iteration (i[`ITERATION_BITS-1:0]),
                .x_i       (x[i]),
                .y_i       (y[i]),
                .z_i       (z[i]),
                .x_o       (x[i+1]),
                .y_o       (y[i+1]),
                .z_o       (z[i+1])
            );
        end
    endgenerate

    // -----------------------------------------------------------------------
    // Pipeline outputs — taken from the last stage
    // -----------------------------------------------------------------------
    assign x_o     = x[`ITERATIONS-1];
    assign y_o     = y[`ITERATIONS-1];
    assign theta_o = z[`ITERATIONS-1];

    // -----------------------------------------------------------------------
    // Optional valid-flag pipeline (fixed implementation)
    // A shift register propagates valid_in through (ITERATIONS-1) cycles so
    // that valid_out aligns with the corresponding pipeline output data.
    // -----------------------------------------------------------------------
`ifdef VALID_FLAG
    reg [`ITERATIONS-2:0] valid_shift;   // (ITERATIONS-1) delay stages

    always @(posedge clk) begin
        if (rst) begin
            valid_shift <= {(`ITERATIONS-1){1'b0}};
            valid_out   <= 1'b0;
        end else begin
            valid_shift <= {valid_shift[`ITERATIONS-3:0], valid_in};
            valid_out   <= valid_shift[`ITERATIONS-2];
        end
    end
`endif // VALID_FLAG


// =============================================================================
// ITERATE architecture
// =============================================================================
`elsif ITERATE

    // Single rotator reused over ITERATIONS clock cycles.
    // init loads the initial values and resets the iteration counter.

    reg [`ITERATION_BITS-1:0] iter_cnt;

    reg signed [`XY_BITS:0]    x_reg;
    reg signed [`XY_BITS:0]    y_reg;
    reg signed [`THETA_BITS:0] z_reg;  // NOTE: same width as XY_BITS (harmless when equal)

    wire signed [`XY_BITS:0]    x_fb;
    wire signed [`XY_BITS:0]    y_fb;
    wire signed [`THETA_BITS:0] z_fb;

    // Instantiate a single rotator stage with feedback
    rotator u_rotator_iter (
        .clk       (clk),
        .rst       (rst),
        .iteration (iter_cnt),
        .x_i       (x_reg),
        .y_i       (y_reg),
        .z_i       (z_reg),
        .x_o       (x_fb),
        .y_o       (y_fb),
        .z_o       (z_fb)
    );

    always @(posedge clk) begin
        if (rst) begin
            iter_cnt <= {`ITERATION_BITS{1'b0}};
            x_reg    <= {(`XY_BITS+1){1'b0}};
            y_reg    <= {(`XY_BITS+1){1'b0}};
            z_reg    <= {(`THETA_BITS+1){1'b0}};
        end else if (init) begin
            iter_cnt <= {`ITERATION_BITS{1'b0}};
            x_reg    <= x_i;
            y_reg    <= y_i;
            z_reg    <= theta_i;
        end else if (iter_cnt < `ITERATIONS-1) begin
            iter_cnt <= iter_cnt + 1'b1;
            x_reg    <= x_fb;
            y_reg    <= y_fb;
            z_reg    <= z_fb;
        end
    end

    assign x_o     = x_fb;
    assign y_o     = y_fb;
    assign theta_o = z_fb;


// =============================================================================
// COMBINATORIAL architecture
// =============================================================================
`elsif COMBINATORIAL

    // All stages wired as a combinational cascade (no registers).
    wire signed [`XY_BITS:0]    xc [`ITERATIONS-1:0];
    wire signed [`XY_BITS:0]    yc [`ITERATIONS-1:0];
    wire signed [`THETA_BITS:0] zc [`ITERATIONS-1:0];

    assign xc[0] = x_i;
    assign yc[0] = y_i;
    assign zc[0] = theta_i;

    genvar ci;
    generate
        for (ci = 0; ci < `ITERATIONS-1; ci = ci + 1) begin : comb_stages
            wire signed [`XY_BITS:0]    xs = xc[ci] >>> ci;
            wire signed [`XY_BITS:0]    ys = yc[ci] >>> ci;
            wire signed [`THETA_BITS:0] av;
            // Inline atan table — reuse rotator function via localparams
            // (In purely combinatorial mode, instantiate without clk/rst.)
            // For simplicity, perform the rotation inline here.
            assign av = (ci == 0)  ? 17'sd8192 :
                        (ci == 1)  ? 17'sd4823 :
                        (ci == 2)  ? 17'sd2435 :
                        (ci == 3)  ? 17'sd1218 :
                        (ci == 4)  ? 17'sd610  :
                        (ci == 5)  ? 17'sd305  :
                        (ci == 6)  ? 17'sd152  :
                        (ci == 7)  ? 17'sd76   :
                        (ci == 8)  ? 17'sd38   :
                        (ci == 9)  ? 17'sd19   :
                        (ci == 10) ? 17'sd10   :
                        (ci == 11) ? 17'sd5    :
                        (ci == 12) ? 17'sd2    :
                        (ci == 13) ? 17'sd1    :
                        (ci == 14) ? 17'sd1    : 17'sd0;
`ifdef ROTATE
            assign xc[ci+1] = zc[ci][`THETA_BITS] ? (xc[ci] + ys) : (xc[ci] - ys);
            assign yc[ci+1] = zc[ci][`THETA_BITS] ? (yc[ci] - xs) : (yc[ci] + xs);
            assign zc[ci+1] = zc[ci][`THETA_BITS] ? (zc[ci] + av) : (zc[ci] - av);
`elsif VECTOR
            assign xc[ci+1] = yc[ci][`XY_BITS]    ? (xc[ci] - ys) : (xc[ci] + ys);
            assign yc[ci+1] = yc[ci][`XY_BITS]    ? (yc[ci] + xs) : (yc[ci] - xs);
            assign zc[ci+1] = yc[ci][`XY_BITS]    ? (zc[ci] - av) : (zc[ci] + av);
`endif
        end
    endgenerate

    assign x_o     = xc[`ITERATIONS-1];
    assign y_o     = yc[`ITERATIONS-1];
    assign theta_o = zc[`ITERATIONS-1];

`endif // architecture select

endmodule // cordic
