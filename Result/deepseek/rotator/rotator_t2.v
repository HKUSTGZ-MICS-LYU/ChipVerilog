`include "signed_shifter.v"

module rotator (
    input wire clk,
    input wire rst,
    `ifdef ITERATE
    input wire init,
    input wire [`ITERATION_BITS:0] iteration,
    input wire signed [`THETA_BITS:0] tangle,
    `endif
    input wire signed  [`XY_BITS:0]    x_i,
    input wire signed  [`XY_BITS:0]    y_i,
    input wire signed  [`THETA_BITS:0] z_i,
    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] z_o
    );

    // Internal registers
    reg signed [`XY_BITS:0]    x_1;
    reg signed [`XY_BITS:0]    y_1;
    reg signed [`THETA_BITS:0] z_1;

    // Shifted versions
    wire signed [`XY_BITS:0] x_i_shifted;
    wire signed [`XY_BITS:0] y_i_shifted;

    `ifdef ITERATE
        wire [`ITERATION_BITS:0] shift_amount = iteration;
    `else
        // For PIPELINE or COMBINATORIAL, iteration and tangle are parameters
        // from the generate loop, given as parameters to this module.
        // We expect them to be passed as parameters.
        parameter [`ITERATION_BITS:0] iteration = 0;
        parameter signed [`THETA_BITS:0] tangle = 0;
        wire [`ITERATION_BITS:0] shift_amount = iteration;
    `endif

    // Instantiate signed shifters
    signed_shifter #(.WIDTH(`XY_BITS+1), .SHIFT_BITS(`ITERATION_BITS+1))
        shifter_x (.data_in(x_i), .shift(shift_amount), .data_out(x_i_shifted));

    signed_shifter #(.WIDTH(`XY_BITS+1), .SHIFT_BITS(`ITERATION_BITS+1))
        shifter_y (.data_in(y_i), .shift(shift_amount), .data_out(y_i_shifted));

    // Determine direction
    wire rotate_mode  = `ifdef ROTATE 1 `else 0 `endif;
    wire vector_mode  = `ifdef VECTOR 1 `else 0 `endif;

    wire direction;
    `ifdef ROTATE
        // Use sign of z_i: negative z_i -> direction = 1 (add tangle)
        assign direction = z_i[`THETA_BITS];
    `elsif VECTOR
        // Use sign of y_i: positive y_i -> direction = 0 (subtract tangle)
        assign direction = ~y_i[`XY_BITS];
    `else
        // Default direction to 0 if neither defined
        assign direction = 1'b0;
    `endif

    // Compute next values
    wire signed [`XY_BITS:0] next_x, next_y;
    wire signed [`THETA_BITS:0] next_z;

    assign next_x = direction ? (x_i + y_i_shifted) : (x_i - y_i_shifted);
    assign next_y = direction ? (y_i - x_i_shifted) : (y_i + x_i_shifted);
    assign next_z = direction ? (z_i + tangle) : (z_i - tangle);

    // Update registers
    always @(posedge clk or posedge rst) begin
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
                    x_1 <= next_x;
                    y_1 <= next_y;
                    z_1 <= next_z;
                end
            `else
                `ifdef COMBINATORIAL
                    // In COMBINATORIAL mode, update is combinational, not clocked.
                    // But the spec says "the same reset branch is still present in the source",
                    // so we keep the reset logic, but the actual update is continuous.
                    // We'll handle the combinatorial assignment outside the always block.
                `else
                    // PIPELINE mode
                    x_1 <= next_x;
                    y_1 <= next_y;
                    z_1 <= next_z;
                `endif
            `endif
        end
    end

    `ifdef COMBINATORIAL
        // In COMBINATORIAL mode, x_1, y_1, z_1 are directly driven by combinational logic,
        // with reset overriding.
        always @* begin
            if (rst) begin
                x_1 = 0;
                y_1 = 0;
                z_1 = 0;
            end else begin
                x_1 = next_x;
                y_1 = next_y;
                z_1 = next_z;
            end
        end
    `endif

    // Output assignments
    assign x_o = x_1;
    assign y_o = y_1;
    assign z_o = z_1;

endmodule
