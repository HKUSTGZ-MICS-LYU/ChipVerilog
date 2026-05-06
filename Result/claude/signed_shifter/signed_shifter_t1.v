// =============================================================================
// signed_shifter.v
// Variable arithmetic right-shift for signed CORDIC datapath values.
//
// Used by the rotator module to compute x_i_shifted and y_i_shifted, which
// implement the CORDIC scaling factor 1/2^i for iteration i.
//
// The shift is performed one bit at a time in a combinational loop.
// On every step the original sign bit D[`XY_BITS] is reinserted into the MSB
// so that sign extension is correctly maintained for negative fixed-point
// values throughout the full shift range.
//
// No clock, reset, or sequential state — purely combinational.
// =============================================================================

module signed_shifter (
    input  wire [`ITERATION_BITS-1:0] i,   // shift amount (current iteration index)
    input  wire signed [`XY_BITS:0]   D,   // signed datapath value to shift
    output reg  signed [`XY_BITS:0]   Q    // arithmetically shifted result
);

    integer j;  // loop variable

    always @(*) begin
        // Initialise Q with the unshifted input value
        Q = D;

        // Repeatedly shift right by one bit, reinserting the original sign bit
        // at the MSB on every step to preserve signed (arithmetic) behaviour.
        for (j = 0; j < i; j = j + 1) begin
            Q = {D[`XY_BITS], Q[`XY_BITS:1]};
        end
    end

endmodule
