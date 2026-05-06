module rotator #(
    parameter XY_BITS = 16,
    parameter THETA_BITS = 16,
    parameter ITERATION_BITS = 4
`ifndef ITERATE
    ,
    parameter [ITERATION_BITS:0] P_ITERATION = 0,
    parameter signed [THETA_BITS:0] P_TANGLE = 0
`endif
) (
    input wire clk,
    input wire rst,
`ifdef ITERATE
    input wire init,
    input wire [ITERATION_BITS:0] iteration,
    input wire signed [THETA_BITS:0] tangle,
`endif
    input wire signed  [XY_BITS:0]    x_i,
    input wire signed  [XY_BITS:0]    y_i,
    input wire signed  [THETA_BITS:0] z_i,
    output wire signed [XY_BITS:0]    x_o,
    output wire signed [XY_BITS:0]    y_o,
    output wire signed [THETA_BITS:0] z_o
);

    // Derived iteration and tangle
`ifdef ITERATE
    wire [ITERATION_BITS:0] cur_iter = iteration;
    wire signed [THETA_BITS:0] cur_tan = tangle;
`else
    wire [ITERATION_BITS:0] cur_iter = P_ITERATION;
    wire signed [THETA_BITS:0] cur_tan = P_TANGLE;
`endif

    // Shifted values
    wire signed [XY_BITS:0] x_shift = x_i >>> cur_iter;
    wire signed [XY_BITS:0] y_shift = y_i >>> cur_iter;

    // Next values for x,y,z (combinational)
    wire signed [XY_BITS:0] x_new, y_new;
    wire signed [THETA_BITS:0] z_new;

`ifdef ROTATE
    assign x_new = (z_i < 0) ? x_i + y_shift : x_i - y_shift;
    assign y_new = (z_i < 0) ? y_i - x_shift : y_i + x_shift;
    assign z_new = (z_i < 0) ? z_i + cur_tan : z_i - cur_tan;
`elsif VECTOR
    assign x_new = (y_i > 0) ? x_i + y_shift : x_i - y_shift;
    assign y_new = (y_i > 0) ? y_i - x_shift : y_i + x_shift;
    assign z_new = (y_i > 0) ? z_i + cur_tan : z_i - cur_tan;
`else
    // default to ROTATE if none defined
    assign x_new = (z_i < 0) ? x_i + y_shift : x_i - y_shift;
    assign y_new = (z_i < 0) ? y_i - x_shift : y_i + x_shift;
    assign z_new = (z_i < 0) ? z_i + cur_tan : z_i - cur_tan;
`endif

    // Internal registers
    reg signed [XY_BITS:0] x_1, y_1;
    reg signed [THETA_BITS:0] z_1;

`ifdef COMBINATORIAL
    // Combinational logic
    always @(*) begin
        if (rst) begin
            x_1 = 0;
            y_1 = 0;
            z_1 = 0;
        end else begin
            x_1 = x_new;
            y_1 = y_new;
            z_1 = z_new;
        end
    end
`else
    // Sequential logic (PIPELINE or ITERATE)
    always @(posedge clk) begin
        if (rst) begin
            x_1 <= 0;
            y_1 <= 0;
            z_1 <= 0;
        end else begin
`ifdef ITERATE
            if (init) begin
                x_1 <= x_i;
                y_1 <= y_i;
                z_1 <= z_i;
            end else begin
                x_1 <= x_new;
                y_1 <= y_new;
                z_1 <= z_new;
            end
`else
            x_1 <= x_new;
            y_1 <= y_new;
            z_1 <= z_new;
`endif
        end
    end
`endif

    // Outputs
    assign x_o = x_1;
    assign y_o = y_1;
    assign z_o = z_1;

endmodule
