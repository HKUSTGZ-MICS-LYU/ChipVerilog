`include "timescale.v"
`include "or1200_defines.v"

module or1200_cpu(
    clk, rst,
    ic_en, icpu_adr_o, icpu_cycstb_o, icpu_sel_o, icpu_tag_o,
    icpu_dat_i, icpu_ack_i, icpu_rty_i, icpu_err_i, icpu_adr_i, icpu_tag_i,
    immu_en,
    ex_insn, ex_freeze, id_pc, branch_op, spr_dat_npc, rf_dataw,
    du_stall, du_addr, du_dat_du, du_read, du_write, du_dsr, du_hwbkpt,
    du_except, du_dat_cpu,
    dc_en, dcpu_adr_o, dcpu_cycstb_o, dcpu_we_o, dcpu_sel_o, dcpu_tag_o,
    dcpu_dat_o, dcpu_dat_i, dcpu_ack_i, dcpu_rty_i, dcpu_err_i, dcpu_tag_i,
    dmmu_en,
    sig_int, sig_tick,
    supv, spr_addr, spr_dat_cpu,
    spr_dat_pic, spr_dat_tt, spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du,
    spr_cs, spr_we
);

input         clk, rst;
output        ic_en;
output [31:0] icpu_adr_o;
output        icpu_cycstb_o;
output [3:0]  icpu_sel_o;
output [3:0]  icpu_tag_o;
input  [31:0] icpu_dat_i;
input         icpu_ack_i;
input         icpu_rty_i;
input         icpu_err_i;
input  [31:0] icpu_adr_i;
input  [3:0]  icpu_tag_i;
output        immu_en;
output [31:0] ex_insn;
output        ex_freeze;
output [31:0] id_pc;
output [2:0]  branch_op;
output [31:0] spr_dat_npc;
output [31:0] rf_dataw;
input         du_stall;
input  [31:0] du_addr;
input  [31:0] du_dat_du;
input         du_read;
input         du_write;
input  [13:0] du_dsr;
input         du_hwbkpt;
output [12:0] du_except;
output [31:0] du_dat_cpu;
output        dc_en;
output [31:0] dcpu_adr_o;
output        dcpu_cycstb_o;
output        dcpu_we_o;
output [3:0]  dcpu_sel_o;
output [3:0]  dcpu_tag_o;
output [31:0] dcpu_dat_o;
input  [31:0] dcpu_dat_i;
input         dcpu_ack_i;
input         dcpu_rty_i;
input         dcpu_err_i;
input  [3:0]  dcpu_tag_i;
input         sig_int;
input         sig_tick;
output        supv;
output [31:0] spr_addr;
output [31:0] spr_dat_cpu;
input  [31:0] spr_dat_pic;
input  [31:0] spr_dat_tt;
input  [31:0] spr_dat_pm;
input  [31:0] spr_dat_dmmu;
input  [31:0] spr_dat_immu;
input  [31:0] spr_dat_du;
output [31:0] spr_cs;
output        spr_we;

// Internal wires
wire [31:0] if_insn;
wire [31:0] if_pc;
wire        if_stall;
wire        if_freeze;
wire        id_freeze;
wire        wb_freeze;
wire        flushpipe;
wire        extend_flush;
wire        genpc_refetch;
wire        if_stall_w;
wire        no_more_dslot;
wire        rfe;
wire [31:0] genpc_refetch_addr;

wire [31:0] ex_pc;
wire [31:0] wb_pc;
wire [31:0] id_insn;
wire [31:0] wb_insn;

wire        ex_nullified;
wire        wb_freeze_w;

// Register file interface
wire [4:0]  rf_addra;
wire [4:0]  rf_addrb;
wire [4:0]  rf_addrw;
wire [31:0] rf_dataa;
wire [31:0] rf_datab;
wire        rf_rda;
wire        rf_rdb;
wire        we;

// Operands
wire [31:0] alu_a;
wire [31:0] alu_b;
wire [31:0] id_immediate;
wire        id_immediate_sel;
wire [31:0] ex_forw;
wire        ex_forw_valid;
wire [31:0] wb_forw;
wire        wb_forw_valid;

// ALU
wire [31:0] result;
wire        flagforw;
wire        flag_we;
wire        cyforw;
wire        cy_we;
wire        flag;
wire        carry;

