module cordic (
    input wire clk,
    input wire rst,
    input wire signed [`XY_BITS:0]    x_i,
    input wire signed [`XY_BITS:0]    y_i,
    input wire signed [`THETA_BITS:0] theta_i,
    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] theta_o
);

parameter THETA_BITS = 16;
parameter XY_BITS = 16;
parameter ITERATIONS = 16;
parameter ITERATION_BITS = 4;

// Inverse CORDIC gain constant for 16 iterations: 1/gain ≈ 0.607252935
// In radian format with 2^15 scaling: 0.607252935 * 32768 = 19897 (0x4DB9)
parameter CORDIC_GAIN = 1.646760258;
parameter CORDIC_1 = 19897;

// Internal arrays for pipeline registers
reg signed [XY_BITS:0]    x_pipe [0:ITERATIONS];
reg signed [XY_BITS:0]    y_pipe [0:ITERATIONS];
reg signed [THETA_BITS:0] z_pipe [0:ITERATIONS];

// Function to return precomputed arctangent constant for given iteration
function signed [THETA_BITS:0] atan_table;
    input integer iteration;
    begin
        case (iteration)
            0: atan_table = 16'h6488;  // atan(1) * 2^15
            1: atan_table = 16'h3B59;  // atan(0.5)
            2: atan_table = 16'h1F5B;  // atan(0.25)
            3: atan_table = 16'h0FEB;  // atan(0.125)
            4: atan_table = 16'h07FD;  // atan(0.0625)
            5: atan_table = 16'h03FF;  // atan(0.03125)
            6: atan_table = 16'h0200;  // atan(0.015625)
            7: atan_table = 16'h0100;  // atan(0.0078125)
            8: atan_table = 16'h0080;  // atan(0.00390625)
            9: atan_table = 16'h0040;  // atan(0.001953125)
            10: atan_table = 16'h0020; // atan(0.0009765625)
            11: atan_table = 16'h0010; // atan(0.00048828125)
            12: atan_table = 16'h0008; // atan(0.000244140625)
            13: atan_table = 16'h0004; // atan(0.0001220703125)
            14: atan_table = 16'h0002; // atan(0.00006103515625)
            15: atan_table = 16'h0001; // atan(0.000030517578125)
            default: atan_table = 0;
        endcase
    end
endfunction

// Pipeline control
integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i <= ITERATIONS; i = i + 1) begin
            x_pipe[i] <= 0;
            y_pipe[i] <= 0;
            z_pipe[i] <= 0;
        end
    end else begin
        // Input stage
        x_pipe[0] <= x_i;
        y_pipe[0] <= y_i;
        z_pipe[0] <= theta_i;

        // CORDIC micro-rotation stages
        for (i = 0; i < ITERATIONS; i = i + 1) begin
            if (z_pipe[i] < 0) begin
                x_pipe[i+1] <= x_pipe[i] + (y_pipe[i] >>> i);
                y_pipe[i+1] <= y_pipe[i] - (x_pipe[i] >>> i);
                z_pipe[i+1] <= z_pipe[i] + atan_table(i);
            end else begin
                x_pipe[i+1] <= x_pipe[i] - (y_pipe[i] >>> i);
                y_pipe[i+1] <= y_pipe[i] + (x_pipe[i] >>> i);
                z_pipe[i+1] <= z_pipe[i] - atan_table(i);
            end
        end
    end
end

assign x_o = x_pipe[ITERATIONS];
assign y_o = y_pipe[ITERATIONS];
assign theta_o = z_pipe[ITERATIONS];

endmodule
