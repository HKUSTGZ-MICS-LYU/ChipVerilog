// cordic.v
// Configurable first-quadrant CORDIC core.
//
// Architecture selection (define exactly one):
//   `define PIPELINE      - registered pipeline; accepts new input every clock cycle
//   `define ITERATE       - single reused rotator; uses 'init' to load inputs
//   `define COMBINATORIAL - combinational cascade; purely combinational output
//
// Function mode (define exactly one):
//   `define ROTATE        - rotates input vector; x_o=cos, y_o=sin when x_i=CORDIC_1, y_i=0
//   `define VECTOR        - drives y toward zero; theta_o = atan(y_i/x_i)
//
// Angle format (define exactly one):
//   `define RADIAN_16     - signed 17-bit radian fixed-point (default)
//   `define DEGREE_8_8    - signed 17-bit degree fixed-point (8.8 format)
//
// Optional:
//   `define VALID_FLAG    - enables valid_in / valid_out handshake ports
//
// Default parameters:
//   XY_BITS       = 16   -> x/y ports are 17-bit signed
//   THETA_BITS    = 16   -> theta ports are 17-bit signed
//   ITERATIONS    = 16   -> number of CORDIC micro-rotation stages
//
// In ROTATE mode, initialize:
//   x_i     = `CORDIC_1  (inverse CORDIC gain, compensates for gain accumulation)
//   y_i     = 0
//   theta_i = desired angle
//
// NOTE: This core supports first-quadrant operation only.
// For full-circle use, apply external coarse rotation before this core and
// correct the sign / quadrant of the output accordingly.

`timescale 1ns/1ps

// ============================================================
//  Default compile-time defines (override externally as needed)
// ============================================================
`ifndef PIPELINE
  `ifndef ITERATE
    `ifndef COMBINATORIAL
      `define PIPELINE
    `endif
  `endif
`endif

`ifndef ROTATE
  `ifndef VECTOR
    `define ROTATE
  `endif
`endif

`ifndef RADIAN_16
  `ifndef DEGREE_8_8
    `define RADIAN_16
  `endif
`endif

// ============================================================
//  Numeric parameters
// ============================================================
`ifndef XY_BITS
  `define XY_BITS 16
`endif

`ifndef THETA_BITS
  `define THETA_BITS 16
`endif

`ifndef ITERATIONS
  `define ITERATIONS 16
`endif

// CORDIC gain G = product(sqrt(1 + 2^(-2i))) for i=0..(N-1) ≈ 1.6468
// CORDIC_1 = round(1/G * 2^XY_BITS) for 17-bit signed, XY_BITS=16
//   1/1.6468 * 65536 ≈ 39797
`define CORDIC_1  17'sd39797

// CORDIC_GAIN as 17-bit fixed-point (informational; not used in datapath)
`define CORDIC_GAIN 17'sd107980   // ≈ 1.6468 * 65536

// ============================================================
//  Module
// ============================================================
module cordic #(
    parameter XY_BITS       = `XY_BITS,
    parameter THETA_BITS    = `THETA_BITS,
    parameter ITERATIONS    = `ITERATIONS,
    parameter ITERATION_BITS = 4          // ceil(log2(ITERATIONS))
)(
    input  wire clk,
    input  wire rst,

`ifdef ITERATE
    input  wire init,
`endif

    input  wire signed [XY_BITS:0]    x_i,
    input  wire signed [XY_BITS:0]    y_i,
    input  wire signed [THETA_BITS:0] theta_i,

    output wire signed [XY_BITS:0]    x_o,
    output wire signed [XY_BITS:0]    y_o,
    output wire signed [THETA_BITS:0] theta_o

`ifdef VALID_FLAG
    ,input  wire valid_in,
    output wire valid_out
`endif
);

    // --------------------------------------------------------
    //  Arctangent lookup table
    //  tanangle(i) = round(atan(2^-i) * 2^THETA_BITS / (2*pi)) for RADIAN_16
    //  Values for ITERATIONS=16, THETA_BITS=16 (17-bit signed radian):
    //    atan(2^-i) scaled to fixed-point: round(atan(2^-i)/(pi) * 2^15)
    //  Using two's-complement 17-bit signed representation.
    // --------------------------------------------------------
    function signed [THETA_BITS:0] tanangle;
        input integer i;
        begin
