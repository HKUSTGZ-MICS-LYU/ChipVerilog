// MIPS_16 ID stage implementation
// OPCODE definitions
`define OP_NOP  4'h0
`define OP_ADD  4'h1
`define OP_SUB  4'h2
`define OP_AND  4'h3
`define OP_OR   4'h4
`define OP_XOR  4'h5
`define OP_SL   4'h6
`define OP_SR   4'h7
`define OP_SRU  4'h8
`define OP_ADDI 4'h9
`define OP_LD   4'hA
`define OP_ST   4'hB
`define OP_BZ   4'hC

// ALU command definitions
`define ALU_ADD  3'b000
`define ALU_SUB  3'b001
`define ALU_AND  3'b010
`define ALU_OR   3'b011
`define ALU_XOR  3'b100
`define ALU_SL   3'b101
`define ALU_SR   3'b110
`define ALU_SRU  3'b111

// Branch condition
`define BRANCH_Z 1'b0

module ID_stage
(
    input                   clk,
    input                   rst,
    input                   instruction_decode_en,
    
    // to EX_stage
    output  reg [56:0]      pipeline_reg_out,
    
    // to IF_stage
    input       [15:0]      instruction,
    output      [5:0]       branch_offset_imm,
    output  reg             branch_taken,
    
    // to register file
    output      [2:0]       reg_read_addr_1,
    output      [2:0]       reg_read_addr_2,
    input       [15:0]      reg_read_data_1,
    input       [15:0]      reg_read_data_2,
    
    // to hazard detection unit
    output      [2:0]       decoding_op_src1,
    output      [2:0]       decoding_op_src2
);

    // Internal instruction register
    reg  [15:0] instruction_reg;
    
    // Instruction fields
    wire [3:0]  ir_op_code;
    wire [2:0]  ir_dest;
    wire [2:0]  ir_src1;
    wire [2:0]  ir_src2;
    wire [5:0]  ir_imm;
    
    // With bubble insertion
    reg  [3:0]  ir_op_code_with_bubble;
    reg  [2:0]  ir_dest_with_bubble;
    
    // Control signals
    wire        is_store;
    wire        is_load;
    wire        is_branch;
    wire        is_immediate;
    wire        is_nop;
    wire        is_reg_reg;
    
    // Decoded control outputs
    reg  [2:0]  alu_cmd;
    reg         mem_write_en;
    reg         write_back_en;
    reg         write_back_result_mux;  // 0: ALU result, 1: Memory data
    reg  [15:0] alu_src1;
    reg  [15:0] alu_src2;
    reg  [15:0] mem_write_data;
    reg  [2:0]  write_back_dest;
    
    // Sign-extended immediate
    wire [15:0] sign_extended_imm;
    
    // Instruction register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instruction_reg <= 16'h0000;
        end else if (instruction_decode_en) begin
            instruction_reg <= instruction;
        end
    end
    
    // Extract instruction fields from instruction_reg
    assign ir_op_code = instruction_reg[15:12];
    assign ir_dest    = instruction_reg[11:9];
    assign ir_src1    = instruction_reg[8:6];
    assign ir_src2    = instruction_reg[5:3];
    assign ir_imm     = instruction_reg[5:0];
    
    // Bubble insertion: when decode is disabled, force NOP
    always @(*) begin
        if (instruction_decode_en) begin
            ir_op_code_with_bubble = ir_op_code;
            ir_dest_with_bubble    = ir_dest;
        end else begin
            ir_op_code_with_bubble = `OP_NOP;
            ir_dest_with_bubble    = 3'b000;
        end
    end
    
    // Instruction type identification
    assign is_store     = (ir_op_code_with_bubble == `OP_ST);
    assign is_load      = (ir_op_code_with_bubble == `OP_LD);
    assign is_branch    = (ir_op_code_with_bubble == `OP_BZ);
    assign is_immediate = (ir_op_code_with_bubble == `OP_ADDI);
    assign is_nop       = (ir_op_code_with_bubble == `OP_NOP);
    assign is_reg_reg   = (ir_op_code_with_bubble == `OP_ADD) || 
                          (ir_op_code_with_bubble == `OP_SUB) || 
                          (ir_op_code_with_bubble == `OP_AND) || 
                          (ir_op_code_with_bubble == `OP_OR)  || 
                          (ir_op_code_with_bubble == `OP_XOR) || 
                          (ir_op_code_with_bubble == `OP_SL)  || 
                          (ir_op_code_with_bubble == `OP_SR)  || 
                          (ir_op_code_with_bubble == `OP_SRU);
    
    // Sign-extend immediate
    assign sign_extended_imm = {{10{ir_imm[5]}}, ir_imm};
    
    // Register file read addresses
    assign reg_read_addr_1 = ir_src1;
    // For store, second read address is destination (data to store)
    assign reg_read_addr_2 = is_store ? ir_dest : ir_src2;
    
    // Central control logic: ALU command, memory, write-back signals
    always @(*) begin
        // Default values
        alu_cmd               = `ALU_ADD;
        mem_write_en          = 1'b0;
        write_back_en         = 1'b0;
        write_back_result_mux = 1'b0;
        alu_src1              = reg_read_data_1;
        alu_src2              = reg_read_data_2;
        mem_write_data        = 16'h0000;
        write_back_dest       = ir_dest_with_bubble;
        
        case (ir_op_code_with_bubble)
            `OP_ADD: begin
                alu_cmd       = `ALU_ADD;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_SUB: begin
                alu_cmd       = `ALU_SUB;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_AND: begin
                alu_cmd       = `ALU_AND;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_OR: begin
                alu_cmd       = `ALU_OR;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_XOR: begin
                alu_cmd       = `ALU_XOR;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_SL: begin
                alu_cmd       = `ALU_SL;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_SR: begin
                alu_cmd       = `ALU_SR;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_SRU: begin
                alu_cmd       = `ALU_SRU;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_ADDI: begin
                alu_cmd       = `ALU_ADD;
                alu_src2      = sign_extended_imm;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b0;
            end
            `OP_LD: begin
                alu_cmd       = `ALU_ADD;
                alu_src2      = sign_extended_imm;
                write_back_en = 1'b1;
                write_back_result_mux = 1'b1;  // Select memory data
            end
            `OP_ST: begin
                alu_cmd       = `ALU_ADD;
                alu_src2      = sign_extended_imm;
                mem_write_en  = 1'b1;
                mem_write_data = reg_read_data_2;  // Data from second read port (destination reg)
                write_back_en = 1'b0;
            end
            `OP_BZ: begin
                // No ALU operation, write-back disabled
                write_back_en = 1'b0;
            end
            default: begin
                // NOP or unknown: defaults remain
            end
        endcase
    end
    
    // Branch logic
    wire decoding_op_is_branch;
    assign decoding_op_is_branch = is_branch;
    
    always @(*) begin
        branch_taken = 1'b0;
        if (decoding_op_is_branch) begin
            // Branch condition: bit 8 of instruction determines branch type
            // For BRANCH_Z (bit 8 = 0), branch if reg_read_data_1 == 0
            if (instruction_reg[8] == `BRANCH_Z) begin
                if (reg_read_data_1 == 16'h0000) begin
                    branch_taken = 1'b1;
                end
            end
        end
    end
    
    assign branch_offset_imm = ir_imm;
    
    // Pipeline register output
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pipeline_reg_out <= 57'h0;
        end else begin
            // Pack control signals into pipeline_reg_out
            // [56:54] alu_cmd
            // [53:38] alu_src1
            // [37:22] alu_src2
            // [21]    mem_write_en
            // [20:5]  mem_write_data
            // [4]     write_back_en
            // [3:1]   write_back_dest
            // [0]     write_back_result_mux
            pipeline_reg_out <= {
                alu_cmd,                    // [56:54]
                alu_src1,                   // [53:38]
                alu_src2,                   // [37:22]
                mem_write_en,               // [21]
                mem_write_data,             // [20:5]
                write_back_en,              // [4]
                write_back_dest,            // [3:1]
                write_back_result_mux       // [0]
            };
        end
    end
    
    // Hazard detection outputs
    assign decoding_op_src1 = ir_src1;
    assign decoding_op_src2 = (is_nop || is_immediate || is_load || is_branch) ? 3'b000 : ir_src2;

endmodule
