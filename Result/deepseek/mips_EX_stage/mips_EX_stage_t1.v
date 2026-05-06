module EX_stage
(
	input					clk,
	input					rst,
	// from ID_stage
	input		[56:0]		pipeline_reg_in,
	
	// to MEM_stage
	output	reg	[37:0]		pipeline_reg_out,
	
	// to hazard detection unit
	output		[2:0]		ex_op_dest
);

	// Internal signals
	wire [2:0]  alu_cmd;
	wire [15:0] alu_src1;
	wire [15:0] alu_src2;
	wire [15:0] ex_alu_result;

	// Extract fields from pipeline_reg_in
	assign alu_cmd   = pipeline_reg_in[56:54];
	assign alu_src1  = pipeline_reg_in[53:38];
	assign alu_src2  = pipeline_reg_in[37:22];

	// Destination register for hazard detection
	assign ex_op_dest = pipeline_reg_in[3:1];

	// ALU instantiation
	alu alu_inst (
		.alu_cmd   (alu_cmd),
		.alu_src1  (alu_src1),
		.alu_src2  (alu_src2),
		.alu_result(ex_alu_result)
	);

	// Pipeline register update
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			pipeline_reg_out <= 38'b0;
		end else begin
			// [37:22] ALU result
			pipeline_reg_out[37:22] <= ex_alu_result;
			// [21:0]  pass-through memory and write-back controls
			pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0];
		end
	end

endmodule
