`include "timescale.v"
`include "or1200_defines.v"

module or1200_top(
    clk_i, rst_i, pic_ints_i, clmode_i,
    iwb_ack_i, iwb_err_i, iwb_rty_i, iwb_dat_i,
    iwb_cyc_o, iwb_adr_o, iwb_stb_o, iwb_we_o, iwb_sel_o, iwb_dat_o,
`ifdef OR1200_WB_CAB
    iwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    iwb_cti_o, iwb_bte_o,
`endif
    dwb_ack_i, dwb_err_i, dwb_rty_i, dwb_dat_i,
    dwb_cyc_o, dwb_adr_o, dwb_stb_o, dwb_we_o, dwb_sel_o, dwb_dat_o,
`ifdef OR1200_WB_CAB
    dwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    dwb_cti_o, dwb_bte_o,
`endif
    dbg_stall_i, dbg_ewt_i,
    dbg_lss_o, dbg_is_o, dbg_wp_o, dbg_bp_o,
    dbg_stb_i, dbg_we_i, dbg_adr_i, dbg_dat_i, dbg_dat_o, dbg_ack_o,
`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif
    pm_cpustall_i,
    pm_clksd_o, pm_dc_gate_o, pm_ic_gate_o,
    pm_dmmu_gate_o, pm_immu_gate_o, pm_tt_gate_o,
    pm_cpu_gate_o, pm_wakeup_o, pm_lvolt_o
);

parameter ppic_ints = `OR1200_PIC_INTS;

input         clk_i, rst_i;
input  [ppic_ints-1:0] pic_ints_i;
input  [1:0]  clmode_i;

input         iwb_ack_i, iwb_err_i, iwb_rty_i;
input  [31:0] iwb_dat_i;
output        iwb_cyc_o, iwb_stb_o, iwb_we_o;
output [31:0] iwb_adr_o, iwb_dat_o;
output [3:0]  iwb_sel_o;
`ifdef OR1200_WB_CAB
output        iwb_cab_o;
`endif
`ifdef OR1200_WB_B3
output [2:0]  iwb_cti_o;
output [1:0]  iwb_bte_o;
`endif

input         dwb_ack_i, dwb_err_i, dwb_rty_i;
input  [31:0] dwb_dat_i;
output        dwb_cyc_o, dwb_stb_o, dwb_we_o;
output [31:0] dwb_adr_o, dwb_dat_o;
output [3:0]  dwb_sel_o;
`ifdef OR1200_WB_CAB
output        dwb_cab_o;
`endif
`ifdef OR1200_WB_B3
output [2:0]  dwb_cti_o;
output [1:0]  dwb_bte_o;
`endif

input         dbg_stall_i, dbg_ewt_i;
output [3:0]  dbg_lss_o;
output [1:0]  dbg_is_o;
output [10:0] dbg_wp_o;
output        dbg_bp_o;
input         dbg_stb_i, dbg_we_i;
input  [31:0] dbg_adr_i, dbg_dat_i;
output [31:0] dbg_dat_o;
output        dbg_ack_o;

`ifdef OR1200_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif

input         pm_cpustall_i;
output [3:0]  pm_clksd_o;
output        pm_dc_gate_o, pm_ic_gate_o;
output        pm_dmmu_gate_o, pm_immu_gate_o, pm_tt_gate_o;
output        pm_cpu_gate_o, pm_wakeup_o, pm_lvolt_o;

// Internal clocks/resets
wire clk = clk_i;
wire rst = rst_i;
wire iwb_clk_i = clk_i;
wire iwb_rst_i = rst_i;
wire dwb_clk_i = clk_i;
wire dwb_rst_i = rst_i;

// CPU interface signals
wire        ic_en, immu_en, supv;
wire [31:0] icpu_adr_o, icpu_adr_i;
wire        icpu_cycstb_o, icpu_rty_i, icpu_err_i, icpu_ack_i;
wire [3:0]  icpu_sel_o, icpu_tag_o, icpu_tag_i;
wire [31:0] icpu_dat_i;
wire        dc_en, dmmu_en;
wire [31:0] dcpu_adr_o, dcpu_dat_o, dcpu_dat_i;
wire        dcpu_cycstb_o, dcpu_we_o, dcpu_ack_i, dcpu_rty_i, dcpu_err_i;
wire [3:0]  dcpu_sel_o, dcpu_tag_o, dcpu_tag_i;

// SPR signals
wire [31:0] spr_addr, spr_dat_cpu, spr_dat_pic, spr_dat_tt;
wire [31:0] spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du;
wire [31:0] spr_cs;
wire        spr_we;

// Debug unit signals
wire        du_stall;
wire [31:0] du_addr, du_dat_du, du_dat_cpu;
wire        du_read, du_write;
wire [12:0] du_except;
wire        du_hwbkpt;
wire [13:0] du_dsr;
wire [31:0] rf_dataw, ex_insn, id_pc, spr_dat_npc, branch_op_w;
wire        ex_freeze;
wire [2:0]  branch_op;

// Exception/interrupt signals
wire        sig_int, sig_tick, pic_wakeup;

// IMMU <-> IC path
wire [31:0] qmemimmu_adr_o, icqmem_adr_o;
wire        qmemimmu_cycstb_o, qmemimmu_rty_i, qmemimmu_err_i;
wire        qmemimmu_ci_o, icqmem_cycstb_o, icqmem_ci_o;
wire [3:0]  qmemimmu_tag_i, icqmem_sel_o, icqmem_tag_o;
wire [31:0] qmemicpu_dat_o, icqmem_dat_i;
wire        qmemicpu_ack_o, icqmem_ack_i, icqmem_rty_i, icqmem_err_i;
wire [3:0]  qmemimmu_tag_o, icqmem_tag_i;
wire [3:0]  qmemicpu_sel_o, qmemicpu_tag_o;
wire [31:0] icqmem_dat_o;
wire [3:0]  icqmem_sel_i, icqmem_tag_i2;

// DMMU <-> DC path
wire [31:0] qmemdmmu_adr_o, dcqmem_adr_o;
wire        qmemdmmu_cycstb_o, qmemdmmu_ci_o;
wire        dcqmem_cycstb_o, dcqmem_ci_o, dcqmem_we_o;
wire [3:0]  dcqmem_sel_o, dcqmem_tag_o;
wire [31:0] dcqmem_dat_o, dcqmem_dat_i;
wire        dcqmem_ack_i, dcqmem_rty_i, dcqmem_err_i;
wire [3:0]  dcqmem_tag_i;
wire [31:0] qmemdcpu_dat_o;
wire        qmemdcpu_ack_o, qmemdcpu_rty_o, qmemdmmu_err_o;
wire [3:0]  qmemdmmu_tag_o;
wire        qmemdmmu_rty_i, qmemdmmu_err_i;
wire [3:0]  qmemdmmu_tag_i;

// IC BIU signals
wire [31:0] icbiu_dat_o, icbiu_adr_o, icbiu_dat_i;
wire        icbiu_cyc_o, icbiu_stb_o, icbiu_we_o, icbiu_ack_i, icbiu_err_i;
wire [3:0]  icbiu_sel_o;
wire        icbiu_cab_o;

// DC/SB/BIU signals
wire [31:0] dcsb_dat_o, dcsb_adr_o, dcsb_dat_i;
wire        dcsb_cyc_o, dcsb_stb_o, dcsb_we_o, dcsb_ack_i, dcsb_err_i;
wire [3:0]  dcsb_sel_o;
wire        dcsb_cab_o;
wire [31:0] sbbiu_dat_o, sbbiu_adr_o, sbbiu_dat_i;
wire        sbbiu_cyc_o, sbbiu_stb_o, sbbiu_we_o, sbbiu_ack_i, sbbiu_err_i;
wire [3:0]  sbbiu_sel_o;
wire        sbbiu_cab_o;

// BIST chain
`ifdef OR1200_BIST
wire mbist_immu_so, mbist_ic_so, mbist_qmem_so, mbist_dmmu_so;
wire mbist_immu_si = mbist_si_i;
wire mbist_ic_si   = mbist_immu_so;
wire mbist_qmem_si = mbist_ic_so;
wire mbist_dmmu_si = mbist_qmem_so;
wire mbist_dc_si   = mbist_dmmu_so;
assign mbist_so_o  = mbist_dc_so;
wire mbist_dc_so;
`endif

// CPU core
or1200_cpu or1200_cpu(
    .clk(clk), .rst(rst),
    .ic_en(ic_en),
    .icpu_adr_o(icpu_adr_o), .icpu_cycstb_o(icpu_cycstb_o),
    .icpu_sel_o(icpu_sel_o), .icpu_tag_o(icpu_tag_o),
    .icpu_dat_i(qmemicpu_dat_o), .icpu_ack_i(qmemicpu_ack_o),
    .icpu_rty_i(qmemimmu_rty_i), .icpu_err_i(qmemimmu_err_i),
    .icpu_adr_i(icpu_adr_o), .icpu_tag_i(qmemimmu_tag_o),
    .immu_en(immu_en),
    .ex_insn(ex_insn), .ex_freeze(ex_freeze),
    .id_pc(id_pc), .branch_op(branch_op),
    .spr_dat_npc(spr_dat_npc), .rf_dataw(rf_dataw),
    .du_stall(du_stall), .du_addr(du_addr), .du_dat_du(du_dat_du),
    .du_read(du_read), .du_write(du_write), .du_dsr(du_dsr),
    .du_hwbkpt(du_hwbkpt), .du_except(du_except), .du_dat_cpu(du_dat_cpu),
    .dc_en(dc_en),
    .dcpu_adr_o(dcpu_adr_o), .dcpu_cycstb_o(dcpu_cycstb_o),
    .dcpu_we_o(dcpu_we_o), .dcpu_sel_o(dcpu_sel_o),
    .dcpu_tag_o(dcpu_tag_o), .dcpu_dat_o(dcpu_dat_o),
    .dcpu_dat_i(qmemdcpu_dat_o), .dcpu_ack_i(qmemdcpu_ack_o),
    .dcpu_rty_i(qmemdcpu_rty_o), .dcpu_err_i(qmemdmmu_err_o),
    .dcpu_tag_i(qmemdmmu_tag_o),
    .dmmu_en(dmmu_en),
    .sig_int(sig_int), .sig_tick(sig_tick),
    .supv(supv),
    .spr_addr(spr_addr), .spr_dat_cpu(spr_dat_cpu),
    .spr_dat_pic(spr_dat_pic), .spr_dat_tt(spr_dat_tt),
    .spr_dat_pm(spr_dat_pm), .spr_dat_dmmu(spr_dat_dmmu),
    .spr_dat_immu(spr_dat_immu), .spr_dat_du(spr_dat_du),
    .spr_cs(spr_cs), .spr_we(spr_we)
);

// IMMU
or1200_immu_top or1200_immu_top(
    .clk(clk), .rst(rst),
    .ic_en(ic_en), .immu_en(immu_en), .supv(supv),
    .icpu_adr_i(icpu_adr_o), .icpu_cycstb_i(icpu_cycstb_o),
    .icpu_adr_o(), .icpu_tag_o(qmemimmu_tag_o),
    .icpu_rty_o(qmemimmu_rty_i), .icpu_err_o(qmemimmu_err_i),
    .spr_cs(spr_cs[2]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_immu),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_immu_si), .mbist_so_o(mbist_immu_so), .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .qmemimmu_rty_i(icqmem_rty_i2), .qmemimmu_err_i(icqmem_err_i2),
    .qmemimmu_tag_i(icqmem_tag_i2),
    .qmemimmu_adr_o(qmemimmu_adr_o),
    .qmemimmu_cycstb_o(qmemimmu_cycstb_o),
    .qmemimmu_ci_o(qmemimmu_ci_o)
);

// QMEM
or1200_qmem_top or1200_qmem_top(
    .clk(clk), .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_qmem_si), .mbist_so_o(mbist_qmem_so), .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .qmemimmu_adr_i(qmemimmu_adr_o),
    .qmemimmu_cycstb_i(qmemimmu_cycstb_o),
    .qmemimmu_ci_i(qmemimmu_ci_o),
    .qmemicpu_sel_i(icpu_sel_o), .qmemicpu_tag_i(icpu_tag_o),
    .qmemicpu_dat_o(qmemicpu_dat_o), .qmemicpu_ack_o(qmemicpu_ack_o),
    .qmemimmu_rty_o(), .qmemimmu_err_o(), .qmemimmu_tag_o(),
    .icqmem_adr_o(icqmem_adr_o), .icqmem_cycstb_o(icqmem_cycstb_o),
    .icqmem_ci_o(icqmem_ci_o), .icqmem_sel_o(icqmem_sel_o), .icqmem_tag_o(icqmem_tag_o),
    .icqmem_dat_i(icqmem_dat_i), .icqmem_ack_i(icqmem_ack_i),
    .icqmem_rty_i(icqmem_rty_i), .icqmem_err_i(icqmem_err_i), .icqmem_tag_i(icqmem_tag_i),
    .qmemdmmu_adr_i(qmemdmmu_adr_o),
    .qmemdmmu_cycstb_i(qmemdmmu_cycstb_o),
    .qmemdmmu_ci_i(qmemdmmu_ci_o),
    .qmemdcpu_we_i(dcpu_we_o), .qmemdcpu_sel_i(dcpu_sel_o),
    .qmemdcpu_tag_i(dcpu_tag_o), .qmemdcpu_dat_i(dcpu_dat_o),
    .qmemdcpu_dat_o(qmemdcpu_dat_o), .qmemdcpu_ack_o(qmemdcpu_ack_o),
    .qmemdcpu_rty_o(qmemdcpu_rty_o),
    .qmemdmmu_err_o(qmemdmmu_err_o), .qmemdmmu_tag_o(qmemdmmu_tag_o),
    .dcqmem_adr_o(dcqmem_adr_o), .dcqmem_cycstb_o(dcqmem_cycstb_o),
    .dcqmem_ci_o(dcqmem_ci_o), .dcqmem_we_o(dcqmem_we_o),
    .dcqmem_sel_o(dcqmem_sel_o), .dcqmem_tag_o(dcqmem_tag_o), .dcqmem_dat_o(dcqmem_dat_o),
    .dcqmem_dat_i(dcqmem_dat_i), .dcqmem_ack_i(dcqmem_ack_i),
    .dcqmem_rty_i(dcqmem_rty_i), .dcqmem_err_i(dcqmem_err_i), .dcqmem_tag_i(dcqmem_tag_i)
);

// DMMU
or1200_dmmu_top or1200_dmmu_top(
    .clk(clk), .rst(rst),
    .dc_en(dc_en), .dmmu_en(dmmu_en), .supv(supv),
    .dcpu_adr_i(dcpu_adr_o), .dcpu_cycstb_i(dcpu_cycstb_o), .dcpu_we_i(dcpu_we_o),
    .dcpu_tag_o(qmemdmmu_tag_o), .dcpu_err_o(qmemdmmu_err_o),
    .spr_cs(spr_cs[1]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_dmmu),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_dmmu_si), .mbist_so_o(mbist_dmmu_so), .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .qmemdmmu_rty_i(dcqmem_rty_i2), .qmemdmmu_err_i(dcqmem_err_i2),
    .qmemdmmu_tag_i(dcqmem_tag_i2),
    .qmemdmmu_adr_o(qmemdmmu_adr_o),
    .qmemdmmu_cycstb_o(qmemdmmu_cycstb_o),
    .qmemdmmu_ci_o(qmemdmmu_ci_o)
);

// Instruction Cache
or1200_ic_top or1200_ic_top(
    .clk(clk), .rst(rst),
    .icbiu_dat_o(icbiu_dat_o), .icbiu_adr_o(icbiu_adr_o),
    .icbiu_cyc_o(icbiu_cyc_o), .icbiu_stb_o(icbiu_stb_o),
    .icbiu_we_o(icbiu_we_o), .icbiu_sel_o(icbiu_sel_o), .icbiu_cab_o(icbiu_cab_o),
    .icbiu_dat_i(icbiu_dat_i), .icbiu_ack_i(icbiu_ack_i), .icbiu_err_i(icbiu_err_i),
    .ic_en(ic_en),
    .icqmem_adr_i(icqmem_adr_o), .icqmem_cycstb_i(icqmem_cycstb_o),
    .icqmem_ci_i(icqmem_ci_o), .icqmem_sel_i(icqmem_sel_o), .icqmem_tag_i(icqmem_tag_o),
    .icqmem_dat_o(icqmem_dat_i), .icqmem_ack_o(icqmem_ack_i),
    .icqmem_rty_o(icqmem_rty_i), .icqmem_err_o(icqmem_err_i), .icqmem_tag_o(icqmem_tag_i),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_ic_si), .mbist_so_o(mbist_ic_so), .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .spr_cs(spr_cs[4]), .spr_write(spr_we), .spr_dat_i(spr_dat_cpu)
);

// Data Cache
or1200_dc_top or1200_dc_top(
    .clk(clk), .rst(rst),
    .dcsb_dat_o(dcsb_dat_o), .dcsb_adr_o(dcsb_adr_o),
    .dcsb_cyc_o(dcsb_cyc_o), .dcsb_stb_o(dcsb_stb_o),
    .dcsb_we_o(dcsb_we_o), .dcsb_sel_o(dcsb_sel_o), .dcsb_cab_o(dcsb_cab_o),
    .dcsb_dat_i(dcsb_dat_i), .dcsb_ack_i(dcsb_ack_i), .dcsb_err_i(dcsb_err_i),
    .dc_en(dc_en),
    .dcqmem_adr_i(dcqmem_adr_o), .dcqmem_cycstb_i(dcqmem_cycstb_o),
    .dcqmem_ci_i(dcqmem_ci_o), .dcqmem_we_i(dcqmem_we_o),
    .dcqmem_sel_i(dcqmem_sel_o), .dcqmem_tag_i(dcqmem_tag_o), .dcqmem_dat_i(dcqmem_dat_o),
    .dcqmem_dat_o(dcqmem_dat_i), .dcqmem_ack_o(dcqmem_ack_i),
    .dcqmem_rty_o(dcqmem_rty_i), .dcqmem_err_o(dcqmem_err_i), .dcqmem_tag_o(dcqmem_tag_i),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_dc_si), .mbist_so_o(mbist_dc_so), .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .spr_cs(spr_cs[3]), .spr_write(spr_we), .spr_dat_i(spr_dat_cpu)
);

// Store Buffer
or1200_sb or1200_sb(
    .clk(clk), .rst(rst),
    .dcsb_dat_i(dcsb_dat_o), .dcsb_adr_i(dcsb_adr_o),
    .dcsb_cyc_i(dcsb_cyc_o), .dcsb_stb_i(dcsb_stb_o),
    .dcsb_we_i(dcsb_we_o), .dcsb_sel_i(dcsb_sel_o), .dcsb_cab_i(dcsb_cab_o),
    .dcsb_dat_o(dcsb_dat_i), .dcsb_ack_o(dcsb_ack_i), .dcsb_err_o(dcsb_err_i),
    .sbbiu_dat_o(sbbiu_dat_o), .sbbiu_adr_o(sbbiu_adr_o),
    .sbbiu_cyc_o(sbbiu_cyc_o), .sbbiu_stb_o(sbbiu_stb_o),
    .sbbiu_we_o(sbbiu_we_o), .sbbiu_sel_o(sbbiu_sel_o), .sbbiu_cab_o(sbbiu_cab_o),
    .sbbiu_dat_i(sbbiu_dat_i), .sbbiu_ack_i(sbbiu_ack_i), .sbbiu_err_i(sbbiu_err_i)
);

// Instruction Wishbone BIU
or1200_iwb_biu or1200_iwb_biu(
    .clk(clk), .rst(rst), .clmode(clmode_i),
    .wb_clk_i(iwb_clk_i), .wb_rst_i(iwb_rst_i),
    .wb_ack_i(iwb_ack_i), .wb_err_i(iwb_err_i), .wb_rty_i(iwb_rty_i),
    .wb_dat_i(iwb_dat_i),
    .wb_cyc_o(iwb_cyc_o), .wb_adr_o(iwb_adr_o), .wb_stb_o(iwb_stb_o),
    .wb_we_o(iwb_we_o), .wb_sel_o(iwb_sel_o), .wb_dat_o(iwb_dat_o),
`ifdef OR1200_WB_CAB
    .wb_cab_o(iwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .wb_cti_o(iwb_cti_o), .wb_bte_o(iwb_bte_o),
`endif
    .biu_dat_i(icbiu_dat_o), .biu_adr_i(icbiu_adr_o),
    .biu_cyc_i(icbiu_cyc_o), .biu_stb_i(icbiu_stb_o),
    .biu_we_i(icbiu_we_o), .biu_sel_i(icbiu_sel_o), .biu_cab_i(icbiu_cab_o),
    .biu_dat_o(icbiu_dat_i), .biu_ack_o(icbiu_ack_i), .biu_err_o(icbiu_err_i)
);

// Data Wishbone BIU
or1200_wb_biu or1200_wb_biu(
    .clk(clk), .rst(rst), .clmode(clmode_i),
    .wb_clk_i(dwb_clk_i), .wb_rst_i(dwb_rst_i),
    .wb_ack_i(dwb_ack_i), .wb_err_i(dwb_err_i), .wb_rty_i(dwb_rty_i),
    .wb_dat_i(dwb_dat_i),
    .wb_cyc_o(dwb_cyc_o), .wb_adr_o(dwb_adr_o), .wb_stb_o(dwb_stb_o),
    .wb_we_o(dwb_we_o), .wb_sel_o(dwb_sel_o), .wb_dat_o(dwb_dat_o),
`ifdef OR1200_WB_CAB
    .wb_cab_o(dwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .wb_cti_o(dwb_cti_o), .wb_bte_o(dwb_bte_o),
`endif
    .biu_dat_i(sbbiu_dat_o), .biu_adr_i(sbbiu_adr_o),
    .biu_cyc_i(sbbiu_cyc_o), .biu_stb_i(sbbiu_stb_o),
    .biu_we_i(sbbiu_we_o), .biu_sel_i(sbbiu_sel_o), .biu_cab_i(sbbiu_cab_o),
    .biu_dat_o(sbbiu_dat_i), .biu_ack_o(sbbiu_ack_i), .biu_err_o(sbbiu_err_i)
);

// Debug Unit
or1200_du or1200_du(
    .clk(clk), .rst(rst),
    .dcpu_cycstb_i(dcpu_cycstb_o), .dcpu_we_i(dcpu_we_o),
    .dcpu_adr_i(dcpu_adr_o), .dcpu_dat_lsu(dcpu_dat_o), .dcpu_dat_dc(qmemdcpu_dat_o),
    .icpu_cycstb_i(icpu_cycstb_o),
    .ex_freeze(ex_freeze), .branch_op(branch_op),
    .ex_insn(ex_insn), .id_pc(id_pc),
    .spr_dat_npc(spr_dat_npc), .rf_dataw(rf_dataw),
    .du_dsr(du_dsr), .du_stall(du_stall),
    .du_addr(du_addr), .du_dat_i(du_dat_cpu), .du_dat_o(du_dat_du),
    .du_read(du_read), .du_write(du_write),
    .du_except(du_except), .du_hwbkpt(du_hwbkpt),
    .spr_cs(spr_cs[6]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_du),
    .dbg_stall_i(dbg_stall_i), .dbg_ewt_i(dbg_ewt_i),
    .dbg_lss_o(dbg_lss_o), .dbg_is_o(dbg_is_o),
    .dbg_wp_o(dbg_wp_o), .dbg_bp_o(dbg_bp_o),
    .dbg_stb_i(dbg_stb_i), .dbg_we_i(dbg_we_i),
    .dbg_adr_i(dbg_adr_i), .dbg_dat_i(dbg_dat_i),
    .dbg_dat_o(dbg_dat_o), .dbg_ack_o(dbg_ack_o)
);

// PIC
or1200_pic or1200_pic(
    .clk(clk), .rst(rst),
    .spr_cs(spr_cs[9]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_pic),
    .pic_wakeup(pic_wakeup), .intr(sig_int),
    .pic_int(pic_ints_i)
);

// Tick Timer
or1200_tt or1200_tt(
    .clk(clk), .rst(rst),
    .spr_cs(spr_cs[10]), .spr_write(spr_we),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_tt),
    .intr(sig_tick)
);

// Power Management
or1200_pm or1200_pm(
    .clk(clk), .rst(rst),
    .pic_wakeup(pic_wakeup),
    .spr_write(spr_we), .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu), .spr_dat_o(spr_dat_pm),
    .pm_clksd(pm_clksd_o), .pm_cpustall(pm_cpustall_i),
    .pm_dc_gate(pm_dc_gate_o), .pm_ic_gate(pm_ic_gate_o),
    .pm_dmmu_gate(pm_dmmu_gate_o), .pm_immu_gate(pm_immu_gate_o),
    .pm_tt_gate(pm_tt_gate_o), .pm_cpu_gate(pm_cpu_gate_o),
    .pm_wakeup(pm_wakeup_o), .pm_lvolt(pm_lvolt_o)
);

// Unused IMMU/DMMU downstream wires (placeholders for unconnected paths)
wire icqmem_rty_i2 = 1'b0;
wire icqmem_err_i2 = 1'b0;
wire [3:0] icqmem_tag_i2 = 4'h0;
wire dcqmem_rty_i2 = 1'b0;
wire dcqmem_err_i2 = 1'b0;
wire [3:0] dcqmem_tag_i2 = 4'h0;

endmodule