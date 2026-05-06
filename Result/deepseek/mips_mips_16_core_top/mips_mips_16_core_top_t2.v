`include "mips_16_defs.v"

module mips_16_core_top
(
    input                       clk,
    input                       rst,

    output  [`PC_WIDTH-1:0]     pc
);

    // Pipeline control signals
    wire                        pipeline_stall_n;
    wire                        branch_taken;
    wire    [`PC_WIDTH-1:0]     branch_offset_imm;
    wire    [15:0]              instruction;

    // IF stage outputs
    wire    [`PC_WIDTH-1:0]     pc_internal;

    // ID stage outputs
    wire    [56:0]              ID_pipeline_reg_out;
    wire    [2:0]               decoding_op_src1;
    wire    [2:0]               decoding_op_src2;
    wire    [2:0]               id_read_addr1;
    wire    [2:0]               id_read_addr2;

    // Register file outputs
    wire    [15:0]              reg_read_data1;
    wire    [15:0]              reg_read_data2;

    // EX stage outputs
    wire    [37:0]              EX_pipeline_reg_out;
    wire    [2:0]               ex_op_dest;

    // MEM stage outputs
    wire    [36:0]              MEM_pipeline_reg_out;
    wire    [2:0]               mem_op_dest;

    // WB stage outputs
    wire                        reg_write_en;
    wire    [2:0]               reg_write_dest;
    wire    [15:0]              reg_write_data;
    wire    [2:0]               wb_op_dest;

    // Assign top-level pc output
    assign pc = pc_internal;

    // IF_stage instantiation
    IF_stage u_IF_stage (
        .clk                (clk),
        .rst                (rst),
        .pipeline_stall_n   (pipeline_stall_n),
        .branch_taken       (branch_taken),
        .branch_offset_imm  (branch_offset_imm),
        .pc                 (pc_internal),
        .instruction        (instruction)
    );

    // ID_stage instantiation
    ID_stage u_ID_stage (
        .clk                    (clk),
        .rst                    (rst),
        .pipeline_stall_n       (pipeline_stall_n),
        .instruction            (instruction),
        .reg_read_data1         (reg_read_data1),
        .reg_read_data2         (reg_read_data2),
        .ID_pipeline_reg_out    (ID_pipeline_reg_out),
        .branch_taken           (branch_taken),
        .branch_offset_imm      (branch_offset_imm),
        .decoding_op_src1       (decoding_op_src1),
        .decoding_op_src2       (decoding_op_src2),
        .read_addr1             (id_read_addr1),
        .read_addr2             (id_read_addr2)
    );

    // EX_stage instantiation
    EX_stage u_EX_stage (
        .clk                    (clk),
        .rst                    (rst),
        .ID_pipeline_reg_in     (ID_pipeline_reg_out),
        .EX_pipeline_reg_out    (EX_pipeline_reg_out),
        .ex_op_dest             (ex_op_dest)
    );

    // MEM_stage instantiation
    MEM_stage u_MEM_stage (
        .clk                    (clk),
        .rst                    (rst),
        .EX_pipeline_reg_in     (EX_pipeline_reg_out),
        .MEM_pipeline_reg_out   (MEM_pipeline_reg_out),
        .mem_op_dest            (mem_op_dest)
    );

    // WB_stage instantiation
    WB_stage u_WB_stage (
        .clk                    (clk),
        .rst                    (rst),
        .MEM_pipeline_reg_in    (MEM_pipeline_reg_out),
        .reg_write_en           (reg_write_en),
        .reg_write_dest         (reg_write_dest),
        .reg_write_data         (reg_write_data),
        .wb_op_dest             (wb_op_dest)
    );

    // Register File instantiation
    register_file u_register_file (
        .clk                (clk),
        .rst                (rst),
        .read_addr1         (id_read_addr1),
        .read_addr2         (id_read_addr2),
        .read_data1         (reg_read_data1),
        .read_data2         (reg_read_data2),
        .write_en           (reg_write_en),
        .write_dest         (reg_write_dest),
        .write_data         (reg_write_data)
    );

    // Hazard Detection Unit instantiation
    hazard_detection_unit u_hazard_detection_unit (
        .decoding_op_src1   (decoding_op_src1),
        .decoding_op_src2   (decoding_op_src2),
        .ex_op_dest         (ex_op_dest),
        .mem_op_dest        (mem_op_dest),
        .wb_op_dest         (wb_op_dest),
        .pipeline_stall_n   (pipeline_stall_n)
    );

endmodule
