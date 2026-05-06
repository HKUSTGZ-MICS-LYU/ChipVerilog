`timescale 1ns / 1ps
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

	localparam RAM_ADDR_WIDTH = `DATA_MEM_ADDR_WIDTH;
	localparam RAM_DEPTH = 1 << RAM_ADDR_WIDTH;

	reg [15:0] ram [0:RAM_DEPTH-1];

	wire [RAM_ADDR_WIDTH-1:0] ram_addr;
	assign ram_addr = mem_access_addr[RAM_ADDR_WIDTH-1:0];

	// Synchronous write
	always @(posedge clk) begin
		if (mem_write_en) begin
			ram[ram_addr] <= mem_write_data;
		end
	end

	// Asynchronous read
	assign mem_read_data = ram[ram_addr];

endmodule
