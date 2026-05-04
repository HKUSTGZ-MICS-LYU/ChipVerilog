//============================================================================
// Module Name  : ID_stage
// Description  : Instruction Decode stage of MIPS_16 5-stage pipeline processor
//                - Decodes 16-bit instruction from IF_stage
//                - Generates control signals for EX/MEM/WB stages
//                - Reads source operands from register file
//                - Handles branch decision in decode stage
//                - Supports pipeline bubble insertion for stall handling
//                - Provides source register info to hazard detection unit
//============================================================================

module ID_stage
(
    input                   clk,
    input                   rst,
    input                   instruction_decode_en,
    //input                 insert_bubble,
    
    // to EX_stage
    output  reg [56:0]      pipeline_reg_out,   // [56:22],35bits: ex_alu_cmd[2:0], ex_alu_src1[15:0], ex_alu_src2[15:0]
                                                // [21:5],17bits:  mem_write_en, mem_write_data[15:0]
                                                // [4:0],5bits:    write_back_en, write_back_dest[2:0], write_back_result_mux
    
    // to IF_stage
    input       [15:0]      instruction,
    output      [5:0]       branch_offset_imm,
    output  reg             branch_taken,
    
    // to register file
    output      [2:0]       reg_read_addr_1,    // register file read port 1 address
    output      [2:0]       reg_read_addr_2,    // register file read port 2 address
    input       [15:0]      reg_read_data_1,    // register file read port 1 data
    input       [15:0]      reg_read_data_2,    // register file read port 2 data
    
    // to hazard detection unit
    output      [2:0]       decoding_op_src1,   // source_1 register number
    output      [2:0]       decoding_op_src2    // source_2 register number
);

    //========================================================================
    // Opcode definitions (MIPS_16 ISA)
    //========================================================================
    localparam  OP_NOP   = 4'b0000;
    localparam  OP_ADD   = 4'b0001;
    localparam  OP_SUB   = 4'b0010;
    localparam  OP_AND   = 4'b0011;
    localparam  OP_OR    = 4'b0100;
    localparam  OP_XOR   = 4'b0101;
    localparam  OP_SL    = 4'b0110;     // shift left
    localparam  OP_SR    = 4'b0111;     // shift right (arithmetic)
    localparam  OP_SRU   = 4'b1000;     // shift right unsigned (logical)
    localparam  OP_ADDI  = 4'b1001;
    localparam  OP_LD    = 4'b1010;
    localparam  OP_ST    = 4'b1011;
    localparam  OP_BZ    = 4'b1100;

    //========================================================================
    // ALU command encoding
    //========================================================================
    localparam  ALU_ADD  = 3'b000;
    localparam  ALU_SUB  = 3'b001;
    localparam  ALU_AND  = 3'b010;
    localparam  ALU_OR   = 3'b011;
    localparam  ALU_XOR  = 3'b100;
    localparam  ALU_SL   = 3'b101;
    localparam  ALU_SR   = 3'b110;
    localparam  ALU_SRU  = 3'b111;

    //========================================================================
    // Branch condition encoding
    //========================================================================
    localparam  BRANCH_Z = 3'b000;      // branch if zero

    //========================================================================
    // Internal instruction register
    //========================================================================
    reg     [15:0]  instruction_reg;

    always @(posedge clk) begin
        if (rst) begin
            instruction_reg <= 16'b0;
        end
        else if (instruction_decode_en) begin
            instruction_reg <= instruction;
        end
        // else: hold previous value to support pipeline stall (freeze)
    end

    //========================================================================
    // Instruction field extraction
    //========================================================================
    wire    [3:0]   ir_op_code;
    wire    [2:0]   ir_dest;
    wire    [2:0]   ir_src1;
    wire    [2:0]   ir_src2;
    wire    [5:0]   ir_imm;

    assign  ir_op_code = instruction_reg[15:12];
    assign  ir_dest    = instruction_reg[11:9];
    assign  ir_src1    = instruction_reg[8:6];
    assign  ir_src2    = instruction_reg[5:3];
    assign  ir_imm     = instruction_reg[5:0];

    //========================================================================
    // Bubble insertion logic
    // When instruction_decode_en is low, force opcode = NOP and dest = 0
    // to prevent stalled instructions from generating spurious side effects
    //========================================================================
    wire    [3:0]   ir_op_code_with_bubble;
    wire    [2:0]   ir_dest_with_bubble;

    assign  ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : OP_NOP;
    assign  ir_dest_with_bubble    = instruction_decode_en ? ir_dest    : 3'b000;

    //========================================================================
    // Sign-extension of 6-bit immediate to 16 bits
    //========================================================================
    wire    [15:0]  imm_sign_ext;
    assign  imm_sign_ext = {{10{ir_imm[5]}}, ir_imm};

    //========================================================================
    // Register file read address generation
    //   - Port 1 always reads ir_src1
    //   - Port 2 reads ir_src2 normally; for ST instruction, reads ir_dest
    //     because ST needs base address (src1) and store data (in dest field)
    //========================================================================
    assign  reg_read_addr_1 = ir_src1;
    assign  reg_read_addr_2 = (ir_op_code_with_bubble == OP_ST) ? ir_dest
                                                                : ir_src2;

    //========================================================================
    // Source register output to hazard detection unit
    //   - For instructions with no second source operand (NOP/ADDI/LD/BZ),
    //     force decoding_op_src2 = 0 to avoid false RAW hazards
    //     (register R0 is the architectural zero register)
    //========================================================================
    assign  decoding_op_src1 = ir_src1;
    assign  decoding_op_src2 = (ir_op_code_with_bubble == OP_NOP)  ? 3'b000 :
                               (ir_op_code_with_bubble == OP_ADDI) ? 3'b000 :
                               (ir_op_code_with_bubble == OP_LD)   ? 3'b000 :
                               (ir_op_code_with_bubble == OP_BZ)   ? 3'b000 :
                               (ir_op_code_with_bubble == OP_ST)   ? ir_dest :
                                                                     ir_src2;

    //========================================================================
    // Central control logic (combinational)
    // Generates control signals based on decoded opcode
    //========================================================================
    reg     [2:0]   ex_alu_cmd;
    reg     [15:0]  ex_alu_src1;
    reg     [15:0]  ex_alu_src2;
    reg             mem_write_en;
    reg     [15:0]  mem_write_data;
    reg             write_back_en;
    reg     [2:0]   write_back_dest;
    reg             write_back_result_mux;  // 0: ALU result, 1: memory data

    always @(*) begin
        // Default values (NOP-like behavior)
        ex_alu_cmd            = ALU_ADD;
        ex_alu_src1           = reg_read_data_1;
        ex_alu_src2           = reg_read_data_2;
        mem_write_en          = 1'b0;
        mem_write_data        = 16'b0;
        write_back_en         = 1'b0;
        write_back_dest       = ir_dest_with_bubble;
        write_back_result_mux = 1'b0;

        case (ir_op_code_with_bubble)
            //----------------------------------------------------------------
            // NOP: no operation
            //----------------------------------------------------------------
            OP_NOP: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = 16'b0;
                ex_alu_src2           = 16'b0;
                mem_write_en          = 1'b0;
                write_back_en         = 1'b0;
                write_back_result_mux = 1'b0;
            end

            //----------------------------------------------------------------
            // R-type arithmetic / logical / shift instructions
            // dest <- src1 OP src2
            //----------------------------------------------------------------
            OP_ADD: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;       // ALU result
            end
            OP_SUB: begin
                ex_alu_cmd            = ALU_SUB;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_AND: begin
                ex_alu_cmd            = ALU_AND;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_OR: begin
                ex_alu_cmd            = ALU_OR;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_XOR: begin
                ex_alu_cmd            = ALU_XOR;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_SL: begin
                ex_alu_cmd            = ALU_SL;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_SR: begin
                ex_alu_cmd            = ALU_SR;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end
            OP_SRU: begin
                ex_alu_cmd            = ALU_SRU;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = reg_read_data_2;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;
            end

            //----------------------------------------------------------------
            // ADDI: dest <- src1 + sign_ext(imm)
            //----------------------------------------------------------------
            OP_ADDI: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = imm_sign_ext;       // immediate as 2nd operand
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b0;               // ALU result
            end

            //----------------------------------------------------------------
            // LD: dest <- MEM[src1 + sign_ext(imm)]
            // ALU computes effective address; write-back from memory data
            //----------------------------------------------------------------
            OP_LD: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = imm_sign_ext;
                mem_write_en          = 1'b0;
                write_back_en         = 1'b1;
                write_back_result_mux = 1'b1;               // memory data
            end

            //----------------------------------------------------------------
            // ST: MEM[src1 + sign_ext(imm)] <- dest_reg_data
            // ALU computes address; reg_read_data_2 (read from dest field) is
            // the data to be stored.
            //----------------------------------------------------------------
            OP_ST: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = reg_read_data_1;
                ex_alu_src2           = imm_sign_ext;
                mem_write_en          = 1'b1;
                mem_write_data        = reg_read_data_2;    // store data
                write_back_en         = 1'b0;
            end

            //----------------------------------------------------------------
            // BZ: branch if reg_read_data_1 == 0
            // Branch decision is made here in ID stage (no write-back, no mem)
            //----------------------------------------------------------------
            OP_BZ: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = 16'b0;
                ex_alu_src2           = 16'b0;
                mem_write_en          = 1'b0;
                write_back_en         = 1'b0;
            end

            //----------------------------------------------------------------
            // Default: behave as NOP for unimplemented opcodes
            //----------------------------------------------------------------
            default: begin
                ex_alu_cmd            = ALU_ADD;
                ex_alu_src1           = 16'b0;
                ex_alu_src2           = 16'b0;
                mem_write_en          = 1'b0;
                write_back_en         = 1'b0;
                write_back_result_mux = 1'b0;
            end
        endcase
    end

    //========================================================================
    // Branch control logic (combinational)
    //   decoding_op_is_branch is true when opcode == OP_BZ
    //   The branch condition field is assumed to be encoded in bits [8:6]
    //   (same field as src1 in the BZ instruction format).
    //   Per the description, BRANCH_Z asserts branch_taken when
    //   reg_read_data_1 == 0.
    //========================================================================
    wire            decoding_op_is_branch;
    wire    [2:0]   branch_condition;

    assign  decoding_op_is_branch = (ir_op_code_with_bubble == OP_BZ);
    assign  branch_condition      = ir_src1;        // condition field

    always @(*) begin
        branch_taken = 1'b0;
        if (decoding_op_is_branch) begin
            case (branch_condition)
                BRANCH_Z: branch_taken = (reg_read_data_1 == 16'b0);
                default : branch_taken = 1'b0;
            endcase
        end
    end

    // Branch offset immediate sent back to IF_stage for target calculation
    assign  branch_offset_imm = ir_imm;

    //========================================================================
    // Output pipeline register to EX_stage
    // Layout (57 bits):
    //   [56:54]  ex_alu_cmd        (3 bits)
    //   [53:38]  ex_alu_src1       (16 bits)
    //   [37:22]  ex_alu_src2       (16 bits)
    //   [21]     mem_write_en      (1 bit)
    //   [20:5]   mem_write_data    (16 bits)
    //   [4]      write_back_en     (1 bit)
    //   [3:1]    write_back_dest   (3 bits)
    //   [0]      write_back_result_mux (1 bit)
    //========================================================================
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 57'b0;
        end
        else begin
            pipeline_reg_out <= {
                ex_alu_cmd,             // [56:54]
                ex_alu_src1,            // [53:38]
                ex_alu_src2,            // [37:22]
                mem_write_en,           // [21]
                mem_write_data,         // [20:5]
                write_back_en,          // [4]
                write_back_dest,        // [3:1]
                write_back_result_mux   // [0]
            };
        end
    end

endmodule