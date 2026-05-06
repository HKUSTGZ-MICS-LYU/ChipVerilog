module EX_stage
(
	input					clk,
	input					rst,
	// from ID_stage
	input		[56:0]		pipeline_reg_in,	//	[56:54],3bits:	alu_cmd[2:0]
												//	[53:38],16bits:	alu_src1[15:0]
												//	[37:22],16bits:	alu_src2[15:0]
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to MEM_stage
	output	reg	[37:0]		pipeline_reg_out,	//	[37:22],16bits:	ex_alu_result[15:0]
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to hazard detection unit
	output		[2:0]		ex_op_dest
);

	// ===== Extract Signals from pipeline_reg_in =====
	wire [2:0]  alu_cmd;
	wire [15:0] alu_src1;
	wire [15:0] alu_src2;
	wire [21:0] mem_and_wb_ctrl;  // Control signals passed through to next stage

	// Bit extraction from pipeline_reg_in
	assign alu_cmd = pipeline_reg_in[56:54];
	assign alu_src1 = pipeline_reg_in[53:38];
	assign alu_src2 = pipeline_reg_in[37:22];
	assign mem_and_wb_ctrl = pipeline_reg_in[21:0];

	// ===== ALU Instance =====
	wire [15:0] ex_alu_result;

	alu alu_inst (
		.a(alu_src1),
		.b(alu_src2),
		.cmd(alu_cmd),
		.r(ex_alu_result)
	);

	// ===== Output to Hazard Detection Unit =====
	// Destination register of instruction in EX_stage
	// Used for RAW hazard detection
	assign ex_op_dest = pipeline_reg_in[3:1];

	// ===== Pipeline Register Update Logic =====
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous reset: clear pipeline register
			pipeline_reg_out <= 38'h0000000000;
		end
		else begin
			// Normal operation: update pipeline register
			// Store ALU result in bits [37:22]
			// Pass through memory and write-back control in bits [21:0]
			pipeline_reg_out <= {ex_alu_result, mem_and_wb_ctrl};
		end
	end

endmodule