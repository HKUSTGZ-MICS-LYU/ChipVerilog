module ID_stage
(
	input					clk,
	input					rst,
	input					instruction_decode_en,
	// to EX_stage
	output	reg	[56:0]		pipeline_reg_out,
	// to IF_stage
	input		[15:0]		instruction,
	output		[5:0]		branch_offset_imm,
	output	reg				branch_taken,
	// to register file
	output		[2:0]		reg_read_addr_1,
	output		[2:0]		reg_read_addr_2,
	input		[15:0]		reg_read_data_1,
	input		[15:0]		reg_read_data_2,
	// to hazard detection unit
	output		[2:0]		decoding_op_src1,
	output		[2:0]		decoding_op_src2
);

	// Opcode definitions
	localparam OP_NOP  = 4'b0000;
	localparam OP_ADD  = 4'b0001;
	localparam OP_SUB  = 4'b0010;
	localparam OP_AND  = 4'b0011;
	localparam OP_OR   = 4'b0100;
	localparam OP_XOR  = 4'b0101;
	localparam OP_SL   = 4'b0110;
	localparam OP_SR   = 4'b0111;
	localparam OP_SRU  = 4'b1000;
	localparam OP_ADDI = 4'b1001;
	localparam OP_LD   = 4'b1010;
	localparam OP_ST   = 4'b1011;
	localparam OP_BZ   = 4'b1100;

	// ALU command definitions
	localparam ALU_ADD = 3'b000;
	localparam ALU_SUB = 3'b001;
	localparam ALU_AND = 3'b010;
	localparam ALU_OR  = 3'b011;
	localparam ALU_XOR = 3'b100;
	localparam ALU_SL  = 3'b101;
	localparam ALU_SR  = 3'b110;
	localparam ALU_SRU = 3'b111;

	// Internal registers and wires
	reg [15:0] instruction_reg;
	wire [3:0] ir_op_code;
	wire [2:0] ir_dest;
	wire [2:0] ir_src1;
	wire [2:0] ir_src2;
	wire [5:0] ir_imm;

	// Decoded fields with bubble insertion
	wire [3:0] ir_op_code_with_bubble;
	wire [2:0] ir_dest_with_bubble;

	// Control signals
	reg [2:0] alu_cmd_comb;
	reg [15:0] alu_src1_comb;
	reg [15:0] alu_src2_comb;
	reg mem_write_en_comb;
	reg [15:0] mem_write_data_comb;
	reg write_back_en_comb;
	reg [2:0] write_back_dest_comb;
	reg write_back_result_mux_comb;
	reg branch_taken_comb;

	// Register file read address selection
	wire [2:0] reg_read_addr_2_from_src2;
	wire [2:0] reg_read_addr_2_from_dest;

	assign ir_op_code = instruction_reg[15:12];
	assign ir_dest    = instruction_reg[11:9];
	assign ir_src1    = instruction_reg[8:6];
	assign ir_src2    = instruction_reg[5:3];
	assign ir_imm     = instruction_reg[5:0];

	// Bubble insertion
	assign ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : OP_NOP;
	assign ir_dest_with_bubble    = instruction_decode_en ? ir_dest   : 3'b0;

	// Register file read addresses
	assign reg_read_addr_1 = ir_src1;
	// For store instructions, second read address comes from destination field
	assign reg_read_addr_2_from_src2 = ir_src2;
	assign reg_read_addr_2_from_dest = ir_dest;
	assign reg_read_addr_2 = (ir_op_code == OP_ST) ? reg_read_addr_2_from_dest : reg_read_addr_2_from_src2;

	// Instruction register update
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			instruction_reg <= 16'b0;
		end else if (instruction_decode_en) begin
			instruction_reg <= instruction;
		end else begin
			instruction_reg <= instruction_reg;
		end
	end

	// Combinational control logic
	always @(*) begin
		// Default assignments
		alu_cmd_comb = ALU_ADD;
		alu_src1_comb = reg_read_data_1;
		alu_src2_comb = reg_read_data_2;
		mem_write_en_comb = 1'b0;
		mem_write_data_comb = reg_read_data_2;
		write_back_en_comb = 1'b0;
		write_back_dest_comb = ir_dest_with_bubble;
		write_back_result_mux_comb = 1'b0;
		branch_taken_comb = 1'b0;

		case (ir_op_code_with_bubble)
			OP_NOP: begin
				// All signals keep defaults (NOP)
			end
			OP_ADD: begin
				alu_cmd_comb = ALU_ADD;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0; // ALU result
			end
			OP_SUB: begin
				alu_cmd_comb = ALU_SUB;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_AND: begin
				alu_cmd_comb = ALU_AND;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_OR: begin
				alu_cmd_comb = ALU_OR;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_XOR: begin
				alu_cmd_comb = ALU_XOR;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_SL: begin
				alu_cmd_comb = ALU_SL;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_SR: begin
				alu_cmd_comb = ALU_SR;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_SRU: begin
				alu_cmd_comb = ALU_SRU;
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_ADDI: begin
				alu_cmd_comb = ALU_ADD;
				alu_src2_comb = {{10{ir_imm[5]}}, ir_imm}; // sign-extend immediate
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b0;
			end
			OP_LD: begin
				alu_cmd_comb = ALU_ADD;
				alu_src2_comb = {{10{ir_imm[5]}}, ir_imm}; // sign-extend immediate
				write_back_en_comb = 1'b1;
				write_back_result_mux_comb = 1'b1; // select memory data
			end
			OP_ST: begin
				alu_cmd_comb = ALU_ADD;
				alu_src2_comb = {{10{ir_imm[5]}}, ir_imm}; // sign-extend immediate
				mem_write_en_comb = 1'b1;
				// mem_write_data_comb stays as reg_read_data_2 (from destination field)
				write_back_en_comb = 1'b0;
			end
			OP_BZ: begin
				// branch logic (branch_taken set below)
				if (reg_read_data_1 == 16'b0) begin
					branch_taken_comb = 1'b1;
				end else begin
					branch_taken_comb = 1'b0;
				end
				write_back_en_comb = 1'b0;
			end
			default: begin
				// Unknown opcode: treat as NOP
			end
		endcase
	end

	// Branch offset direct assignment
	assign branch_offset_imm = ir_imm;

	// Branch taken output (combinational)
	always @(*) begin
		branch_taken = branch_taken_comb;
	end

	// Hazard detection outputs
	assign decoding_op_src1 = ir_src1;
	assign decoding_op_src2 = (ir_op_code == OP_NOP || ir_op_code == OP_ADDI || ir_op_code == OP_LD || ir_op_code == OP_BZ) ? 3'b0 : ir_src2;

	// Pipeline register output
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			pipeline_reg_out <= 57'b0;
		end else begin
			pipeline_reg_out[56:54] <= alu_cmd_comb;
			pipeline_reg_out[53:38] <= alu_src1_comb;
			pipeline_reg_out[37:22] <= alu_src2_comb;
			pipeline_reg_out[21]    <= mem_write_en_comb;
			pipeline_reg_out[20:5]  <= mem_write_data_comb;
			pipeline_reg_out[4]     <= write_back_en_comb;
			pipeline_reg_out[3:1]   <= write_back_dest_comb;
			pipeline_reg_out[0]     <= write_back_result_mux_comb;
		end
	end

endmodule
