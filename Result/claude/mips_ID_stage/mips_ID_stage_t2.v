// ============================================================
// ID_stage.v  –  Instruction Decode Stage for MIPS-16
//
// Instruction word layout (16 bits):
//   [15:12]  opcode      (4 bits)
//   [11:9]   dest        (3 bits)  / branch condition for BZ
//   [8:6]    src1        (3 bits)
//   [5:3]    src2        (3 bits)
//   [5:0]    imm6        (6 bits, overlaps src2/src1 LSBs)
//
// pipeline_reg_out [56:0] to EX_stage:
//   [56:54]  alu_cmd           (3 bits)
//   [53:38]  alu_src1          (16 bits)
//   [37:22]  alu_src2          (16 bits)
//   [21]     mem_write_en      (1 bit)
//   [20:5]   mem_write_data    (16 bits)
//   [4]      write_back_en     (1 bit)
//   [3:1]    write_back_dest   (3 bits)
//   [0]      write_back_result_mux (1 bit)
// ============================================================

`include "mips_16_defs.v"

module ID_stage
(
    input                   clk,
    input                   rst,
    input                   instruction_decode_en,

    // to EX_stage
    output reg  [56:0]      pipeline_reg_out,

    // from / to IF_stage
    input        [15:0]     instruction,
    output       [5:0]      branch_offset_imm,
    output reg              branch_taken,

    // to / from register file
    output       [2:0]      reg_read_addr_1,
    output       [2:0]      reg_read_addr_2,
    input        [15:0]     reg_read_data_1,
    input        [15:0]     reg_read_data_2,

    // to hazard detection unit
    output       [2:0]      decoding_op_src1,
    output       [2:0]      decoding_op_src2
);

    // ----------------------------------------------------------
    // Instruction register – holds the current instruction
    // Updated on rising edge when instruction_decode_en is high.
    // Frozen (stalled) when instruction_decode_en is low.
    // ----------------------------------------------------------
    reg [15:0] instruction_reg;

    always @(posedge clk) begin
        if (rst)
            instruction_reg <= 16'b0;
        else if (instruction_decode_en)
            instruction_reg <= instruction;
        // else: hold current value (pipeline stall)
    end

    // ----------------------------------------------------------
    // Raw field extraction from instruction_reg
    // ----------------------------------------------------------
    wire [3:0] ir_op_code = instruction_reg[15:12];
    wire [2:0] ir_dest    = instruction_reg[11:9];
    wire [2:0] ir_src1    = instruction_reg[8:6];
    wire [2:0] ir_src2    = instruction_reg[5:3];
    wire [5:0] ir_imm     = instruction_reg[5:0];
    wire [1:0] ir_branch_cond = instruction_reg[11:10]; // branch condition in BZ

    // ----------------------------------------------------------
    // Bubble insertion
    // When instruction_decode_en is low (stall), force opcode
    // and dest to zero → NOP bubble into EX_stage.
    // ----------------------------------------------------------
    wire [3:0] ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : 4'b0;
    wire [2:0] ir_dest_with_bubble    = instruction_decode_en ? ir_dest    : 3'b0;

    // ----------------------------------------------------------
    // Sign-extended immediate (6-bit → 16-bit)
    // ----------------------------------------------------------
    wire [15:0] imm_sign_extended = {{10{ir_imm[5]}}, ir_imm};

    // ----------------------------------------------------------
    // Register file read addresses
    // For ST: reg_read_addr_2 uses the dest field (data to store)
    // For all others: reg_read_addr_2 uses ir_src2
    // ----------------------------------------------------------
    assign reg_read_addr_1 = ir_src1;
    assign reg_read_addr_2 = (ir_op_code_with_bubble == `OP_ST)
                             ? ir_dest_with_bubble
                             : ir_src2;

    // ----------------------------------------------------------
    // Hazard detection unit source register outputs
    // src2 is forced to 0 for instructions that have no second
    // source register (NOP, ADDI, LD, BZ) to avoid false stalls.
    // ----------------------------------------------------------
    assign decoding_op_src1 = ir_src1;
    assign decoding_op_src2 = (ir_op_code_with_bubble == `OP_ADDI ||
                               ir_op_code_with_bubble == `OP_LD   ||
                               ir_op_code_with_bubble == `OP_BZ   ||
                               ir_op_code_with_bubble == 4'b0)      // NOP/bubble
                              ? 3'b0
                              : ir_src2;

    // ----------------------------------------------------------
    // Branch outputs (combinational)
    // ----------------------------------------------------------
    assign branch_offset_imm    = ir_imm;
    wire   decoding_op_is_branch = (ir_op_code_with_bubble == `OP_BZ);

    always @(*) begin
        branch_taken = 1'b0;
        if (decoding_op_is_branch) begin
            case (ir_branch_cond)
                `BRANCH_Z : branch_taken = (reg_read_data_1 == 16'b0);
                default   : branch_taken = 1'b0;
            endcase
        end
    end

    // ----------------------------------------------------------
    // Control logic + pipeline_reg_out packing
    // All control signals are computed combinationally and then
    // registered into pipeline_reg_out on the rising clock edge.
    // ----------------------------------------------------------

    // Intermediate control signals
    reg  [2:0]  alu_cmd;
    reg  [15:0] alu_src1;
    reg  [15:0] alu_src2;
    reg         mem_write_en;
    reg  [15:0] mem_write_data;
    reg         write_back_en;
    reg  [2:0]  write_back_dest;
    reg         write_back_result_mux;

    always @(*) begin
        // Defaults – safe NOP state
        alu_cmd              = `ALU_ADD;
        alu_src1             = reg_read_data_1;
        alu_src2             = reg_read_data_2;
        mem_write_en         = 1'b0;
        mem_write_data       = 16'b0;
        write_back_en        = 1'b0;
        write_back_dest      = ir_dest_with_bubble;
        write_back_result_mux = `WB_FROM_ALU;

        case (ir_op_code_with_bubble)
            // --- Register-to-register arithmetic / logic ---
            `OP_ADD : begin
                alu_cmd   = `ALU_ADD;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_SUB : begin
                alu_cmd   = `ALU_SUB;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_AND : begin
                alu_cmd   = `ALU_AND;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_OR  : begin
                alu_cmd   = `ALU_OR;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_XOR : begin
                alu_cmd   = `ALU_XOR;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_SL  : begin
                alu_cmd   = `ALU_SL;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_SR  : begin
                alu_cmd   = `ALU_SR;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end
            `OP_SRU : begin
                alu_cmd   = `ALU_SRU;
                alu_src2  = reg_read_data_2;
                write_back_en = 1'b1;
            end

            // --- Immediate add ---
            `OP_ADDI : begin
                alu_cmd   = `ALU_ADD;
                alu_src2  = imm_sign_extended;
                write_back_en = 1'b1;
            end

            // --- Load: ALU computes address, WB from memory ---
            `OP_LD : begin
                alu_cmd              = `ALU_ADD;
                alu_src2             = imm_sign_extended;
                write_back_en        = 1'b1;
                write_back_result_mux = `WB_FROM_MEM;
            end

            // --- Store: ALU computes address, write data = reg[dest] ---
            `OP_ST : begin
                alu_cmd        = `ALU_ADD;
                alu_src2       = imm_sign_extended;
                mem_write_en   = 1'b1;
                mem_write_data = reg_read_data_2; // reg_read_addr_2 = ir_dest
                write_back_en  = 1'b0;
            end

            // --- Branch: no write-back, no memory write ---
            `OP_BZ : begin
                alu_cmd       = `ALU_ADD;   // ALU unused; don't-care value
                write_back_en = 1'b0;
            end

            // --- NOP / bubble (opcode == 0 or any unrecognised) ---
            default : begin
                alu_cmd       = `ALU_ADD;
                write_back_en = 1'b0;
            end
        endcase
    end

    // ----------------------------------------------------------
    // Pipeline register update
    // Pack all control / data signals into the 57-bit output bus.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 57'b0;
        end else begin
            pipeline_reg_out[56:54] <= alu_cmd;
            pipeline_reg_out[53:38] <= alu_src1;
            pipeline_reg_out[37:22] <= alu_src2;
            pipeline_reg_out[21]    <= mem_write_en;
            pipeline_reg_out[20:5]  <= mem_write_data;
            pipeline_reg_out[4]     <= write_back_en;
            pipeline_reg_out[3:1]   <= write_back_dest;
            pipeline_reg_out[0]     <= write_back_result_mux;
        end
    end

endmodule
