//=============================================================================
// Module: signed_shifter
// Description: Variable arithmetic right-shift for signed CORDIC datapath.
//              Shifts input D right by i bit positions while preserving 
//              the sign bit. Implements the CORDIC scaling term 1/2^i.
//
// Notes:
//   - Pure combinational logic (no clock, no reset)
//   - Used by rotator module to generate x_i_shifted and y_i_shifted
//   - Sign extension is critical for correct signed arithmetic behavior
//=============================================================================

module signed_shifter (
    input  wire [`ITERATION_BITS-1:0] i,   // Shift amount (CORDIC iteration index)
    input  wire signed [`XY_BITS:0]   D,   // Signed input value to be shifted
    output reg  signed [`XY_BITS:0]   Q    // Signed arithmetic right-shifted output
);

    // Loop index for the shift iterations
    integer j;

    //-------------------------------------------------------------------------
    // Combinational arithmetic right shift
    //
    // Algorithm:
    //   1. Initialize Q with the unshifted input D
    //   2. For each step from 0 to i-1, shift Q right by one bit
    //   3. After each one-bit shift, reinsert the original sign bit
    //      D[`XY_BITS] into the MSB position of Q to preserve the
    //      signed value during arithmetic right shift
    //-------------------------------------------------------------------------
    always @(*) begin
        // Step 1: Start with the unshifted input value
        Q = D;

        // Step 2: Apply i one-bit arithmetic right shifts
        for (j = 0; j < i; j = j + 1) begin
            // Shift Q right by one bit (logical shift)
            Q = Q >> 1;
            // Step 3: Reinsert the original sign bit into the MSB
            //         to maintain signed arithmetic behavior
            Q[`XY_BITS] = D[`XY_BITS];
        end
    end

endmodule