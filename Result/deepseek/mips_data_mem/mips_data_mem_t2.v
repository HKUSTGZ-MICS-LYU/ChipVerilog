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

	localparam RAM_DEPTH = 1 << `DATA_MEM_ADDR_WIDTH;
	wire [`DATA_MEM_ADDR_WIDTH-1:0] ram_addr;

	reg [15:0] ram [0:RAM_DEPTH-1];

	assign ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH-1:0];
	assign mem_read_data = ram[ram_addr];

	always @(posedge clk) begin
		if (mem_write_en) begin
			ram[ram_addr] <= mem_write_data;
		end
	end

endmodule
