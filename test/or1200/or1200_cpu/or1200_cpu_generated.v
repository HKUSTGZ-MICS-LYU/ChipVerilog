`include "timescale.v"
`include "or1200_defines.v"

module or1200_cpu(
	clk, rst,

	ic_en,
	icpu_adr_o, icpu_cycstb_o, icpu_sel_o, icpu_tag_o,
	icpu_dat_i, icpu_ack_i, icpu_rty_i, icpu_err_i, icpu_adr_i, icpu_tag_i,
	immu_en,

	ex_insn, ex_freeze, id_pc, branch_op,
	spr_dat_npc, rf_dataw,
	du_stall, du_addr, du_dat_du, du_read, du_write, du_dsr, du_hwbkpt,
	du_except, du_dat_cpu,

	dc_en,
	dcpu_adr_o, dcpu_cycstb_o, dcpu_we_o, dcpu_sel_o, dcpu_tag_o, dcpu_dat_o,
	dcpu_dat_i, dcpu_ack_i, dcpu_rty_i, dcpu_err_i, dcpu_tag_i,
	dmmu_en,

	sig_int, sig_tick,

	supv, spr_addr, spr_dat_cpu, spr_dat_pic, spr_dat_tt, spr_dat_pm,
	spr_dat_dmmu, spr_dat_immu, spr_dat_du, spr_cs, spr_we
);

input			clk;
input			rst;

output			ic_en;
output	[31:0]		icpu_adr_o;
output			icpu_cycstb_o;
output	[3:0]		icpu_sel_o;
output	[3:0]		icpu_tag_o;
input	[31:0]		icpu_dat_i;
input			icpu_ack_i;
input			icpu_rty_i;
input			icpu_err_i;
input	[31:0]		icpu_adr_i;
input	[3:0]		icpu_tag_i;
output			immu_en;

output	[31:0]		ex_insn;
output			ex_freeze;
output	[31:0]		id_pc;
output	[2:0]		branch_op;
input			du_stall;
input	[31:0]		du_addr;
input	[31:0]		du_dat_du;
input			du_read;
input			du_write;
input	[13:0]		du_dsr;
input			du_hwbkpt;
output	[12:0]		du_except;
output	[31:0]		du_dat_cpu;
output	[31:0]		rf_dataw;

output	[31:0]		dcpu_adr_o;
output			dcpu_cycstb_o;
output			dcpu_we_o;
output	[3:0]		dcpu_sel_o;
output	[3:0]		dcpu_tag_o;
output	[31:0]		dcpu_dat_o;
input	[31:0]		dcpu_dat_i;
input			dcpu_ack_i;
input			dcpu_rty_i;
input			dcpu_err_i;
input	[3:0]		dcpu_tag_i;
output			dc_en;
output			dmmu_en;

output			supv;
input	[31:0]		spr_dat_pic;
input	[31:0]		spr_dat_tt;
input	[31:0]		spr_dat_pm;
input	[31:0]		spr_dat_dmmu;
input	[31:0]		spr_dat_immu;
input	[31:0]		spr_dat_du;
output	[31:0]		spr_addr;
output	[31:0]		spr_dat_cpu;
output	[31:0]		spr_dat_npc;
output	[31:0]		spr_cs;
output			spr_we;

input			sig_int;
input			sig_tick;

