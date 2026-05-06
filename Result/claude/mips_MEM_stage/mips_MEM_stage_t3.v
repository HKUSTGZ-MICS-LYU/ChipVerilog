module MEM_stage
(
	input					clk,
	input					rst,
	
	// from EX_stage
	input		[37:0]		pipeline_reg_in,	//	[37:22],16bits:	ex_alu_result[15:0]
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to WB_stage
	output	reg	[36:0]		pipeline_reg_out,	//	[36:21],16bits:	ex_alu_result[15:0]
												//	[20:5],16bits:	mem_read_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to hazard detection unit
	output		[2:0]		mem_op_dest
);

	// ===== Extract Signals from pipeline_reg_in =====
	wire [15:0] ex_alu_result;
	wire        mem_write_en;
	wire [15:0] mem_write_data;
	wire [4:0]  write_back_ctrl;

	// Bit extraction from pipeline_reg_in (38 bits)
	assign ex_alu_result   = pipeline_reg_in[37:22];  // [37:22] 16 bits
	assign mem_write_en    = pipeline_reg_in[21];     // [21] 1 bit
	assign mem_write_data  = pipeline_reg_in[20:5];   // [20:5] 16 bits
	assign write_back_ctrl = pipeline_reg_in[4:0];    // [4:0] 5 bits

	// ===== Data Memory Instance =====
	wire [15:0] mem_read_data;

	data_mem dmem (
		.clk              (clk),
		.mem_access_addr  (ex_alu_result),      // ALU result as memory address
		.mem_write_data   (mem_write_data),     // Data to write
		.mem_write_en     (mem_write_en),       // Write enable
		.mem_read_data    (mem_read_data)       // Read data from memory
	);

	// ===== Output to Hazard Detection Unit =====
	// Destination register of instruction in MEM_stage
	// Used for RAW hazard detection
	assign mem_op_dest = pipeline_reg_in[3:1];

	// ===== Pipeline Register Update Logic =====
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous reset: clear pipeline register
			pipeline_reg_out <= 37'h0000000000;
		end
		else begin
			// Normal operation: update pipeline register
			// Pack ALU result, memory read data, and write-back control signals
			pipeline_reg_out <= {ex_alu_result, mem_read_data, write_back_ctrl};
		end
	end

endmodule