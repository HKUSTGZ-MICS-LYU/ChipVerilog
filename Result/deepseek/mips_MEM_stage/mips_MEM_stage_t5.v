module mips_MEM_stage
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

	// Extract fields from input pipeline register
	wire	[15:0]	ex_alu_result	= pipeline_reg_in[37:22];
	wire			mem_write_en	= pipeline_reg_in[21];
	wire	[15:0]	mem_write_data	= pipeline_reg_in[20:5];
	wire	[4:0]	write_back_ctrl	= pipeline_reg_in[4:0]; // includes write_back_en, dest, result_mux

	// Data memory read data
	wire	[15:0]	mem_read_data;

	// Instantiate data memory
	data_mem dmem (
		.clk		(clk),
		.wr_en		(mem_write_en),
		.addr		(ex_alu_result),
		.wr_data	(mem_write_data),
		.rd_data	(mem_read_data)
	);

	// Destination register for hazard detection
	assign mem_op_dest = pipeline_reg_in[3:1];

	// Output pipeline register update (synchronous reset)
	always @(posedge clk) begin
		if (rst) begin
			pipeline_reg_out <= 37'd0;
		end else begin
			pipeline_reg_out[36:21] <= ex_alu_result;
			pipeline_reg_out[20:5]  <= mem_read_data;
			pipeline_reg_out[4:0]   <= write_back_ctrl;
		end
	end

endmodule

// Data memory module: 16-bit word addressable, combinational read, synchronous write
module data_mem
(
	input			clk,
	input			wr_en,
	input	[15:0]	addr,
	input	[15:0]	wr_data,
	output	[15:0]	rd_data
);

	// Memory array (2^16 words, each 16 bits)
	reg	[15:0]	mem [0:65535];

	// Combinational read
	assign rd_data = mem[addr];

	// Synchronous write
	always @(posedge clk) begin
		if (wr_en) begin
			mem[addr] <= wr_data;
		end
	end

endmodule