wire	[31:0]		if_insn;
wire	[31:0]		if_pc;
wire	[31:2]		lr_sav;
wire	[4:0]		rf_addrw;
wire	[4:0]		rf_addra;
wire	[4:0]		rf_addrb;
wire			rf_rda;
wire			rf_rdb;
wire	[31:0]		simm;
wire	[31:2]		branch_addrofs;
wire	[3:0]		alu_op;
wire	[1:0]		shrot_op;
wire	[3:0]		comp_op;
wire	[2:0]		branch_op;
wire	[3:0]		lsu_op;
wire			genpc_freeze;
wire			if_freeze;
wire			id_freeze;
wire			ex_freeze;
wire			wb_freeze;
wire	[1:0]		sel_a;
wire	[1:0]		sel_b;
wire	[2:0]		rfwb_op;
wire	[31:0]		rf_dataw;
wire	[31:0]		rf_dataa;
wire	[31:0]		rf_datab;
wire	[31:0]		muxed_b;
wire	[31:0]		wb_forw;
wire			wbforw_valid;
wire	[31:0]		operand_a;
wire	[31:0]		operand_b;
wire	[31:0]		alu_dataout;
wire	[31:0]		lsu_dataout;
wire	[31:0]		sprs_dataout;
wire	[31:0]		lsu_addrofs;
wire	[1:0]		multicycle;
wire	[3:0]		except_type;
wire	[4:0]		cust5_op;
wire	[5:0]		cust5_limm;
wire			flushpipe;
wire			extend_flush;
wire			branch_taken;
wire			flag;
wire			flagforw;
wire			flag_we;
wire			carry;
wire			cyforw;
wire			cy_we;
wire			lsu_stall;
wire			epcr_we;
wire			eear_we;
wire			esr_we;
wire			pc_we;
wire	[31:0]		epcr;
wire	[31:0]		eear;
wire	[15:0]		esr;
wire			sr_we;
wire	[15:0]		to_sr;
wire	[15:0]		sr;
wire			except_start;
wire			except_started;
wire	[31:0]		wb_insn;
wire	[15:0]		spr_addrimm;
wire			sig_syscall;
wire			sig_trap;
wire	[31:0]		spr_dat_cfgr;
wire	[31:0]		spr_dat_rf;
wire	[31:0]		spr_dat_npc;
wire	[31:0]		spr_dat_ppc;
wire	[31:0]		spr_dat_mac;
wire			force_dslot_fetch;
wire			no_more_dslot;
wire			ex_void;
wire			if_stall;
wire			id_macrc_op;
wire			ex_macrc_op;
wire	[1:0]		mac_op;
wire	[31:0]		mult_mac_result;
wire			mac_stall;
wire	[12:0]		except_stop;
wire			genpc_refetch;
wire			rfe;
wire			lsu_unstall;
wire			except_align;
wire			except_dtlbmiss;
wire			except_dmmufault;
wire			except_illegal;
wire			except_itlbmiss;
wire			except_immufault;
wire			except_ibuserr;
wire			except_dbuserr;
wire			abort_ex;

// Status-register derived enables
// dc_en from SR[3] (DCE)
assign dc_en = sr[3];
// ic_en from SR[4] (ICE)
assign ic_en = sr[4];
// dmmu_en from SR[5] (DME)
assign dmmu_en = sr[5];
// immu_en from SR[6] (IME)
assign immu_en = sr[6];
// supv from SR[0] (SM)
assign supv = sr[0];
// except_prefix from SR[14] (EPH)
wire except_prefix;
assign except_prefix = sr[14];

// du_except = except_stop
assign du_except = except_stop;