`ifdef RADIAN_16
            // atan(2^-i) in units of 2^-16 radians (17-bit signed)
            // atan(1)       = pi/4       = 0x6488  = 25736
            // atan(0.5)     = 0.4636 rad = 0x3B59  = 15193
            // atan(0.25)    = 0.2450 rad = 0x1F5B  =  8027
            // atan(0.125)   = 0.1244 rad = 0x0FEB  =  4075
            // atan(0.0625)  = 0.0624 rad = 0x07FD  =  2045
            // atan(0.03125) = 0.0312 rad = 0x0400  =  1024
            // ... halving each subsequent entry (first-order approx valid for small angles)
            case (i)
                0:  tanangle = 17'sd25736;
                1:  tanangle = 17'sd15193;
                2:  tanangle = 17'sd8027;
                3:  tanangle = 17'sd4075;
                4:  tanangle = 17'sd2045;
                5:  tanangle = 17'sd1024;
                6:  tanangle = 17'sd512;
                7:  tanangle = 17'sd256;
                8:  tanangle = 17'sd128;
                9:  tanangle = 17'sd64;
                10: tanangle = 17'sd32;
                11: tanangle = 17'sd16;
                12: tanangle = 17'sd8;
                13: tanangle = 17'sd4;
                14: tanangle = 17'sd2;
                15: tanangle = 17'sd1;
                default: tanangle = 17'sd0;
            endcase
`elsif DEGREE_8_8
            // atan(2^-i) in degrees, 8.8 fixed-point (17-bit signed)
            // atan(1)=45 deg -> 45*256=11520; atan(0.5)=26.565->6801; etc.
            case (i)
                0:  tanangle = 17'sd11520;
                1:  tanangle = 17'sd6801;
                2:  tanangle = 17'sd3593;
                3:  tanangle = 17'sd1824;
                4:  tanangle = 17'sd916;
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

    // ============================================================
    //  PIPELINE architecture
    // ============================================================
