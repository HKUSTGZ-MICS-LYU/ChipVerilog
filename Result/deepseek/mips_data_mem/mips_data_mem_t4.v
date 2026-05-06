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

// local RAM address width from macro
localparam RAM_ADDR_WIDTH = `DATA_MEM_ADDR_WIDTH;
localparam RAM_DEPTH = 2 ** RAM_ADDR_WIDTH;

// internal RAM array
reg [15:0] ram [0:RAM_DEPTH-1];

// extract RAM address from access address (lower bits)
wire [RAM_ADDR_WIDTH-1:0] ram_addr;
assign ram_addr = mem_access_addr[RAM_ADDR_WIDTH-1:0];

// synchronous write
always @(posedge clk) begin
	if (mem_write_en)
		ram[ram_addr] <= mem_write_data;
end

// asynchronous read
assign mem_read_data = ram[ram_addr];

endmodule
