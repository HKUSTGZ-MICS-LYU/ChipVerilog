`define ROTATE
`endif
`endif

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

    // Shifted values
    wire signed [`XY_BITS:0] x_i_shifted;
    wire signed [`XY_BITS:0] y_i_shifted;

    // Shift amount
`ifdef ITERATE
    wire [`ITERATION_BITS:0] shift_amt = iteration;
`else
    wire [`ITERATION_BITS:0] shift_amt = `ITERATION;
`endif

    // Arithmetic right shifts
    assign x_i_shifted = x_i >>> shift_amt;
    assign y_i_shifted = y_i >>> shift_amt;

    // Control signal for rotation direction
    wire direction;

`ifdef ROTATE
    // Use sign of z_i
    assign direction = z_i[`THETA_BITS]; // sign bit
`else
    // VECTOR mode: use sign of y_i
    assign direction = y_i[`XY_BITS]; // sign bit
`endif

    // Next values logic
    wire signed [`XY_BITS:0]    x_next, y_next;
    wire signed [`THETA_BITS:0] z_next;

    // For z_i sign: if direction=1 (negative), we add tangle; else subtract
    // For ROTATE: direction = sign(z_i) -> negative => add, positive => subtract
    // For VECTOR: direction = sign(y_i) -> positive => subtract, negative => add
    // The equations in spec:
    // ROTATE:
    //   if z_i negative: x_o = x_i + y_i_shifted, y_o = y_i - x_i_shifted, z_o = z_i + tangle
    //   else:            x_o = x_i - y_i_shifted, y_o = y_i + x_i_shifted, z_o = z_i - tangle
    // VECTOR:
    //   if y_i positive: same as positive-angle correction path (the else path above)
    //   else:            opposite (the if path above)
    // So mapping:
    // ROTATE: dir = sign(z_i)  -> dir=1 => negative => use + for z and + for x with y_shifted? Wait: spec: negative => x_o = x_i + y_i_shifted, y_o = y_i - x_i_shifted, z_o = z_i + tangle.
    //          dir=0 => positive => x_o = x_i - y_i_shifted, y_o = y_i + x_i_shifted, z_o = z_i - tangle.
    // VECTOR: dir = sign(y_i)  -> dir=0 => positive => use "positive-angle correction path" which is the else path above: x_i - y_i_shifted, y_i + x_i_shifted, z_i - tangle.
    //          dir=1 => negative => use opposite (the if path above): x_i + y_i_shifted, y_i - x_i_shifted, z_i + tangle.
    // So the logic is consistent: direction=1 selects the "add y_shifted, sub x_shifted, add tangle" path; direction=0 selects the opposite.
    // Let's verify:
    // ROTATE: direction = z_i[THETA_BITS] (1 if negative). Correct mapping as above.
    // VECTOR: direction = y_i[XY_BITS] (1 if negative). Then for VECTOR negative y_i, spec says opposite update (the if path). That matches direction=1 selecting the add path.
    // For VECTOR positive y_i, direction=0 selects the sub path. Matches spec.
    // So we can unify.

    assign x_next = direction ? (x_i + y_i_shifted) : (x_i - y_i_shifted);
    assign y_next = direction ? (y_i - x_i_shifted) : (y_i + x_i_shifted);
`ifdef ITERATE
    assign z_next = direction ? (z_i + tangle) : (z_i - tangle);
`else
    assign z_next = direction ? (z_i + `TANGLE) : (z_i - `TANGLE);
`endif

    // Registered or combinational update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_1 <= 0;
            y_1 <= 0;
            z_1 <= 0;
        end else begin
`ifdef COMBINATORIAL
            // In COMBINATORIAL, no clock, but the source uses same reset branch. 
            // However, sequential always block with posedge clk cannot be combinational.
            // We'll handle COMBINATORIAL separately.
`else
`ifdef ITERATE
            if (init) begin
                x_1 <= x_i;
                y_1 <= y_i;
                z_1 <= z_i;
            end else begin
                x_1 <= x_next;
                y_1 <= y_next;
                z_1 <= z_next;
            end
`else
            // PIPELINE mode: no init, always update
            x_1 <= x_next;
            y_1 <= y_next;
            z_1 <= z_next;
`endif
`endif
        end
    end

`ifdef COMBINATORIAL
    // Combinational update with reset
    always @* begin
        if (rst) begin
            x_1 = 0;
            y_1 = 0;
            z_1 = 0;
        end else begin
            x_1 = x_next;
            y_1 = y_next;
            z_1 = z_next;
        end
    end
`endif

    // Output assignments
    assign x_o = x_1;
    assign y_o = y_1;
    assign z_o = z_1;

endmodule
