//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 ID Stage — Instruction Decode Pipeline Stage        ////
////                                                              ////
////  Decodes 16-bit instructions, generates control signals,     ////
////  reads register file operands, handles branch decisions,     ////
////  and packs 57-bit pipeline register for EX_stage.            ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module ID_stage (
    input         clk,
    input         rst,
    input         instruction_decode_en,    // active-high; low = stall/freeze

    // From IF_stage
    input  [15:0] instruction,

    // To IF_stage — branch control
    output  [5:0] branch_offset_imm,
    output reg    branch_taken,

    // To / from register file
    output  [2:0] reg_read_addr_1,
    output  [2:0] reg_read_addr_2,
    input  [15:0] reg_read_data_1,
    input  [15:0] reg_read_data_2,

    // To EX_stage
    // [56:54] alu_cmd[2:0]
    // [53:38] alu_src1[15:0]
    // [37:22] alu_src2[15:0]
    // [21]    mem_write_en
    // [20:5]  mem_write_data[15:0]
    // [4]     write_back_en
    // [3:1]   write_back_dest[2:0]
    // [0]     write_back_result_mux
    output reg [56:0] pipeline_reg_out,

    // To hazard detection unit
    output  [2:0] decoding_op_src1,
    output  [2:0] decoding_op_src2
);

    // ----------------------------------------------------------------
    // Opcode definitions
    // ----------------------------------------------------------------
    localparam [3:0]
        OP_ADD  = 4'd0,
        OP_SUB  = 4'd1,
        OP_AND  = 4'd2,
        OP_OR   = 4'd3,
        OP_XOR  = 4'd4,
        OP_SL   = 4'd5,
        OP_SR   = 4'd6,
        OP_SRU  = 4'd7,
        OP_ADDI = 4'd8,
        OP_LD   = 4'd9,
        OP_ST   = 4'd10,
        OP_BZ   = 4'd11,
        OP_NOP  = 4'd15;    // all-zero opcode treated as NOP

    // ALU command encoding
    localparam [2:0]
        ALU_ADD = 3'd0,
        ALU_SUB = 3'd1,
        ALU_AND = 3'd2,
        ALU_OR  = 3'd3,
        ALU_XOR = 3'd4,
        ALU_SL  = 3'd5,
        ALU_SR  = 3'd6,
        ALU_SRU = 3'd7;

    // Branch condition encoding (bits [8:6] of instruction for BZ)
    localparam [2:0] BRANCH_Z = 3'd0;

    // ----------------------------------------------------------------
    // Instruction register — clocked, stall-aware
    // ----------------------------------------------------------------
    reg [15:0] instruction_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            instruction_reg <= 16'h0000;
        else if (instruction_decode_en)
            instruction_reg <= instruction;
        // else: hold (pipeline frozen)
    end

    // ----------------------------------------------------------------
    // Field extraction from instruction_reg
    // ----------------------------------------------------------------
    wire [3:0] ir_op_code = instruction_reg[15:12];
    wire [2:0] ir_dest    = instruction_reg[11:9];
    wire [2:0] ir_src1    = instruction_reg[8:6];
    wire [2:0] ir_src2    = instruction_reg[5:3];
    wire [5:0] ir_imm     = instruction_reg[5:0];

    // ----------------------------------------------------------------
    // Bubble insertion — when frozen, force NOP and dest = 0
    // ----------------------------------------------------------------
    wire [3:0] ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : 4'b0000;
    wire [2:0] ir_dest_with_bubble    = instruction_decode_en ? ir_dest    : 3'b000;

    // ----------------------------------------------------------------
    // Register file read addresses
    // For ST: second source is ir_dest (data to store)
    // ----------------------------------------------------------------
    assign reg_read_addr_1 = ir_src1;
    assign reg_read_addr_2 = (ir_op_code_with_bubble == OP_ST) ? ir_dest : ir_src2;

    // ----------------------------------------------------------------
    // Sign-extend 6-bit immediate to 16 bits
    // ----------------------------------------------------------------
    wire [15:0] imm_sign_ext = {{10{ir_imm[5]}}, ir_imm};

    // ----------------------------------------------------------------
    // Branch outputs (combinational)
    // ----------------------------------------------------------------
    assign branch_offset_imm = ir_imm;

    always @(*) begin
        branch_taken = 1'b0;
        if (ir_op_code_with_bubble == OP_BZ) begin
            case (ir_src1)      // branch condition in [8:6] for BZ
                BRANCH_Z: branch_taken = (reg_read_data_1 == 16'h0000);
                default:  branch_taken = 1'b0;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Hazard detection source registers
    // For NOP, ADDI, LD, BZ: no meaningful src2 → force to 0
    // ----------------------------------------------------------------
    assign decoding_op_src1 = ir_src1;
    assign decoding_op_src2 = (ir_op_code_with_bubble == OP_NOP  ||
                               ir_op_code_with_bubble == OP_ADDI ||
                               ir_op_code_with_bubble == OP_LD   ||
                               ir_op_code_with_bubble == OP_BZ)
                              ? 3'b000 : ir_src2;

    // ----------------------------------------------------------------
    // Control signal generation + pipeline register packing
    // Updated synchronously; cleared on reset
    // ----------------------------------------------------------------
    reg  [2:0] alu_cmd;
    reg [15:0] alu_src1, alu_src2;
    reg        mem_write_en;
    reg [15:0] mem_write_data;
    reg        write_back_en;
    reg  [2:0] write_back_dest;
    reg        write_back_result_mux;   // 0 = ALU, 1 = memory

    always @(*) begin
        // Defaults — NOP
        alu_cmd              = ALU_ADD;
        alu_src1             = reg_read_data_1;
        alu_src2             = reg_read_data_2;
        mem_write_en         = 1'b0;
        mem_write_data       = 16'h0000;
        write_back_en        = 1'b0;
        write_back_dest      = ir_dest_with_bubble;
        write_back_result_mux = 1'b0;

        case (ir_op_code_with_bubble)
            OP_ADD: begin
                alu_cmd    = ALU_ADD;
                write_back_en = 1'b1;
            end
            OP_SUB: begin
                alu_cmd    = ALU_SUB;
                write_back_en = 1'b1;
            end
            OP_AND: begin
                alu_cmd    = ALU_AND;
                write_back_en = 1'b1;
            end
            OP_OR: begin
                alu_cmd    = ALU_OR;
                write_back_en = 1'b1;
            end
            OP_XOR: begin
                alu_cmd    = ALU_XOR;
                write_back_en = 1'b1;
            end
            OP_SL: begin
                alu_cmd    = ALU_SL;
                write_back_en = 1'b1;
            end
            OP_SR: begin
                alu_cmd    = ALU_SR;
                write_back_en = 1'b1;
            end
            OP_SRU: begin
                alu_cmd    = ALU_SRU;
                write_back_en = 1'b1;
            end
            OP_ADDI: begin
                alu_cmd    = ALU_ADD;
                alu_src2   = imm_sign_ext;
                write_back_en = 1'b1;
            end
            OP_LD: begin
                alu_cmd              = ALU_ADD;         // address = src1 + imm
                alu_src2             = imm_sign_ext;
                write_back_en        = 1'b1;
                write_back_result_mux = 1'b1;           // WB from memory
            end
            OP_ST: begin
                alu_cmd        = ALU_ADD;               // address = src1 + imm
                alu_src2       = imm_sign_ext;
                mem_write_en   = 1'b1;
                mem_write_data = reg_read_data_2;       // data reg (via addr_2 = ir_dest)
                write_back_en  = 1'b0;
            end
            OP_BZ: begin
                // Branch: no write-back, no memory write
                write_back_en = 1'b0;
            end
            default: begin
                // OP_NOP and any undefined opcode
                write_back_en = 1'b0;
            end
        endcase
    end

    // Pack into pipeline_reg_out on rising edge
    always @(posedge clk or posedge rst) begin
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
