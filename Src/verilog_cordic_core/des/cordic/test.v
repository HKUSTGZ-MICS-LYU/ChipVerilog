//=============================================================================
// cordic.v - Configurable first-quadrant CORDIC core
//
// Supported compile-time configurations (selected via `define):
//   Architecture (pick exactly one): COMBINATORIAL | ITERATE | PIPELINE
//   Function     (pick exactly one): ROTATE        | VECTOR
//   Angle format (pick exactly one): RADIAN_16     | DEGREE_8_8
//   Optional handshake             : VALID_FLAG
//
// Default in this file: PIPELINE + ROTATE + RADIAN_16, ITERATIONS = 16.
//
// Usage notes (sin/cos in ROTATE mode):
//   x_i     = `CORDIC_1   (inverse CORDIC gain, pre-scaling)
//   y_i     = 0
//   theta_i = input angle in Q1.16 radians
//   After pipeline latency: x_o ~= cos(theta), y_o ~= sin(theta)
//
// Limitation:
//   The core is first-quadrant only. Full-circle support requires external
//   coarse-rotation logic before the core and sign/angle correction after.
//
// Notes on fixes vs. the original spec source:
//   1) PIPELINE generate loop uses i < ITERATIONS (not ITERATIONS-1) so that
//      all 16 stages are instantiated.
//   2) VALID_FLAG shift register is declared as reg and driven correctly;
//      the assign for valid_out has a proper '=' sign.
//   3) ITERATE mode uses THETA_BITS for the z accumulator (not XY_BITS).
//=============================================================================


//-----------------------------------------------------------------------------
// Configuration defines
//-----------------------------------------------------------------------------
`ifndef CORDIC_CFG_DONE
`define CORDIC_CFG_DONE

// ---- Architecture (choose one) ----
// `define COMBINATORIAL
// `define ITERATE
`define PIPELINE

// ---- Function mode (choose one) ----
`define ROTATE
// `define VECTOR

// ---- Angle format (choose one) ----
`define RADIAN_16
// `define DEGREE_8_8

// ---- Optional valid handshake ----
// `define VALID_FLAG

// ---- Datapath widths ----
`define XY_BITS         16   // x/y width: actual signed width is XY_BITS+1
`define THETA_BITS      16   // theta width: actual signed width is THETA_BITS+1
`define ITERATIONS      16   // Number of CORDIC micro-rotations
`define ITERATION_BITS  4    // Index width for the atan LUT (>= clog2(ITERATIONS))

// ---- CORDIC gain constants (Q1.16, 17-bit signed) ----
//   CORDIC_GAIN ~= 1.6467602...     (product of sqrt(1 + 2^-2i))
//   CORDIC_1    ~= 1/CORDIC_GAIN ~= 0.6072529...
`define CORDIC_GAIN     17'sd107936  // 1.6467602 * 2^16
`define CORDIC_1        17'sd39797   // 0.6072529 * 2^16

