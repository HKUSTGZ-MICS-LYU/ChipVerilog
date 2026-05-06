module register_file
(
	input				clk,
	input				rst,
	
	// write port
	input				reg_write_en,
	input		[2:0]	reg_write_dest,
	input		[15:0]	reg_write_data,
	
	//read port 1
	input		[2:0]	reg_read_addr_1,
	output		[15:0]	reg_read_data_1,
	//read port 2
	input		[2:0]	reg_read_addr_2,
	output		[15:0]	reg_read_data_2
);

	// 8-entry register file, each entry is 16 bits wide
	reg [15:0] reg_array [7:0];
	
	// Write logic - synchronous write on rising edge of clk
	always @(posedge clk) begin
		if (rst) begin
			// Reset all registers to zero
			reg_array[0] <= 16'h0000;
			reg_array[1] <= 16'h0000;
			reg_array[2] <= 16'h0000;
			reg_array[3] <= 16'h0000;
			reg_array[4] <= 16'h0000;
			reg_array[5] <= 16'h0000;
			reg_array[6] <= 16'h0000;
			reg_array[7] <= 16'h0000;
		end
		else if (reg_write_en) begin
			// Write to the selected register (writes to reg_array[0] are allowed but ignored on read)
			reg_array[reg_write_dest] <= reg_write_data;
		end
	end
	
	// Read logic - asynchronous read using continuous assignment
	// Register 0 always returns zero on read
	assign reg_read_data_1 = (reg_read_addr_1 == 3'b000) ? 16'h0000 : reg_array[reg_read_addr_1];
	assign reg_read_data_2 = (reg_read_addr_2 == 3'b000) ? 16'h0000 : reg_array[reg_read_addr_2];

endmodule