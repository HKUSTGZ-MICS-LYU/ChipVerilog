// Define opcodes
`define OP_NOP   4'b0000
`define OP_ADD   4'b0001
`define OP_SUB   4'b0010
`define OP_AND   4'b0011
`define OP_OR    4'b0100
`define OP_XOR   4'b0101
`define OP_SL    4'b0110
`define OP_SR    4'b0111
`define OP_SRU   4'b1000
`define OP_ADDI  4'b1001
`define OP_LD    4'b1010
`define OP_ST    4'b1011
`define OP_BZ    4'b1100

// Define ALU commands
`define ALU_ADD  3'b000
`define ALU_SUB  3'b001
`define ALU_AND  3'b010
`define ALU_OR   3'b011
`define ALU_XOR  3'b100
`define ALU_SL   3'b101
`define ALU_SR   3'b110
`define ALU_SRU  3'b111

// Define branch conditions
`define BRANCH_Z 2'b00
// other conditions can be defined if needed

module ID_stage
(
    input                    clk,
    input                    rst,
    input                    instruction_decode_en,
    
    // to EX_stage
    output reg [56:0]        pipeline_reg_out,
    
    // to IF_stage
    input        [15:0]      instruction,
    output       [5:0]       branch_offset_imm,
    output reg               branch_taken,
    
    // to register file
    output       [2:0]       reg_read_addr_1,
    output       [2:0]       reg_read_addr_2,
    input        [15:0]      reg_read_data_1,
    input        [15:0]      reg_read_data_2,
    
    // to hazard detection unit
    output       [2:0]       decoding_op_src1,
    output       [2:0]       decoding_op_src2
);

    // Internal instruction register
    reg [15:0] instruction_reg;

    // Instruction fields extracted from instruction_reg
    wire [3:0]  ir_opcode;
    wire [2:0]  ir_dest;
    wire [2:0]  ir_src1;
    wire [2:0]  ir_src2;
    wire [5:0]  ir_imm;

    // Decoded opcode with bubble insertion
    wire [3:0]  ir_op_code_with_bubble;
    wire [2:0]  ir_dest_with_bubble;

    // Control signals
    reg         wb_en;
    reg         wb_result_mux; // 0: ALU result, 1: memory data
    reg [2:0]   alu_cmd;
    reg         alu_src2_sel;  // 0: reg_read_data_2, 1: sign-extended immediate
    reg         mem_write_en;
    reg         is_branch;
    wire [15:0] sign_extended_imm;

    // ALU operands
    wire [15:0] alu_src1;
    wire [15:0] alu_src2;

    // Memory write data
    wire [15:0] mem_write_data;

    // Update instruction register
    always @(posedge clk or posedge rst) begin
        if (rst)
            instruction_reg <= 16'h0000;
        else if (instruction_decode_en)
            instruction_reg <= instruction;
        // else hold previous value (stall)
    end

    // Extract instruction fields
    assign ir_opcode = instruction_reg[15:12];
    assign ir_dest   = instruction_reg[11:9];
    assign ir_src1   = instruction_reg[8:6];
    assign ir_src2   = instruction_reg[5:3];
    assign ir_imm    = instruction_reg[5:0];

    // Bubble insertion: if decode is disabled, force NOP
    assign ir_op_code_with_bubble = instruction_decode_en ? ir_opcode : `OP_NOP;
    assign ir_dest_with_bubble    = instruction_decode_en ? ir_dest   : 3'b000;

    // Sign-extend immediate (6-bit to 16-bit)
    assign sign_extended_imm = {{10{ir_imm[5]}}, ir_imm};

    // Register file read addresses
    assign reg_read_addr_1 = ir_src1;
    // For store, second read address is destination register (data to store)
    assign reg_read_addr_2 = (ir_op_code_with_bubble == `OP_ST) ? ir_dest : ir_src2;

    // Hazard detection source registers
    assign decoding_op_src1 = ir_src1;
    assign decoding_op_src2 = (ir_op_code_with_bubble == `OP_NOP  ||
                               ir_op_code_with_bubble == `OP_ADDI ||
                               ir_op_code_with_bubble == `OP_LD   ||
                               ir_op_code_with_bubble == `OP_BZ)  ? 3'b000 : ir_src2;

    // Central control logic (combinational)
    always @(*) begin
        // Default values
        wb_en         = 1'b0;
        wb_result_mux = 1'b0;
        alu_cmd       = `ALU_ADD;
        alu_src2_sel  = 1'b0;
        mem_write_en  = 1'b0;
        is_branch     = 1'b0;

        case (ir_op_code_with_bubble)
            `OP_ADD: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_ADD;
            end
            `OP_SUB: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_SUB;
            end
            `OP_AND: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_AND;
            end
            `OP_OR: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_OR;
            end
            `OP_XOR: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_XOR;
            end
            `OP_SL: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_SL;
            end
            `OP_SR: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_SR;
            end
            `OP_SRU: begin
                wb_en    = 1'b1;
                alu_cmd  = `ALU_SRU;
            end
            `OP_ADDI: begin
                wb_en        = 1'b1;
                alu_cmd      = `ALU_ADD;
                alu_src2_sel = 1'b1; // use immediate
            end
            `OP_LD: begin
                wb_en         = 1'b1;
                wb_result_mux = 1'b1; // select memory data for WB
                alu_cmd       = `ALU_ADD;
                alu_src2_sel  = 1'b1; // use immediate as offset
            end
            `OP_ST: begin
                mem_write_en  = 1'b1;
                alu_cmd       = `ALU_ADD;
                alu_src2_sel  = 1'b1; // use immediate as offset
            end
            `OP_BZ: begin
                is_branch     = 1'b1;
                // no write-back, no memory access
            end
            default: begin
                // NOP or undefined: all defaults
            end
        endcase
    end

    // ALU source selection
    assign alu_src1 = reg_read_data_1;
    assign alu_src2 = alu_src2_sel ? sign_extended_imm : reg_read_data_2;

    // Memory write data (always from second read port)
    assign mem_write_data = reg_read_data_2;

    // Pipeline output register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pipeline_reg_out <= 57'b0;
        end else begin
            // Pack control signals and data into pipeline_reg_out
            // [56:54] ex_alu_cmd
            // [53:38] ex_alu_src1
            // [37:22] ex_alu_src2
            // [21]    mem_write_en
            // [20:5]  mem_write_data
            // [4]     write_back_en
            // [3:1]   write_back_dest
            // [0]     write_back_result_mux
            pipeline_reg_out <= {alu_cmd, alu_src1, alu_src2,
                                 mem_write_en, mem_write_data,
                                 wb_en, ir_dest_with_bubble, wb_result_mux};
        end
    end

    // Branch logic
    assign branch_offset_imm = ir_imm;

    always @(*) begin
        branch_taken = 1'b0;
        if (is_branch) begin
            // Check branch condition field (bits [11:10] of instruction)
            // For OP_BZ, condition field is instruction_reg[11:10]
            case (instruction_reg[11:10])
                `BRANCH_Z: begin
                    if (reg_read_data_1 == 16'h0000)
                        branch_taken = 1'b1;
                    else
                        branch_taken = 1'b0;
                end
                // Additional conditions can be added here
                default: branch_taken = 1'b0;
            endcase
        end
    end

endmodule
