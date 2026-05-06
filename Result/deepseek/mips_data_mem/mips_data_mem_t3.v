module data_mem
(
	input					clk,
	input	[15:0]			mem_access_addr,
	input	[15:0]			mem_write_data,
	input					mem_write_en,
	output	[15:0]			mem_read_data
);

	// Define RAM array: depth determined by macro
	// Use `DATA_MEM_ADDR_WIDTH to compute number of words
	localparam RAM_DEPTH = 1 << `DATA_MEM_ADDR_WIDTH;
	reg [15:0] ram [0:RAM_DEPTH-1];

	// Extract lower bits as RAM address
	wire [`DATA_MEM_ADDR_WIDTH-1:0] ram_addr;
	assign ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH-1:0];

	// Asynchronous read
	assign mem_read_data = ram[ram_addr];

	// Synchronous write on rising edge of clk
	always @(posedge clk) begin
		if (mem_write_en)
			ram[ram_addr] <= mem_write_data;
	end

endmodule
