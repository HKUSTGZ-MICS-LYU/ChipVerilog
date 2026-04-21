`include "timescale.v"
`include "or1200_defines.v"

module or1200_ctrl(
	clk, rst,
	id_freeze, ex_freeze, wb_freeze, flushpipe, if_insn, ex_insn, branch_op, branch_taken,
	rf_addra, rf_addrb, rf_rda, rf_rdb, alu_op, mac_op, shrot_op, comp_op, rf_addrw, rfwb_op,
	wb_insn, simm, branch_addrofs, lsu_addrofs, sel_a, sel_b, lsu_op,
	cust5_op, cust5_limm,
	multicycle, spr_addrimm, wbforw_valid, du_hwbkpt, sig_syscall, sig_trap,
	force_dslot_fetch, no_more_dslot, ex_void, id_macrc_op, ex_macrc_op, rfe, except_illegal
);

input			clk;
input			rst;
input			id_freeze;
input			ex_freeze;
input			wb_freeze;
input			flushpipe;
input	[31:0]		if_insn;
output	[31:0]		ex_insn;
output	[2:0]		branch_op;
input			branch_taken;
output	[4:0]		rf_addrw;
output	[4:0]		rf_addra;
output	[4:0]		rf_addrb;
output			rf_rda;
output			rf_rdb;
output	[3:0]		alu_op;
output	[1:0]		mac_op;
output	[1:0]		shrot_op;
output	[2:0]		rfwb_op;
output	[31:0]		wb_insn;
output	[31:0]		simm;
output	[31:2]		branch_addrofs;
output	[31:0]		lsu_addrofs;
output	[1:0]		sel_a;
output	[1:0]		sel_b;
output	[3:0]		lsu_op;
output	[3:0]		comp_op;
output	[1:0]		multicycle;
output	[4:0]		cust5_op;
output	[5:0]		cust5_limm;
output	[15:0]		spr_addrimm;
input			wbforw_valid;
input			du_hwbkpt;
output			sig_syscall;
output			sig_trap;
output			force_dslot_fetch;
output			no_more_dslot;
output			ex_void;
output			id_macrc_op;
output			ex_macrc_op;
output			rfe;
output			except_illegal;

reg	[2:0]		pre_branch_op;
reg	[2:0]		branch_op;
reg	[3:0]		alu_op;
`ifdef OR1200_MAC_IMPLEMENTED
reg	[1:0]		mac_op;
reg			ex_macrc_op;
`else
wire	[1:0]		mac_op;
wire			ex_macrc_op;
`endif
reg	[1:0]		shrot_op;
reg	[31:0]		id_insn;
reg	[31:0]		ex_insn;
reg	[31:0]		wb_insn;
reg	[4:0]		rf_addrw;
reg	[4:0]		wb_rfaddrw;
reg	[2:0]		rfwb_op;
reg	[31:0]		lsu_addrofs;
reg	[1:0]		sel_a;
reg	[1:0]		sel_b;
reg			sel_imm;
reg	[3:0]		lsu_op;
reg	[3:0]		comp_op;
reg	[1:0]		multicycle;
reg			imm_signextend;
reg	[15:0]		spr_addrimm;
reg			sig_syscall;
reg			sig_trap;
reg			except_illegal;
wire			id_void;

// rf_addra, rf_addrb derived from instruction fields
assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
// rf_rda/rf_rdb based on instruction-encoded control bits
assign rf_rda = if_insn[31];
assign rf_rdb = if_insn[30];

assign force_dslot_fetch = 1'b0;
assign no_more_dslot = |branch_op & !id_void & branch_taken | (branch_op == `OR1200_BRANCHOP_RFE);
assign id_void = (id_insn[31:26] == `OR1200_OR32_NOP) & id_insn[16];
assign ex_void = (ex_insn[31:26] == `OR1200_OR32_NOP) & ex_insn[16];

assign simm = (imm_signextend == 1'b1 ? {{16{id_insn[15]}}, id_insn[15:0]} : {{16'b0}, id_insn[15:0]});
assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0]};

`ifdef OR1200_MAC_IMPLEMENTED
assign id_macrc_op = (id_insn[31:26] == `OR1200_OR32_MOVHI) & id_insn[16];
`else
assign id_macrc_op = 1'b0;
`endif

