module mips_16_core_top (
    input                     clk,
    input                     rst,
    output [`PC_WIDTH-1:0]    pc
);

    // IF_stage signals
    wire                      pipeline_stall_n;
    wire [15:0]               instruction;
    wire                      branch_taken;
    wire [15:0]               branch_offset_imm;

    // ID_stage signals
    wire [2:0]                reg_read_addr1, reg_read_addr2;
    wire [15:0]               reg_read_data1, reg_read_data2;
    wire [56:0]               ID_pipeline_reg_out;
    wire [2:0]                decoding_op_src1, decoding_op_src2;

    // EX_stage signals
    wire [37:0]               EX_pipeline_reg_out;
    wire [2:0]                ex_op_dest;

    // MEM_stage signals
    wire [36:0]               MEM_pipeline_reg_out;
    wire [2:0]                mem_op_dest;

    // WB_stage signals
    wire                      reg_write_en;
    wire [2:0]                reg_write_dest;
    wire [15:0]               reg_write_data;
    wire [2:0]                wb_op_dest;

    // Instantiate IF_stage
    IF_stage u_if_stage (
        .clk                (clk),
        .rst                (rst),
        .pipeline_stall_n   (pipeline_stall_n),
        .branch_taken       (branch_taken),
        .branch_offset_imm  (branch_offset_imm),
        .pc                 (pc),
        .instruction        (instruction)
    );

    // Instantiate ID_stage
    ID_stage u_id_stage (
        .clk                (clk),
        .rst                (rst),
        .pipeline_stall_n   (pipeline_stall_n),
        .instruction        (instruction),
        .reg_read_data1     (reg_read_data1),
        .reg_read_data2     (reg_read_data2),
        .reg_read_addr1     (reg_read_addr1),
        .reg_read_addr2     (reg_read_addr2),
        .ID_pipeline_reg_out(ID_pipeline_reg_out),
        .decoding_op_src1   (decoding_op_src1),
        .decoding_op_src2   (decoding_op_src2),
        .branch_taken       (branch_taken),
        .branch_offset_imm  (branch_offset_imm)
    );

    // Instantiate EX_stage
    EX_stage u_ex_stage (
        .clk                (clk),
        .rst                (rst),
        .ID_pipeline_reg_in (ID_pipeline_reg_out),
        .EX_pipeline_reg_out(EX_pipeline_reg_out),
        .ex_op_dest         (ex_op_dest)
    );

    // Instantiate MEM_stage
    MEM_stage u_mem_stage (
        .clk                (clk),
        .rst                (rst),
        .EX_pipeline_reg_in (EX_pipeline_reg_out),
        .MEM_pipeline_reg_out(MEM_pipeline_reg_out),
        .mem_op_dest        (mem_op_dest)
    );

    // Instantiate WB_stage
    WB_stage u_wb_stage (
        .clk                (clk),
        .rst                (rst),
        .MEM_pipeline_reg_in(MEM_pipeline_reg_out),
        .reg_write_en       (reg_write_en),
        .reg_write_dest     (reg_write_dest),
        .reg_write_data     (reg_write_data),
        .wb_op_dest         (wb_op_dest)
    );

    // Instantiate register_file
    register_file u_register_file (
        .clk                (clk),
        .rst                (rst),
        .reg_write_en       (reg_write_en),
        .reg_write_dest     (reg_write_dest),
        .reg_write_data     (reg_write_data),
        .reg_read_addr1     (reg_read_addr1),
        .reg_read_addr2     (reg_read_addr2),
        .reg_read_data1     (reg_read_data1),
        .reg_read_data2     (reg_read_data2)
    );

    // Instantiate hazard_detection_unit
    hazard_detection_unit u_hazard_detection_unit (
        .decoding_op_src1   (decoding_op_src1),
        .decoding_op_src2   (decoding_op_src2),
        .ex_op_dest         (ex_op_dest),
        .mem_op_dest        (mem_op_dest),
        .wb_op_dest         (wb_op_dest),
        .pipeline_stall_n   (pipeline_stall_n)
    );

endmodule
