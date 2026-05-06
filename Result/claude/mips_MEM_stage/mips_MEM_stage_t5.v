module MEM_stage
(
	input					clk,
	input					rst,
	
	// from EX_stage
	input		[37:0]		pipeline_reg_in,	//	[37:22],16bits:	ex_alu_result[15:0];
												//	[21:5],17bits:	mem_write_en, mem_write_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux, 
	
	// to WB_stage
	output	reg	[36:0]		pipeline_reg_out,	//	[36:21],16bits:	ex_alu_result[15:0]
												//	[20:5],16bits:	mem_read_data[15:0]
												//	[4:0],5bits:	write_back_en, write_back_dest[2:0], write_back_result_mux, 
	output		[2:0]		mem_op_dest
);

	//==========================================================
	// 从输入流水线寄存器中拆分各字段
	//==========================================================
	wire	[15:0]	ex_alu_result;		// EX阶段送来的ALU运算结果,作为数据存储器访问地址
	wire			mem_write_en;		// 存储器写使能信号(store指令时有效)
	wire	[15:0]	mem_write_data;		// 待写入存储器的数据
	wire	[4:0]	wb_ctrl;			// 传递给WB阶段的写回控制信号
	
	assign	ex_alu_result	= pipeline_reg_in[37:22];
	assign	mem_write_en	= pipeline_reg_in[21];
	assign	mem_write_data	= pipeline_reg_in[20:5];
	assign	wb_ctrl			= pipeline_reg_in[4:0];
	
	//==========================================================
	// 数据存储器读出数据
	//==========================================================
	wire	[15:0]	mem_read_data;
	
	//==========================================================
	// 实例化数据存储器 data_mem
	// 地址: ex_alu_result (来自EX阶段ALU计算的访存地址)
	// 写使能: mem_write_en (store时为1, load时为0)
	// 写数据: mem_write_data
	// 读数据: mem_read_data (load指令时使用)
	//==========================================================
	data_mem dmem
	(
		.clk				(clk),
		.mem_access_addr	(ex_alu_result),
		.mem_write_data		(mem_write_data),
		.mem_write_en		(mem_write_en),
		.mem_read_data		(mem_read_data)
	);
	
	//==========================================================
	// 输出流水线寄存器,在时钟上升沿更新
	// 复位时清零,防止无效数据传播到WB阶段
	//==========================================================
	always @(posedge clk)
	begin
		if (rst)
			pipeline_reg_out <= 37'b0;
		else
		begin
			pipeline_reg_out[36:21]	<= ex_alu_result;	// ALU结果转发至WB阶段
			pipeline_reg_out[20:5]	<= mem_read_data;	// 存储器读出数据转发至WB阶段
			pipeline_reg_out[4:0]	<= wb_ctrl;			// 写回控制信号透传
		end
	end
	
	//==========================================================
	// 送往冒险检测单元的目的寄存器编号
	// pipeline_reg_in[4]   : write_back_en
	// pipeline_reg_in[3:1] : write_back_dest[2:0]  <-- 取此字段
	// pipeline_reg_in[0]   : write_back_result_mux
	//==========================================================
	assign	mem_op_dest = pipeline_reg_in[3:1];

endmodule