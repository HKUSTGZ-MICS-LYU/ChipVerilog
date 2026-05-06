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

	reg [15:0] reg_array [0:7];
	integer i;

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			for (i = 0; i < 8; i = i + 1) begin
				reg_array[i] <= 16'd0;
			end
		end else if (reg_write_en) begin
			reg_array[reg_write_dest] <= reg_write_data;
		end
	end

	assign reg_read_data_1 = (reg_read_addr_1 == 3'd0) ? 16'd0 : reg_array[reg_read_addr_1];
	assign reg_read_data_2 = (reg_read_addr_2 == 3'd0) ? 16'd0 : reg_array[reg_read_addr_2];

endmodule
