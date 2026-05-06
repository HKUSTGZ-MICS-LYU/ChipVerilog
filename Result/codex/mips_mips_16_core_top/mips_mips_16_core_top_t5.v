module mips_16_core_top
(
    input                       clk,
    input                       rst,
    output [`PC_WIDTH-1:0]      pc
);

wire                           pipeline_stall_n;
wire                           branch_taken;
wire [`DATA_WIDTH-1:0]         branch_offset_imm;
wire [`DATA_WIDTH-1:0]         instruction;

wire [56:0]                    ID_pipeline_reg_out;
wire [37:0]                    EX_pipeline_reg_out;
wire [36:0]                    MEM_pipeline_reg_out;

wire [`REG_ADDR_WIDTH-1:0]     reg_read_addr1;
wire [`REG_ADDR_WIDTH-1:0]     reg_read_addr2;
wire [`DATA_WIDTH-1:0]         reg_read_data1;
wire [`DATA_WIDTH-1:0]         reg_read_data2;

wire                           reg_write_en;
wire [`REG_ADDR_WIDTH-1:0]     reg_write_dest;
wire [`DATA_WIDTH-1:0]         reg_write_data;

wire [`REG_ADDR_WIDTH-1:0]     decoding_op_src1;
wire [`REG_ADDR_WIDTH-1:0]     decoding_op_src2;
wire [`REG_ADDR_WIDTH-1:0]     ex_op_dest;
wire [`REG_ADDR_WIDTH-1:0]     mem_op_dest;
wire [`REG_ADDR_WIDTH-1:0]     wb_op_dest;

IF_stage u_if_stage
(
    .clk                (clk),
    .rst                (rst),
    .instruction_fetch_en(pipeline_stall_n),
    .branch_offset_imm  (branch_offset_imm),
    .branch_taken       (branch_taken),
    .pc                 (pc),
    .instruction        (instruction)
);

ID_stage u_id_stage
(
    .clk                (clk),
    .rst                (rst),
    .instruction_decode_en(pipeline_stall_n),
    .instruction        (instruction),
    .reg_read_addr1     (reg_read_addr1),
    .reg_read_addr2     (reg_read_addr2),
    .reg_read_data1     (reg_read_data1),
    .reg_read_data2     (reg_read_data2),
    .branch_offset_imm  (branch_offset_imm),
    .branch_taken       (branch_taken),
    .decoding_op_src1   (decoding_op_src1),
    .decoding_op_src2   (decoding_op_src2),
    .ID_pipeline_reg_out(ID_pipeline_reg_out)
);

EX_stage u_ex_stage
(
    .clk                (clk),
    .rst                (rst),
    .ID_pipeline_reg_out(ID_pipeline_reg_out),
    .ex_op_dest         (ex_op_dest),
    .EX_pipeline_reg_out(EX_pipeline_reg_out)
);

MEM_stage u_mem_stage
(
    .clk                (clk),
    .rst                (rst),
    .EX_pipeline_reg_out(EX_pipeline_reg_out),
    .mem_op_dest        (mem_op_dest),
    .MEM_pipeline_reg_out(MEM_pipeline_reg_out)
);

WB_stage u_wb_stage
(
    .clk                (clk),
    .rst                (rst),
    .MEM_pipeline_reg_out(MEM_pipeline_reg_out),
    .reg_write_en       (reg_write_en),
    .reg_write_dest     (reg_write_dest),
    .reg_write_data     (reg_write_data),
    .wb_op_dest         (wb_op_dest)
);

register_file u_register_file
(
    .clk                (clk),
    .rst                (rst),
    .read_addr1         (reg_read_addr1),
    .read_addr2         (reg_read_addr2),
    .read_data1         (reg_read_data1),
    .read_data2         (reg_read_data2),
    .write_en           (reg_write_en),
    .write_dest         (reg_write_dest),
    .write_data         (reg_write_data)
);

hazard_detection_unit u_hazard_detection_unit
(
    .decoding_op_src1   (decoding_op_src1),
    .decoding_op_src2   (decoding_op_src2),
    .ex_op_dest         (ex_op_dest),
    .mem_op_dest        (mem_op_dest),
    .wb_op_dest         (wb_op_dest),
    .pipeline_stall_n   (pipeline_stall_n)
);

endmodule
