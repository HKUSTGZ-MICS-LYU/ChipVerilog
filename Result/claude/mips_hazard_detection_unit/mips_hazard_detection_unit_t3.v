module hazard_detection_unit
(
	input		[2:0]		decoding_op_src1,		//ID stage source_1 register number
	input		[2:0]		decoding_op_src2,		//ID stage source_2 register number
	
	input		[2:0]		ex_op_dest,				//EX stage destinaton register number
	input		[2:0]		mem_op_dest,			//MEM stage destinaton register number
	input		[2:0]		wb_op_dest,				//WB stage destinaton register number
	
	output	reg				pipeline_stall_n		// Active low
);

	// ===== Combinational Hazard Detection Logic =====
	always @(*) begin
		// Default: no hazard, pipeline can continue
		pipeline_stall_n = 1'b1;

		// ===== Check First Source Register (decoding_op_src1) =====
		// Ignore register 0 (hardwired zero register)
		// Check against destination registers in EX, MEM, and WB stages
		if (decoding_op_src1 != 3'b000) begin
			if ((decoding_op_src1 == ex_op_dest) ||
				(decoding_op_src1 == mem_op_dest) ||
				(decoding_op_src1 == wb_op_dest)) begin
				// RAW hazard detected on first source register
				pipeline_stall_n = 1'b0;
			end
		end

		// ===== Check Second Source Register (decoding_op_src2) =====
		// Ignore register 0 (hardwired zero register)
		// Check against destination registers in EX, MEM, and WB stages
		if (decoding_op_src2 != 3'b000) begin
			if ((decoding_op_src2 == ex_op_dest) ||
				(decoding_op_src2 == mem_op_dest) ||
				(decoding_op_src2 == wb_op_dest)) begin
				// RAW hazard detected on second source register
				pipeline_stall_n = 1'b0;
			end
		end
	end

endmodule