// Control signals from ctrl
wire [3:0]  alu_op;
wire [1:0]  shrot_op;
wire [3:0]  comp_op;
wire [4:0]  cust5_op;
wire [5:0]  cust5_limm;
wire [2:0]  mac_op;
wire [3:0]  rfwb_op;
wire [3:0]  lsu_op;
wire        id_lsu_op_w;
wire [2:0]  branch_op_w;
wire [31:0] id_branch_addrtarget;
wire        ex_branch_taken;
wire        ex_branch_op_w;
wire        id_void;
wire        ex_void;
wire        multicycle;
wire        macs_op;
wire        macrc_op;
wire        id_macrc_op;
wire        mac_stall_r;
wire        lsu_stall;
wire        lsu_unstall;
wire        except_align;
wire        except_dtlbmiss;
wire        except_dmmufault;
wire        except_dbuserr;
wire        except_itlbmiss;
wire        except_immufault;
wire        except_ibuserr;
wire        ex_freeze_w;
wire        abort_ex;
wire        abort_mvspr;

// Exception
wire [31:0] except_type;
wire        except_start;
wire        except_started;
wire        except_stop;
wire        except_flushpipe;
wire [31:0] epcr;
wire [31:0] eear;
wire [15:0] esr;
wire        epcr_we;
wire        eear_we;
wire        esr_we;
wire        pc_we;
wire [31:0] sr;
wire [15:0] to_sr;
wire        sr_we;

// SPR internal
wire        spr_valid;
wire [31:0] spr_dat_cfgr;
wire [31:0] spr_dat_rf;
wire [31:0] spr_dat_npc_w;
wire [31:0] spr_dat_ppc;
wire [31:0] spr_dat_mac;
wire [31:0] to_wbmux;

// WB mux
wire [31:0] muxout;
wire [31:0] muxreg;
wire        muxreg_valid;

// LSU
wire [31:0] lsu_dataout;
wire [31:0] lsu_datain;
wire [31:0] lsu_addrbase;
wire [31:0] lsu_addrofs;

// Freeze / flush
wire        genpc_freeze;
wire        if_freeze_w;
wire        id_freeze_w;

// SR-derived enables
assign dc_en       = sr[3];
assign ic_en       = sr[4];
assign dmmu_en     = sr[5];
assign immu_en     = sr[6];
assign supv        = sr[0];
wire   except_prefix = sr[14];

assign du_except   = except_stop;
assign branch_op   = branch_op_w;
assign spr_dat_npc = spr_dat_npc_w;
assign rf_dataw    = muxreg;
assign ex_freeze   = ex_freeze_w;

// Program Counter Generation
or1200_genpc or1200_genpc(
    .clk(clk), .rst(rst),
    .icpu_adr_o(icpu_adr_o), .icpu_cycstb_o(icpu_cycstb_o),
    .icpu_sel_o(icpu_sel_o), .icpu_tag_o(icpu_tag_o),
    .branch_op(branch_op_w), .except_type(except_type),
    .except_prefix(except_prefix), .branch_addrofs(id_branch_addrtarget),
    .lr_restor(alu_a), .flag(flag), .flagforw(flagforw),
    .ex_branch_taken(ex_branch_taken), .epcr(epcr),
    .spr_dat_i(spr_dat_cpu), .spr_pc_we(pc_we),
    .genpc_refetch(genpc_refetch), .genpc_freeze(genpc_freeze),
    .no_more_dslot(no_more_dslot), .except_start(except_start),
    .except_stop(except_stop), .icpu_adr_i(icpu_adr_i)
);

// Instruction Fetch
or1200_if or1200_if(
    .clk(clk), .rst(rst),
    .icpu_dat_i(icpu_dat_i), .icpu_ack_i(icpu_ack_i),
    .icpu_err_i(icpu_err_i), .icpu_adr_i(icpu_adr_i),
    .icpu_tag_i(icpu_tag_i),
    .if_freeze(if_freeze_w), .if_insn(if_insn), .if_pc(if_pc),
    .flushpipe(flushpipe), .if_stall(if_stall),
    .no_more_dslot(no_more_dslot), .genpc_refetch(genpc_refetch),
    .rfe(rfe),
    .except_itlbmiss(except_itlbmiss),
    .except_immufault(except_immufault),
    .except_ibuserr(except_ibuserr)
);