`endif


//=============================================================================
// rotator - One CORDIC micro-rotation stage
//   Performs a single iteration: shift, add/sub, sign-controlled direction.
//   Outputs are registered so this block can be used as a pipeline stage
//   or as a reusable rotator in ITERATE mode.
//=============================================================================
module rotator (
    input  wire                              clk,
    input  wire                              rst,
    input  wire [`ITERATION_BITS-1:0]        iteration,    // current stage index
    input  wire signed [`THETA_BITS:0]       tanangle_i,   // atan(2^-iteration) constant
    input  wire signed [`XY_BITS:0]          x_i,          // current x
    input  wire signed [`XY_BITS:0]          y_i,          // current y
    input  wire signed [`THETA_BITS:0]       z_i,          // current angle accumulator
    output reg  signed [`XY_BITS:0]          x_1,          // next x
    output reg  signed [`XY_BITS:0]          y_1,          // next y
    output reg  signed [`THETA_BITS:0]       z_1           // next z
);

    // Arithmetic right shift implements division by 2^iteration while
    // preserving the sign bit, which is the key CORDIC simplification.
    wire signed [`XY_BITS:0] x_shifted = x_i >>> iteration;
    wire signed [`XY_BITS:0] y_shifted = y_i >>> iteration;

    // Direction of micro-rotation:
    //   ROTATE: drive z toward zero -> use sign of z_i
    //   VECTOR: drive y toward zero -> use sign of y_i
    // dir_neg == 1 means "rotate the opposite way and add the atan constant".
`ifdef ROTATE
    wire dir_neg = z_i[`THETA_BITS];        // z_i < 0 ?
`elsif VECTOR
    wire dir_neg = ~y_i[`XY_BITS];          // y_i >= 0 ?
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_1 <= {(`XY_BITS+1){1'b0}};
            y_1 <= {(`XY_BITS+1){1'b0}};
            z_1 <= {(`THETA_BITS+1){1'b0}};
        end else begin
            if (dir_neg) begin
                // ROTATE & z<0  : x += y>>i ; y -= x>>i ; z += atan
                // VECTOR & y>=0 : same arithmetic, used to push y toward 0
                x_1 <= x_i + y_shifted;
                y_1 <= y_i - x_shifted;
                z_1 <= z_i + tanangle_i;
            end else begin
                // ROTATE & z>=0 : x -= y>>i ; y += x>>i ; z -= atan
                // VECTOR & y<0  : same arithmetic, used to push y toward 0
                x_1 <= x_i - y_shifted;
                y_1 <= y_i + x_shifted;
                z_1 <= z_i - tanangle_i;
            end
        end
    end

endmodule


//=============================================================================
// cordic - Top-level configurable CORDIC core
//=============================================================================
module cordic (
    input  wire                          clk,
    input  wire                          rst,
`ifdef ITERATE
    input  wire                          init,    // load inputs and restart iteration
`endif
    input  wire signed [`XY_BITS:0]      x_i,
    input  wire signed [`XY_BITS:0]      y_i,
    input  wire signed [`THETA_BITS:0]   theta_i,

    output wire signed [`XY_BITS:0]      x_o,
    output wire signed [`XY_BITS:0]      y_o,
    output wire signed [`THETA_BITS:0]   theta_o
`ifdef VALID_FLAG
    , input  wire                        valid_in,
    output wire                          valid_out
`endif
);

    //-------------------------------------------------------------------------
    // tanangle: returns the atan(2^-i) constant for stage i.
    //   RADIAN_16 : Q1.16 radians, 17-bit signed.
    //   DEGREE_8_8: 8.8 fixed-point degrees (placeholder values).
    // If ITERATIONS, widths, or angle format change, regenerate this table.
    //-------------------------------------------------------------------------
    function signed [`THETA_BITS:0] tanangle;
        input [`ITERATION_BITS-1:0] i;
        begin
`ifdef RADIAN_16
            // atan(2^-i) * 2^16
            case (i)
                4'd0 : tanangle = 17'sd51472; // atan(1)      = 0.7853982
                4'd1 : tanangle = 17'sd30386; // atan(1/2)    = 0.4636476
                4'd2 : tanangle = 17'sd16055; // atan(1/4)    = 0.2449787
                4'd3 : tanangle = 17'sd8150;  // atan(1/8)    = 0.1243550
                4'd4 : tanangle = 17'sd4091;  // atan(1/16)   = 0.0624188
                4'd5 : tanangle = 17'sd2047;  // atan(1/32)   = 0.0312398
                4'd6 : tanangle = 17'sd1024;  // atan(1/64)   = 0.0156237
                4'd7 : tanangle = 17'sd512;   // atan(1/128)  = 0.0078123
                4'd8 : tanangle = 17'sd256;
                4'd9 : tanangle = 17'sd128;
                4'd10: tanangle = 17'sd64;
                4'd11: tanangle = 17'sd32;
                4'd12: tanangle = 17'sd16;
                4'd13: tanangle = 17'sd8;
                4'd14: tanangle = 17'sd4;
                4'd15: tanangle = 17'sd2;
                default: tanangle = 17'sd0;
            endcase
`elsif DEGREE_8_8
            // atan(2^-i) in degrees * 2^8 (placeholder; regenerate as needed)
            case (i)
                4'd0 : tanangle = 17'sd11520; // 45.000
                4'd1 : tanangle = 17'sd6801;  // 26.565
                4'd2 : tanangle = 17'sd3593;  // 14.036
                4'd3 : tanangle = 17'sd1824;  //  7.125
                4'd4 : tanangle = 17'sd915;   //  3.576
                4'd5 : tanangle = 17'sd458;   //  1.790
                4'd6 : tanangle = 17'sd229;
                4'd7 : tanangle = 17'sd115;
                4'd8 : tanangle = 17'sd57;
                4'd9 : tanangle = 17'sd29;
                4'd10: tanangle = 17'sd14;
                4'd11: tanangle = 17'sd7;
                4'd12: tanangle = 17'sd4;
                4'd13: tanangle = 17'sd2;
                4'd14: tanangle = 17'sd1;
                4'd15: tanangle = 17'sd0;
                default: tanangle = 17'sd0;
            endcase
`endif
        end
    endfunction


    //=========================================================================
    // PIPELINE architecture (default)
    //   - One rotator per stage; new sample accepted every cycle.
    //   - Latency = ITERATIONS clock cycles.
    //=========================================================================
`ifdef PIPELINE

    // Boundary nodes between stages (ITERATIONS+1 nodes total)
    wire signed [`XY_BITS:0]    x_pipe [0:`ITERATIONS];
    wire signed [`XY_BITS:0]    y_pipe [0:`ITERATIONS];
    wire signed [`THETA_BITS:0] z_pipe [0:`ITERATIONS];

    // Stage 0 driven directly by inputs (registered inside the first rotator)
    assign x_pipe[0] = x_i;
    assign y_pipe[0] = y_i;
    assign z_pipe[0] = theta_i;

    // Instantiate ITERATIONS rotator stages.
    // (Spec note: original source used i < ITERATIONS-1, which gave only 15
    //  stages for ITERATIONS=16. Fixed here to instantiate all 16.)
    genvar i;
    generate
        for (i = 0; i < `ITERATIONS; i = i + 1) begin : g_stage
            wire signed [`XY_BITS:0]    s_x;
            wire signed [`XY_BITS:0]    s_y;
            wire signed [`THETA_BITS:0] s_z;

            rotator u_rotator (
                .clk        (clk),
                .rst        (rst),
                .iteration  (i[`ITERATION_BITS-1:0]),
                .tanangle_i (tanangle(i[`ITERATION_BITS-1:0])),
                .x_i        (x_pipe[i]),
                .y_i        (y_pipe[i]),
                .z_i        (z_pipe[i]),
                .x_1        (s_x),
                .y_1        (s_y),
                .z_1        (s_z)
            );

            assign x_pipe[i+1] = s_x;
            assign y_pipe[i+1] = s_y;
            assign z_pipe[i+1] = s_z;
        end
    endgenerate

    // Final stage drives the module outputs
    assign x_o     = x_pipe[`ITERATIONS];
    assign y_o     = y_pipe[`ITERATIONS];
    assign theta_o = z_pipe[`ITERATIONS];

`endif // PIPELINE


    //=========================================================================
    // ITERATE architecture
    //   - One rotator reused over multiple cycles.
    //   - 'init' loads inputs and resets the iteration counter.
    //   - Result valid after ITERATIONS cycles.
    //=========================================================================
`ifdef ITERATE

    reg  signed [`XY_BITS:0]            x_reg;
    reg  signed [`XY_BITS:0]            y_reg;
    reg  signed [`THETA_BITS:0]         z_reg;       // fixed: width = THETA_BITS+1
    reg         [`ITERATION_BITS-1:0]   iter_cnt;

    wire signed [`XY_BITS:0]            x_next;
    wire signed [`XY_BITS:0]            y_next;
    wire signed [`THETA_BITS:0]         z_next;

    // Reused rotator. Internal registers are bypassed by feeding x_reg/y_reg/z_reg
    // back as inputs and capturing x_next/y_next/z_next into the same registers.
    rotator u_rotator_iter (
        .clk        (clk),
        .rst        (rst),
        .iteration  (iter_cnt),
        .tanangle_i (tanangle(iter_cnt)),
        .x_i        (x_reg),
        .y_i        (y_reg),
        .z_i        (z_reg),
        .x_1        (x_next),
        .y_1        (y_next),
        .z_1        (z_next)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_reg    <= {(`XY_BITS+1){1'b0}};
            y_reg    <= {(`XY_BITS+1){1'b0}};
            z_reg    <= {(`THETA_BITS+1){1'b0}};
            iter_cnt <= {`ITERATION_BITS{1'b0}};
        end else if (init) begin
            // Load initial vector and restart iteration sequence
            x_reg    <= x_i;
            y_reg    <= y_i;
            z_reg    <= theta_i;
            iter_cnt <= {`ITERATION_BITS{1'b0}};
        end else if (iter_cnt < (`ITERATIONS - 1)) begin
            x_reg    <= x_next;
            y_reg    <= y_next;
            z_reg    <= z_next;
            iter_cnt <= iter_cnt + 1'b1;
        end
        // When iter_cnt reaches ITERATIONS-1, hold result until next 'init'.
    end

    assign x_o     = x_reg;
    assign y_o     = y_reg;
    assign theta_o = z_reg;

`endif // ITERATE


    //=========================================================================
    // COMBINATORIAL architecture
    //   - Pure combinational cascade, no clock used in the datapath.
    //   - Same equations as the rotator, unrolled.
    //=========================================================================
`ifdef COMBINATORIAL

    wire signed [`XY_BITS:0]    x_c [0:`ITERATIONS];
    wire signed [`XY_BITS:0]    y_c [0:`ITERATIONS];
    wire signed [`THETA_BITS:0] z_c [0:`ITERATIONS];

    assign x_c[0] = x_i;
    assign y_c[0] = y_i;
    assign z_c[0] = theta_i;

    genvar k;
    generate
        for (k = 0; k < `ITERATIONS; k = k + 1) begin : g_comb
            wire signed [`XY_BITS:0] xs = x_c[k] >>> k;
            wire signed [`XY_BITS:0] ys = y_c[k] >>> k;
        `ifdef ROTATE
            wire dir_neg = z_c[k][`THETA_BITS];
        `elsif VECTOR
            wire dir_neg = ~y_c[k][`XY_BITS];
        `endif
            assign x_c[k+1] = dir_neg ? (x_c[k] + ys) : (x_c[k] - ys);
            assign y_c[k+1] = dir_neg ? (y_c[k] - xs) : (y_c[k] + xs);
            assign z_c[k+1] = dir_neg ? (z_c[k] + tanangle(k[`ITERATION_BITS-1:0]))
                                      : (z_c[k] - tanangle(k[`ITERATION_BITS-1:0]));
        end
    endgenerate

    assign x_o     = x_c[`ITERATIONS];
    assign y_o     = y_c[`ITERATIONS];
    assign theta_o = z_c[`ITERATIONS];

`endif // COMBINATORIAL


    //=========================================================================
    // Optional VALID_FLAG handshake
    //   Aligns valid_in with the corresponding output sample by shifting it
    //   through the same number of registers as the datapath latency.
    //
    //   Spec fixes vs. original source:
    //     - shift register is declared as 'reg' (was wire)
    //     - assign for valid_out has the proper '=' sign
    //=========================================================================
`ifdef VALID_FLAG
  `ifdef PIPELINE
    // Latency = ITERATIONS for the pipelined datapath
    reg [`ITERATIONS-1:0] valid_shift;

    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_shift <= {`ITERATIONS{1'b0}};
        else
            valid_shift <= {valid_shift[`ITERATIONS-2:0], valid_in};
    end

    assign valid_out = valid_shift[`ITERATIONS-1];

  `elsif ITERATE
    // Pulse valid_out when the iteration sequence completes
    reg valid_r;
    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_r <= 1'b0;
        else
            valid_r <= (iter_cnt == (`ITERATIONS - 1));
    end
    assign valid_out = valid_r;

  `else // COMBINATORIAL
    // Pure combinational path: valid passes through directly
    assign valid_out = valid_in;
  `endif
`endif // VALID_FLAG

endmodule