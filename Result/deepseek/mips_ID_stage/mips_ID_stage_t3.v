module ID_stage
(
	input					clk,
	input					rst,
	input					instruction_decode_en,
	output	reg	[56:0]		pipeline_reg_out,
	input		[15:0]		instruction,
	output		[5:0]		branch_offset_imm,
	output	reg				branch_taken,
	output		[2:0]		reg_read_addr_1,
	output		[2:0]		reg_read_addr_2,
	input		[15:0]		reg_read_data_1,
	input		[15:0]		reg_read_data_2,
	output		[2:0]		decoding_op_src1,
	output		[2:0]		decoding_op_src2
);

	// localparam opcodes
	localparam [3:0] OP_NOP  = 4'b0000;
	localparam [3:0] OP_ADD  = 4'b0001;
	localparam [3:0] OP_SUB  = 4'b0010;
	localparam [3:0] OP_AND  = 4'b0011;
	localparam [3:0] OP_OR   = 4'b0100;
	localparam [3:0] OP_XOR  = 4'b0101;
	localparam [3:0] OP_SL   = 4'b0110;
	localparam [3:0] OP_SR   = 4'b0111;
	localparam [3:0] OP_SRU  = 4'b1000;
	localparam [3:0] OP_ADDI = 4'b1001;
	localparam [3:0] OP_LD   = 4'b1010;
	localparam [3:0] OP_ST   = 4'b1011;
	localparam [3:0] OP_BZ   = 4'b1100;

	// localparam ALU commands
	localparam [2:0] ALU_ADD = 3'b000;
	localparam [2:0] ALU_SUB = 3'b001;
	localparam [2:0] ALU_AND = 3'b010;
	localparam [2:0] ALU_OR  = 3'b011;
	localparam [2:0] ALU_XOR = 3'b100;
	localparam [2:0] ALU_SL  = 3'b101;
	localparam [2:0] ALU_SR  = 3'b110;
	localparam [2:0] ALU_SRU = 3'b111;

	// instruction register
	reg [15:0] instruction_reg;

	// internal wires
	wire [3:0] opcode;
	wire [2:0] dest, src1, src2;
	wire [5:0] imm;
	wire [3:0] ir_op_code_with_bubble;
	wire [2:0] ir_dest_with_bubble;
	wire [15:0] imm_sext;

	// instruction register behavior
	always @(posedge clk or posedge rst) begin
		if (rst)
			instruction_reg <= 16'd0;
		else if (instruction_decode_en)
			instruction_reg <= instruction;
		else
			instruction_reg <= instruction_reg;
	end

	assign opcode = instruction_reg[15:12];
	assign dest   = instruction_reg[11:9];
	assign src1   = instruction_reg[8:6];
	assign src2   = instruction_reg[5:3];
	assign imm    = instruction_reg[5:0];

	assign ir_op_code_with_bubble = instruction_decode_en ? opcode : 4'b0;
	assign ir_dest_with_bubble    = instruction_decode_en ? dest   : 3'b0;

	// sign extension
	assign imm_sext = {{10{imm[5]}}, imm};

	// register file read addresses
	assign reg_read_addr_1 = src1;
	assign reg_read_addr_2 = (opcode == OP_ST) ? instruction_reg[11:9] : src2;

	// hazard detection outputs
	assign decoding_op_src1 = src1;
	wire no_src2 = (opcode == OP_NOP) || (opcode == OP_ADDI) || (opcode == OP_LD) || (opcode == OP_BZ);
	assign decoding_op_src2 = no_src2 ? 3'b0 : src2;

	// branch offset immediate
	assign branch_offset_imm = imm;

	// control signals (combinational)
	reg [2:0] alu_cmd;
	reg [15:0] alu_src1, alu_src2;
	reg mem_write_en;
	reg [15:0] mem_write_data;
	reg write_back_en;
	reg [2:0] write_back_dest;
	reg write_back_result_mux;

	always @(*) begin
		// default values
		alu_cmd = ALU_ADD;
		alu_src1 = reg_read_data_1;
		alu_src2 = 16'd0;
		mem_write_en = 1'b0;
		mem_write_data = 16'd0;
		write_back_en = 1'b0;
		write_back_dest = ir_dest_with_bubble;
		write_back_result_mux = 1'b0;

		case (ir_op_code_with_bubble)
			OP_NOP: begin
				// nothing to do
			end
			OP_ADD: begin
				alu_cmd = ALU_ADD;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_SUB: begin
				alu_cmd = ALU_SUB;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_AND: begin
				alu_cmd = ALU_AND;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_OR: begin
				alu_cmd = ALU_OR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_XOR: begin
				alu_cmd = ALU_XOR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_SL: begin
				alu_cmd = ALU_SL;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_SR: begin
				alu_cmd = ALU_SR;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_SRU: begin
				alu_cmd = ALU_SRU;
				alu_src2 = reg_read_data_2;
				write_back_en = 1'b1;
			end
			OP_ADDI: begin
				alu_cmd = ALU_ADD;
				alu_src2 = imm_sext;
				write_back_en = 1'b1;
			end
			OP_LD: begin
				alu_cmd = ALU_ADD;
				alu_src2 = imm_sext;
				write_back_en = 1'b1;
				write_back_result_mux = 1'b1; // select memory data
			end
			OP_ST: begin
				alu_cmd = ALU_ADD;
				alu_src2 = imm_sext;
				mem_write_en = 1'b1;
				mem_write_data = reg_read_data_2;
			end
			OP_BZ: begin
				// no writes, ALU not used
			end
			default: begin
				// treat as NOP
			end
		endcase
	end

	// branch taken (combinational)
	always @(*) begin
		if (ir_op_code_with_bubble == OP_BZ && reg_read_data_1 == 16'd0)
			branch_taken = 1'b1;
		else
			branch_taken = 1'b0;
	end

	// pipeline register out (registered)
	always @(posedge clk or posedge rst) begin
		if (rst)
			pipeline_reg_out <= 57'd0;
		else
			pipeline_reg_out <= {alu_cmd, alu_src1, alu_src2, mem_write_en, mem_write_data, write_back_en, write_back_dest, write_back_result_mux};
	end

endmodule
