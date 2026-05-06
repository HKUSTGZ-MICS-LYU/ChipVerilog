module mips_16_core_top (
    input                      clk,
    input                      rst,
    output [`PC_WIDTH-1:0]     pc
);

    // Internal signals
    wire                        stall_n;
    wire [`PC_WIDTH-1:0]        branch_offset_imm;
    wire                        branch_taken;
    wire [15:0]                 instruction;

    // ID <-> Register file
    wire [2:0]                  reg_read_addr1;
    wire [2:0]                  reg_read_addr2;
    wire [15:0]                 reg_read_data1;
    wire [15:0]                 reg_read_data2;

    // Pipeline register buses
    wire [56:0]                 ID_pipeline_reg_out;
    wire [37:0]                 EX_pipeline_reg_out;
    wire [36:0]                 MEM_pipeline_reg_out;

    // Hazard detection signals
    wire [2:0]                  decoding_op_src1;
    wire [2:0]                  decoding_op_src2;
    wire [2:0]                  ex_op_dest;
    wire [2:0]                  mem_op_dest;
    wire [2:0]                  wb_op_dest;

    // Write-back signals
    wire                        reg_write_en;
    wire [2:0]                  reg_write_dest;
    wire [15:0]                 reg_write_data;

    // Instantiate pipeline stages
    IF_stage u_IF_stage (
        .clk                  (clk),
        .rst                  (rst),
        .stall_n              (stall_n),
        .branch_offset_imm    (branch_offset_imm),
        .branch_taken         (branch_taken),
        .pc                   (pc),
        .instruction          (instruction)
    );

    ID_stage u_ID_stage (
        .clk                  (clk),
        .rst                  (rst),
        .stall_n              (stall_n),
        .instruction          (instruction),
        .reg_read_data1       (reg_read_data1),
        .reg_read_data2       (reg_read_data2),
        .reg_read_addr1       (reg_read_addr1),
        .reg_read_addr2       (reg_read_addr2),
        .branch_taken         (branch_taken),
        .branch_offset_imm    (branch_offset_imm),
        .ID_pipeline_reg_out  (ID_pipeline_reg_out),
        .decoding_op_src1     (decoding_op_src1),
        .decoding_op_src2     (decoding_op_src2)
    );

    EX_stage u_EX_stage (
        .clk                  (clk),
        .rst                  (rst),
        .ID_pipeline_reg_out  (ID_pipeline_reg_out),
        .EX_pipeline_reg_out  (EX_pipeline_reg_out),
        .ex_op_dest           (ex_op_dest)
    );

    MEM_stage u_MEM_stage (
        .clk                  (clk),
        .rst                  (rst),
        .EX_pipeline_reg_out  (EX_pipeline_reg_out),
        .MEM_pipeline_reg_out (MEM_pipeline_reg_out),
        .mem_op_dest          (mem_op_dest)
    );

    WB_stage u_WB_stage (
        .clk                  (clk),
        .rst                  (rst),
        .MEM_pipeline_reg_out (MEM_pipeline_reg_out),
        .reg_write_en         (reg_write_en),
        .reg_write_dest       (reg_write_dest),
        .reg_write_data       (reg_write_data),
        .wb_op_dest           (wb_op_dest)
    );

    // Register file
    register_file u_register_file (
        .clk                  (clk),
        .rst                  (rst),
        .reg_write_en         (reg_write_en),
        .reg_write_dest       (reg_write_dest),
        .reg_write_data       (reg_write_data),
        .reg_read_addr1       (reg_read_addr1),
        .reg_read_addr2       (reg_read_addr2),
        .reg_read_data1       (reg_read_data1),
        .reg_read_data2       (reg_read_data2)
    );

    // Hazard detection unit
    hazard_detection_unit u_hazard_detection_unit (
        .decoding_op_src1      (decoding_op_src1),
        .decoding_op_src2      (decoding_op_src2),
        .ex_op_dest            (ex_op_dest),
        .mem_op_dest           (mem_op_dest),
        .wb_op_dest            (wb_op_dest),
        .pipeline_stall_n      (stall_n)
    );

endmodule
