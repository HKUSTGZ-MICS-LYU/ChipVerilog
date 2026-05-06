module rotator #(
    `ifndef ITERATE
        parameter integer iteration = 0,
        parameter signed [`THETA_BITS:0] tangle = 0
    `endif
) (
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

    reg signed [`XY_BITS:0] x_1, y_1;
    reg signed [`THETA_BITS:0] z_1;

    assign x_o = x_1;
    assign y_o = y_1;
    assign z_o = z_1;

    wire signed [`XY_BITS:0] x_i_shifted, y_i_shifted;

    assign x_i_shifted = x_i >>> iteration;
    assign y_i_shifted = y_i >>> iteration;

    wire dir;
    generate
        ifdef ROTATE
            assign dir = (x_i_shifted === 0) ? 1'b0 : ($signed(z_i) < 0) ? 1'b0 : 1'b1;
        endif
        ifdef VECTOR
            assign dir = ($signed(y_i) > 0) ? 1'b1 : 1'b0;
        endif
    endgenerate

    wire signed [`XY_BITS:0] x_update, y_update;
    wire signed [`THETA_BITS:0] z_update;

    assign x_update = dir ? (x_i - y_i_shifted) : (x_i + y_i_shifted);
    assign y_update = dir ? (y_i + x_i_shifted) : (y_i - x_i_shifted);
    assign z_update = dir ? (z_i - tangle) : (z_i + tangle);

    `ifdef COMBINATORIAL
        always @(*) begin
            if (rst) begin
                x_1 = {(`XY_BITS+1){1'b0}};
                y_1 = {(`XY_BITS+1){1'b0}};
                z_1 = {(`THETA_BITS+1){1'b0}};
            end else begin
                x_1 = x_update;
                y_1 = y_update;
                z_1 = z_update;
            end
        end
    `else
        `ifdef ITERATE
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    x_1 <= {(`XY_BITS+1){1'b0}};
                    y_1 <= {(`XY_BITS+1){1'b0}};
                    z_1 <= {(`THETA_BITS+1){1'b0}};
                end else if (init) begin
                    x_1 <= x_i;
                    y_1 <= y_i;
                    z_1 <= z_i;
                end else begin
                    x_1 <= x_update;
                    y_1 <= y_update;
                    z_1 <= z_update;
                end
            end
        `else // PIPELINE mode (no ITERATE, no COMBINATORIAL)
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    x_1 <= {(`XY_BITS+1){1'b0}};
                    y_1 <= {(`XY_BITS+1){1'b0}};
                    z_1 <= {(`THETA_BITS+1){1'b0}};
                end else begin
                    x_1 <= x_update;
                    y_1 <= y_update;
                    z_1 <= z_update;
                end
            end
        `endif
    `endif

endmodule