// Decode / Control
or1200_ctrl or1200_ctrl(
    .clk(clk), .rst(rst),
    .id_freeze(id_freeze_w), .ex_freeze(ex_freeze_w), .wb_freeze(wb_freeze),
    .flushpipe(flushpipe), .if_insn(if_insn), .if_pc(if_pc),
    .id_insn(id_insn), .ex_insn(ex_insn), .id_pc(id_pc), .ex_pc(ex_pc),
    .branch_op(branch_op_w), .branch_addrofs(id_branch_addrtarget),
    .ex_branch_taken(ex_branch_taken),
    .rf_addra(rf_addra), .rf_addrb(rf_addrb), .rf_rda(rf_rda), .rf_rdb(rf_rdb),
    .alu_op(alu_op), .alu_op2(shrot_op), .comp_op(comp_op),
    .cust5_op(cust5_op), .cust5_limm(cust5_limm),
    .rfwb_op(rfwb_op), .rf_addrw(rf_addrw),
    .id_immediate(id_immediate), .id_immediate_sel(id_immediate_sel),
    .lsu_addrofs(lsu_addrofs), .lsu_op(lsu_op),
    .mac_op(mac_op), .macrc_op(macrc_op), .id_macrc_op(id_macrc_op),
    .macs_op(macs_op),
    .rfe(rfe), .except_illegal(except_type), .except_align(except_align),
    .abort_ex(abort_ex), .abort_mvspr(abort_mvspr),
    .du_hwbkpt(du_hwbkpt), .no_more_dslot(no_more_dslot),
    .multicycle(multicycle), .id_void(id_void), .ex_void(ex_void),
    .spr_addr(spr_addr), .spr_dat_o(spr_dat_cpu), .spr_cs(spr_cs), .spr_we(spr_we)
);

// Register File
or1200_rf or1200_rf(
    .clk(clk), .rst(rst),
    .supv(supv), .wb_freeze(wb_freeze), .addrw(rf_addrw),
    .dataw(rf_dataw), .we(we), .flushpipe(flushpipe),
    .id_freeze(id_freeze_w), .addra(rf_addra), .addrb(rf_addrb),
    .dataa(rf_dataa), .datab(rf_datab), .rda(rf_rda), .rdb(rf_rdb),
    .spr_cs(spr_cs[0]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_rf)
);

assign we = rfwb_op[0];

// Operand Muxes
or1200_operandmuxes or1200_operandmuxes(
    .clk(clk), .rst(rst),
    .id_freeze(id_freeze_w), .ex_freeze(ex_freeze_w),
    .rf_dataa(rf_dataa), .rf_datab(rf_datab),
    .ex_forw(ex_forw), .wb_forw(wb_forw),
    .ex_forw_valid(ex_forw_valid), .wb_forw_valid(wb_forw_valid),
    .id_immediate(id_immediate), .id_immediate_sel(id_immediate_sel),
    .alu_a(alu_a), .alu_b(alu_b)
);

// ALU
or1200_alu or1200_alu(
    .a(alu_a), .b(alu_b), .mult_mac_result(muxout),
    .macrc_op(macrc_op), .alu_op(alu_op),
    .shrot_op(shrot_op), .comp_op(comp_op),
    .cust5_op(cust5_op), .cust5_limm(cust5_limm),
    .result(result), .flagforw(flagforw), .flag_we(flag_we),
    .cyforw(cyforw), .cy_we(cy_we),
    .carry(carry), .flag(flag)
);

// Multiplier/MAC
or1200_mult_mac or1200_mult_mac(
    .clk(clk), .rst(rst),
    .ex_freeze(ex_freeze_w), .id_macrc_op(id_macrc_op),
    .macrc_op(macrc_op), .a(alu_a), .b(alu_b),
    .mac_op(mac_op), .alu_op(alu_op),
    .result(muxout), .mac_stall_r(mac_stall_r),
    .spr_cs(spr_cs[0]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_mac)
);

// SPR block
or1200_sprs or1200_sprs(
    .clk(clk), .rst(rst),
    .flagforw(flagforw), .flag_we(flag_we), .flag(flag),
    .cyforw(cyforw), .cy_we(cy_we), .carry(carry),
    .addrbase(alu_a), .addrofs(id_immediate),
    .dat_i(alu_b), .alu_op(alu_op), .branch_op(branch_op_w),
    .epcr(epcr), .eear(eear), .esr(esr), .except_started(except_started),
    .to_wbmux(to_wbmux),
    .epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we),
    .pc_we(pc_we), .sr_we(sr_we), .to_sr(to_sr), .sr(sr),
    .spr_dat_cfgr(spr_dat_cfgr), .spr_dat_rf(spr_dat_rf),
    .spr_dat_npc(spr_dat_npc_w), .spr_dat_ppc(spr_dat_ppc),
    .spr_dat_mac(spr_dat_mac),
    .spr_dat_pic(spr_dat_pic), .spr_dat_tt(spr_dat_tt),
    .spr_dat_pm(spr_dat_pm), .spr_dat_dmmu(spr_dat_dmmu),
    .spr_dat_immu(spr_dat_immu), .spr_dat_du(spr_dat_du),
    .spr_addr(spr_addr), .spr_dat_o(spr_dat_cpu),
    .spr_cs(spr_cs), .spr_we(spr_we),
    .du_addr(du_addr), .du_dat_du(du_dat_du),
    .du_read(du_read), .du_write(du_write), .du_dat_cpu(du_dat_cpu)
);