assign cust5_op  = ex_insn[4:0];
assign cust5_limm = ex_insn[10:5];

assign rfe = (pre_branch_op == `OR1200_BRANCHOP_RFE) | (branch_op == `OR1200_BRANCHOP_RFE);

// sel_a forwarding
always @(rf_addrw or id_insn or rfwb_op or wbforw_valid or wb_rfaddrw)
	if ((id_insn[20:16] == rf_addrw) && rfwb_op[0])
		sel_a = `OR1200_SEL_EX_FORW;
	else if ((id_insn[20:16] == wb_rfaddrw) && wbforw_valid)
		sel_a = `OR1200_SEL_WB_FORW;
	else
		sel_a = `OR1200_SEL_RF;

// sel_b forwarding; immediate has highest priority
always @(rf_addrw or sel_imm or id_insn or rfwb_op or wbforw_valid or wb_rfaddrw)
	if (sel_imm)
		sel_b = `OR1200_SEL_IMM;
	else if ((id_insn[15:11] == rf_addrw) && rfwb_op[0])
		sel_b = `OR1200_SEL_EX_FORW;
	else if ((id_insn[15:11] == wb_rfaddrw) && wbforw_valid)
		sel_b = `OR1200_SEL_WB_FORW;
	else
		sel_b = `OR1200_SEL_RF;

// ex_macrc_op pipeline register
`ifdef OR1200_MAC_IMPLEMENTED
always @(posedge clk or posedge rst) begin
	if (rst)
		ex_macrc_op <= #1 1'b0;
	else if (!ex_freeze & id_freeze | flushpipe)
		ex_macrc_op <= #1 1'b0;
	else if (!ex_freeze)
		ex_macrc_op <= #1 id_macrc_op;
end
`else
assign ex_macrc_op = 1'b0;
`endif

// spr_addrimm decode
always @(posedge clk or posedge rst) begin
	if (rst)
		spr_addrimm <= #1 16'h0000;
	else if (!ex_freeze & id_freeze | flushpipe)
		spr_addrimm <= #1 16'h0000;
	else if (!ex_freeze) begin
		case (id_insn[31:26])
			`OR1200_OR32_MFSPR:
				spr_addrimm <= #1 id_insn[15:0];
			default:
				spr_addrimm <= #1 {id_insn[25:21], id_insn[10:0]};
		endcase
	end
end

// multicycle decode — multiply/MAC and selected ALU multi-cycle classes
always @(id_insn) begin
	case (id_insn[31:26])
		`OR1200_OR32_ALU:
			multicycle = id_insn[9:8];
		default:
			multicycle = `OR1200_ONE_CYCLE;
	endcase
end

// imm_signextend decode
always @(id_insn) begin
	case (id_insn[31:26])
		`OR1200_OR32_ADDI,
		`OR1200_OR32_ADDIC,
		`OR1200_OR32_XORI,
`ifdef OR1200_MULT_IMPLEMENTED
		`OR1200_OR32_MULI,
`endif
`ifdef OR1200_MAC_IMPLEMENTED
		`OR1200_OR32_MACI,
`endif
		`OR1200_OR32_SFXXI:
			imm_signextend = 1'b1;
		default:
			imm_signextend = 1'b0;
	endcase
end

// lsu_addrofs
always @(lsu_op or ex_insn) begin
	lsu_addrofs[10:0] = ex_insn[10:0];
	case (lsu_op)
		`OR1200_LSUOP_SW, `OR1200_LSUOP_SH, `OR1200_LSUOP_SB:
			lsu_addrofs[31:11] = {{16{ex_insn[25]}}, ex_insn[25:21]};
		default:
			lsu_addrofs[31:11] = {{16{ex_insn[15]}}, ex_insn[15:11]};
	endcase
end

// rf_addrw
always @(posedge clk or posedge rst) begin
	if (rst)
		rf_addrw <= #1 5'd0;
	else if (!ex_freeze & id_freeze)
		rf_addrw <= #1 5'd0;
	else if (!ex_freeze)
		case (pre_branch_op)
			`OR1200_BRANCHOP_JR, `OR1200_BRANCHOP_BAL:
				rf_addrw <= #1 5'd09;
			default:
				rf_addrw <= #1 id_insn[25:21];
		endcase