wire supv_wire;
assign supv_wire = sr[0];
// Register-file write-enable derived from rfwb_op[0]
wire we;
assign we = rfwb_op[0];
wire spr_cs_group_sys;
assign spr_cs_group_sys = spr_cs[0];
wire spr_cs_group_mac;
assign spr_cs_group_mac = spr_cs[5];
wire [31:0] muxin_d;
assign muxin_d = {lr_sav, 2'b0};

or1200_genpc or1200_genpc(
	.clk(clk), .rst(rst),
	.icpu_adr_o(icpu_adr_o), .icpu_cycstb_o(icpu_cycstb_o),
	.icpu_sel_o(icpu_sel_o), .icpu_tag_o(icpu_tag_o),
	.icpu_rty_i(icpu_rty_i), .icpu_adr_i(icpu_adr_i),
	.branch_op(branch_op), .except_type(except_type),
	.except_start(except_start), .except_prefix(except_prefix),
	.branch_addrofs(branch_addrofs), .lr_restor(operand_b),
	.flag(flag), .taken(branch_taken), .binsn_addr(lr_sav),
	.epcr(epcr), .spr_dat_i(spr_dat_cpu), .spr_pc_we(pc_we),
	.genpc_refetch(genpc_refetch), .genpc_freeze(genpc_freeze),
	.genpc_stop_prefetch(1'b0), .no_more_dslot(no_more_dslot)
);

or1200_if or1200_if(
	.clk(clk), .rst(rst),
	.icpu_dat_i(icpu_dat_i), .icpu_ack_i(icpu_ack_i),
	.icpu_err_i(icpu_err_i), .icpu_adr_i(icpu_adr_i),
	.icpu_tag_i(icpu_tag_i),
	.if_freeze(if_freeze), .if_insn(if_insn), .if_pc(if_pc),
	.flushpipe(flushpipe), .if_stall(if_stall),
	.no_more_dslot(no_more_dslot), .genpc_refetch(genpc_refetch),
	.rfe(rfe), .except_itlbmiss(except_itlbmiss),
	.except_immufault(except_immufault), .except_ibuserr(except_ibuserr)
);

or1200_ctrl or1200_ctrl(
	.clk(clk), .rst(rst),
	.id_freeze(id_freeze), .ex_freeze(ex_freeze), .wb_freeze(wb_freeze),
	.flushpipe(flushpipe), .if_insn(if_insn), .ex_insn(ex_insn),
	.branch_op(branch_op), .branch_taken(branch_taken),
	.rf_addra(rf_addra), .rf_addrb(rf_addrb),
	.rf_rda(rf_rda), .rf_rdb(rf_rdb),
	.alu_op(alu_op), .mac_op(mac_op), .shrot_op(shrot_op), .comp_op(comp_op),
	.rf_addrw(rf_addrw), .rfwb_op(rfwb_op), .wb_insn(wb_insn),
	.simm(simm), .branch_addrofs(branch_addrofs), .lsu_addrofs(lsu_addrofs),
	.sel_a(sel_a), .sel_b(sel_b), .lsu_op(lsu_op),
	.cust5_op(cust5_op), .cust5_limm(cust5_limm),
	.multicycle(multicycle), .spr_addrimm(spr_addrimm),
	.wbforw_valid(wbforw_valid), .sig_syscall(sig_syscall), .sig_trap(sig_trap),
	.force_dslot_fetch(force_dslot_fetch), .no_more_dslot(no_more_dslot),
	.ex_void(ex_void), .id_macrc_op(id_macrc_op), .ex_macrc_op(ex_macrc_op),
	.rfe(rfe), .du_hwbkpt(du_hwbkpt), .except_illegal(except_illegal)
);

or1200_rf or1200_rf(
	.clk(clk), .rst(rst), .supv(supv_wire), .wb_freeze(wb_freeze),
	.addrw(rf_addrw), .dataw(rf_dataw), .id_freeze(id_freeze),
	.we(we), .flushpipe(flushpipe),
	.addra(rf_addra), .rda(rf_rda), .dataa(rf_dataa),
	.addrb(rf_addrb), .rdb(rf_rdb), .datab(rf_datab),
	.spr_cs(spr_cs_group_sys), .spr_write(spr_we),
	.spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_rf)
);

or1200_operandmuxes or1200_operandmuxes(
	.clk(clk), .rst(rst),
	.id_freeze(id_freeze), .ex_freeze(ex_freeze),
	.rf_dataa(rf_dataa), .rf_datab(rf_datab),
	.ex_forw(rf_dataw), .wb_forw(wb_forw),
	.simm(simm), .sel_a(sel_a), .sel_b(sel_b),
	.operand_a(operand_a), .operand_b(operand_b), .muxed_b(muxed_b)
);

or1200_alu or1200_alu(
	.a(operand_a), .b(operand_b),
	.mult_mac_result(mult_mac_result), .macrc_op(ex_macrc_op),
	.alu_op(alu_op), .shrot_op(shrot_op), .comp_op(comp_op),
	.cust5_op(cust5_op), .cust5_limm(cust5_limm),
	.result(alu_dataout), .flagforw(flagforw), .flag_we(flag_we),
	.cyforw(cyforw), .cy_we(cy_we), .flag(flag), .carry(carry)
);

or1200_mult_mac or1200_mult_mac(
	.clk(clk), .rst(rst), .ex_freeze(ex_freeze),
	.id_macrc_op(id_macrc_op), .macrc_op(ex_macrc_op),
	.a(operand_a), .b(operand_b), .mac_op(mac_op), .alu_op(alu_op),
	.result(mult_mac_result), .mac_stall_r(mac_stall),
	.spr_cs(spr_cs_group_mac), .spr_write(spr_we),
	.spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_mac)
);

or1200_sprs or1200_sprs(
	.clk(clk), .rst(rst),
	.addrbase(operand_a), .addrofs(spr_addrimm), .dat_i(operand_b),
	.alu_op(alu_op), .flagforw(flagforw), .flag_we(flag_we), .flag(flag),
	.cyforw(cyforw), .cy_we(cy_we), .carry(carry), .to_wbmux(sprs_dataout),
	.du_addr(du_addr), .du_dat_du(du_dat_du), .du_read(du_read),
	.du_write(du_write), .du_dat_cpu(du_dat_cpu),
	.spr_addr(spr_addr), .spr_dat_pic(spr_dat_pic), .spr_dat_tt(spr_dat_tt),
	.spr_dat_pm(spr_dat_pm), .spr_dat_cfgr(spr_dat_cfgr),
	.spr_dat_rf(spr_dat_rf), .spr_dat_npc(spr_dat_npc),
	.spr_dat_ppc(spr_dat_ppc), .spr_dat_mac(spr_dat_mac),
	.spr_dat_dmmu(spr_dat_dmmu), .spr_dat_immu(spr_dat_immu),
	.spr_dat_du(spr_dat_du), .spr_dat_o(spr_dat_cpu),
	.spr_cs(spr_cs), .spr_we(spr_we),
	.epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we), .pc_we(pc_we),
	.epcr(epcr), .eear(eear), .esr(esr), .except_started(except_started),
	.sr_we(sr_we), .to_sr(to_sr), .sr(sr), .branch_op(branch_op)
);

