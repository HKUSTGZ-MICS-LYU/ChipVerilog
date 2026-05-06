module MEM_stage
(
	input					clk,
	input					rst,
	
	// from EX_stage
	input		[37:0]		pipeline_reg_in,
	
	// to WB_stage
	output	reg	[36:0]		pipeline_reg_out,
	output		[2:0]		mem_op_dest
);

	// Extract fields from input pipeline register
	wire [15:0] ex_alu_result = pipeline_reg_in[37:22];
	wire        mem_write_en  = pipeline_reg_in[21];
	wire [15:0] mem_write_data = pipeline_reg_in[20:5];
	wire [4:0]  wb_control    = pipeline_reg_in[4:0];

	// Memory read data bus
	wire [15:0] mem_read_data;

	// Instantiate data memory
	data_mem dmem (
		.clk       (clk),
		.addr      (ex_alu_result),
		.write_en  (mem_write_en),
		.write_data(mem_write_data),
		.read_data (mem_read_data)
	);

	// Pipeline output register
	always @(posedge clk or posedge rst) begin
		if (rst)
			pipeline_reg_out <= 37'd0;
		else begin
			pipeline_reg_out[36:21] <= ex_alu_result;
			pipeline_reg_out[20:5]  <= mem_read_data;
			pipeline_reg_out[4:0]   <= wb_control;
		end
	end

	// Destination register for hazard detection
	assign mem_op_dest = pipeline_reg_in[3:1];

endmodule

// Data memory module: 64K x 16-bit synchronous write, combinational read
module data_mem
(
	input				clk,
	input		[15:0]	addr,
	input				write_en,
	input		[15:0]	write_data,
	output reg	[15:0]	read_data
);

	reg [15:0] mem [0:2**16-1];

	// Combinational read
	always @(*) begin
		read_data = mem[addr];
	end

	// Synchronous write
	always @(posedge clk) begin
		if (write_en)
			mem[addr] <= write_data;
	end

endmodule
