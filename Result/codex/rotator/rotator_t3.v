module rotator
`ifndef ITERATE
#(
    parameter [`ITERATION_BITS:0] iteration = {(`ITERATION_BITS + 1){1'b0}},
    parameter signed [`THETA_BITS:0] tangle = {(`THETA_BITS + 1){1'b0}}
)
`endif
(
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

reg signed [`XY_BITS:0] x_1;
reg signed [`XY_BITS:0] y_1;
reg signed [`THETA_BITS:0] z_1;

wire signed [`XY_BITS:0] x_i_shifted;
wire signed [`XY_BITS:0] y_i_shifted;

assign x_i_shifted = x_i >>> iteration;
assign y_i_shifted = y_i >>> iteration;

assign x_o = x_1;
assign y_o = y_1;
assign z_o = z_1;

`ifdef COMBINATORIAL
always @* begin
    if (rst) begin
        x_1 = {(`XY_BITS + 1){1'b0}};
        y_1 = {(`XY_BITS + 1){1'b0}};
        z_1 = {(`THETA_BITS + 1){1'b0}};
    end
`ifdef ITERATE
    else if (init) begin
        x_1 = x_i;
        y_1 = y_i;
        z_1 = z_i;
    end
`endif
`ifdef ROTATE
    else if (z_i < 0) begin
        x_1 = x_i + y_i_shifted;
        y_1 = y_i - x_i_shifted;
        z_1 = z_i + tangle;
    end
    else begin
        x_1 = x_i - y_i_shifted;
        y_1 = y_i + x_i_shifted;
        z_1 = z_i - tangle;
    end
`elsif VECTOR
    else if (y_i > 0) begin
        x_1 = x_i - y_i_shifted;
        y_1 = y_i + x_i_shifted;
        z_1 = z_i - tangle;
    end
    else begin
        x_1 = x_i + y_i_shifted;
        y_1 = y_i - x_i_shifted;
        z_1 = z_i + tangle;
    end
`else
    else begin
        x_1 = x_i;
        y_1 = y_i;
        z_1 = z_i;
    end
`endif
end
`else
always @(posedge clk or posedge rst) begin
    if (rst) begin
        x_1 <= {(`XY_BITS + 1){1'b0}};
        y_1 <= {(`XY_BITS + 1){1'b0}};
        z_1 <= {(`THETA_BITS + 1){1'b0}};
    end
`ifdef ITERATE
    else if (init) begin
        x_1 <= x_i;
        y_1 <= y_i;
        z_1 <= z_i;
    end
`endif
`ifdef ROTATE
    else if (z_i < 0) begin
        x_1 <= x_i + y_i_shifted;
        y_1 <= y_i - x_i_shifted;
        z_1 <= z_i + tangle;
    end
    else begin
        x_1 <= x_i - y_i_shifted;
        y_1 <= y_i + x_i_shifted;
        z_1 <= z_i - tangle;
    end
`elsif VECTOR
    else if (y_i > 0) begin
        x_1 <= x_i - y_i_shifted;
        y_1 <= y_i + x_i_shifted;
        z_1 <= z_i - tangle;
    end
    else begin
        x_1 <= x_i + y_i_shifted;
        y_1 <= y_i - x_i_shifted;
        z_1 <= z_i + tangle;
    end
`else
    else begin
        x_1 <= x_i;
        y_1 <= y_i;
        z_1 <= z_i;
    end
`endif
end
`endif

endmodule
