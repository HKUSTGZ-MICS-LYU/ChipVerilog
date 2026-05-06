module ID_stage
(
	input					clk,
	input					rst,
	input					instruction_decode_en,
	
	// to EX_stage
	output	reg	[56:0]		pipeline_reg_out,	//	[56:54],3bits:	alu_cmd[2:0]
												//	[53:38],16bits:	alu_src1[15:0]
												//	[37:22],16bits:	alu_src2[15:0]
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to IF_stage
	input		[15:0]		instruction,
	output		[5:0]		branch_offset_imm,
	output	reg				branch_taken,
	
	// to register file
	output		[2:0]		reg_read_addr_1,	// register file read port 1 address
	output		[2:0]		reg_read_addr_2,	// register file read port 2 address
	input		[15:0]		reg_read_data_1,	// register file read port 1 data
	input		[15:0]		reg_read_data_2,	// register file read port 2 data
	
	// to hazard detection unit
	output		[2:0]		decoding_op_src1,		//source_1 register number
	output		[2:0]		decoding_op_src2		//source_2 register number
);

	// ===== Instruction Encoding Definitions =====
	// Opcodes (4 bits)
	localparam OP_NOP  = 4'b0000;
	localparam OP_ADD  = 4'b0001;
	localparam OP_SUB  = 4'b0010;
	localparam OP_AND  = 4'b0011;
	localparam OP_OR   = 4'b0100;
	localparam OP_XOR  = 4'b0101;
	localparam OP_ADDI = 4'b0110;
	localparam OP_LD   = 4'b0111;
	localparam OP_ST   = 4'b1000;
	localparam OP_BZ   = 4'b1001;
	localparam OP_SL   = 4'b1010;
	localparam OP_SR   = 4'b1011;
	localparam OP_SRU  = 4'b1100;

	// ALU command definitions
	localparam ALU_ADD = 3'b000;
	localparam ALU_SUB = 3'b001;
	localparam ALU_AND = 3'b010;
	localparam ALU_OR  = 3'b011;
	localparam ALU_XOR = 3'b100;
	localparam ALU_SL  = 3'b101;
	localparam ALU_SR  = 3'b110;
	localparam ALU_SRU = 3'b111;

	// Branch condition definitions
	localparam BRANCH_Z = 3'b000;

	// ===== Internal Instruction Register =====
	reg [15:0] instruction_reg;

	// ===== Extract Instruction Fields =====
	wire [3:0]  ir_opcode;
	wire [2:0]  ir_dest;
	wire [2:0]  ir_src1;
	wire [2:0]  ir_src2;
	wire [5:0]  ir_imm;

	assign ir_opcode = instruction_reg[15:12];
	assign ir_dest   = instruction_reg[11:9];
	assign ir_src1   = instruction_reg[8:6];
	assign ir_src2   = instruction_reg[5:3];
	assign ir_imm    = instruction_reg[5:0];

	// ===== Bubble Insertion Logic =====
	// When instruction_decode_en is low, force opcode and dest to zero (NOP)
	wire [3:0]  ir_opcode_with_bubble;
	wire [2:0]  ir_dest_with_bubble;

	assign ir_opcode_with_bubble = instruction_decode_en ? ir_opcode : 4'b0000;
	assign ir_dest_with_bubble   = instruction_decode_en ? ir_dest : 3'b000;

	// ===== Sign-Extended Immediate =====
	wire [15:0] sign_extended_imm;
	assign sign_extended_imm = {{10{ir_imm[5]}}, ir_imm};

	// ===== Control Signal Generation (Combinational) =====
	reg [2:0]  alu_cmd;
	reg        mem_write_en;
	reg [15:0] mem_write_data;
	reg        write_back_en;
	reg [2:0]  write_back_dest;
	reg        write_back_result_mux;  // 0: ALU result, 1: Memory data
	reg [3:0]  branch_condition;
	reg        is_branch_instruction;

	// First ALU operand (always from source 1)
	wire [15:0] alu_src1;
	assign alu_src1 = reg_read_data_1;

	// Second ALU operand (depends on instruction type)
	reg [15:0] alu_src2;

	// Register file read addresses
	assign reg_read_addr_1 = ir_src1;
	assign reg_read_addr_2 = (ir_opcode_with_bubble == OP_ST) ? ir_dest : ir_src2;

	// ===== Instruction Decode Logic =====
	always @(*) begin
		// Default values
		alu_cmd = ALU_ADD;
		mem_write_en = 1'b0;
		mem_write_data = 16'h0000;
		write_back_en = 1'b0;
		write_back_dest = 3'b000;
		write_back_result_mux = 1'b0;
		branch_condition = 4'h0;
		is_branch_instruction = 1'b0;
		alu_src2 = reg_read_data_2;

		case (ir_opcode_with_bubble)
			OP_NOP: begin
				// No operation: all outputs remain default (zero)
				alu_cmd = ALU_ADD;
				write_back_en = 1'b0;
			end

			OP_ADD: begin
				// ADD rd, rs1, rs2: rd = rs1 + rs2
				alu_cmd = ALU_ADD;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_SUB: begin
				// SUB rd, rs1, rs2: rd = rs1 - rs2
				alu_cmd = ALU_SUB;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_AND: begin
				// AND rd, rs1, rs2: rd = rs1 & rs2
				alu_cmd = ALU_AND;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_OR: begin
				// OR rd, rs1, rs2: rd = rs1 | rs2
				alu_cmd = ALU_OR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_XOR: begin
				// XOR rd, rs1, rs2: rd = rs1 ^ rs2
				alu_cmd = ALU_XOR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_SL: begin
				// SL rd, rs1, rs2: rd = rs1 << rs2
				alu_cmd = ALU_SL;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_SR: begin
				// SR rd, rs1, rs2: rd = rs1 >> rs2 (arithmetic)
				alu_cmd = ALU_SR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_SRU: begin
				// SRU rd, rs1, rs2: rd = rs1 >> rs2 (unsigned)
				alu_cmd = ALU_SRU;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_ADDI: begin
				// ADDI rd, rs1, imm: rd = rs1 + sign_extended_imm
				alu_cmd = ALU_ADD;
				alu_src2 = sign_extended_imm;
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b0;  // Select ALU result
			end

			OP_LD: begin
				// LD rd, rs1, imm: rd = mem[rs1 + sign_extended_imm]
				alu_cmd = ALU_ADD;
				alu_src2 = sign_extended_imm;  // Address = rs1 + imm
				mem_write_en = 1'b0;           // Read from memory
				write_back_en = 1'b1;
				write_back_dest = ir_dest_with_bubble;
				write_back_result_mux = 1'b1;  // Select memory data
			end

			OP_ST: begin
				// ST rs2, rs1, imm: mem[rs1 + sign_extended_imm] = rs2
				alu_cmd = ALU_ADD;
				alu_src2 = sign_extended_imm;  // Address = rs1 + imm
				mem_write_en = 1'b1;           // Write to memory
				mem_write_data = reg_read_data_2;  // Data from rs2
				write_back_en = 1'b0;          // No write-back
			end

			OP_BZ: begin
				// BZ rs1, imm: branch if rs1 == 0
				is_branch_instruction = 1'b1;
				branch_condition = BRANCH_Z;
				write_back_en = 1'b0;          // No write-back
				alu_cmd = ALU_ADD;
			end

			default: begin
				// Unknown opcode: treat as NOP
				alu_cmd = ALU_ADD;
				write_back_en = 1'b0;
			end
		endcase
	end

	// ===== Branch Logic (Combinational) =====
	always @(*) begin
		branch_taken = 1'b0;

		if (is_branch_instruction) begin
			case (branch_condition)
				BRANCH_Z: begin
					// Branch if reg_read_data_1 == 0
					branch_taken = (reg_read_data_1 == 16'h0000);
				end
				default: begin
					branch_taken = 1'b0;
				end
			endcase
		end
	end

	// ===== Assign Branch Offset Immediate =====
	assign branch_offset_imm = ir_imm;

	// ===== Hazard Detection Inputs (Source Registers) =====
	assign decoding_op_src1 = ir_src1;

	// Second source register depends on instruction type
	// For NOP, ADDI, LD, BZ: decoding_op_src2 = 0 (no second source)
	// For other instructions: decoding_op_src2 = ir_src2
	assign decoding_op_src2 = ((ir_opcode_with_bubble == OP_NOP) ||
	                            (ir_opcode_with_bubble == OP_ADDI) ||
	                            (ir_opcode_with_bubble == OP_LD) ||
	                            (ir_opcode_with_bubble == OP_BZ)) ? 3'b000 : ir_src2;

	// ===== Instruction Register Update (Sequential) =====
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous reset: clear instruction register
			instruction_reg <= 16'h0000;
		end
		else if (instruction_decode_en) begin
			// Load new instruction when decode is enabled
			instruction_reg <= instruction;
		end
		// If instruction_decode_en is low, hold current instruction (stall)
	end

	// ===== Pipeline Register Update (Sequential) =====
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous reset: clear pipeline register
			pipeline_reg_out <= 57'h000000000000000;
		end
		else begin
			// Pack all control signals into 57-bit output
			pipeline_reg_out <= {
				alu_cmd,                    // [56:54] 3 bits
				alu_src1,                   // [53:38] 16 bits
				alu_src2,                   // [37:22] 16 bits
				mem_write_en,               // [21] 1 bit
				mem_write_data,             // [20:5] 16 bits
				write_back_en,              // [4] 1 bit
				write_back_dest,            // [3:1] 3 bits
				write_back_result_mux       // [0] 1 bit
			};
		end
	end

endmodule