`define PIPELINE
`define ROTATE
`define RADIAN_16
`define XY_BITS    16
`define THETA_BITS 16
`define ITERATIONS 16
`define ITERATION_BITS 4

// ============================================================
//  rotator — one CORDIC micro-rotation stage
// ============================================================
module rotator #(
    parameter XY_BITS        = 16,
    parameter THETA_BITS     = 16,
    parameter ITERATION_BITS = 4
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire [ITERATION_BITS-1:0]     iteration,
    input  wire signed [XY_BITS:0]       x_i,
    input  wire signed [XY_BITS:0]       y_i,
    input  wire signed [THETA_BITS:0]    z_i,
    input  wire signed [THETA_BITS:0]    atan_val,
    output reg  signed [XY_BITS:0]       x_1,
    output reg  signed [XY_BITS:0]       y_1,
    output reg  signed [THETA_BITS:0]    z_1
);

    // Arithmetic right-shifted versions of x and y
    wire signed [XY_BITS:0] x_shr = x_i >>> iteration;
    wire signed [XY_BITS:0] y_shr = y_i >>> iteration;

    always @(posedge clk) begin
        if (rst) begin
            x_1 <= 0;
            y_1 <= 0;
            z_1 <= 0;
        end else begin
`ifdef ROTATE
            // ROTATE mode: drive z toward zero using sign of z
            if (z_i[THETA_BITS]) begin
                // z is negative -> rotate CW: add shifted y, subtract shifted x, add atan
                x_1 <= x_i + y_shr;
                y_1 <= y_i - x_shr;
                z_1 <= z_i + atan_val;
            end else begin
                // z is non-negative -> rotate CCW: subtract shifted y, add shifted x, subtract atan
                x_1 <= x_i - y_shr;
                y_1 <= y_i + x_shr;
                z_1 <= z_i - atan_val;
            end
`elsif VECTOR
            // VECTOR mode: drive y toward zero using sign of y
            if (y_i[XY_BITS]) begin
                // y is negative -> rotate CW
                x_1 <= x_i + y_shr;
                y_1 <= y_i - x_shr;
                z_1 <= z_i + atan_val;
            end else begin
                // y is non-negative -> rotate CCW
                x_1 <= x_i - y_shr;
                y_1 <= y_i + x_shr;
                z_1 <= z_i - atan_val;
            end
`endif
        end
    end

endmodule


