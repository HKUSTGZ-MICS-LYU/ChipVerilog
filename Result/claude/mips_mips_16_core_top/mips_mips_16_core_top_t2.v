//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 Core Top — Five-Stage Pipeline Integration          ////
////                                                              ////
////  Connects IF, ID, EX, MEM, WB stages, register file, and    ////
////  hazard detection unit into a complete 16-bit pipelined CPU. ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module mips_16_core_top (
    input                    clk,
    input                    rst,

    output [`PC_WIDTH-1:0]   pc
);

    // ----------------------------------------------------------------
    // Internal wires — pipeline inter-stage buses
    // ----------------------------------------------------------------
    wire [15:0] if_instruction;         // IF  → ID
    wire [56:0] ID_pipeline_reg_out;    // ID  → EX
    wire [37:0] EX_pipeline_reg_out;    // EX  → MEM
    wire [36:0] MEM_pipeline_reg_out;   // MEM → WB

    // ----------------------------------------------------------------
    // Internal wires — branch control (ID → IF)
    // ----------------------------------------------------------------
    wire [15:0] branch_offset_imm;
    wire        branch_taken;

    // ----------------------------------------------------------------
    // Internal wires — register file (ID ↔ RF, WB → RF)
    // ----------------------------------------------------------------
    wire  [2:0] reg_read_addr1, reg_read_addr2;
    wire [15:0] reg_read_data1, reg_read_data2;
    wire        reg_write_en;
    wire  [2:0] reg_write_dest;
    wire [15:0] reg_write_data;

    // ----------------------------------------------------------------
    // Internal wires — hazard detection
    // ----------------------------------------------------------------
    wire        pipeline_stall_n;       // active-low stall
    wire  [2:0] decoding_op_src1;       // ID  → HDU
    wire  [2:0] decoding_op_src2;       // ID  → HDU
    wire  [2:0] ex_op_dest;             // EX  → HDU
    wire  [2:0] mem_op_dest;            // MEM → HDU
    wire  [2:0] wb_op_dest;             // WB  → HDU

    // ================================================================
    // 1. IF STAGE
    // ================================================================
    IF_stage if_stage (
        .clk                  (clk),
        .rst                  (rst),
        .instruction_fetch_en (pipeline_stall_n),
        .branch_offset_imm    (branch_offset_imm),
        .branch_taken         (branch_taken),
        .pc                   (pc),
        .instruction          (if_instruction)
    );

    // ================================================================
    // 2. ID STAGE
    // ================================================================
    ID_stage id_stage (
        .clk                  (clk),
        .rst                  (rst),
        .instruction_decode_en(pipeline_stall_n),
        .instruction          (if_instruction),
        // Register file read ports
        .reg_read_addr1       (reg_read_addr1),
        .reg_read_addr2       (reg_read_addr2),
        .reg_read_data1       (reg_read_data1),
        .reg_read_data2       (reg_read_data2),
        // Branch outputs to IF
        .branch_offset_imm    (branch_offset_imm),
        .branch_taken         (branch_taken),
        // Hazard detection source registers
        .decoding_op_src1     (decoding_op_src1),
        .decoding_op_src2     (decoding_op_src2),
        // Pipeline register to EX
        .pipeline_reg_out     (ID_pipeline_reg_out)
    );

    // ================================================================
    // 3. EX STAGE
    // ================================================================
    EX_stage ex_stage (
        .clk              (clk),
        .rst              (rst),
        .pipeline_reg_in  (ID_pipeline_reg_out),
        .pipeline_reg_out (EX_pipeline_reg_out),
        .ex_op_dest       (ex_op_dest)
    );

    // ================================================================
    // 4. MEM STAGE
    // ================================================================
    MEM_stage mem_stage (
        .clk              (clk),
        .rst              (rst),
        .pipeline_reg_in  (EX_pipeline_reg_out),
        .pipeline_reg_out (MEM_pipeline_reg_out),
        .mem_op_dest      (mem_op_dest)
    );

    // ================================================================
    // 5. WB STAGE
    // ================================================================
    WB_stage wb_stage (
        .clk              (clk),
        .rst              (rst),
        .pipeline_reg_in  (MEM_pipeline_reg_out),
        .reg_write_en     (reg_write_en),
        .reg_write_dest   (reg_write_dest),
        .reg_write_data   (reg_write_data),
        .wb_op_dest       (wb_op_dest)
    );

    // ================================================================
    // 6. REGISTER FILE
    // ================================================================
    register_file reg_file (
        .clk            (clk),
        .rst            (rst),
        // Read ports (driven by ID)
        .read_addr1     (reg_read_addr1),
        .read_addr2     (reg_read_addr2),
        .read_data1     (reg_read_data1),
        .read_data2     (reg_read_data2),
        // Write port (driven by WB)
        .write_en       (reg_write_en),
        .write_dest     (reg_write_dest),
        .write_data     (reg_write_data)
    );

    // ================================================================
    // 7. HAZARD DETECTION UNIT
    // ================================================================
    hazard_detection_unit hdu (
        // Source registers of instruction in ID
        .decoding_op_src1  (decoding_op_src1),
        .decoding_op_src2  (decoding_op_src2),
        // Destination registers of instructions in EX, MEM, WB
        .ex_op_dest        (ex_op_dest),
        .mem_op_dest       (mem_op_dest),
        .wb_op_dest        (wb_op_dest),
        // Active-low stall output
        .pipeline_stall_n  (pipeline_stall_n)
    );

endmodule
