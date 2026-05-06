module WB_stage
(
	//input					clk,
	
	// from EX stage
	input		[36:0]		pipeline_reg_in,	//	[36:21],16bits:	ex_alu_result[15:0]
												//	[20:5],16bits:	mem_read_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux, 
	
	// to register file
	output					reg_write_en,
	output		[2:0]		reg_write_dest,
	output		[15:0]		reg_write_data,
	
	output		[2:0]		wb_op_dest
);

	// Extract signals from pipeline_reg_in
	wire [15:0] ex_alu_result;
	wire [15:0] mem_read_data;
	wire write_back_en;
	wire [2:0] write_back_dest;
	wire write_back_result_mux;
	
	// Assign extracted signals from pipeline_reg_in
	assign ex_alu_result = pipeline_reg_in[36:21];
	assign mem_read_data = pipeline_reg_in[20:5];
	assign write_back_en = pipeline_reg_in[4];
	assign write_back_dest = pipeline_reg_in[3:1];
	assign write_back_result_mux = pipeline_reg_in[0];
	
	// Write-back enable to register file
	assign reg_write_en = write_back_en;
	
	// Destination register to register file
	assign reg_write_dest = write_back_dest;
	
	// Result multiplexer: select between ALU result and memory read data
	// When write_back_result_mux = 0: select ex_alu_result
	// When write_back_result_mux = 1: select mem_read_data
	assign reg_write_data = (write_back_result_mux == 1'b0) ? ex_alu_result : mem_read_data;
	
	// Output destination register to hazard detection unit
	assign wb_op_dest = write_back_dest;

endmodule