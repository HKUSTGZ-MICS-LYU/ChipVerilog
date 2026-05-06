module hazard_detection_unit
(
	input		[2:0]		decoding_op_src1,
	input		[2:0]		decoding_op_src2,
	input		[2:0]		ex_op_dest,
	input		[2:0]		mem_op_dest,
	input		[2:0]		wb_op_dest,
	output	reg				pipeline_stall_n
);

always @(*) begin
	pipeline_stall_n = 1'b1;
	if (decoding_op_src1 != 3'd0) begin
		if (decoding_op_src1 == ex_op_dest || decoding_op_src1 == mem_op_dest || decoding_op_src1 == wb_op_dest)
			pipeline_stall_n = 1'b0;
	end
	if (decoding_op_src2 != 3'd0) begin
		if (decoding_op_src2 == ex_op_dest || decoding_op_src2 == mem_op_dest || decoding_op_src2 == wb_op_dest)
			pipeline_stall_n = 1'b0;
	end
end

endmodule
