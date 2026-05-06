module MEM_stage
(
	input					clk,
	input					rst,
	
	// from EX_stage
	input		[37:0]		pipeline_reg_in,
	
	// to WB_stage
	output	reg	[36:0]		pipeline_reg_out,
	output		[2:0]		mem_op_dest
);

	wire [15:0] ex_alu_result;
	wire        mem_write_en;
	wire [15:0] mem_write_data;
	wire [15:0] mem_read_data;

	assign ex_alu_result  = pipeline_reg_in[37:22];
	assign mem_write_en   = pipeline_reg_in[21];
	assign mem_write_data = pipeline_reg_in[20:5];

	data_mem dmem (
		.clk(clk),
		.mem_access_addr(ex_alu_result),
		.mem_write_data(mem_write_data),
		.mem_write_en(mem_write_en),
		.mem_read_data(mem_read_data)
	);

	assign mem_op_dest = pipeline_reg_in[3:1];

	always @(posedge clk) begin
		if (rst) begin
			pipeline_reg_out <= 37'd0;
		end else begin
			pipeline_reg_out[36:21] <= ex_alu_result;
			pipeline_reg_out[20:5]  <= mem_read_data;
			pipeline_reg_out[4:0]   <= pipeline_reg_in[4:0];
		end
	end

endmodule