// LSU
assign lsu_addrbase = alu_a;
assign lsu_datain   = alu_b;

or1200_lsu or1200_lsu(
    .addrbase(lsu_addrbase), .addrofs(lsu_addrofs),
    .lsu_op(lsu_op), .lsu_datain(lsu_datain),
    .lsu_dataout(lsu_dataout), .lsu_stall(lsu_stall),
    .lsu_unstall(lsu_unstall), .du_stall(du_stall),
    .except_align(except_align), .except_dtlbmiss(except_dtlbmiss),
    .except_dmmufault(except_dmmufault), .except_dbuserr(except_dbuserr),
    .dcpu_adr_o(dcpu_adr_o), .dcpu_cycstb_o(dcpu_cycstb_o),
    .dcpu_we_o(dcpu_we_o), .dcpu_sel_o(dcpu_sel_o),
    .dcpu_tag_o(dcpu_tag_o), .dcpu_dat_o(dcpu_dat_o),
    .dcpu_dat_i(dcpu_dat_i), .dcpu_ack_i(dcpu_ack_i),
    .dcpu_rty_i(dcpu_rty_i), .dcpu_err_i(dcpu_err_i),
    .dcpu_tag_i(dcpu_tag_i)
);

// Write-back Mux
or1200_wbmux or1200_wbmux(
    .clk(clk), .rst(rst),
    .wb_freeze(wb_freeze), .rfwb_op(rfwb_op),
    .muxin_a(result), .muxin_b(lsu_dataout),
    .muxin_c(to_wbmux), .muxin_d(ex_pc),
    .muxout(muxout), .muxreg(muxreg), .muxreg_valid(muxreg_valid)
);

assign ex_forw       = muxout;
assign ex_forw_valid = rfwb_op[0];
assign wb_forw       = muxreg;
assign wb_forw_valid = muxreg_valid;

// Exception module
or1200_except or1200_except(
    .clk(clk), .rst(rst),
    .sig_ibuserr(except_ibuserr), .sig_dbuserr(except_dbuserr),
    .sig_illegal(except_type), .sig_align(except_align),
    .sig_dtlbmiss(except_dtlbmiss), .sig_dmmufault(except_dmmufault),
    .sig_int(sig_int), .sig_syscall(id_void), .sig_trap(ex_void),
    .sig_itlbmiss(except_itlbmiss), .sig_immufault(except_immufault),
    .sig_tick(sig_tick),
    .branch_op(branch_op_w), .id_freeze(id_freeze_w),
    .ex_freeze(ex_freeze_w), .wb_freeze(wb_freeze),
    .du_dsr(du_dsr), .du_hwbkpt(du_hwbkpt),
    .except_flushpipe(except_flushpipe),
    .extend_flush(extend_flush),
    .except_type(except_type), .except_start(except_start),
    .except_started(except_started), .except_stop(except_stop),
    .epcr_we(epcr_we), .eear_we(eear_we), .esr_we(esr_we),
    .epcr(epcr), .eear(eear), .esr(esr),
    .abort_ex(abort_ex)
);

assign flushpipe = except_flushpipe;

// Freeze logic
or1200_freeze or1200_freeze(
    .clk(clk), .rst(rst),
    .multicycle(multicycle), .flushpipe(flushpipe),
    .extend_flush(extend_flush), .lsu_stall(lsu_stall),
    .lsu_unstall(lsu_unstall), .force_dslot_fetch(1'b0),
    .abort_ex(abort_ex), .du_stall(du_stall),
    .mac_stall_r(mac_stall_r), .if_stall(if_stall),
    .icpu_ack_i(icpu_ack_i), .icpu_err_i(icpu_err_i),
    .genpc_freeze(genpc_freeze), .if_freeze(if_freeze_w),
    .id_freeze(id_freeze_w), .ex_freeze(ex_freeze_w),
    .wb_freeze(wb_freeze)
);

// Configuration registers
or1200_cfgr or1200_cfgr(
    .spr_addr(spr_addr),
    .spr_dat_o(spr_dat_cfgr)
);

endmodule