or1200_lsu or1200_lsu(
	.addrbase(operand_a), .addrofs(lsu_addrofs), .lsu_op(lsu_op),
	.lsu_datain(operand_b), .lsu_dataout(lsu_dataout),
	.lsu_stall(lsu_stall), .lsu_unstall(lsu_unstall), .du_stall(du_stall),
	.except_align(except_align), .except_dtlbmiss(except_dtlbmiss),
	.except_dmmufault(except_dmmufault), .except_dbuserr(except_dbuserr),
	.dcpu_adr_o(dcpu_adr_o), .dcpu_cycstb_o(dcpu_cycstb_o),
	.dcpu_we_o(dcpu_we_o), .dcpu_sel_o(dcpu_sel_o), .dcpu_tag_o(dcpu_tag_o),
	.dcpu_dat_o(dcpu_dat_o), .dcpu_dat_i(dcpu_dat_i), .dcpu_ack_i(dcpu_ack_i),
	.dcpu_rty_i(dcpu_rty_i), .dcpu_err_i(dcpu_err_i), .dcpu_tag_i(dcpu_tag_i)
);

or1200_wbmux or1200_wbmux(
	.clk(clk), .rst(rst), .wb_freeze(wb_freeze), .rfwb_op(rfwb_op),
	.muxin_a(alu_dataout), .muxin_b(lsu_dataout),
	.muxin_c(sprs_dataout), .muxin_d(muxin_d),
	.muxout(rf_dataw), .muxreg(wb_forw), .muxreg_valid(wbforw_valid)
);

or1200_freeze or1200_freeze(
	.clk(clk), .rst(rst), .multicycle(multicycle),
	.flushpipe(flushpipe), .extend_flush(extend_flush),
	.lsu_stall(lsu_stall), .if_stall(if_stall), .lsu_unstall(lsu_unstall),
	.force_dslot_fetch(force_dslot_fetch), .abort_ex(abort_ex),
	.du_stall(du_stall), .mac_stall(mac_stall),
	.genpc_freeze(genpc_freeze), .if_freeze(if_freeze),
	.id_freeze(id_freeze), .ex_freeze(ex_freeze), .wb_freeze(wb_freeze),
	.icpu_ack_i(icpu_ack_i), .icpu_err_i(icpu_err_i)
);

or1200_except or1200_except(
	.clk(clk), .rst(rst),
	.sig_ibuserr(except_ibuserr), .sig_dbuserr(except_dbuserr),
	.sig_illegal(except_illegal), .sig_align(except_align),
	.sig_range(1'b0), .sig_dtlbmiss(except_dtlbmiss),
	.sig_dmmufault(except_dmmufault), .sig_int(sig_int),
	.sig_syscall(sig_syscall), .sig_trap(sig_trap),
	.sig_itlbmiss(except_itlbmiss), .sig_immufault(except_immufault),
	.sig_tick(sig_tick), .branch_taken(branch_taken),
	.icpu_ack_i(icpu_ack_i), .icpu_err_i(icpu_err_i),
	.dcpu_ack_i(dcpu_ack_i), .dcpu_err_i(dcpu_err_i),
	.genpc_freeze(genpc_freeze), .id_freeze(id_freeze),
	.ex_freeze(ex_freeze), .wb_freeze(wb_freeze),
	.if_stall(if_stall), .if_pc(if_pc), .id_pc(id_pc), .lr_sav(lr_sav),
	.flushpipe(flushpipe), .extend_flush(extend_flush),
	.except_type(except_type), .except_start(except_start),
	.except_started(except_started), .except_stop(except_stop),
	.ex_void(ex_void), .spr_dat_ppc(spr_dat_ppc), .spr_dat_npc(spr_dat_npc),
	.datain(operand_b), .du_dsr(du_dsr),
	.epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we), .pc_we(pc_we),
	.epcr(epcr), .eear(eear), .esr(esr),
	.lsu_addr(dcpu_adr_o), .sr_we(sr_we), .to_sr(to_sr), .sr(sr),
	.abort_ex(abort_ex)
);

or1200_cfgr or1200_cfgr(
	.spr_addr(spr_addr),
	.spr_dat_o(spr_dat_cfgr)
);

endmodule
