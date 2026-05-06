// IF_stage module for MIPS_16 processor
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

	// Internal wires
	wire [`PC_WIDTH-1:0] next_pc;
	wire [`PC_WIDTH-1:0] branch_offset_ext;
	wire [`PC_WIDTH-1:0] pc_plus_1;
	wire [`PC_WIDTH-1:0] branch_target;

	// Sign extend 6-bit branch offset to PC_WIDTH
	assign branch_offset_ext = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

	// Compute sequential next PC and branch target
	assign pc_plus_1 = pc + 1;
	assign branch_target = pc + branch_offset_ext;

	// Determine next PC value
	assign next_pc = (branch_taken && instruction_fetch_en) ? branch_target :
	                 (instruction_fetch_en) ? pc_plus_1 : pc;

	// Program counter register
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			pc <= {`PC_WIDTH{1'b0}};
		end else begin
			pc <= next_pc;
		end
	end

	// Instruction memory instantiation
	instruction_mem imem (
		.pc(pc),
		.instruction(instruction)
	);

endmodule
