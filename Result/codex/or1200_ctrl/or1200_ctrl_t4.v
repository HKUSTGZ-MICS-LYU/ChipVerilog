`timescale 1ns/1ps
`include "or1200_defines.v"
module or1200_ctrl(
    input clk,
    input rst,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input flushpipe,
    input [31:0] if_insn,
    output reg [31:0] ex_insn,
    output reg [2:0] branch_op,
    input branch_taken,
    output [4:0] rf_addra,
    output [4:0] rf_addrb,
    output rf_rda,
    output rf_rdb,
    output reg [3:0] alu_op,
    output reg [1:0] mac_op,
    output reg [1:0] shrot_op,
    output reg [3:0] comp_op,
    output reg [4:0] rf_addrw,
    output reg [2:0] rfwb_op,
    output reg [31:0] wb_insn,
    output [31:0] simm,
    output [31:2] branch_addrofs,
    output reg [31:0] lsu_addrofs,
    output reg [1:0] sel_a,
    output reg [1:0] sel_b,
    output reg [3:0] lsu_op,
    output reg [4:0] cust5_op,
    output reg [5:0] cust5_limm,
    output reg [1:0] multicycle,
    output reg [15:0] spr_addrimm,
    input wbforw_valid,
    input du_hwbkpt,
    output reg sig_syscall,
    output reg sig_trap,
    output force_dslot_fetch,
    output reg no_more_dslot,
    output ex_void,
    output reg id_macrc_op,
    output reg ex_macrc_op,
    output reg rfe,
    output reg except_illegal
);
    localparam NOP_INSN = {`OR1200_OR32_NOP, 26'd0};
    reg [31:0] id_insn;
    reg [4:0] wb_rfaddrw;
    reg imm_signextend;
    reg sel_imm;
    reg [2:0] pre_branch_op;
    wire [5:0] op = id_insn[31:26];
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda = !(if_insn[31:26] == `OR1200_OR32_J || if_insn[31:26] == `OR1200_OR32_JAL || if_insn[31:26] == `OR1200_OR32_NOP || if_insn[31:26] == `OR1200_OR32_MOVHI);
    assign rf_rdb = (if_insn[31:26] == `OR1200_OR32_ALU || if_insn[31:26] == `OR1200_OR32_SW || if_insn[31:26] == `OR1200_OR32_SB || if_insn[31:26] == `OR1200_OR32_SH || if_insn[31:26] == `OR1200_OR32_SFXX);
    assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'd0, id_insn[15:0]};
    assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0]};
    assign force_dslot_fetch = 1'b0;
    assign ex_void = (ex_insn == NOP_INSN);
    always @(*) begin
        pre_branch_op = `OR1200_BRANCHOP_NOP; alu_op = `OR1200_ALUOP_NOP; mac_op = `OR1200_MACOP_NOP; shrot_op = `OR1200_SHROTOP_NOP;
        comp_op = {1'b0,`OR1200_COP_SFEQ}; rfwb_op = `OR1200_RFWBOP_NOP; lsu_op = `OR1200_LSUOP_NOP; multicycle = 2'b00;
        cust5_op = id_insn[10:6]; cust5_limm = id_insn[5:0]; imm_signextend = 1'b1; sel_imm = 1'b0;
        sig_syscall = 0; sig_trap = 0; rfe = 0; except_illegal = 0; id_macrc_op = 0;
        lsu_addrofs = {{16{id_insn[15]}}, id_insn[15:0]}; spr_addrimm = id_insn[15:0];
        case (op)
            `OR1200_OR32_J:       pre_branch_op = `OR1200_BRANCHOP_J;
            `OR1200_OR32_JAL: begin pre_branch_op = `OR1200_BRANCHOP_BAL; rfwb_op = `OR1200_RFWBOP_LR; end
            `OR1200_OR32_BNF:      pre_branch_op = `OR1200_BRANCHOP_BNF;
            `OR1200_OR32_BF:       pre_branch_op = `OR1200_BRANCHOP_BF;
            `OR1200_OR32_JR:       pre_branch_op = `OR1200_BRANCHOP_JR;
            `OR1200_OR32_JALR: begin pre_branch_op = `OR1200_BRANCHOP_BAL; rfwb_op = `OR1200_RFWBOP_LR; end
            `OR1200_OR32_RFE: begin pre_branch_op = `OR1200_BRANCHOP_RFE; rfe = 1; end
            `OR1200_OR32_MOVHI: begin alu_op = `OR1200_ALUOP_MOVHI; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; imm_signextend = 0; id_macrc_op = id_insn[16]; end
            `OR1200_OR32_ADDI: begin alu_op = `OR1200_ALUOP_ADD; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; end
            `OR1200_OR32_ADDIC: begin alu_op = `OR1200_ALUOP_ADDC; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; end
            `OR1200_OR32_ANDI: begin alu_op = `OR1200_ALUOP_AND; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; imm_signextend = 0; end
            `OR1200_OR32_ORI: begin alu_op = `OR1200_ALUOP_OR; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; imm_signextend = 0; end
            `OR1200_OR32_XORI: begin alu_op = `OR1200_ALUOP_XOR; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; imm_signextend = 0; end
            `OR1200_OR32_MULI: begin alu_op = `OR1200_ALUOP_MUL; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; multicycle = 2'b10; end
            `OR1200_OR32_LWZ: begin lsu_op = `OR1200_LSUOP_LWZ; rfwb_op = `OR1200_RFWBOP_LSU; sel_imm = 1; end
            `OR1200_OR32_LBZ: begin lsu_op = `OR1200_LSUOP_LBZ; rfwb_op = `OR1200_RFWBOP_LSU; sel_imm = 1; end
            `OR1200_OR32_LBS: begin lsu_op = `OR1200_LSUOP_LBS; rfwb_op = `OR1200_RFWBOP_LSU; sel_imm = 1; end
            `OR1200_OR32_LHZ: begin lsu_op = `OR1200_LSUOP_LHZ; rfwb_op = `OR1200_RFWBOP_LSU; sel_imm = 1; end
            `OR1200_OR32_LHS: begin lsu_op = `OR1200_LSUOP_LHS; rfwb_op = `OR1200_RFWBOP_LSU; sel_imm = 1; end
            `OR1200_OR32_SW:  begin lsu_op = `OR1200_LSUOP_SW; sel_imm = 1; lsu_addrofs = {{16{id_insn[25]}}, id_insn[25:21], id_insn[10:0]}; end
            `OR1200_OR32_SB:  begin lsu_op = `OR1200_LSUOP_SB; sel_imm = 1; lsu_addrofs = {{16{id_insn[25]}}, id_insn[25:21], id_insn[10:0]}; end
            `OR1200_OR32_SH:  begin lsu_op = `OR1200_LSUOP_SH; sel_imm = 1; lsu_addrofs = {{16{id_insn[25]}}, id_insn[25:21], id_insn[10:0]}; end
            `OR1200_OR32_MFSPR: begin alu_op = `OR1200_ALUOP_MFSR; rfwb_op = `OR1200_RFWBOP_SPRS; sel_imm = 1; spr_addrimm = id_insn[15:0]; end
            `OR1200_OR32_MTSPR: begin alu_op = `OR1200_ALUOP_MTSR; spr_addrimm = {id_insn[25:21], id_insn[10:0]}; end
            `OR1200_OR32_SH_ROTI: begin alu_op = `OR1200_ALUOP_SHROT; shrot_op = id_insn[`OR1200_SHROTOP_POS]; rfwb_op = `OR1200_RFWBOP_ALU; sel_imm = 1; imm_signextend = 0; end
            `OR1200_OR32_SFXXI: begin alu_op = `OR1200_ALUOP_COMP; comp_op = {id_insn[21], id_insn[23:21]}; sel_imm = 1; end
            `OR1200_OR32_SFXX: begin alu_op = `OR1200_ALUOP_COMP; comp_op = {id_insn[21], id_insn[23:21]}; end
            `OR1200_OR32_ALU: begin
                rfwb_op = `OR1200_RFWBOP_ALU;
                case (id_insn[3:0])
                    4'h0: alu_op = `OR1200_ALUOP_ADD;
                    4'h1: alu_op = `OR1200_ALUOP_ADDC;
                    4'h2: alu_op = `OR1200_ALUOP_SUB;
                    4'h3: alu_op = `OR1200_ALUOP_AND;
                    4'h4: alu_op = `OR1200_ALUOP_OR;
                    4'h5: alu_op = `OR1200_ALUOP_XOR;
                    4'h6: begin alu_op = `OR1200_ALUOP_MUL; multicycle = 2'b10; end
                    4'h8: begin alu_op = `OR1200_ALUOP_SHROT; shrot_op = id_insn[`OR1200_SHROTOP_POS]; end
                    4'h9: begin alu_op = `OR1200_ALUOP_DIV; multicycle = 2'b10; end
                    4'ha: begin alu_op = `OR1200_ALUOP_DIVU; multicycle = 2'b10; end
                    default: except_illegal = 1;
                endcase
            end
            `OR1200_OR32_NOP: begin sig_syscall = (id_insn[25:0] == 26'h000001); sig_trap = (id_insn[25:0] == 26'h000002); end
            default: except_illegal = 1;
        endcase
    end
    always @(*) begin
        sel_a = 2'b00; sel_b = sel_imm ? 2'b10 : 2'b00;
        if (wbforw_valid && (rf_addra == wb_rfaddrw) && (rf_addra != 0)) sel_a = 2'b01;
        if (!sel_imm && wbforw_valid && (rf_addrb == wb_rfaddrw) && (rf_addrb != 0)) sel_b = 2'b01;
    end
    always @(posedge clk) begin
        if (rst || flushpipe) begin
            id_insn <= NOP_INSN; ex_insn <= NOP_INSN; wb_insn <= NOP_INSN; branch_op <= `OR1200_BRANCHOP_NOP; rf_addrw <= 0; wb_rfaddrw <= 0; ex_macrc_op <= 0; no_more_dslot <= 0;
        end else begin
            if (!id_freeze) id_insn <= if_insn;
            if (!ex_freeze) begin
                ex_insn <= (id_freeze && !ex_freeze) ? NOP_INSN : id_insn;
                branch_op <= pre_branch_op;
                rf_addrw <= (pre_branch_op == `OR1200_BRANCHOP_BAL) ? 5'd9 : id_insn[25:21];
                ex_macrc_op <= id_macrc_op;
                no_more_dslot <= ((pre_branch_op != `OR1200_BRANCHOP_NOP) && branch_taken) || (pre_branch_op == `OR1200_BRANCHOP_RFE);
            end
            if (!wb_freeze) begin wb_insn <= ex_insn; wb_rfaddrw <= rf_addrw; end
        end
    end
endmodule
