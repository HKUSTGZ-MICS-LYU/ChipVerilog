`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_cpu (
    // Clk & Rst
    input clk,
    input rst,

    // Insn interface
    output ic_en,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    output immu_en,

    // Debug unit
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

    // Data interface
    output dc_en,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i,
    output dmmu_en,

    // Interrupt & tick exceptions
    input sig_int,
    input sig_tick,

    // SPR interface
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

    // SR bits
    wire [31:0] sr;
    wire        except_prefix;

    assign supv          = sr[0];
    assign dc_en         = sr[3];
    assign ic_en         = sr[4];
    assign dmmu_en       = sr[5];
    assign immu_en       = sr[6];
    assign except_prefix = sr[14];

    // Freeze / flush
    wire genpc_freeze, if_freeze, id_freeze, ex_freeze_int, wb_freeze;
    wire flushpipe, extend_flush;
    assign ex_freeze = ex_freeze_int;

    // IF stage
    wire [31:0] if_insn, if_pc;
    wire        if_stall;
    wire        except_itlbmiss, except_immufault, except_ibuserr;

    // ID/decode stage
    wire [4:0]  rf_addrw, rf_addra, rf_addrb;
    wire        rf_rda, rf_rdb;
    wire [31:0] id_simm;
    wire [31:0] branch_addrofs, lsu_addrofs;
    wire [3:0]  alu_op;
    wire [1:0]  shrot_op;
    wire [3:0]  comp_op;
    wire [2:0]  rfwb_op;
    wire [1:0]  mac_op;
    wire        mac_stall;
    wire [4:0]  cust5_op;
    wire [5:0]  cust5_limm;
    wire        rfe, wbforw_valid;
    wire        sig_syscall, sig_trap, except_illegal;
    wire        multicycle;
    wire [15:0] spr_addrimm;
    wire        id_void, ex_void;
    wire        sel_imm, delay_insn;
    wire [2:0]  branch_op_int;
    assign branch_op = branch_op_int;

    wire [31:0] rf_dataa, rf_datab;
    assign /* we = */ 1'b0;  // placeholder; driven below via rfwb_op[0]
    wire we = rfwb_op[0];

    wire [31:0] alu_a, alu_b;
    wire [31:0] ex_forw, wb_forw;

    wire [31:0] alu_result;
    wire        flagforw, flag_we, cyforw, cy_we, flag, carry;

    wire [31:0] mult_mac_result;
    wire [3:0]  macrc_op_int;
    wire        macrc_op = macrc_op_int[0];

    wire [31:0] lsu_result;
    wire        lsu_stall, lsu_unstall;
    wire        except_align, except_dtlbmiss, except_dmmufault, except_dbuserr;

    wire [31:0] except_type;
    wire        except_start, except_started;
    wire [12:0] except_stop;
    wire [31:0] epcr, eear, esr;
    wire        epcr_we, eear_we, esr_we, sr_we;
    wire [31:0] sr_in;
    wire [31:0] ex_pc, wb_pc;
    wire        abort_ex;

    wire [31:0] spr_dat_cfgr, spr_dat_rf_int, spr_dat_mac;
    wire [31:0] npc, ppc;
    wire        genpc_refetch;

    assign du_except = except_stop;
    assign ex_forw   = alu_result;
    assign ppc       = ex_pc;

    or1200_genpc or1200_genpc (
        .clk(clk), .rst(rst),
        .icpu_adr_o(icpu_adr_o), .icpu_cycstb_o(icpu_cycstb_o),
        .icpu_sel_o(icpu_sel_o), .icpu_tag_o(icpu_tag_o),
        .branch_op(branch_op_int), .except_type(except_type),
        .except_prefix(except_prefix), .branch_addrofs(branch_addrofs),
        .lr_restor(rf_datab), .flag(flag), .taken(flagforw),
        .binsn_addr(id_pc), .epcr(epcr),
        .spr_dat_i(spr_dat_cpu), .spr_pc_we(spr_cs[0] & spr_we),
        .genpc_freeze(genpc_freeze), .except_start(except_start),
        .if_stall(if_stall), .ppc_i(ppc), .npc_o(npc),
        .genpc_refetch(genpc_refetch), .except_stop(except_stop)
    );

    or1200_if or1200_if (
        .clk(clk), .rst(rst),
        .icpu_dat_i(icpu_dat_i), .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i), .icpu_adr_i(icpu_adr_i),
        .icpu_tag_i(icpu_tag_i), .if_freeze(if_freeze),
        .flushpipe(flushpipe), .if_insn(if_insn), .if_pc(if_pc),
        .if_stall(if_stall), .no_more_dslot(1'b0),
        .except_ibuserr(except_ibuserr),
        .genpc_refetch(genpc_refetch), .rfe(rfe)
    );

    or1200_ctrl or1200_ctrl (
        .clk(clk), .rst(rst),
        .id_freeze(id_freeze), .ex_freeze(ex_freeze_int), .wb_freeze(wb_freeze),
        .if_insn(if_insn), .if_pc(if_pc), .id_pc(id_pc),
        .ex_pc(ex_pc), .wb_pc(wb_pc),
        .flushpipe(flushpipe), .extend_flush(extend_flush),
        .branch_op(branch_op_int), .branch_addrofs(branch_addrofs),
        .rf_addra(rf_addra), .rf_addrb(rf_addrb),
        .rf_rda(rf_rda), .rf_rdb(rf_rdb), .rf_addrw(rf_addrw),
        .rfwb_op(rfwb_op), .id_simm(id_simm), .lsu_addrofs(lsu_addrofs),
        .alu_op(alu_op), .shrot_op(shrot_op), .comp_op(comp_op),
        .mac_op(mac_op), .cust5_op(cust5_op), .cust5_limm(cust5_limm),
        .id_void(id_void), .ex_void(ex_void), .ex_insn(ex_insn),
        .multicycle(multicycle), .spr_addrimm(spr_addrimm),
        .sig_syscall(sig_syscall), .sig_trap(sig_trap),
        .except_illegal(except_illegal), .sel_imm(sel_imm),
        .delay_insn(delay_insn), .rfe(rfe), .du_hwbkpt(du_hwbkpt),
        .mac_stall(mac_stall), .macrc_op(macrc_op_int)
    );

    or1200_rf or1200_rf (
        .clk(clk), .rst(rst),
        .cy_we(cy_we), .cyforw(cyforw), .flag_we(flag_we), .flagforw(flagforw),
        .carry(carry), .flag(flag),
        .id_freeze(id_freeze), .wb_freeze(wb_freeze), .flushpipe(flushpipe),
        .rf_addra(rf_addra), .rf_addrb(rf_addrb), .rf_addrw(rf_addrw),
        .rf_rda(rf_rda), .rf_rdb(rf_rdb),
        .rf_dataw(rf_dataw), .rf_dataa(rf_dataa), .rf_datab(rf_datab),
        .we(we), .spr_cs(spr_cs[0]), .spr_we(spr_we),
        .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_rf_int)
    );

    or1200_operandmuxes or1200_operandmuxes (
        .id_freeze(id_freeze), .ex_freeze(ex_freeze_int),
        .rf_dataa(rf_dataa), .rf_datab(rf_datab),
        .ex_forw(ex_forw), .wb_forw(wb_forw),
        .simm(id_simm), .sel_imm(sel_imm),
        .id_void(id_void), .wbforw_valid(wbforw_valid),
        .operand_a(alu_a), .operand_b(alu_b)
    );

    or1200_alu or1200_alu (
        .a(alu_a), .b(alu_b), .mult_mac_result(mult_mac_result),
        .macrc_op(macrc_op), .alu_op(alu_op), .shrot_op(shrot_op),
        .comp_op(comp_op), .cust5_op(cust5_op), .cust5_limm(cust5_limm),
        .result(alu_result), .flagforw(flagforw), .flag_we(flag_we),
        .cyforw(cyforw), .cy_we(cy_we), .carry(carry), .flag(flag)
    );

    or1200_mult_mac or1200_mult_mac (
        .clk(clk), .rst(rst),
        .ex_freeze(ex_freeze_int), .wb_freeze(wb_freeze), .flushpipe(flushpipe),
        .mulop_a(alu_a), .mulop_b(alu_b),
        .mac_op(mac_op), .macrc_op(macrc_op),
        .mult_mac_result(mult_mac_result), .mac_stall(mac_stall),
        .spr_cs(spr_cs[`OR1200_SPR_GROUP_MAC]), .spr_we(spr_we),
        .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_mac)
    );

    or1200_sprs or1200_sprs (
        .clk(clk), .rst(rst),
        .addrbase(alu_a), .addrimm(spr_addrimm), .alu_op(alu_op),
        .flagforw(flagforw), .flag_we(flag_we),
        .cyforw(cyforw), .cy_we(cy_we),
        .flag(flag), .carry(carry),
        .epcr(epcr), .eear(eear), .esr(esr),
        .epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we),
        .sr_we(sr_we), .to_sr(sr_in), .sr(sr),
        .du_addr(du_addr), .du_dat_du(du_dat_du),
        .du_read(du_read), .du_write(du_write), .du_dat_cpu(du_dat_cpu),
        .spr_dat_pic(spr_dat_pic), .spr_dat_tt(spr_dat_tt),
        .spr_dat_pm(spr_dat_pm), .spr_dat_dmmu(spr_dat_dmmu),
        .spr_dat_immu(spr_dat_immu), .spr_dat_du(spr_dat_du),
        .spr_dat_rf(spr_dat_rf_int), .spr_dat_mac(spr_dat_mac),
        .spr_dat_cfgr(spr_dat_cfgr),
        .spr_addr(spr_addr), .spr_dat_cpu(spr_dat_cpu),
        .spr_dat_npc(spr_dat_npc), .spr_cs(spr_cs), .spr_we(spr_we),
        .ex_void(ex_void)
    );

    or1200_lsu or1200_lsu (
        .clk(clk), .rst(rst),
        .id_addrbase(alu_a), .id_addrofs(lsu_addrofs),
        .ex_addrbase(alu_a), .ex_addrofs(lsu_addrofs),
        .id_lsu_op(alu_op), .lsu_datain(alu_b), .lsu_dataout(lsu_result),
        .lsu_stall(lsu_stall), .lsu_unstall(lsu_unstall),
        .except_align(except_align), .except_dtlbmiss(except_dtlbmiss),
        .except_dmmufault(except_dmmufault), .except_dbuserr(except_dbuserr),
        .dcpu_adr_o(dcpu_adr_o), .dcpu_cycstb_o(dcpu_cycstb_o),
        .dcpu_we_o(dcpu_we_o), .dcpu_sel_o(dcpu_sel_o),
        .dcpu_tag_o(dcpu_tag_o), .dcpu_dat_o(dcpu_dat_o),
        .dcpu_dat_i(dcpu_dat_i), .dcpu_ack_i(dcpu_ack_i),
        .dcpu_rty_i(dcpu_rty_i), .dcpu_err_i(dcpu_err_i),
        .dcpu_tag_i(dcpu_tag_i)
    );

    or1200_wbmux or1200_wbmux (
        .clk(clk), .rst(rst),
        .wb_freeze(wb_freeze), .rfwb_op(rfwb_op),
        .alu_result(alu_result), .lsu_result(lsu_result),
        .sprs_result(spr_dat_cpu), .lnk_addr(ex_pc + 32'd8),
        .rf_dataw(rf_dataw), .wb_forw(wb_forw), .wbforw_valid(wbforw_valid)
    );

    or1200_except or1200_except (
        .clk(clk), .rst(rst),
        .sig_ibuserr(except_ibuserr), .sig_dbuserr(except_dbuserr),
        .sig_illegal(except_illegal), .sig_align(except_align),
        .sig_range(1'b0),
        .sig_dtlbmiss(except_dtlbmiss), .sig_dmmufault(except_dmmufault),
        .sig_itlbmiss(except_itlbmiss), .sig_immufault(except_immufault),
        .sig_int(sig_int), .sig_syscall(sig_syscall),
        .sig_trap(sig_trap), .sig_tick(sig_tick),
        .branch_taken(flagforw),
        .id_freeze(id_freeze), .ex_freeze(ex_freeze_int), .wb_freeze(wb_freeze),
        .if_stall(if_stall), .lsu_stall(lsu_stall),
        .if_pc(if_pc), .id_pc(id_pc), .ex_pc(ex_pc), .wb_pc(wb_pc),
        .id_void(id_void), .ex_void(ex_void),
        .du_dsr(du_dsr), .du_stall(du_stall),
        .flushpipe(flushpipe), .extend_flush(extend_flush),
        .except_start(except_start), .except_started(except_started),
        .except_type(except_type), .except_stop(except_stop),
        .epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we),
        .sr_we(sr_we), .to_sr(sr_in),
        .epcr(epcr), .eear(eear), .esr(esr), .abort_ex(abort_ex)
    );

    or1200_freeze or1200_freeze (
        .clk(clk), .rst(rst),
        .multicycle(multicycle), .flushpipe(flushpipe), .extend_flush(extend_flush),
        .lsu_stall(lsu_stall), .if_stall(if_stall), .lsu_unstall(lsu_unstall),
        .force_dslot_fetch(1'b0), .abort_ex(abort_ex),
        .du_stall(du_stall), .mac_stall(mac_stall),
        .genpc_freeze(genpc_freeze), .if_freeze(if_freeze),
        .id_freeze(id_freeze), .ex_freeze(ex_freeze_int), .wb_freeze(wb_freeze),
        .icpu_ack_i(icpu_ack_i), .icpu_err_i(icpu_err_i)
    );

    or1200_cfgr or1200_cfgr (
        .spr_addr(spr_addr), .spr_dat_o(spr_dat_cfgr)
    );

endmodule
EOF