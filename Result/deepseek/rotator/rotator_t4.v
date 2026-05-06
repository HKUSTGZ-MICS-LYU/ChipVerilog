module rotator (
    input wire clk,
    input wire rst,
`ifdef ITERATE
    input wire init,
    input wire [`ITERATION_BITS:0] iteration,
    input wire signed [`THETA_BITS:0] tangle,
`endif
    input wire signed [`XY_BITS:0] x_i,
    input wire signed [`XY_BITS:0] y_i,
    input wire signed [`THETA_BITS:0] z_i,
    output wire signed [`XY_BITS:0] x_o,
    output wire signed [`XY_BITS:0] y_o,
    output wire signed [`THETA_BITS:0] z_o
);

`ifndef ITERATE
    parameter integer iteration = 0;
    parameter signed [`THETA_BITS:0] tangle = 0;
`endif

// Shifted values
wire signed [`XY_BITS:0] x_i_shifted;
wire signed [`XY_BITS:0] y_i_shifted;
assign x_i_shifted = x_i >>> iteration;
assign y_i_shifted = y_i >>> iteration;

// Direction selection
wire dir;
`ifdef ROTATE
    assign dir = (z_i >= 0) ? 1'b0 : 1'b1;
`elsif VECTOR
    assign dir = (y_i > 0) ? 1'b0 : 1'b1;
`else
    assign dir = 1'b0;
`endif

// Next state values
wire signed [`XY_BITS:0] next_x;
wire signed [`XY_BITS:0] next_y;
wire signed [`THETA_BITS:0] next_z;
assign next_x = dir ? (x_i + y_i_shifted) : (x_i - y_i_shifted);
assign next_y = dir ? (y_i - x_i_shifted) : (y_i + x_i_shifted);
assign next_z = dir ? (z_i + tangle) : (z_i - tangle);

// Internal registers / wires
reg signed [`XY_BITS:0] x_1;
reg signed [`XY_BITS:0] y_1;
reg signed [`THETA_BITS:0] z_1;

`ifdef COMBINATORIAL
    always @(*) begin
        if (rst) begin
            x_1 = {(`XY_BITS+1){1'b0}};
            y_1 = {(`XY_BITS+1){1'b0}};
            z_1 = {(`THETA_BITS+1){1'b0}};
        end
        else begin
`ifdef ITERATE
            if (init) begin
                x_1 = x_i;
                y_1 = y_i;
                z_1 = z_i;
            end
            else begin
`endif
                x_1 = next_x;
                y_1 = next_y;
                z_1 = next_z;
`ifdef ITERATE
            end
`endif
        end
    end
`else // sequential
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_1 <= {(`XY_BITS+1){1'b0}};
            y_1 <= {(`XY_BITS+1){1'b0}};
            z_1 <= {(`THETA_BITS+1){1'b0}};
        end
        else begin
`ifdef ITERATE
            if (init) begin
                x_1 <= x_i;
                y_1 <= y_i;
                z_1 <= z_i;
            end
            else begin
`endif
                x_1 <= next_x;
                y_1 <= next_y;
                z_1 <= next_z;
`ifdef ITERATE
            end
`endif
        end
    end
`endif

// Output assignments
assign x_o = x_1;
assign y_o = y_1;
assign z_o = z_1;

endmodule
