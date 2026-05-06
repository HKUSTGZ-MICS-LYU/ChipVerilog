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

reg [15:0] instruction_reg;

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

localparam [2:0] ALU_ADD = 3'd0;
localparam [2:0] ALU_SUB = 3'd1;
localparam [2:0] ALU_AND = 3'd2;
localparam [2:0] ALU_OR  = 3'd3;
localparam [2:0] ALU_XOR = 3'd4;
localparam [2:0] ALU_SL  = 3'd5;
localparam [2:0] ALU_SR  = 3'd6;
localparam [2:0] ALU_SRU = 3'd7;

wire [3:0] ir_op_code = instruction_reg[15:12];
wire [2:0] ir_dest    = instruction_reg[11:9];
wire [2:0] ir_src1    = instruction_reg[8:6];
wire [2:0] ir_src2    = instruction_reg[5:3];
wire [5:0] ir_imm     = instruction_reg[5:0];

wire [15:0] sign_ext_imm = {{10{ir_imm[5]}}, ir_imm};
wire [3:0] ir_op_code_with_bubble = instruction_decode_en ? ir_op_code : OP_NOP;
wire [2:0] ir_dest_with_bubble    = instruction_decode_en ? ir_dest : 3'b000;
wire       decoding_op_is_branch  = (ir_op_code_with_bubble == OP_BZ);

reg [2:0]  ex_alu_cmd_comb;
reg [15:0] ex_alu_src1_comb;
reg [15:0] ex_alu_src2_comb;
reg        mem_write_en_comb;
reg [15:0] mem_write_data_comb;
reg        write_back_en_comb;
reg [2:0]  write_back_dest_comb;
reg        write_back_result_mux_comb;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        instruction_reg <= 16'b0;
    end else if (instruction_decode_en) begin
        instruction_reg <= instruction;
    end
end

assign reg_read_addr_1 = ir_src1;
assign reg_read_addr_2 = (ir_op_code == OP_ST) ? ir_dest : ir_src2;

assign branch_offset_imm = ir_imm;
assign decoding_op_src1 = ir_src1;
assign decoding_op_src2 = (ir_op_code == OP_ST)                 ? ir_dest :
                          ((ir_op_code == OP_NOP)  ||
                           (ir_op_code == OP_ADDI) ||
                           (ir_op_code == OP_LD)   ||
                           (ir_op_code == OP_BZ))  ? 3'b000 :
                                                      ir_src2;

always @(*) begin
    ex_alu_cmd_comb              = ALU_ADD;
    ex_alu_src1_comb             = reg_read_data_1;
    ex_alu_src2_comb             = reg_read_data_2;
    mem_write_en_comb            = 1'b0;
    mem_write_data_comb          = 16'b0;
    write_back_en_comb           = 1'b0;
    write_back_dest_comb         = ir_dest_with_bubble;
    write_back_result_mux_comb   = 1'b0;

    case (ir_op_code_with_bubble)
        OP_ADD: begin
            ex_alu_cmd_comb    = ALU_ADD;
            write_back_en_comb = 1'b1;
        end
        OP_SUB: begin
            ex_alu_cmd_comb    = ALU_SUB;
            write_back_en_comb = 1'b1;
        end
        OP_AND: begin
            ex_alu_cmd_comb    = ALU_AND;
            write_back_en_comb = 1'b1;
        end
        OP_OR: begin
            ex_alu_cmd_comb    = ALU_OR;
            write_back_en_comb = 1'b1;
        end
        OP_XOR: begin
            ex_alu_cmd_comb    = ALU_XOR;
            write_back_en_comb = 1'b1;
        end
        OP_SL: begin
            ex_alu_cmd_comb    = ALU_SL;
            write_back_en_comb = 1'b1;
        end
        OP_SR: begin
            ex_alu_cmd_comb    = ALU_SR;
            write_back_en_comb = 1'b1;
        end
        OP_SRU: begin
            ex_alu_cmd_comb    = ALU_SRU;
            write_back_en_comb = 1'b1;
        end
        OP_ADDI: begin
            ex_alu_cmd_comb    = ALU_ADD;
            ex_alu_src2_comb   = sign_ext_imm;
            write_back_en_comb = 1'b1;
        end
        OP_LD: begin
            ex_alu_cmd_comb            = ALU_ADD;
            ex_alu_src2_comb           = sign_ext_imm;
            write_back_en_comb         = 1'b1;
            write_back_result_mux_comb = 1'b1;
        end
        OP_ST: begin
            ex_alu_cmd_comb     = ALU_ADD;
            ex_alu_src2_comb    = sign_ext_imm;
            mem_write_en_comb   = 1'b1;
            mem_write_data_comb = reg_read_data_2;
        end
        default: begin
            ex_alu_cmd_comb            = ALU_ADD;
            ex_alu_src1_comb           = reg_read_data_1;
            ex_alu_src2_comb           = reg_read_data_2;
            mem_write_en_comb          = 1'b0;
            mem_write_data_comb        = 16'b0;
            write_back_en_comb         = 1'b0;
            write_back_dest_comb       = ir_dest_with_bubble;
            write_back_result_mux_comb = 1'b0;
        end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pipeline_reg_out <= 57'b0;
    end else begin
        pipeline_reg_out <= {
            ex_alu_cmd_comb,
            ex_alu_src1_comb,
            ex_alu_src2_comb,
            mem_write_en_comb,
            mem_write_data_comb,
            write_back_en_comb,
            write_back_dest_comb,
            write_back_result_mux_comb
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
