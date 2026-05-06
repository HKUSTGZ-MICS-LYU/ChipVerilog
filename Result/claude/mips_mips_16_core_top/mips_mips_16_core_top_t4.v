//=============================================================================
// Module Name : mips_16_core_top
// Description : Top-level integration module of the MIPS_16 processor core.
//               Connects all five pipeline stages (IF/ID/EX/MEM/WB),
//               the register file, and the hazard detection unit together
//               to form a complete 16-bit pipelined CPU datapath.
//
// Pipeline    : Classic 5-stage static pipeline (IF -> ID -> EX -> MEM -> WB)
// Data Width  : 16-bit
// Reg File    : 8 x 16-bit general-purpose registers (R0 hard-wired to zero)
// Hazard      : RAW hazard detection by stall (no forwarding)
//=============================================================================
`include "mips_16_define.v"

module mips_16_core_top
(
    input                       clk,
    input                       rst,

    output  [`PC_WIDTH-1:0]     pc
);

    //-------------------------------------------------------------------------
    // Internal Wires
    //-------------------------------------------------------------------------

    // ---- IF stage <-> ID stage ----
    wire    [15:0]              if_instruction;        // fetched instruction

    // ---- ID stage <-> Register File ----
    wire    [2:0]               id_reg_read_addr1;     // register file read address 1
    wire    [2:0]               id_reg_read_addr2;     // register file read address 2
    wire    [15:0]              rf_read_data1;         // register file read data 1
    wire    [15:0]              rf_read_data2;         // register file read data 2

    // ---- ID stage -> IF stage (branch path) ----
    wire    [`PC_WIDTH-1:0]     branch_offset_imm;     // branch offset immediate
    wire                        branch_taken;          // branch decision

    // ---- ID stage -> Hazard Detection Unit ----
    wire    [2:0]               decoding_op_src1;      // src1 register number in ID
    wire    [2:0]               decoding_op_src2;      // src2 register number in ID

    // ---- ID stage -> EX stage pipeline bus (57 bits) ----
    wire    [56:0]              ID_pipeline_reg_out;

    // ---- EX stage -> MEM stage pipeline bus (38 bits) ----
    wire    [37:0]              EX_pipeline_reg_out;

    // ---- EX stage -> Hazard Detection Unit ----
    wire    [2:0]               ex_op_dest;            // dest register in EX

    // ---- MEM stage -> WB stage pipeline bus (37 bits) ----
    wire    [36:0]              MEM_pipeline_reg_out;

    // ---- MEM stage -> Hazard Detection Unit ----
    wire    [2:0]               mem_op_dest;           // dest register in MEM

    // ---- WB stage -> Register File ----
    wire                        reg_write_en;          // write-back enable
    wire    [2:0]               reg_write_dest;        // write-back destination
    wire    [15:0]              reg_write_data;        // write-back data

    // ---- WB stage -> Hazard Detection Unit ----
    wire    [2:0]               wb_op_dest;            // dest register in WB

    // ---- Hazard Detection Unit -> IF/ID stages ----
    wire                        pipeline_stall_n;      // active-low stall signal


    //-------------------------------------------------------------------------
    // IF stage : Program Counter & Instruction Memory
    //-------------------------------------------------------------------------
    IF_stage  u_IF_stage
    (
        .clk                    (clk),
        .rst                    (rst),

        // stall control (active-low)
        .instruction_fetch_en   (pipeline_stall_n),

        // branch path from ID stage
        .branch_offset_imm      (branch_offset_imm),
        .branch_taken           (branch_taken),

        // outputs to ID stage
        .pc                     (pc),
        .instruction            (if_instruction)
    );


    //-------------------------------------------------------------------------
    // ID stage : Decoding, control generation, branch decision, register read
    //-------------------------------------------------------------------------
    ID_stage  u_ID_stage
    (
        .clk                    (clk),
        .rst                    (rst),

        // stall control (active-low) -- freezes ID & inserts bubble
        .instruction_decode_en  (pipeline_stall_n),

        // from IF stage
        .pc                     (pc),
        .instruction            (if_instruction),

        // register file interface
        .reg_read_addr1         (id_reg_read_addr1),
        .reg_read_addr2         (id_reg_read_addr2),
        .reg_read_data1         (rf_read_data1),
        .reg_read_data2         (rf_read_data2),

        // branch outputs to IF stage
        .branch_offset_imm      (branch_offset_imm),
        .branch_taken           (branch_taken),

        // source register numbers to hazard detection unit
        .decoding_op_src1       (decoding_op_src1),
        .decoding_op_src2       (decoding_op_src2),

        // pipeline register output to EX stage
        .ID_pipeline_reg_out    (ID_pipeline_reg_out)
    );


    //-------------------------------------------------------------------------
    // EX stage : ALU execution
    //-------------------------------------------------------------------------
    EX_stage  u_EX_stage
    (
        .clk                    (clk),
        .rst                    (rst),

        // pipeline bus from ID stage
        .ID_pipeline_reg_out    (ID_pipeline_reg_out),

        // pipeline bus to MEM stage
        .EX_pipeline_reg_out    (EX_pipeline_reg_out),

        // dest register to hazard detection unit
        .ex_op_dest             (ex_op_dest)
    );


    //-------------------------------------------------------------------------
    // MEM stage : Data memory access (load / store)
    //-------------------------------------------------------------------------
    MEM_stage  u_MEM_stage
    (
        .clk                    (clk),
        .rst                    (rst),

        // pipeline bus from EX stage
        .EX_pipeline_reg_out    (EX_pipeline_reg_out),

        // pipeline bus to WB stage
        .MEM_pipeline_reg_out   (MEM_pipeline_reg_out),

        // dest register to hazard detection unit
        .mem_op_dest            (mem_op_dest)
    );


    //-------------------------------------------------------------------------
    // WB stage : Write-back data selection & register file write
    //-------------------------------------------------------------------------
    WB_stage  u_WB_stage
    (
        // pipeline bus from MEM stage
        .MEM_pipeline_reg_out   (MEM_pipeline_reg_out),

        // register file write-back signals
        .reg_write_en           (reg_write_en),
        .reg_write_dest         (reg_write_dest),
        .reg_write_data         (reg_write_data),

        // dest register to hazard detection unit
        .wb_op_dest             (wb_op_dest)
    );


    //-------------------------------------------------------------------------
    // Register File : 8 x 16-bit, 2 read ports + 1 write port (R0 = 0)
    //-------------------------------------------------------------------------
    register_file  u_register_file
    (
        .clk                    (clk),
        .rst                    (rst),

        // read ports (driven by ID stage)
        .reg_read_addr1         (id_reg_read_addr1),
        .reg_read_addr2         (id_reg_read_addr2),
        .reg_read_data1         (rf_read_data1),
        .reg_read_data2         (rf_read_data2),

        // write port (driven by WB stage)
        .reg_write_en           (reg_write_en),
        .reg_write_dest         (reg_write_dest),
        .reg_write_data         (reg_write_data)
    );


    //-------------------------------------------------------------------------
    // Hazard Detection Unit : RAW hazard detection by stall
    //
    // If decoding_op_src1 / decoding_op_src2 in ID matches the destination of
    // the instructions currently in EX / MEM / WB, drive pipeline_stall_n low
    // to freeze IF & ID and insert a bubble into EX.
    //-------------------------------------------------------------------------
    hazard_detection_unit  u_hazard_detection_unit
    (
        // source registers from ID
        .decoding_op_src1       (decoding_op_src1),
        .decoding_op_src2       (decoding_op_src2),

        // destination registers from EX / MEM / WB
        .ex_op_dest             (ex_op_dest),
        .mem_op_dest            (mem_op_dest),
        .wb_op_dest             (wb_op_dest),

        // active-low stall output
        .pipeline_stall_n       (pipeline_stall_n)
    );


endmodule