module rotator (
    input wire clk,
    input wire rst,
    `ifdef ITERATE
    input wire init,
    input wire [`ITERATION_BITS-1:0] iteration,
    input wire signed [`THETA_BITS:0] tangle,
    `endif
    input wire signed  [`XY_BITS:0]    x_i,
    input wire signed  [`XY_BITS:0]    y_i,
    input wire signed  [`THETA_BITS:0] z_i,
    output wire signed [`XY_BITS:0]    x_o,
    output wire signed [`XY_BITS:0]    y_o,
    output wire signed [`THETA_BITS:0] z_o
);

	// ===== Configuration Macros =====
	`ifndef XY_BITS
		`define XY_BITS 16
	`endif
	`ifndef THETA_BITS
		`define THETA_BITS 16
	`endif
	`ifndef ITERATION_BITS
		`define ITERATION_BITS 4
	`endif

	// ===== Architecture Selection =====
	`define PIPELINE  // Active by default
	// `define ITERATE
	// `define COMBINATORIAL

	// ===== Function Mode Selection =====
	`define ROTATE    // Active by default
	// `define VECTOR

	// ===== Internal Registers (Result Storage) =====
	reg signed [`XY_BITS:0]    x_1;
	reg signed [`XY_BITS:0]    y_1;
	reg signed [`THETA_BITS:0] z_1;

	// ===== Continuous Assignment of Outputs =====
	assign x_o = x_1;
	assign y_o = y_1;
	assign z_o = z_1;

	// ===== Shifted Operand Generation =====
	// Compute x_i_shifted and y_i_shifted using arithmetic right shifts
	// The shift amount is determined by the current iteration index
	
	`ifdef ITERATE
		// In ITERATE mode, iteration is a dynamic input port
		wire signed [`XY_BITS:0] x_i_shifted;
		wire signed [`XY_BITS:0] y_i_shifted;
		
		assign x_i_shifted = x_i >>> iteration;
		assign y_i_shifted = y_i >>> iteration;
	`else
		// In PIPELINE and COMBINATORIAL modes, iteration is a parameter
		// Use parameter-based shift which may be optimized to hardwired shifts
		wire signed [`XY_BITS:0] x_i_shifted;
		wire signed [`XY_BITS:0] y_i_shifted;
		
		`ifdef PIPELINE
			parameter [`ITERATION_BITS-1:0] iteration = 4'h0;
			parameter signed [`THETA_BITS:0] tangle = {(`THETA_BITS+1){1'b0}};
		`endif
		
		assign x_i_shifted = x_i >>> iteration;
		assign y_i_shifted = y_i >>> iteration;
	`endif

	// ===== Updated Value Computation (Before Registration) =====
	reg signed [`XY_BITS:0]    x_next;
	reg signed [`XY_BITS:0]    y_next;
	reg signed [`THETA_BITS:0] z_next;

	// Determine rotation direction and compute updated values
	always @(*) begin
		// Default: no rotation (hold current values)
		x_next = x_i;
		y_next = y_i;
		z_next = z_i;

		`ifdef ROTATE
			// ROTATE mode: Use sign of angle accumulator z_i
			// If z_i is negative (MSB = 1), rotate in positive direction
			// If z_i is non-negative (MSB = 0), rotate in negative direction
			if (z_i[`THETA_BITS]) begin  // z_i is negative
				// Rotate in positive direction: add arctangent
				x_next = x_i + y_i_shifted;
				y_next = y_i - x_i_shifted;
				z_next = z_i + tangle;
			end
			else begin  // z_i is non-negative
				// Rotate in negative direction: subtract arctangent
				x_next = x_i - y_i_shifted;
				y_next = y_i + x_i_shifted;
				z_next = z_i - tangle;
			end

		`elsif defined(VECTOR)
			// VECTOR mode: Use sign of y component
			// If y_i is negative (MSB = 1), apply one direction
			// If y_i is non-negative (MSB = 0), apply opposite direction
			if (y_i[`XY_BITS]) begin  // y_i is negative
				// Rotate to drive y toward zero (same as negative z case in ROTATE)
				x_next = x_i + y_i_shifted;
				y_next = y_i - x_i_shifted;
				z_next = z_i + tangle;
			end
			else begin  // y_i is non-negative
				// Rotate to drive y toward zero (same as non-negative z case in ROTATE)
				x_next = x_i - y_i_shifted;
				y_next = y_i + x_i_shifted;
				z_next = z_i - tangle;
			end

		`else
			// Default to ROTATE mode if neither is defined
			if (z_i[`THETA_BITS]) begin
				x_next = x_i + y_i_shifted;
				y_next = y_i - x_i_shifted;
				z_next = z_i + tangle;
			end
			else begin
				x_next = x_i - y_i_shifted;
				y_next = y_i + x_i_shifted;
				z_next = z_i - tangle;
			end
		`endif
	end

	// ===== Sequential Logic for Result Registration =====
	`ifdef COMBINATORIAL
		// COMBINATORIAL mode: Output is combinational (no clock)
		// Note: reset is still honored through the combinational path
		always @(*) begin
			if (rst) begin
				// Clear outputs on reset
				x_1 = {(`XY_BITS+1){1'b0}};
				y_1 = {(`XY_BITS+1){1'b0}};
				z_1 = {(`THETA_BITS+1){1'b0}};
			end
			else begin
				// Use computed next values directly (combinational)
				x_1 = x_next;
				y_1 = y_next;
				z_1 = z_next;
			end
		end

	`else
		// PIPELINE and ITERATE modes: Clocked update
		always @(posedge clk) begin
			if (rst) begin
				// Synchronous reset: clear internal registers
				x_1 <= {(`XY_BITS+1){1'b0}};
				y_1 <= {(`XY_BITS+1){1'b0}};
				z_1 <= {(`THETA_BITS+1){1'b0}};
			end
			`ifdef ITERATE
			else if (init) begin
				// ITERATE mode: init signal loads initial values
				// Bypasses CORDIC update to load starting values
				x_1 <= x_i;
				y_1 <= y_i;
				z_1 <= z_i;
			end
			`endif
			else begin
				// Normal CORDIC update: load computed next values
				// Implement one CORDIC micro-rotation step
				x_1 <= x_next;
				y_1 <= y_next;
				z_1 <= z_next;
			end
		end

	`endif

endmodule