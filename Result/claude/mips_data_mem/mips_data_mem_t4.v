module data_mem
(
	input					clk,
	
	// address input, shared by read and write port
	input	[15:0]			mem_access_addr,
	
	// write port
	input	[15:0]			mem_write_data,
	input					mem_write_en,
	// read port
	output	[15:0]			mem_read_data
	
);

	// ===== Memory Configuration =====
	// DATA_MEM_ADDR_WIDTH defines the number of address bits used for RAM
	// The actual memory depth is 2^DATA_MEM_ADDR_WIDTH entries
	// This macro is typically defined in a header file (mips_16_defs.v or similar)
	`ifndef DATA_MEM_ADDR_WIDTH
		`define DATA_MEM_ADDR_WIDTH 10  // Default: 1024 entries (1KB with 16-bit words)
	`endif

	// ===== Internal RAM Array =====
	// RAM with 16-bit data width and configurable depth
	// Each entry stores one 16-bit word
	reg [15:0] ram [2**`DATA_MEM_ADDR_WIDTH - 1 : 0];

	// ===== Internal Address Signals =====
	// Extract the lower DATA_MEM_ADDR_WIDTH bits from the 16-bit external address
	// This allows the module to support flexible memory sizes while maintaining
	// a standard 16-bit address interface
	wire [`DATA_MEM_ADDR_WIDTH - 1 : 0] ram_addr;
	assign ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH - 1 : 0];

	// ===== Synchronous Write Port =====
	// Writes occur on the rising edge of the clock when mem_write_en is asserted
	always @(posedge clk) begin
		if (mem_write_en) begin
			// Write mem_write_data to RAM at ram_addr on rising edge of clock
			// Uses non-blocking assignment (<=) for proper sequential behavior
			ram[ram_addr] <= mem_write_data;
		end
		// If mem_write_en is low, RAM contents are not modified
	end

	// ===== Asynchronous Read Port =====
	// Continuous assignment: read data directly from RAM
	// When ram_addr changes, mem_read_data updates combinationally after propagation delay
	assign mem_read_data = ram[ram_addr];

	// ===== Optional: RAM Initialization =====
	// Uncomment and modify if RAM should be pre-loaded with data at simulation start
	/*
	initial begin
		$readmemh("data_mem_init.hex", ram);  // Load from hex file
		// or
		// ram[0] = 16'h0000;
		// ram[1] = 16'h1234;
		// etc.
	end
	*/

endmodule