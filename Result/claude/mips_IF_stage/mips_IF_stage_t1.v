module IF_stage
(
	input							clk,
	input							rst,				//active high
	input							instruction_fetch_en,
	
	input	[5:0]					branch_offset_imm,
	input							branch_taken,
	
	output	reg	[`PC_WIDTH-1:0]		pc,
	output	[15:0]					instruction
);

	// ===== PC Width Configuration =====
	// PC_WIDTH is typically defined in mips_16_defs.v
	// Default value supports 16-bit addresses (2^16 instruction memory locations)
	`ifndef PC_WIDTH
		`define PC_WIDTH 16
	`endif

	// ===== Sign-Extended Branch Offset =====
	// Extend 6-bit branch immediate to PC width with sign extension
	wire [`PC_WIDTH-1:0] sign_extended_branch_offset;
	assign sign_extended_branch_offset = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

	// ===== Next PC Calculation =====
	// Two cases: branch taken or sequential fetch
	wire [`PC_WIDTH-1:0] next_pc;
	assign next_pc = branch_taken ? (pc + sign_extended_branch_offset) : (pc + 1'b1);

	// ===== Instruction Memory Instance =====
	instruction_mem imem (
		.address(pc),
		.instruction(instruction)
	);

	// ===== Program Counter Update Logic =====
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous active-high reset
			// Clear PC to zero, causing instruction fetch to restart from address 0
			pc <= {`PC_WIDTH{1'b0}};
		end
		else if (instruction_fetch_en) begin
			// Update PC only when instruction fetch is enabled
			// This allows IF_stage to be frozen during pipeline stalls
			pc <= next_pc;
		end
		// If instruction_fetch_en is low, PC holds current value (pipeline stall)
	end

endmodule