module ID_stage
(
    input                   clk,
    input                   rst,
    input                   instruction_decode_en,

    output reg [56:0]       pipeline_reg_out,

    input      [15:0]       instruction,
    output     [5:0]        branch_offset_imm,
    output reg              branch_taken,

    output     [2:0]        reg_read_addr_1,
    output     [2:0]        reg_read_addr_2,
    input      [15:0]       reg_read_data_1,
    input      [15:0]       reg_read_data_2,

    output     [2:0]        decoding_op_src1,
    output     [2:0]        decoding_op_src2
);

localparam [3:0] OP_NOP  = 4'h0;
localparam [3:0] OP_ADD  = 4'h1;
localparam [3:0] OP_SUB  = 4'h2;
localparam [3:0] OP_AND  = 4'h3;
localparam [3:0] OP_OR   = 4'h4;
localparam [3:0] OP_XOR  = 4'h5;
localparam [3:0] OP_SL   = 4'h6;
localparam [3:0] OP_SR   = 4'h7;
localparam [3:0] OP_SRU  = 4'h8;
localparam [3:0] OP_ADDI = 4'h9;
localparam [3:0] OP_LD   = 4'hA;
localparam [3:0] OP_ST   = 4'hB;
localparam [3:0] OP_BZ   = 4'hC;

localparam [2:0] ALU_ADD = 3'b000;
localparam [2:0] ALU_SUB = 3'b001;
localparam [2:0] ALU_AND = 3'b010;
localparam [2:0] ALU_OR  = 3'b011;
localparam [2:0] ALU_XOR = 3'b100;
localparam [2:0] ALU_SL  = 3'b101;
localparam [2:0] ALU_SR  = 3'b110;
localparam [2:0] ALU_SRU = 3'b111;

reg [15:0] instruction_reg;

wire [3:0] ir_op_code;
wire [2:0] ir_dest;
wire [2:0] ir_src1;
wire [2:0] ir_src2;
wire [5:0] ir_imm;
wire [15:0] ir_imm_sext;

wire [3:0] ir_op_code_with_bubble;
wire [2:0] ir_dest_with_bubble;
wire decoding_op_is_branch;

reg  [2:0] ex_alu_cmd;
reg  [15:0] ex_alu_src1;
reg  [15:0] ex_alu_src2;
reg         mem_write_en;
reg  [15:0] mem_write_data;
reg         write_back_en;
reg  [2:0] write_back_dest;
reg         write_back_result_mux;

assign ir_op_code = instruction_reg[15:12];
assign ir_dest = instruction_reg[11:9];
assign ir_src1 = instruction_reg[8:6];
assign ir_src2 = instruction_reg[5:3];
assign ir_imm = instruction_reg[5:0];
assign ir_imm_sext = {{10{ir_imm[5]}}, ir_imm};

assign ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : OP_NOP;
assign ir_dest_with_bubble = instruction_decode_en ? ir_dest : 3'b000;

assign reg_read_addr_1 = ir_src1;
assign reg_read_addr_2 = (ir_op_code == OP_ST) ? ir_dest : ir_src2;

assign decoding_op_src1 = ir_src1;
assign decoding_op_src2 =
    ((ir_op_code_with_bubble == OP_NOP) ||
     (ir_op_code_with_bubble == OP_ADDI) ||
     (ir_op_code_with_bubble == OP_LD) ||
     (ir_op_code_with_bubble == OP_BZ)) ? 3'b000 :
    ((ir_op_code_with_bubble == OP_ST) ? ir_dest : ir_src2);

assign branch_offset_imm = ir_imm;
assign decoding_op_is_branch = (ir_op_code_with_bubble == OP_BZ);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        instruction_reg <= 16'b0;
    end else if (instruction_decode_en) begin
        instruction_reg <= instruction;
    end
end

always @(*) begin
    ex_alu_cmd = ALU_ADD;
    ex_alu_src1 = reg_read_data_1;
    ex_alu_src2 = reg_read_data_2;
    mem_write_en = 1'b0;
    mem_write_data = reg_read_data_2;
    write_back_en = 1'b0;
    write_back_dest = ir_dest_with_bubble;
    write_back_result_mux = 1'b0;

    case (ir_op_code_with_bubble)
        OP_ADD: begin
            ex_alu_cmd = ALU_ADD;
            write_back_en = 1'b1;
        end
        OP_SUB: begin
            ex_alu_cmd = ALU_SUB;
            write_back_en = 1'b1;
        end
        OP_AND: begin
            ex_alu_cmd = ALU_AND;
            write_back_en = 1'b1;
        end
        OP_OR: begin
            ex_alu_cmd = ALU_OR;
            write_back_en = 1'b1;
        end
        OP_XOR: begin
            ex_alu_cmd = ALU_XOR;
            write_back_en = 1'b1;
        end
        OP_SL: begin
            ex_alu_cmd = ALU_SL;
            write_back_en = 1'b1;
        end
        OP_SR: begin
            ex_alu_cmd = ALU_SR;
            write_back_en = 1'b1;
        end
        OP_SRU: begin
            ex_alu_cmd = ALU_SRU;
            write_back_en = 1'b1;
        end
        OP_ADDI: begin
            ex_alu_cmd = ALU_ADD;
            ex_alu_src2 = ir_imm_sext;
            write_back_en = 1'b1;
        end
        OP_LD: begin
            ex_alu_cmd = ALU_ADD;
            ex_alu_src2 = ir_imm_sext;
            write_back_en = 1'b1;
            write_back_result_mux = 1'b1;
        end
        OP_ST: begin
            ex_alu_cmd = ALU_ADD;
            ex_alu_src2 = ir_imm_sext;
            mem_write_en = 1'b1;
            mem_write_data = reg_read_data_2;
            write_back_en = 1'b0;
            write_back_dest = 3'b000;
        end
        OP_BZ: begin
            ex_alu_cmd = ALU_ADD;
            ex_alu_src2 = 16'b0;
            write_back_en = 1'b0;
            write_back_dest = 3'b000;
        end
        default: begin
            ex_alu_cmd = ALU_ADD;
            ex_alu_src2 = reg_read_data_2;
            mem_write_en = 1'b0;
            mem_write_data = reg_read_data_2;
            write_back_en = 1'b0;
            write_back_dest = 3'b000;
            write_back_result_mux = 1'b0;
        end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pipeline_reg_out <= 57'b0;
    end else begin
        pipeline_reg_out <= {
            ex_alu_cmd,
            ex_alu_src1,
            ex_alu_src2,
            mem_write_en,
            mem_write_data,
            write_back_en,
            write_back_dest,
            write_back_result_mux
        };
    end
end

always @(*) begin
    branch_taken = 1'b0;
    if (decoding_op_is_branch && (reg_read_data_1 == 16'b0)) begin
        branch_taken = 1'b1;
    end
end

endmodule