// ============================================================
//  cordic — top-level pipelined CORDIC core
// ============================================================
module cordic (
    input  wire                          clk,
    input  wire                          rst,
`ifdef ITERATE
    input  wire                          init,
`endif
    input  wire signed [`XY_BITS:0]      x_i,
    input  wire signed [`XY_BITS:0]      y_i,
    input  wire signed [`THETA_BITS:0]   theta_i,

    output wire signed [`XY_BITS:0]      x_o,
    output wire signed [`XY_BITS:0]      y_o,
    output wire signed [`THETA_BITS:0]   theta_o
`ifdef VALID_FLAG
    ,input  wire                         valid_in,
    output wire                          valid_out
`endif
);

    // ---------------------------------------------------------
    //  Arctangent lookup table  (RADIAN_16, 17-bit signed)
    //  atan(2^-i) in Q1.15 fixed-point radians, scaled to
    //  fit the 17-bit THETA_BITS+1 signed representation.
    //
    //  Values = round( atan(2^-i) / pi * 2^15 ) expressed as
    //  the same 17-bit signed word used throughout the datapath.
    //  For RADIAN_16 the LSB weight is pi/2^15 radians.
    // ---------------------------------------------------------
    function automatic signed [`THETA_BITS:0] tanangle;
        input integer i;
        begin
`ifdef RADIAN_16
            case (i)
                0:  tanangle = 17'sh0C910; // atan(2^0)  = pi/4
                1:  tanangle = 17'sh076B2; // atan(2^-1)
                2:  tanangle = 17'sh03EB7; // atan(2^-2)
                3:  tanangle = 17'sh01FD6; // atan(2^-3)
                4:  tanangle = 17'sh00FFB; // atan(2^-4)
                5:  tanangle = 17'sh007FF; // atan(2^-5)
                6:  tanangle = 17'sh00400; // atan(2^-6)
                7:  tanangle = 17'sh00200; // atan(2^-7)
                8:  tanangle = 17'sh00100; // atan(2^-8)
                9:  tanangle = 17'sh00080; // atan(2^-9)
                10: tanangle = 17'sh00040; // atan(2^-10)
                11: tanangle = 17'sh00020; // atan(2^-11)
                12: tanangle = 17'sh00010; // atan(2^-12)
                13: tanangle = 17'sh00008; // atan(2^-13)
                14: tanangle = 17'sh00004; // atan(2^-14)
                15: tanangle = 17'sh00002; // atan(2^-15)
                default: tanangle = 17'sh00000;
            endcase
`elsif DEGREE_8_8
            // Degree-format 16.8 fixed-point constants (not active)
            case (i)
                0:  tanangle = 17'sh02D00; // 45.0 degrees
                1:  tanangle = 17'sh01A00; // 26.565 degrees
                2:  tanangle = 17'sh00E00; // 14.036 degrees
                3:  tanangle = 17'sh00700; //  7.125 degrees
                4:  tanangle = 17'sh00380; //  3.576 degrees
                5:  tanangle = 17'sh001C0; //  1.790 degrees
                6:  tanangle = 17'sh000E0; //  0.895 degrees
                7:  tanangle = 17'sh00070; //  0.448 degrees
                8:  tanangle = 17'sh00038; //  0.224 degrees
                9:  tanangle = 17'sh0001C; //  0.112 degrees
                10: tanangle = 17'sh0000E; //  0.056 degrees
                11: tanangle = 17'sh00007; //  0.028 degrees
                12: tanangle = 17'sh00004; //  0.014 degrees
                13: tanangle = 17'sh00002; //  0.007 degrees
                14: tanangle = 17'sh00001; //  0.003 degrees
                15: tanangle = 17'sh00001; //  0.002 degrees
                default: tanangle = 17'sh00000;
            endcase
`endif
        end
    endfunction

    // ---------------------------------------------------------
    //  CORDIC gain constants (Q1.15 fixed-point, 17-bit signed)
    //  CORDIC_GAIN ≈ 1.6468  -> 17'sh0D413
    //  CORDIC_1    ≈ 0.6073  -> 17'sh04DBA  (inverse gain, used as x_i seed)
    // ---------------------------------------------------------
    localparam signed [`XY_BITS:0] CORDIC_GAIN = 17'sh0D413;
    localparam signed [`XY_BITS:0] CORDIC_1    = 17'sh04DBA;

`ifdef PIPELINE
    // ---------------------------------------------------------
    //  Pipeline stage wire arrays
    //  Index 0 = pipeline input, index ITERATIONS-1 = output
    // ---------------------------------------------------------
    wire signed [`XY_BITS:0]    x [`ITERATIONS-1:0];
    wire signed [`XY_BITS:0]    y [`ITERATIONS-1:0];
    wire signed [`THETA_BITS:0] z [`ITERATIONS-1:0];

    // Stage 0: connect primary inputs
    assign x[0] = x_i;
    assign y[0] = y_i;
    assign z[0] = theta_i;

    // Generate pipeline stages 0 .. ITERATIONS-2
    // (creates ITERATIONS-1 rotator instances; see spec note on loop bound)
    genvar i;
    generate
        for (i = 0; i < `ITERATIONS-1; i = i + 1) begin : stages
            rotator #(
                .XY_BITS       (`XY_BITS),
                .THETA_BITS    (`THETA_BITS),
                .ITERATION_BITS(`ITERATION_BITS)
            ) u_rot (
                .clk      (clk),
                .rst      (rst),
                .iteration(i[`ITERATION_BITS-1:0]),
                .x_i      (x[i]),
                .y_i      (y[i]),
                .z_i      (z[i]),
                .atan_val (tanangle(i)),
                .x_1      (x[i+1]),
                .y_1      (y[i+1]),
                .z_1      (z[i+1])
            );
        end
    endgenerate

    // Connect final stage to outputs
    assign x_o     = x[`ITERATIONS-1];
    assign y_o     = y[`ITERATIONS-1];
    assign theta_o = z[`ITERATIONS-1];

`ifdef VALID_FLAG
    // ---------------------------------------------------------
    //  Valid-flag pipeline  (fixed version)
    //  Shifts valid_in through a register chain so that
    //  valid_out aligns with the output data after pipeline latency.
    //  BUG FIXES applied vs. original source:
    //    1. valid_pipe declared as reg (not wire) for always-block assignment
    //    2. valid_out assignment uses '=' not a missing operator
    // ---------------------------------------------------------
    reg [`ITERATIONS-2:0] valid_pipe;
    integer k;
    always @(posedge clk) begin
        if (rst)
            valid_pipe <= 0;
        else begin
            valid_pipe[0] <= valid_in;
            for (k = 1; k < `ITERATIONS-1; k = k+1)
                valid_pipe[k] <= valid_pipe[k-1];
        end
    end
    assign valid_out = valid_pipe[`ITERATIONS-2];
`endif // VALID_FLAG

`elsif ITERATE
    // ---------------------------------------------------------
    //  Iterative architecture (single reused rotator)
    //  Active only when ITERATE is defined.
    //  init loads inputs and resets iteration counter.
    // ---------------------------------------------------------
    reg signed [`XY_BITS:0]    x_reg, y_reg;
    reg signed [`THETA_BITS:0] z_reg;          // NOTE: uses THETA_BITS; matches XY_BITS in default config
    reg [`ITERATION_BITS-1:0]  iter_cnt;

    wire signed [`XY_BITS:0]    x_fb;
    wire signed [`XY_BITS:0]    y_fb;
    wire signed [`THETA_BITS:0] z_fb;

    rotator #(
        .XY_BITS       (`XY_BITS),
        .THETA_BITS    (`THETA_BITS),
        .ITERATION_BITS(`ITERATION_BITS)
    ) u_iter_rot (
        .clk      (clk),
        .rst      (rst),
        .iteration(iter_cnt),
        .x_i      (x_reg),
        .y_i      (y_reg),
        .z_i      (z_reg),
        .atan_val (tanangle(iter_cnt)),
        .x_1      (x_fb),
        .y_1      (y_fb),
        .z_1      (z_fb)
    );

    always @(posedge clk) begin
        if (rst) begin
            x_reg    <= 0;
            y_reg    <= 0;
            z_reg    <= 0;
            iter_cnt <= 0;
        end else if (init) begin
            x_reg    <= x_i;
            y_reg    <= y_i;
            z_reg    <= theta_i;
            iter_cnt <= 0;
        end else if (iter_cnt < `ITERATIONS-1) begin
            x_reg    <= x_fb;
            y_reg    <= y_fb;
            z_reg    <= z_fb;
            iter_cnt <= iter_cnt + 1;
        end
    end

    assign x_o     = x_reg;
    assign y_o     = y_reg;
    assign theta_o = z_reg;

`elsif COMBINATORIAL
    // ---------------------------------------------------------
    //  Combinatorial architecture (all stages cascaded with no registers)
    // ---------------------------------------------------------
    wire signed [`XY_BITS:0]    xc [`ITERATIONS:0];
    wire signed [`THETA_BITS:0] zc [`ITERATIONS:0];
    wire signed [`XY_BITS:0]    yc [`ITERATIONS:0];

    assign xc[0] = x_i;
    assign yc[0] = y_i;
    assign zc[0] = theta_i;

    genvar ci;
    generate
        for (ci = 0; ci < `ITERATIONS; ci = ci + 1) begin : comb_stages
            wire signed [`XY_BITS:0]    xs = xc[ci] >>> ci;
            wire signed [`XY_BITS:0]    ys = yc[ci] >>> ci;
`ifdef ROTATE
            assign xc[ci+1] = zc[ci][`THETA_BITS] ? xc[ci] + ys : xc[ci] - ys;
            assign yc[ci+1] = zc[ci][`THETA_BITS] ? yc[ci] - xs : yc[ci] + xs;
            assign zc[ci+1] = zc[ci][`THETA_BITS] ? zc[ci] + tanangle(ci) : zc[ci] - tanangle(ci);
`elsif VECTOR
            assign xc[ci+1] = yc[ci][`XY_BITS] ? xc[ci] + ys : xc[ci] - ys;
            assign yc[ci+1] = yc[ci][`XY_BITS] ? yc[ci] - xs : yc[ci] + xs;
            assign zc[ci+1] = yc[ci][`XY_BITS] ? zc[ci] + tanangle(ci) : zc[ci] - tanangle(ci);
`endif
        end
    endgenerate

    assign x_o     = xc[`ITERATIONS];
    assign y_o     = yc[`ITERATIONS];
    assign theta_o = zc[`ITERATIONS];

`endif // architecture select

endmodule