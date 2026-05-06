module mips_16_core_top
(
	input						clk,
	input						rst,

	output	[`PC_WIDTH-1:0]		pc
);

	// ===== PC Width Configuration =====
	`ifndef PC_WIDTH
		`define PC_WIDTH 16
	`endif

	// ===== Internal Interconnect Signals =====

	// ===== IF_stage Signals =====
	wire [`PC_WIDTH-1:0]		if_pc;
	wire [15:0]					if_instruction;
	wire [5:0]					if_branch_offset_imm;
	wire						if_branch_taken;
	wire						if_instruction_fetch_en;

	// ===== ID_stage Signals =====
	wire [56:0]					id_pipeline_reg_out;
	wire [15:0]					id_instruction;
	wire [5:0]					id_branch_offset_imm;
	wire						id_branch_taken;
	wire [2:0]					id_reg_read_addr_1;
	wire [2:0]					id_reg_read_addr_2;
	wire [15:0]					id_reg_read_data_1;
	wire [15:0]					id_reg_read_data_2;
	wire [2:0]					id_decoding_op_src1;
	wire [2:0]					id_decoding_op_src2;
	wire						id_instruction_decode_en;

	// ===== EX_stage Signals =====
	wire [37:0]					ex_pipeline_reg_in;
	wire [37:0]					ex_pipeline_reg_out;
	wire [2:0]					ex_op_dest;

	// ===== MEM_stage Signals =====
	wire [37:0]					mem_pipeline_reg_in;
	wire [36:0]					mem_pipeline_reg_out;
	wire [2:0]					mem_op_dest;

	// ===== WB_stage Signals =====
	wire [36:0]					wb_pipeline_reg_in;
	wire						wb_reg_write_en;
	wire [2:0]					wb_reg_write_dest;
	wire [15:0]					wb_reg_write_data;
	wire [2:0]					wb_op_dest;

	// ===== Hazard Detection Signals =====
	wire						pipeline_stall_n;

	// ===== Assign PC Output =====
	assign pc = if_pc;

	// ===== Stall Control Signal =====
	// The hazard detection unit drives pipeline_stall_n
	// This signal freezes IF_stage and ID_stage during pipeline stall
	assign if_instruction_fetch_en = pipeline_stall_n;
	assign id_instruction_decode_en = pipeline_stall_n;

	// ===== Instantiate IF_stage =====
	IF_stage if_stage_inst (
		.clk						(clk),
		.rst						(rst),
		.instruction_fetch_en		(if_instruction_fetch_en),
		
		.branch_offset_imm			(if_branch_offset_imm),
		.branch_taken				(if_branch_taken),
		
		.pc							(if_pc),
		.instruction				(if_instruction)
	);

	// ===== Instantiate ID_stage =====
	ID_stage id_stage_inst (
		.clk						(clk),
		.rst						(rst),
		.instruction_decode_en		(id_instruction_decode_en),
		
		.pipeline_reg_out			(id_pipeline_reg_out),
		
		.instruction				(if_instruction),
		.branch_offset_imm			(if_branch_offset_imm),
		.branch_taken				(if_branch_taken),
		
		.reg_read_addr_1			(id_reg_read_addr_1),
		.reg_read_addr_2			(id_reg_read_addr_2),
		.reg_read_data_1			(id_reg_read_data_1),
		.reg_read_data_2			(id_reg_read_data_2),
		
		.decoding_op_src1			(id_decoding_op_src1),
		.decoding_op_src2			(id_decoding_op_src2)
	);

	// ===== Instantiate EX_stage =====
	EX_stage ex_stage_inst (
		.clk						(clk),
		.rst						(rst),
		
		.pipeline_reg_in			(id_pipeline_reg_out),
		.pipeline_reg_out			(ex_pipeline_reg_out),
		
		.ex_op_dest					(ex_op_dest)
	);

	// ===== Instantiate MEM_stage =====
	MEM_stage mem_stage_inst (
		.clk						(clk),
		.rst						(rst),
		
		.pipeline_reg_in			(ex_pipeline_reg_out),
		.pipeline_reg_out			(mem_pipeline_reg_out),
		
		.mem_op_dest				(mem_op_dest)
	);

	// ===== Instantiate WB_stage =====
	WB_stage wb_stage_inst (
		.pipeline_reg_in			(mem_pipeline_reg_out),
		
		.reg_write_en				(wb_reg_write_en),
		.reg_write_dest				(wb_reg_write_dest),
		.reg_write_data				(wb_reg_write_data),
		
		.wb_op_dest					(wb_op_dest)
	);

	// ===== Instantiate Register File =====
	register_file reg_file_inst (
		.clk						(clk),
		.rst						(rst),
		
		.reg_write_en				(wb_reg_write_en),
		.reg_write_dest				(wb_reg_write_dest),
		.reg_write_data				(wb_reg_write_data),
		
		.reg_read_addr_1			(id_reg_read_addr_1),
		.reg_read_data_1			(id_reg_read_data_1),
		.reg_read_addr_2			(id_reg_read_addr_2),
		.reg_read_data_2			(id_reg_read_data_2)
	);

	// ===== Instantiate Hazard Detection Unit =====
	hazard_detection_unit hazard_unit_inst (
		.decoding_op_src1			(id_decoding_op_src1),
		.decoding_op_src2			(id_decoding_op_src2),
		
		.ex_op_dest					(ex_op_dest),
		.mem_op_dest				(mem_op_dest),
		.wb_op_dest					(wb_op_dest),
		
		.pipeline_stall_n			(pipeline_stall_n)
	);

endmodule