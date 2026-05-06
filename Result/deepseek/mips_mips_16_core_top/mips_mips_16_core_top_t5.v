module mips_16_core_top
(
	input clk,
	input rst,
	output [`PC_WIDTH-1:0] pc
);

	wire [15:0] instruction;
	wire [15:0] reg_read_data1, reg_read_data2;
	wire [2:0] reg_read_addr1, reg_read_addr2;
	wire [2:0] decoding_op_src1, decoding_op_src2;
	wire branch_taken;
	wire [15:0] branch_offset_imm;
	wire [56:0] ID_pipeline_reg_out;
	wire [37:0] EX_pipeline_reg_out;
	wire [36:0] MEM_pipeline_reg_out;
	wire [2:0] ex_op_dest, mem_op_dest, wb_op_dest;
	wire reg_write_en;
	wire [2:0] reg_write_dest;
	wire [15:0] reg_write_data;
	wire pipeline_stall_n;

	IF_stage IF_stage_inst
	(
		.clk(clk),
		.rst(rst),
		.pipeline_stall_n(pipeline_stall_n),
		.branch_offset_imm(branch_offset_imm),
		.branch_taken(branch_taken),
		.pc(pc),
		.instruction(instruction)
	);

	ID_stage ID_stage_inst
	(
		.clk(clk),
		.rst(rst),
		.instruction(instruction),
		.pipeline_stall_n(pipeline_stall_n),
		.reg_read_data1(reg_read_data1),
		.reg_read_data2(reg_read_data2),
		.reg_read_addr1(reg_read_addr1),
		.reg_read_addr2(reg_read_addr2),
		.decoding_op_src1(decoding_op_src1),
		.decoding_op_src2(decoding_op_src2),
		.branch_taken(branch_taken),
		.branch_offset_imm(branch_offset_imm),
		.ID_pipeline_reg_out(ID_pipeline_reg_out)
	);

	EX_stage EX_stage_inst
	(
		.clk(clk),
		.rst(rst),
		.ID_pipeline_reg_out(ID_pipeline_reg_out),
		.EX_pipeline_reg_out(EX_pipeline_reg_out),
		.ex_op_dest(ex_op_dest)
	);

	MEM_stage MEM_stage_inst
	(
		.clk(clk),
		.rst(rst),
		.EX_pipeline_reg_out(EX_pipeline_reg_out),
		.MEM_pipeline_reg_out(MEM_pipeline_reg_out),
		.mem_op_dest(mem_op_dest)
	);

	WB_stage WB_stage_inst
	(
		.clk(clk),
		.rst(rst),
		.MEM_pipeline_reg_out(MEM_pipeline_reg_out),
		.reg_write_en(reg_write_en),
		.reg_write_dest(reg_write_dest),
		.reg_write_data(reg_write_data),
		.wb_op_dest(wb_op_dest)
	);

	register_file register_file_inst
	(
		.clk(clk),
		.rst(rst),
		.reg_write_en(reg_write_en),
		.reg_write_dest(reg_write_dest),
		.reg_write_data(reg_write_data),
		.reg_read_addr1(reg_read_addr1),
		.reg_read_addr2(reg_read_addr2),
		.reg_read_data1(reg_read_data1),
		.reg_read_data2(reg_read_data2)
	);

	hazard_detection_unit hazard_detection_unit_inst
	(
		.decoding_op_src1(decoding_op_src1),
		.decoding_op_src2(decoding_op_src2),
		.ex_op_dest(ex_op_dest),
		.mem_op_dest(mem_op_dest),
		.wb_op_dest(wb_op_dest),
		.pipeline_stall_n(pipeline_stall_n)
	);

endmodule