end

// wb_rfaddrw
always @(posedge clk or posedge rst) begin
	if (rst)
		wb_rfaddrw <= #1 5'd0;
	else if (!wb_freeze)
		wb_rfaddrw <= #1 rf_addrw;
end

// id_insn pipeline register
always @(posedge clk or posedge rst) begin
	if (rst)
		id_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (flushpipe)
		id_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (!id_freeze)
		id_insn <= #1 if_insn;
end

// ex_insn pipeline register
always @(posedge clk or posedge rst) begin
	if (rst)
		ex_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (!ex_freeze & id_freeze | flushpipe)
		ex_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (!ex_freeze)
		ex_insn <= #1 id_insn;
end

// wb_insn pipeline register
always @(posedge clk or posedge rst) begin
	if (rst)
		wb_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (flushpipe)
		wb_insn <= #1 {`OR1200_OR32_NOP, 26'h041_0000};
	else if (!wb_freeze)
		wb_insn <= #1 ex_insn;
end

// sel_imm
always @(posedge clk or posedge rst) begin
	if (rst)
		sel_imm <= #1 1'b0;
	else if (!id_freeze) begin
		case (if_insn[31:26])
			`OR1200_OR32_JALR, `OR1200_OR32_JR, `OR1200_OR32_RFE,
			`OR1200_OR32_MFSPR, `OR1200_OR32_MTSPR, `OR1200_OR32_XSYNC,
`ifdef OR1200_MAC_IMPLEMENTED
			`OR1200_OR32_MACMSB,
`endif
			`OR1200_OR32_SW, `OR1200_OR32_SB, `OR1200_OR32_SH,
			`OR1200_OR32_ALU, `OR1200_OR32_SFXX,
`ifdef OR1200_OR32_CUST5
			`OR1200_OR32_CUST5,
`endif
			`OR1200_OR32_NOP:
				sel_imm <= #1 1'b0;
			default:
				sel_imm <= #1 1'b1;
		endcase
	end
end

// except_illegal
always @(posedge clk or posedge rst) begin
	if (rst)
		except_illegal <= #1 1'b0;
	else if (!ex_freeze & id_freeze | flushpipe)
		except_illegal <= #1 1'b0;
	else if (!ex_freeze) begin
		case (id_insn[31:26])
			`OR1200_OR32_J, `OR1200_OR32_JAL, `OR1200_OR32_JALR, `OR1200_OR32_JR,
			`OR1200_OR32_BNF, `OR1200_OR32_BF, `OR1200_OR32_RFE, `OR1200_OR32_MOVHI,
			`OR1200_OR32_MFSPR, `OR1200_OR32_XSYNC,
`ifdef OR1200_MAC_IMPLEMENTED
			`OR1200_OR32_MACI,
`endif
			`OR1200_OR32_LWZ, `OR1200_OR32_LBZ, `OR1200_OR32_LBS,
			`OR1200_OR32_LHZ, `OR1200_OR32_LHS,
			`OR1200_OR32_ADDI, `OR1200_OR32_ADDIC, `OR1200_OR32_ANDI,
			`OR1200_OR32_ORI, `OR1200_OR32_XORI,
`ifdef OR1200_MULT_IMPLEMENTED
			`OR1200_OR32_MULI,
`endif
			`OR1200_OR32_SH_ROTI, `OR1200_OR32_SFXXI, `OR1200_OR32_MTSPR,
`ifdef OR1200_MAC_IMPLEMENTED
			`OR1200_OR32_MACMSB,
`endif
			`OR1200_OR32_SW, `OR1200_OR32_SB, `OR1200_OR32_SH,
			`OR1200_OR32_ALU, `OR1200_OR32_SFXX,
`ifdef OR1200_OR32_CUST5
			`OR1200_OR32_CUST5,
`endif
			`OR1200_OR32_NOP:
				except_illegal <= #1 1'b0;
			default:
				except_illegal <= #1 1'b1;
		endcase
	end
end

// alu_op
always @(posedge clk or posedge rst) begin
	if (rst)
		alu_op <= #1 `OR1200_ALUOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		alu_op <= #1 `OR1200_ALUOP_NOP;
	else if (!ex_freeze) begin
		case (id_insn[31:26])
			`OR1200_OR32_J, `OR1200_OR32_JAL:	alu_op <= #1 `OR1200_ALUOP_IMM;
			`OR1200_OR32_BNF, `OR1200_OR32_BF:	alu_op <= #1 `OR1200_ALUOP_NOP;
			`OR1200_OR32_MOVHI:			alu_op <= #1 `OR1200_ALUOP_MOVHI;
			`OR1200_OR32_MFSPR:			alu_op <= #1 `OR1200_ALUOP_MFSR;
			`OR1200_OR32_MTSPR:			alu_op <= #1 `OR1200_ALUOP_MTSR;
			`OR1200_OR32_ADDI:			alu_op <= #1 `OR1200_ALUOP_ADD;
			`OR1200_OR32_ADDIC:			alu_op <= #1 `OR1200_ALUOP_ADDC;
			`OR1200_OR32_ANDI:			alu_op <= #1 `OR1200_ALUOP_AND;
			`OR1200_OR32_ORI:			alu_op <= #1 `OR1200_ALUOP_OR;
			`OR1200_OR32_XORI:			alu_op <= #1 `OR1200_ALUOP_XOR;
