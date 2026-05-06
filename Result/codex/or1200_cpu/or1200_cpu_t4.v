`timescale 1ns/1ps
`include "or1200_defines.v"
module or1200_cpu(
    input clk,
    input rst,
    output ic_en,
    output reg [31:0] icpu_adr_o,
    output reg icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    output immu_en,
    output [31:0] ex_insn,
    output ex_freeze,
    output [31:0] id_pc,
    output [2:0] branch_op,
    output [31:0] spr_dat_npc,
    output [31:0] rf_dataw,
    input du_stall,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    input [13:0] du_dsr,
    input du_hwbkpt,
    output [12:0] du_except,
    output [31:0] du_dat_cpu,
    output dc_en,
    output reg [31:0] dcpu_adr_o,
    output reg dcpu_cycstb_o,
    output reg dcpu_we_o,
    output reg [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output reg [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i,
    output dmmu_en,
    input sig_int,
    input sig_tick,
    output supv,
    output [31:0] spr_addr,
    output [31:0] spr_dat_cpu,
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output [31:0] spr_cs,
    output spr_we
);
    reg [31:0] pc;
    reg [31:0] insn_r;
    reg [31:0] id_pc_r;
    reg [31:0] sr;
    wire [4:0] rf_addra, rf_addrb, rf_addrw;
    wire rf_rda, rf_rdb;
    wire [3:0] alu_op, lsu_op, comp_op;
    wire [1:0] mac_op, shrot_op, sel_a, sel_b, multicycle;
    wire [2:0] rfwb_op;
    wire [31:0] wb_insn, simm, lsu_addrofs;
    wire [31:2] branch_addrofs;
    wire [4:0] cust5_op;
    wire [5:0] cust5_limm;
    wire [15:0] spr_addrimm;
    wire sig_syscall, sig_trap, force_dslot_fetch, no_more_dslot, ex_void, id_macrc_op, ex_macrc_op, rfe, except_illegal;
    assign ic_en = 1'b1;
    assign dc_en = 1'b1;
    assign immu_en = 1'b0;
    assign dmmu_en = 1'b0;
    assign supv = 1'b1;
    assign icpu_sel_o = 4'b1111;
    assign icpu_tag_o = `OR1200_ITAG_NI;
    assign dcpu_tag_o = `OR1200_DTAG_ND;
    assign ex_freeze = du_stall;
    assign id_pc = id_pc_r;
    assign spr_dat_npc = pc;
    assign rf_dataw = 32'd0;
    assign du_except = {9'd0, sig_tick, sig_int, except_illegal, sig_syscall};
    assign du_dat_cpu = (du_addr[3:0] == 4'h0) ? pc : (du_addr[3:0] == 4'h1 ? insn_r : sr);
    assign spr_addr = {16'd0, spr_addrimm};
    assign spr_dat_cpu = sr;
    assign spr_cs = 32'd0;
    assign spr_we = 1'b0;
    or1200_ctrl u_ctrl(
        .clk(clk), .rst(rst), .id_freeze(du_stall), .ex_freeze(du_stall), .wb_freeze(du_stall), .flushpipe(1'b0), .if_insn(insn_r),
        .ex_insn(ex_insn), .branch_op(branch_op), .branch_taken(1'b0), .rf_addra(rf_addra), .rf_addrb(rf_addrb), .rf_rda(rf_rda), .rf_rdb(rf_rdb),
        .alu_op(alu_op), .mac_op(mac_op), .shrot_op(shrot_op), .comp_op(comp_op), .rf_addrw(rf_addrw), .rfwb_op(rfwb_op), .wb_insn(wb_insn),
        .simm(simm), .branch_addrofs(branch_addrofs), .lsu_addrofs(lsu_addrofs), .sel_a(sel_a), .sel_b(sel_b), .lsu_op(lsu_op),
        .cust5_op(cust5_op), .cust5_limm(cust5_limm), .multicycle(multicycle), .spr_addrimm(spr_addrimm), .wbforw_valid(1'b0), .du_hwbkpt(du_hwbkpt),
        .sig_syscall(sig_syscall), .sig_trap(sig_trap), .force_dslot_fetch(force_dslot_fetch), .no_more_dslot(no_more_dslot), .ex_void(ex_void),
        .id_macrc_op(id_macrc_op), .ex_macrc_op(ex_macrc_op), .rfe(rfe), .except_illegal(except_illegal)
    );
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h0000_0100; icpu_adr_o <= 32'h0000_0100; icpu_cycstb_o <= 1'b0; insn_r <= {`OR1200_OR32_NOP,26'd0}; id_pc_r <= 0; sr <= 0;
            dcpu_adr_o <= 0; dcpu_cycstb_o <= 0; dcpu_we_o <= 0; dcpu_sel_o <= 4'b0000; dcpu_dat_o <= 0;
        end else if (!du_stall) begin
            icpu_cycstb_o <= 1'b1;
            icpu_adr_o <= pc;
            if (icpu_ack_i) begin
                insn_r <= icpu_dat_i;
                id_pc_r <= pc;
                pc <= pc + 32'd4;
            end
            if (du_write) begin
                case (du_addr[3:0])
                    4'h0: pc <= du_dat_du;
                    4'h2: sr <= du_dat_du;
                endcase
            end
            dcpu_cycstb_o <= 1'b0;
            dcpu_we_o <= 1'b0;
            dcpu_sel_o <= 4'b1111;
            dcpu_adr_o <= 32'd0;
            dcpu_dat_o <= 32'd0;
        end
    end
endmodule
