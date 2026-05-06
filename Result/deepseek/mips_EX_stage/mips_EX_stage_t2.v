module EX_stage
(
	input					clk,
	input					rst,
	input		[56:0]		pipeline_reg_in,
	output	reg	[37:0]		pipeline_reg_out,
	output		[2:0]		ex_op_dest
);

	wire [2:0] alu_cmd;
	wire [15:0] alu_src1;
	wire [15:0] alu_src2;
	wire [15:0] ex_alu_result;

	assign alu_cmd   = pipeline_reg_in[56:54];
	assign alu_src1  = pipeline_reg_in[53:38];
	assign alu_src2  = pipeline_reg_in[37:22];
	assign ex_op_dest = pipeline_reg_in[3:1];

	alu alu_inst (
		.alu_src1 (alu_src1),
		.alu_src2 (alu_src2),
		.alu_cmd  (alu_cmd),
		.alu_result (ex_alu_result)
	);

	always @(posedge clk) begin
		if (rst)
			pipeline_reg_out <= 38'd0;
		else begin
			pipeline_reg_out[37:22] <= ex_alu_result;
			pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0];
		end
	end

endmodule