`ifdef OR1200_MULT_IMPLEMENTED
			`OR1200_OR32_MULI:			alu_op <= #1 `OR1200_ALUOP_MUL;
`endif
			`OR1200_OR32_SH_ROTI:			alu_op <= #1 `OR1200_ALUOP_SHROT;
			`OR1200_OR32_SFXXI:			alu_op <= #1 `OR1200_ALUOP_COMP;
			`OR1200_OR32_ALU:			alu_op <= #1 id_insn[3:0];
			`OR1200_OR32_SFXX:			alu_op <= #1 `OR1200_ALUOP_COMP;
`ifdef OR1200_OR32_CUST5
			`OR1200_OR32_CUST5:			alu_op <= #1 `OR1200_ALUOP_CUST5;
`endif
			default:				alu_op <= #1 `OR1200_ALUOP_NOP;
		endcase
	end
end

// mac_op
`ifdef OR1200_MAC_IMPLEMENTED
always @(posedge clk or posedge rst) begin
	if (rst)
		mac_op <= #1 `OR1200_MACOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		mac_op <= #1 `OR1200_MACOP_NOP;
	else if (!ex_freeze)
		case (id_insn[31:26])
			`OR1200_OR32_MACI:	mac_op <= #1 `OR1200_MACOP_MAC;
			`OR1200_OR32_MACMSB:	mac_op <= #1 id_insn[1:0];
			default:		mac_op <= #1 `OR1200_MACOP_NOP;
		endcase
	else
		mac_op <= #1 `OR1200_MACOP_NOP;
end
`else
assign mac_op = `OR1200_MACOP_NOP;
`endif

// shrot_op
always @(posedge clk or posedge rst) begin
	if (rst)
		shrot_op <= #1 `OR1200_SHROTOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		shrot_op <= #1 `OR1200_SHROTOP_NOP;
	else if (!ex_freeze)
		shrot_op <= #1 id_insn[7:6];
end

// rfwb_op
always @(posedge clk or posedge rst) begin
	if (rst)
		rfwb_op <= #1 `OR1200_RFWBOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		rfwb_op <= #1 `OR1200_RFWBOP_NOP;
	else if (!ex_freeze) begin
		case (id_insn[31:26])
			`OR1200_OR32_JAL, `OR1200_OR32_JALR:	rfwb_op <= #1 `OR1200_RFWBOP_LR;
			`OR1200_OR32_MOVHI:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
			`OR1200_OR32_MFSPR:			rfwb_op <= #1 `OR1200_RFWBOP_SPRS;
			`OR1200_OR32_LWZ, `OR1200_OR32_LBZ,
			`OR1200_OR32_LBS, `OR1200_OR32_LHZ,
			`OR1200_OR32_LHS:			rfwb_op <= #1 `OR1200_RFWBOP_LSU;
			`OR1200_OR32_ADDI, `OR1200_OR32_ADDIC,
			`OR1200_OR32_ANDI, `OR1200_OR32_ORI,
			`OR1200_OR32_XORI:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
`ifdef OR1200_MULT_IMPLEMENTED
			`OR1200_OR32_MULI:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
`endif
			`OR1200_OR32_SH_ROTI:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
			`OR1200_OR32_ALU:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
