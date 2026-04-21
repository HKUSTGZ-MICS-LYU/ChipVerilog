`include "timescale.v"
`include "or1200_defines.v"

module or1200_sprs(
	clk, rst,
	flagforw, flag_we, flag, cyforw, cy_we, carry,
	addrbase, addrofs, dat_i, alu_op, branch_op,
	epcr, eear, esr, except_started,
	to_wbmux, epcr_we, eear_we, esr_we, pc_we, sr_we, to_sr, sr,
	spr_dat_cfgr, spr_dat_rf, spr_dat_npc, spr_dat_ppc, spr_dat_mac,
	spr_dat_pic, spr_dat_tt, spr_dat_pm,
	spr_dat_dmmu, spr_dat_immu, spr_dat_du,
	spr_addr, spr_dat_o, spr_cs, spr_we,
	du_addr, du_dat_du, du_read, du_write, du_dat_cpu
);

input		clk;
input		rst;
input		flagforw;
input		flag_we;
output		flag;
input		cyforw;
input		cy_we;
output		carry;
input	[31:0]	addrbase;
input	[15:0]	addrofs;
input	[31:0]	dat_i;
input	[3:0]	alu_op;
input	[2:0]	branch_op;
input	[31:0]	epcr;
input	[31:0]	eear;
input	[15:0]	esr;
input		except_started;
output	[31:0]	to_wbmux;
output		epcr_we;
output		eear_we;
output		esr_we;
output		pc_we;
output		sr_we;
output	[15:0]	to_sr;
output	[15:0]	sr;
input	[31:0]	spr_dat_cfgr;
input	[31:0]	spr_dat_rf;
input	[31:0]	spr_dat_npc;
input	[31:0]	spr_dat_ppc;
input	[31:0]	spr_dat_mac;
input	[31:0]	spr_dat_pic;
input	[31:0]	spr_dat_tt;
input	[31:0]	spr_dat_pm;
input	[31:0]	spr_dat_dmmu;
input	[31:0]	spr_dat_immu;
input	[31:0]	spr_dat_du;
output	[31:0]	spr_addr;
output	[31:0]	spr_dat_o;
output	[31:0]	spr_cs;
output		spr_we;
input	[31:0]	du_addr;
input	[31:0]	du_dat_du;
input		du_read;
input		du_write;
output	[31:0]	du_dat_cpu;

reg	[15:0]	sr;
reg		write_spr;
reg		read_spr;
reg	[31:0]	to_wbmux;
wire		cfgr_sel;
wire		rf_sel;
wire		npc_sel;
wire		ppc_sel;
wire		sr_sel;
wire		epcr_sel;
wire		eear_sel;
wire		esr_sel;
wire	[31:0]	sys_data;
wire		du_access;
wire	[3:0]	sprs_op;
reg	[31:0]	unqualified_cs;

assign du_access = du_read | du_write;
assign sprs_op   = du_write ? `OR1200_ALUOP_MTSR : du_read ? `OR1200_ALUOP_MFSR : alu_op;

