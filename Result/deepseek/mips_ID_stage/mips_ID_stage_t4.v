`timescale 1ns/1ps

// MIPS_16 ID stage module
module ID_stage
(
    input                clk,
    input                rst,
    input                instruction_decode_en,
    // to EX_stage
    output reg [56:0]    pipeline_reg_out,
    // to IF_stage
    input        [15:0]  instruction,
    output       [5:0]   branch_offset_imm,
    output reg           branch_taken,
    // to register file
    output       [2:0]   reg_read_addr_1,
    output       [2:0]   reg_read_addr_2,
    input        [15:0]  reg_read_data_1,
    input        [15:0]  reg_read_data_2,
    // to hazard detection unit
    output       [2:0]   decoding_op_src1,
    output       [2:0]   decoding_op_src2
);

// Opcode definitions
localparam OP_ADD  = 4'b0000;
localparam OP_SUB  = 4'b0001;
localparam OP_AND  = 4'b0010;
localparam OP_OR   = 4'b0011;
localparam OP_XOR  = 4'b0100;
localparam OP_SL   = 4'b0101;
localparam OP_SR   = 4'b0110;
localparam OP_SRU  = 4'b0111;
localparam OP_ADDI = 4'b1000;
localparam OP_LD   = 4'b1001;
localparam OP_ST   = 4'b1010;
localparam OP_BZ   = 4'b1011;
localparam OP_NOP  = 4'b0000; // NOP opcode (same as ADD, but handled by control)

// ALU command definitions (3 bits)
localparam ALU_ADD = 3'b000;
localparam ALU_SUB = 3'b001;
localparam ALU_AND = 3'b010;
localparam ALU_OR  = 3'b011;
localparam ALU_XOR = 3'b100;
localparam ALU_SL  = 3'b101;
localparam ALU_SR  = 3'b110;
localparam ALU_SRU = 3'b111;
localparam ALU_PASS = 3'b000; // for LD, ST, ADDI we also use ADD for address calc

// Internal registers
reg [15:0] instruction_reg;

// Internal wires for instruction fields
wire [3:0] opcode;
wire [2:0] dest;
wire [2:0] src1;
wire [2:0] src2;
wire [5:0] imm;

// Bubble insertion wires
wire [3:0] ir_op_code_with_bubble;
wire [2:0] ir_dest_with_bubble;

// Combinational signals for pipeline output
wire [2:0] alu_cmd;
wire [15:0] alu_src1;
wire [15:0] alu_src2;
wire mem_write_en;
wire [15:0] mem_write_data;
wire write_back_en;
wire [2:0] write_back_dest;
wire write_back_result_mux;

// Branch related
wire decoding_op_is_branch;

// Instruction fields extraction
assign opcode = instruction_reg[15:12];
assign dest   = instruction_reg[11:9];
assign src1   = instruction_reg[8:6];
assign src2   = instruction_reg[5:3];
assign imm    = instruction_reg[5:0];

// Bubble insertion: when instruction_decode_en is low, force opcode to NOP and dest to 0
assign ir_op_code_with_bubble = (instruction_decode_en) ? opcode : 4'b0000;
assign ir_dest_with_bubble = (instruction_decode_en) ? dest : 3'b000;

// Register file read addresses
assign reg_read_addr_1 = src1;
assign reg_read_addr_2 = (ir_op_code_with_bubble == OP_ST) ? instruction_reg[11:9] : src2;

// Hazard detection unit outputs
assign decoding_op_src1 = src1;

// decoding_op_src2: force to zero for instructions that do not use second source
always_comb begin
    case (ir_op_code_with_bubble)
        OP_NOP, OP_ADDI, OP_LD, OP_BZ: decoding_op_src2 = 3'b000;
        default: decoding_op_src2 = src2;
    endcase
end

// Branch detection
assign decoding_op_is_branch = (ir_op_code_with_bubble == OP_BZ);
assign branch_offset_imm = imm; // immediate offset to IF stage

// Branch taken logic (combinational)
// For BRANCH_Z, taken if register data 1 equals zero
always_comb begin
    if (decoding_op_is_branch && (reg_read_data_1 == 16'b0))
        branch_taken = 1'b1;
    else
        branch_taken = 1'b0;
end

// Combinational control logic for pipeline_reg_out next value
always_comb begin
    // Default values
    alu_cmd = ALU_ADD;
    alu_src1 = reg_read_data_1;
    alu_src2 = reg_read_data_2;
    mem_write_en = 1'b0;
    mem_write_data = 16'b0;
    write_back_en = 1'b0;
    write_back_dest = ir_dest_with_bubble;
    write_back_result_mux = 1'b0; // ALU result

    case (ir_op_code_with_bubble)
        // Arithmetic/logical R-type
        OP_ADD: begin
            alu_cmd = ALU_ADD;
            write_back_en = 1'b1;
        end
        OP_SUB: begin
            alu_cmd = ALU_SUB;
            write_back_en = 1'b1;
        end
        OP_AND: begin
            alu_cmd = ALU_AND;
            write_back_en = 1'b1;
        end
        OP_OR: begin
            alu_cmd = ALU_OR;
            write_back_en = 1'b1;
        end
        OP_XOR: begin
            alu_cmd = ALU_XOR;
            write_back_en = 1'b1;
        end
        OP_SL: begin
            alu_cmd = ALU_SL;
            write_back_en = 1'b1;
        end
        OP_SR: begin
            alu_cmd = ALU_SR;
            write_back_en = 1'b1;
        end
        OP_SRU: begin
            alu_cmd = ALU_SRU;
            write_back_en = 1'b1;
        end
        // ADDI: ALU add with sign-extended immediate
        OP_ADDI: begin
            alu_cmd = ALU_ADD;
            alu_src2 = {{10{imm[5]}}, imm}; // sign extend 6-bit to 16
            write_back_en = 1'b1;
            write_back_result_mux = 1'b0;
        end
        // Load: ALU add for address, write back from memory
        OP_LD: begin
            alu_cmd = ALU_ADD;
            alu_src2 = {{10{imm[5]}}, imm};
            mem_write_en = 1'b0;
            write_back_en = 1'b1;
            write_back_result_mux = 1'b1; // select memory data
        end
        // Store: ALU add for address, memory write, no write back
        OP_ST: begin
            alu_cmd = ALU_ADD;
            alu_src2 = {{10{imm[5]}}, imm};
            mem_write_en = 1'b1;
            mem_write_data = reg_read_data_2; // data to store from second read port
            write_back_en = 1'b0;
            write_back_result_mux = 1'b0;
        end
        // Branch: no writes
        OP_BZ: begin
            mem_write_en = 1'b0;
            write_back_en = 1'b0;
            // ALU not used, set to safe value
            alu_cmd = ALU_ADD;
        end
        // NOP or unknown
        default: begin
            // everything default
        end
    endcase
end

// Sequential logic: instruction register and pipeline output register
always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        instruction_reg <= 16'b0;
        pipeline_reg_out <= 57'b0;
    end else begin
        // Update instruction register only when decode enable is high (or hold)
        if (instruction_decode_en)
            instruction_reg <= instruction;
        // pipeline register always updates
        pipeline_reg_out <= {
            alu_cmd,          // [56:54]
            alu_src1,         // [53:38]
            alu_src2,         // [37:22]
            mem_write_en,     // [21]
            mem_write_data,   // [20:5]
            write_back_en,    // [4]
            write_back_dest,  // [3:1]
            write_back_result_mux // [0]
        };
    end
end

endmodule
