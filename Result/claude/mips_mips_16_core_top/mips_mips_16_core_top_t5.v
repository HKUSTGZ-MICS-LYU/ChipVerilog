module mips_16_core_top
(
    input                       clk,
    input                       rst,

    output  [`PC_WIDTH-1:0]     pc
);

    //--------------------------------------------------------------------------
    // Internal Signal Declarations
    //--------------------------------------------------------------------------

    // IF <-> ID
    wire [15:0]                 instruction;

    // ID <-> IF (branch)
    wire [`PC_WIDTH-1:0]        branch_offset_imm;
    wire                        branch_taken;

    // ID -> EX pipeline bus
    wire [56:0]                 ID_pipeline_reg_out;

    // EX -> MEM pipeline bus
    wire [37:0]                 EX_pipeline_reg_out;

    // MEM -> WB pipeline bus
    wire [36:0]                 MEM_pipeline_reg_out;

    // Register file: ID read ports
    wire [2:0]                  reg_read_addr1;
    wire [2:0]                  reg_read_addr2;
    wire [15:0]                 reg_read_data1;
    wire [15:0]                 reg_read_data2;

    // WB -> register file write ports
    wire                        reg_write_en;
    wire [2:0]                  reg_write_dest;
    wire [15:0]                 reg_write_data;

    // Hazard detection: source registers from ID
    wire [2:0]                  decoding_op_src1;
    wire [2:0]                  decoding_op_src2;

    // Hazard detection: destination registers from EX, MEM, WB
    wire [2:0]                  ex_op_dest;
    wire [2:0]                  mem_op_dest;
    wire [2:0]                  wb_op_dest;

    // Stall control (active-low)
    wire                        pipeline_stall_n;

    //--------------------------------------------------------------------------
    // IF Stage
    //--------------------------------------------------------------------------
    IF_stage u_IF_stage
    (
        .clk                    (clk),
        .rst                    (rst),
        .instruction_fetch_en   (pipeline_stall_n),
        .branch_offset_imm      (branch_offset_imm),
        .branch_taken           (branch_taken),
        .pc                     (pc),
        .instruction            (instruction)
    );

    //--------------------------------------------------------------------------
    // ID Stage
    //--------------------------------------------------------------------------
    ID_stage u_ID_stage
    (
        .clk                    (clk),
        .rst                    (rst),
        .instruction_decode_en  (pipeline_stall_n),
        .instruction            (instruction),
        // Register file read
        .reg_read_addr1         (reg_read_addr1),
        .reg_read_addr2         (reg_read_addr2),
        .reg_read_data1         (reg_read_data1),
        .reg_read_data2         (reg_read_data2),
        // Branch to IF
        .branch_offset_imm      (branch_offset_imm),
        .branch_taken           (branch_taken),
        // Hazard source registers
        .decoding_op_src1       (decoding_op_src1),
        .decoding_op_src2       (decoding_op_src2),
        // Pipeline bus to EX
        .ID_pipeline_reg_out    (ID_pipeline_reg_out)
    );

    //--------------------------------------------------------------------------
    // EX Stage
    //--------------------------------------------------------------------------
    EX_stage u_EX_stage
    (
        .clk                    (clk),
        .rst                    (rst),
        .ID_pipeline_reg_in     (ID_pipeline_reg_out),
        .ex_op_dest             (ex_op_dest),
        .EX_pipeline_reg_out    (EX_pipeline_reg_out)
    );

    //--------------------------------------------------------------------------
    // MEM Stage
    //--------------------------------------------------------------------------
    MEM_stage u_MEM_stage
    (
        .clk                    (clk),
        .rst                    (rst),
        .EX_pipeline_reg_in     (EX_pipeline_reg_out),
        .mem_op_dest            (mem_op_dest),
        .MEM_pipeline_reg_out   (MEM_pipeline_reg_out)
    );

    //--------------------------------------------------------------------------
    // WB Stage
    //--------------------------------------------------------------------------
    WB_stage u_WB_stage
    (
        .clk                    (clk),
        .rst                    (rst),
        .MEM_pipeline_reg_in    (MEM_pipeline_reg_out),
        .wb_op_dest             (wb_op_dest),
        .reg_write_en           (reg_write_en),
        .reg_write_dest         (reg_write_dest),
        .reg_write_data         (reg_write_data)
    );

    //--------------------------------------------------------------------------
    // Register File
    //--------------------------------------------------------------------------
    register_file u_register_file
    (
        .clk                    (clk),
        // Write port (from WB)
        .reg_write_en           (reg_write_en),
        .reg_write_dest         (reg_write_dest),
        .reg_write_data         (reg_write_data),
        // Read port 1 (from ID)
        .reg_read_addr1         (reg_read_addr1),
        .reg_read_data1         (reg_read_data1),
        // Read port 2 (from ID)
        .reg_read_addr2         (reg_read_addr2),
        .reg_read_data2         (reg_read_data2)
    );

    //--------------------------------------------------------------------------
    // Hazard Detection Unit
    //--------------------------------------------------------------------------
    hazard_detection_unit u_hazard_detection_unit
    (
        // Source registers of instruction in ID stage
        .decoding_op_src1       (decoding_op_src1),
        .decoding_op_src2       (decoding_op_src2),
        // Destination registers of instructions in EX, MEM, WB stages
        .ex_op_dest             (ex_op_dest),
        .mem_op_dest            (mem_op_dest),
        .wb_op_dest             (wb_op_dest),
        // Active-low stall output
        .pipeline_stall_n       (pipeline_stall_n)
    );

endmodule