// ORIGINAL: address described as "addrbase combined with addrofs" (ambiguous - could be + or |)
// Generated as addition (wrong)
assign spr_addr  = du_access ? du_addr : addrbase + {16'h0000, addrofs};

assign spr_dat_o = du_write ? du_dat_du : dat_i;
assign du_dat_cpu = du_write ? du_dat_du : du_read ? to_wbmux : dat_i;
assign spr_we    = du_write | write_spr;
assign spr_cs    = unqualified_cs & {32{read_spr | write_spr}};

always @(spr_addr)
	case (spr_addr[15:11])
		`OR1200_SPR_GROUP_WIDTH'd00: unqualified_cs = 32'h0000_0001;
		`OR1200_SPR_GROUP_WIDTH'd01: unqualified_cs = 32'h0000_0002;
		`OR1200_SPR_GROUP_WIDTH'd02: unqualified_cs = 32'h0000_0004;
		`OR1200_SPR_GROUP_WIDTH'd03: unqualified_cs = 32'h0000_0008;
		`OR1200_SPR_GROUP_WIDTH'd04: unqualified_cs = 32'h0000_0010;
		`OR1200_SPR_GROUP_WIDTH'd05: unqualified_cs = 32'h0000_0020;
		`OR1200_SPR_GROUP_WIDTH'd06: unqualified_cs = 32'h0000_0040;
		`OR1200_SPR_GROUP_WIDTH'd07: unqualified_cs = 32'h0000_0080;
		`OR1200_SPR_GROUP_WIDTH'd08: unqualified_cs = 32'h0000_0100;
		`OR1200_SPR_GROUP_WIDTH'd09: unqualified_cs = 32'h0000_0200;
		`OR1200_SPR_GROUP_WIDTH'd10: unqualified_cs = 32'h0000_0400;
		`OR1200_SPR_GROUP_WIDTH'd11: unqualified_cs = 32'h0000_0800;
		`OR1200_SPR_GROUP_WIDTH'd12: unqualified_cs = 32'h0000_1000;
		`OR1200_SPR_GROUP_WIDTH'd13: unqualified_cs = 32'h0000_2000;
		`OR1200_SPR_GROUP_WIDTH'd14: unqualified_cs = 32'h0000_4000;
		`OR1200_SPR_GROUP_WIDTH'd15: unqualified_cs = 32'h0000_8000;
		`OR1200_SPR_GROUP_WIDTH'd16: unqualified_cs = 32'h0001_0000;
		`OR1200_SPR_GROUP_WIDTH'd17: unqualified_cs = 32'h0002_0000;
		`OR1200_SPR_GROUP_WIDTH'd18: unqualified_cs = 32'h0004_0000;
		`OR1200_SPR_GROUP_WIDTH'd19: unqualified_cs = 32'h0008_0000;
		`OR1200_SPR_GROUP_WIDTH'd20: unqualified_cs = 32'h0010_0000;
		`OR1200_SPR_GROUP_WIDTH'd21: unqualified_cs = 32'h0020_0000;
		`OR1200_SPR_GROUP_WIDTH'd22: unqualified_cs = 32'h0040_0000;
		`OR1200_SPR_GROUP_WIDTH'd23: unqualified_cs = 32'h0080_0000;
		`OR1200_SPR_GROUP_WIDTH'd24: unqualified_cs = 32'h0100_0000;
		`OR1200_SPR_GROUP_WIDTH'd25: unqualified_cs = 32'h0200_0000;
		`OR1200_SPR_GROUP_WIDTH'd26: unqualified_cs = 32'h0400_0000;
		`OR1200_SPR_GROUP_WIDTH'd27: unqualified_cs = 32'h0800_0000;
		`OR1200_SPR_GROUP_WIDTH'd28: unqualified_cs = 32'h1000_0000;
		`OR1200_SPR_GROUP_WIDTH'd29: unqualified_cs = 32'h2000_0000;
		`OR1200_SPR_GROUP_WIDTH'd30: unqualified_cs = 32'h4000_0000;
		`OR1200_SPR_GROUP_WIDTH'd31: unqualified_cs = 32'h8000_0000;
	endcase

assign to_sr[15:11] =
	(branch_op == `OR1200_BRANCHOP_RFE) ? esr[15:11] :
	(write_spr && sr_sel) ? {1'b1, spr_dat_o[14:11]} :
	sr[15:11];
assign to_sr[10] =
	(branch_op == `OR1200_BRANCHOP_RFE) ? esr[10] :
	cy_we ? cyforw :
	(write_spr && sr_sel) ? spr_dat_o[10] :
	sr[10];
assign to_sr[9] =
	(branch_op == `OR1200_BRANCHOP_RFE) ? esr[9] :
	flag_we ? flagforw :
	(write_spr && sr_sel) ? spr_dat_o[9] :
	sr[9];
assign to_sr[8:0] =
	(branch_op == `OR1200_BRANCHOP_RFE) ? esr[8:0] :
	(write_spr && sr_sel) ? spr_dat_o[8:0] :
	sr[8:0];

assign cfgr_sel = (spr_cs[0] && (spr_addr[10:4] == `OR1200_SPR_CFGR));
assign rf_sel   = (spr_cs[0] && (spr_addr[10:5] == `OR1200_SPR_RF));
assign npc_sel  = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_NPC));
assign ppc_sel  = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_PPC));
assign sr_sel   = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_SR));
assign epcr_sel = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_EPCR));
assign eear_sel = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_EEAR));
assign esr_sel  = (spr_cs[0] && (spr_addr[10:0] == `OR1200_SPR_ESR));

assign sr_we   = (write_spr && sr_sel) | (branch_op == `OR1200_BRANCHOP_RFE) | flag_we | cy_we;
assign pc_we   = (write_spr && (npc_sel | ppc_sel));
assign epcr_we = (write_spr && epcr_sel);
assign eear_we = (write_spr && eear_sel);
assign esr_we  = (write_spr && esr_sel);

// ORIGINAL: sys_data described as case/mux (wrong structure)
assign sys_data =
	(cfgr_sel ? spr_dat_cfgr : 32'b0) |
	(rf_sel   ? spr_dat_rf   : 32'b0) |
	(npc_sel  ? spr_dat_npc  : 32'b0) |
	(ppc_sel  ? spr_dat_ppc  : 32'b0) |
	(sr_sel   ? {{32-`OR1200_SR_WIDTH{1'b0}}, sr} : 32'b0) |
	(epcr_sel ? epcr : 32'b0) |
	(eear_sel ? eear : 32'b0) |
	(esr_sel  ? {{32-`OR1200_SR_WIDTH{1'b0}}, esr} : 32'b0);

assign flag  = sr[9];
assign carry = sr[10];

// ORIGINAL: SR priority flattened (except_started not given explicit precedence)
always @(posedge clk or posedge rst)
	if (rst)
		sr <= #1 {1'b1, `OR1200_SR_EPH_DEF, {`OR1200_SR_WIDTH-3{1'b0}}, 1'b1};
	else if (sr_we)
		sr <= #1 to_sr[15:0];

always @(sprs_op or spr_addr or sys_data or spr_dat_mac or spr_dat_pic or spr_dat_pm or
	spr_dat_dmmu or spr_dat_immu or spr_dat_du or spr_dat_tt) begin
	case (sprs_op)
		`OR1200_ALUOP_MTSR: write_spr = 1'b1;
		`OR1200_ALUOP_MFSR: write_spr = 1'b0;
		default:            write_spr = 1'b0;
	endcase
end

always @(sprs_op or spr_addr or sys_data or spr_dat_mac or spr_dat_pic or spr_dat_pm or
	spr_dat_dmmu or spr_dat_immu or spr_dat_du or spr_dat_tt) begin
	case (sprs_op)
		`OR1200_ALUOP_MTSR: read_spr = 1'b0;
		`OR1200_ALUOP_MFSR: read_spr = 1'b1;
		default:            read_spr = 1'b0;
	endcase
end

always @(sprs_op or spr_addr or sys_data or spr_dat_mac or spr_dat_pic or spr_dat_pm or
	spr_dat_dmmu or spr_dat_immu or spr_dat_du or spr_dat_tt) begin
	case (sprs_op)
		`OR1200_ALUOP_MTSR: to_wbmux = 32'b0;
		`OR1200_ALUOP_MFSR: begin
			casex (spr_addr[15:11])
				`OR1200_SPR_GROUP_TT:   to_wbmux = spr_dat_tt;
				`OR1200_SPR_GROUP_PIC:  to_wbmux = spr_dat_pic;
				`OR1200_SPR_GROUP_PM:   to_wbmux = spr_dat_pm;
				`OR1200_SPR_GROUP_DMMU: to_wbmux = spr_dat_dmmu;
				`OR1200_SPR_GROUP_IMMU: to_wbmux = spr_dat_immu;
				`OR1200_SPR_GROUP_MAC:  to_wbmux = spr_dat_mac;
				`OR1200_SPR_GROUP_DU:   to_wbmux = spr_dat_du;
				`OR1200_SPR_GROUP_SYS:  to_wbmux = sys_data;
				default:                to_wbmux = 32'b0;
			endcase
		end
		default: to_wbmux = 32'b0;
	endcase
end

endmodule
