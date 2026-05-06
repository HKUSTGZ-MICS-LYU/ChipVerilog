module WB_stage
(
	// from MEM_stage
	input		[36:0]		pipeline_reg_in,	//	[36:21],16bits:	ex_alu_result[15:0]
												//	[20:5],16bits:	mem_read_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux
	
	// to register file
	output					reg_write_en,
	output		[2:0]		reg_write_dest,
	output		[15:0]		reg_write_data,
	
	// to hazard detection unit
	output		[2:0]		wb_op_dest
);

	// ===== Extract Signals from pipeline_reg_in =====
	wire [15:0] ex_alu_result;
	wire [15:0] mem_read_data;
	wire        write_back_en;
	wire [2:0]  write_back_dest;
	wire        write_back_result_mux;

	// Bit extraction from pipeline_reg_in (37 bits total)
	assign ex_alu_result          = pipeline_reg_in[36:21];  // [36:21] 16 bits: ALU result
	assign mem_read_data          = pipeline_reg_in[20:5];   // [20:5] 16 bits: Memory read data
	assign write_back_en          = pipeline_reg_in[4];      // [4] 1 bit: Write-back enable
	assign write_back_dest        = pipeline_reg_in[3:1];    // [3:1] 3 bits: Destination register
	assign write_back_result_mux  = pipeline_reg_in[0];      // [0] 1 bit: Result selection mux

	// ===== Register File Write-Back Logic (Combinational) =====
	
	// Forward write-back enable signal to register file
	assign reg_write_en = write_back_en;
	
	// Forward destination register to register file
	assign reg_write_dest = write_back_dest;
	
	// Select final write-back data based on instruction type
	// write_back_result_mux = 0: Use ALU result (arithmetic, logic, shift, immediate, address)
	// write_back_result_mux = 1: Use memory read data (load instructions)
	assign reg_write_data = write_back_result_mux ? mem_read_data : ex_alu_result;

	// ===== Output to Hazard Detection Unit =====
	// Destination register of instruction in WB_stage
	// Used for RAW hazard detection
	assign wb_op_dest = pipeline_reg_in[3:1];

endmodule