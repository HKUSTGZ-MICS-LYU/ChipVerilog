module register_file
(
	input				clk,
	input				rst,
	
	// write port
	input				reg_write_en,
	input		[2:0]	reg_write_dest,
	input		[15:0]	reg_write_data,
	
	// read port 1
	input		[2:0]	reg_read_addr_1,
	output		[15:0]	reg_read_data_1,
	// read port 2
	input		[2:0]	reg_read_addr_2,
	output		[15:0]	reg_read_data_2
);

	// ===== Register Array =====
	// Eight 16-bit general-purpose registers
	// reg_array[0] is register 0 (special: always reads as zero)
	// reg_array[1-7] are registers 1-7 (general-purpose)
	reg [15:0] reg_array [7:0];

	// ===== Synchronous Write Port =====
	// Writes occur on the rising edge of clk
	always @(posedge clk) begin
		if (rst) begin
			// Synchronous reset: clear all registers to zero
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
			// Write reg_write_data to register at reg_write_dest
			// Note: Writes to reg_array[0] are technically allowed here,
			// but the read logic always returns zero for register 0,
			// so software-visible behavior treats register 0 as read-only zero
			reg_array[reg_write_dest] <= reg_write_data;
		end
		// If reg_write_en is low, register contents remain unchanged
	end

	// ===== Asynchronous Read Port 1 =====
	// Combinational read: output changes immediately when address changes
	assign reg_read_data_1 = (reg_read_addr_1 == 3'b000) ? 16'h0000 : reg_array[reg_read_addr_1];

	// ===== Asynchronous Read Port 2 =====
	// Combinational read: output changes immediately when address changes
	assign reg_read_data_2 = (reg_read_addr_2 == 3'b000) ? 16'h0000 : reg_array[reg_read_addr_2];

endmodule