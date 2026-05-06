// cordic.v
// Configurable CORDIC core.
// Current configuration: PIPELINE, ROTATE, RADIAN_16
// THETA_BITS = 16, XY_BITS = 16, ITERATIONS = 16

`timescale 1ns / 1ps

module cordic #(
    parameter XY_BITS = 16,
    parameter THETA_BITS = 16,
    parameter ITERATIONS = 16,
    parameter ITERATION_BITS = 4,
    // CORDIC gain and inverse gain constants for XY_BITS=16
    // CORDIC_GAIN ≈ 1.64676, CORDIC_1 ≈ 0.607253
    // Scaled to 16-bit signed fixed-point (1 sign bit, 15 fractional bits)
    parameter signed [XY_BITS:0] CORDIC_1 = 17'd49742  // 0.607253 * 2^15
) (
    input wire clk,
    input wire rst,
    input wire signed [XY_BITS:0] x_i,
    input wire signed [XY_BITS:0] y_i,
    input wire signed [THETA_BITS:0] theta_i,
    output wire signed [XY_BITS:0] x_o,
    output wire signed [XY_BITS:0] y_o,
    output wire signed [THETA_BITS:0] theta_o
);

    // ------------------------------------------------------------------------
    // Arctangent lookup table
    // Precomputed values of atan(2^-i) for i=0..ITERATIONS-1
    // Format: signed fixed-point radian, THETA_BITS+1 bits
    // With THETA_BITS=16, PI/2 ≈ 16'h6487 (25735)
    // ------------------------------------------------------------------------
    function signed [THETA_BITS:0] tanangle;
        input [ITERATION_BITS-1:0] i;
        begin
            case (i)
                0: tanangle = 17'd25735; // atan(2^0)   = 45.000°  = 0.785398 rad
                1: tanangle = 17'd15192; // atan(2^-1)  = 26.565°  = 0.463648 rad
                2: tanangle = 17'd8027;  // atan(2^-2)  = 14.036°  = 0.244979 rad
                3: tanangle = 17'd4074;  // atan(2^-3)  = 7.125°   = 0.124355 rad
                4: tanangle = 17'd2041;  // atan(2^-4)  = 3.576°   = 0.062419 rad
                5: tanangle = 17'd1021;  // atan(2^-5)  = 1.790°   = 0.031240 rad
                6: tanangle = 17'd510;   // atan(2^-6)  = 0.895°   = 0.015624 rad
                7: tanangle = 17'd255;   // atan(2^-7)  = 0.448°   = 0.007812 rad
                8: tanangle = 17'd127;   // atan(2^-8)  = 0.224°   = 0.003906 rad
                9: tanangle = 17'd63;    // atan(2^-9)  = 0.112°   = 0.001953 rad
                10: tanangle = 17'd31;   // atan(2^-10) = 0.056°   = 0.000977 rad
                11: tanangle = 17'd15;   // atan(2^-11) = 0.028°   = 0.000488 rad
                12: tanangle = 17'd7;    // atan(2^-12) = 0.014°   = 0.000244 rad
                13: tanangle = 17'd3;    // atan(2^-13) = 0.007°   = 0.000122 rad
                14: tanangle = 17'd1;    // atan(2^-14) = 0.0035°  = 0.000061 rad
                15: tanangle = 17'd0;    // atan(2^-15) = 0.0017°  = 0.000031 rad
                default: tanangle = 17'd0;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // Pipeline stage arrays
    // ------------------------------------------------------------------------
    reg signed [XY_BITS:0] x_pipe [0:ITERATIONS];
    reg signed [XY_BITS:0] y_pipe [0:ITERATIONS];
    reg signed [THETA_BITS:0] z_pipe [0:ITERATIONS];

    // ------------------------------------------------------------------------
    // Pipeline stage 0: load input
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_pipe[0] <= 0;
            y_pipe[0] <= 0;
            z_pipe[0] <= 0;
        end else begin
            x_pipe[0] <= x_i;
            y_pipe[0] <= y_i;
            z_pipe[0] <= theta_i;
        end
    end

    // ------------------------------------------------------------------------
    // Pipeline stages 1 through ITERATIONS
    // Each stage implements one CORDIC micro-rotation (ROTATE mode)
    // ------------------------------------------------------------------------
    genvar stage;
    generate
        for (stage = 0; stage < ITERATIONS; stage = stage + 1) begin : cordic_stage
            wire signed [XY_BITS:0] x_in = x_pipe[stage];
            wire signed [XY_BITS:0] y_in = y_pipe[stage];
            wire signed [THETA_BITS:0] z_in = z_pipe[stage];
            wire signed [XY_BITS:0] x_shifted;
            wire signed [XY_BITS:0] y_shifted;
            wire signed [THETA_BITS:0] atan_val;

            // Arithmetic right shift by stage index
            // stage is 0-based here, corresponding to iteration i=stage
            assign x_shifted = (stage < XY_BITS) ? (x_in >>> stage) : {XY_BITS+1{x_in[XY_BITS]}};
            assign y_shifted = (stage < XY_BITS) ? (y_in >>> stage) : {XY_BITS+1{y_in[XY_BITS]}};

            assign atan_val = tanangle(stage[ITERATION_BITS-1:0]);

            // ROTATE mode: direction determined by sign of z_in
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    x_pipe[stage+1] <= 0;
                    y_pipe[stage+1] <= 0;
                    z_pipe[stage+1] <= 0;
                end else begin
                    if (z_in[THETA_BITS]) begin // z_in negative
                        x_pipe[stage+1] <= x_in + y_shifted;
                        y_pipe[stage+1] <= y_in - x_shifted;
                        z_pipe[stage+1] <= z_in + atan_val;
                    end else begin
                        x_pipe[stage+1] <= x_in - y_shifted;
                        y_pipe[stage+1] <= y_in + x_shifted;
                        z_pipe[stage+1] <= z_in - atan_val;
                    end
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------------------
    // Output assignments: final stage values
    // ------------------------------------------------------------------------
    assign x_o = x_pipe[ITERATIONS];
    assign y_o = y_pipe[ITERATIONS];
    assign theta_o = z_pipe[ITERATIONS];

endmodule
