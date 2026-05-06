module signed_shifter (
  input wire [`ITERATION_BITS-1:0] i,
  input wire signed [`XY_BITS:0] D,
  output reg signed [`XY_BITS:0] Q
);

	// ===== Configuration Macros =====
	`ifndef XY_BITS
		`define XY_BITS 16
	`endif
	`ifndef ITERATION_BITS
		`define ITERATION_BITS 4
	`endif

	// ===== Combinational Arithmetic Right-Shift Logic =====
	always @(*) begin
		// Initialize Q with unshifted input value
		Q = D;

		// Apply i one-bit arithmetic right shifts
		for (int j = 0; j < i; j = j + 1) begin
			// Shift Q right by one bit
			Q = Q >> 1;
			
			// Preserve sign bit during right shift
			// Reinsert original sign bit D[`XY_BITS] into MSB position
			Q[`XY_BITS] = D[`XY_BITS];
		end
	end

endmodule