`ifdef OR1200_OR32_CUST5
			`OR1200_OR32_CUST5:			rfwb_op <= #1 `OR1200_RFWBOP_ALU;
`endif
			default:				rfwb_op <= #1 `OR1200_RFWBOP_NOP;
		endcase
	end
end

// pre_branch_op
always @(posedge clk or posedge rst) begin
	if (rst)
		pre_branch_op <= #1 `OR1200_BRANCHOP_NOP;
	else if (flushpipe)
		pre_branch_op <= #1 `OR1200_BRANCHOP_NOP;
	else if (!id_freeze) begin
		case (if_insn[31:26])
			`OR1200_OR32_J, `OR1200_OR32_JAL:	pre_branch_op <= #1 `OR1200_BRANCHOP_BAL;
			`OR1200_OR32_JALR:			pre_branch_op <= #1 `OR1200_BRANCHOP_JR;
			`OR1200_OR32_JR:			pre_branch_op <= #1 `OR1200_BRANCHOP_JR;
			`OR1200_OR32_BNF:			pre_branch_op <= #1 `OR1200_BRANCHOP_BNF;
			`OR1200_OR32_BF:			pre_branch_op <= #1 `OR1200_BRANCHOP_BF;
			`OR1200_OR32_RFE:			pre_branch_op <= #1 `OR1200_BRANCHOP_RFE;
			default:				pre_branch_op <= #1 `OR1200_BRANCHOP_NOP;
		endcase
	end
end

// branch_op
always @(posedge clk or posedge rst)
	if (rst)
		branch_op <= #1 `OR1200_BRANCHOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		branch_op <= #1 `OR1200_BRANCHOP_NOP;
	else if (!ex_freeze)
		branch_op <= #1 pre_branch_op;

// lsu_op
always @(posedge clk or posedge rst) begin
	if (rst)
		lsu_op <= #1 `OR1200_LSUOP_NOP;
	else if (!ex_freeze & id_freeze | flushpipe)
		lsu_op <= #1 `OR1200_LSUOP_NOP;
	else if (!ex_freeze) begin
		case (id_insn[31:26])
			`OR1200_OR32_LWZ:	lsu_op <= #1 `OR1200_LSUOP_LWZ;
			`OR1200_OR32_LBZ:	lsu_op <= #1 `OR1200_LSUOP_LBZ;
			`OR1200_OR32_LBS:	lsu_op <= #1 `OR1200_LSUOP_LBS;
			`OR1200_OR32_LHZ:	lsu_op <= #1 `OR1200_LSUOP_LHZ;
			`OR1200_OR32_LHS:	lsu_op <= #1 `OR1200_LSUOP_LHS;
			`OR1200_OR32_SW:	lsu_op <= #1 `OR1200_LSUOP_SW;
			`OR1200_OR32_SB:	lsu_op <= #1 `OR1200_LSUOP_SB;
			`OR1200_OR32_SH:	lsu_op <= #1 `OR1200_LSUOP_SH;
			default:		lsu_op <= #1 `OR1200_LSUOP_NOP;
		endcase
	end
end

// comp_op
always @(posedge clk or posedge rst) begin
	if (rst)
		comp_op <= #1 4'd0;
	else if (!ex_freeze & id_freeze | flushpipe)
		comp_op <= #1 4'd0;
	else if (!ex_freeze)
		comp_op <= #1 id_insn[24:21];
end

// sig_syscall
always @(posedge clk or posedge rst) begin
	if (rst)
		sig_syscall <= #1 1'b0;
	else if (!ex_freeze & id_freeze | flushpipe)
		sig_syscall <= #1 1'b0;
	else if (!ex_freeze)
		sig_syscall <= #1 (id_insn[31:23] == {`OR1200_OR32_XSYNC, 3'b000});
end

// sig_trap
always @(posedge clk or posedge rst) begin
	if (rst)
		sig_trap <= #1 1'b0;
	else if (!ex_freeze & id_freeze | flushpipe)
		sig_trap <= #1 1'b0;
	else if (!ex_freeze)
		sig_trap <= #1 (id_insn[31:23] == {`OR1200_OR32_XSYNC, 3'b010}) | du_hwbkpt;
end

endmodule
