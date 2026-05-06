module MEM_stage
(
	input					clk,
	input					rst,
	
	// from EX_stage
	input		[37:0]		pipeline_reg_in,	//	[37:22],16bits:	ex_alu_result[15:0];
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux, 
	
	// to WB_stage
	output	reg	[36:0]		pipeline_reg_out,	//	[36:21],16bits:	ex_alu_result[15:0]
												//	[20:5],16bits:	mem_read_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux, 
	output		[2:0]		mem_op_dest
);

	// Internal signals
	wire [15:0] ex_alu_result;
	wire        mem_write_en;
	wire [15:0] mem_write_data;
	wire [15:0] mem_read_data;

	// Extract fields from pipeline_reg_in
	assign ex_alu_result   = pipeline_reg_in[37:22];
	assign mem_write_en    = pipeline_reg_in[21];
	assign mem_write_data  = pipeline_reg_in[20:5];
	// pipeline_reg_in[4:0] is writeback control, used directly in output register

	// Data memory instantiation
	data_mem dmem (
		.clk             (clk),
		.mem_access_addr (ex_alu_result),
		.mem_write_data  (mem_write_data),
		.mem_write_en    (mem_write_en),
		.mem_read_data   (mem_read_data)
	);

	// Output pipeline register
	always @(posedge clk) begin
		if (rst) begin
			pipeline_reg_out <= 37'd0;
		end else begin
			// pipeline_reg_out[36:21] = ex_alu_result
			// pipeline_reg_out[20:5]  = mem_read_data
			// pipeline_reg_out[4:0]   = writeback control (from input)
			pipeline_reg_out <= {ex_alu_result, mem_read_data, pipeline_reg_in[4:0]};
		end
	end

	// Destination register for hazard detection (bits [3:1] of writeback control)
	assign mem_op_dest = pipeline_reg_in[3:1];

endmodule