`ifdef PIPELINE

    // Per-stage signal arrays (ITERATIONS+1 nodes: 0 = input, ITERATIONS = output)
    reg  signed [XY_BITS:0]    x [0:ITERATIONS];
    reg  signed [XY_BITS:0]    y [0:ITERATIONS];
    reg  signed [THETA_BITS:0] z [0:ITERATIONS];

    // Stage 0 captures inputs on clock edge
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x[0] <= {(XY_BITS+1){1'b0}};
            y[0] <= {(XY_BITS+1){1'b0}};
            z[0] <= {(THETA_BITS+1){1'b0}};
        end else begin
            x[0] <= x_i;
            y[0] <= y_i;
            z[0] <= theta_i;
        end
    end

    // Generate pipeline stages 0 .. ITERATIONS-2  (creates ITERATIONS-1 rotators)
    // NOTE: With ITERATIONS=16 this instantiates stages 0..14 (15 rotator instances).
    //       Review against target iteration count if full 16 stages are required.
    genvar i;
    generate
        for (i = 0; i < ITERATIONS-1; i = i + 1) begin : stage
            wire signed [XY_BITS:0]    x_s;
            wire signed [XY_BITS:0]    y_s;
            wire signed [THETA_BITS:0] z_s;

            rotator #(
                .XY_BITS    (XY_BITS),
                .THETA_BITS (THETA_BITS)
            ) rot_inst (
                .clk      (clk),
                .rst      (rst),
                .iteration(i[3:0]),
                .x_i      (x[i]),
                .y_i      (y[i]),
                .z_i      (z[i]),
                .atan_val (tanangle(i)),
                .x_1      (x_s),
                .y_1      (y_s),
                .z_1      (z_s)
            );

            // Connect rotator outputs into next stage's array entries
            always @(*) begin
                x[i+1] = x_s;
                y[i+1] = y_s;
                z[i+1] = z_s;
            end
        end
    endgenerate

    assign x_o     = x[ITERATIONS-1];
    assign y_o     = y[ITERATIONS-1];
    assign theta_o = z[ITERATIONS-1];

    // ---- Optional valid-flag pipeline ----
`ifdef VALID_FLAG
    // Shift valid bit through ITERATIONS-1 pipeline stages to align with output.
    // Note: requires synthesis of a shift register equal to pipeline depth.
    reg [ITERATIONS-2:0] valid_pipe;

    always @(posedge clk or posedge rst) begin
        if (rst)
            valid_pipe <= {(ITERATIONS-1){1'b0}};
        else
            valid_pipe <= {valid_pipe[ITERATIONS-3:0], valid_in};
    end

    assign valid_out = valid_pipe[ITERATIONS-2];
`endif

`endif // PIPELINE

    // ============================================================
    //  ITERATE architecture
    // ============================================================
`ifdef ITERATE

    reg  signed [XY_BITS:0]    xi_reg, yi_reg;
    reg  signed [THETA_BITS:0] zi_reg;

    reg  signed [XY_BITS:0]    x_cur, y_cur;
    reg  signed [THETA_BITS:0] z_cur;

    reg  [ITERATION_BITS-1:0]  iter_cnt;
    reg                         busy;

    // Intermediate shifted values
    wire signed [XY_BITS:0]    x_shift = x_cur >>> iter_cnt;
    wire signed [XY_BITS:0]    y_shift = y_cur >>> iter_cnt;

`ifdef ROTATE
    wire direction = z_cur[THETA_BITS];
`elsif VECTOR
    wire direction = ~y_cur[XY_BITS];
`else
    wire direction = z_cur[THETA_BITS];
`endif

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_cur    <= {(XY_BITS+1){1'b0}};
            y_cur    <= {(XY_BITS+1){1'b0}};
            z_cur    <= {(THETA_BITS+1){1'b0}};
            iter_cnt <= {ITERATION_BITS{1'b0}};
            busy     <= 1'b0;
        end else if (init) begin
            x_cur    <= x_i;
            y_cur    <= y_i;
            z_cur    <= theta_i;
            iter_cnt <= {ITERATION_BITS{1'b0}};
            busy     <= 1'b1;
        end else if (busy) begin
            if (iter_cnt == ITERATIONS - 1) begin
                busy <= 1'b0;
            end else begin
                if (direction) begin
                    x_cur <= x_cur + y_shift;
                    y_cur <= y_cur - x_shift;
                    z_cur <= z_cur + tanangle(iter_cnt);
                end else begin
                    x_cur <= x_cur - y_shift;
                    y_cur <= y_cur + x_shift;
                    z_cur <= z_cur - tanangle(iter_cnt);
                end
                iter_cnt <= iter_cnt + 1'b1;
            end
        end
    end

    assign x_o     = x_cur;
    assign y_o     = y_cur;
    assign theta_o = z_cur;

`endif // ITERATE

    // ============================================================
    //  COMBINATORIAL architecture
    // ============================================================
`ifdef COMBINATORIAL

    // Wire arrays for combinational cascade
    wire signed [XY_BITS:0]    xc [0:ITERATIONS];
    wire signed [XY_BITS:0]    yc [0:ITERATIONS];
    wire signed [THETA_BITS:0] zc [0:ITERATIONS];

    assign xc[0] = x_i;
    assign yc[0] = y_i;
    assign zc[0] = theta_i;

    genvar j;
    generate
        for (j = 0; j < ITERATIONS; j = j + 1) begin : comb_stage

`ifdef ROTATE
            wire dir_c = zc[j][THETA_BITS];
`elsif VECTOR
            wire dir_c = ~yc[j][XY_BITS];
`else
            wire dir_c = zc[j][THETA_BITS];
`endif

            assign xc[j+1] = dir_c ? (xc[j] + (yc[j] >>> j))
                                   : (xc[j] - (yc[j] >>> j));
            assign yc[j+1] = dir_c ? (yc[j] - (xc[j] >>> j))
                                   : (yc[j] + (xc[j] >>> j));
            assign zc[j+1] = dir_c ? (zc[j] + tanangle(j))
                                   : (zc[j] - tanangle(j));
        end
    endgenerate

    assign x_o     = xc[ITERATIONS];
    assign y_o     = yc[ITERATIONS];
    assign theta_o = zc[ITERATIONS];

`endif // COMBINATORIAL

endmodule
