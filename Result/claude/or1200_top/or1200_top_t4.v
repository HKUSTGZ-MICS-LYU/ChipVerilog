// Generated from: Description/or1200_top_description.txt
module or1200_top #(
    parameter integer ppic_ints = 20
) (
    // System
    input         clk_i,
    input         rst_i,
    input  [ppic_ints-1:0] pic_ints_i,
    input  [1:0]  clmode_i,

    // Instruction WISHBONE INTERFACE
    input         iwb_ack_i,
    input         iwb_err_i,
    input         iwb_rty_i,
    input  [31:0] iwb_dat_i,
    output        iwb_cyc_o,
    output [31:0] iwb_adr_o,
    output        iwb_stb_o,
    output        iwb_we_o,
    output [3:0]  iwb_sel_o,
    output [31:0] iwb_dat_o,
`ifdef OR1200_WB_CAB
    output        iwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]  iwb_cti_o,
    output [1:0]  iwb_bte_o,
`endif

    // Data WISHBONE INTERFACE
    input         dwb_ack_i,
    input         dwb_err_i,
    input         dwb_rty_i,
    input  [31:0] dwb_dat_i,
    output        dwb_cyc_o,
    output [31:0] dwb_adr_o,
    output        dwb_stb_o,
    output        dwb_we_o,
    output [3:0]  dwb_sel_o,
    output [31:0] dwb_dat_o,
`ifdef OR1200_WB_CAB
    output        dwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]  dwb_cti_o,
    output [1:0]  dwb_bte_o,
`endif

    // External Debug Interface
    input         dbg_stall_i,
    input         dbg_ewt_i,
    output [3:0]  dbg_lss_o,
    output [1:0]  dbg_is_o,
    output [10:0] dbg_wp_o,
    output        dbg_bp_o,
    input         dbg_stb_i,
    input         dbg_we_i,
    input  [31:0] dbg_adr_i,
    input  [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output        dbg_ack_o,

`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input  [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Power Management
    input         pm_cpustall_i,
    output [3:0]  pm_clksd_o,
    output        pm_dc_gate_o,
    output        pm_ic_gate_o,
    output        pm_dmmu_gate_o,
    output        pm_immu_gate_o,
    output        pm_tt_gate_o,
    output        pm_cpu_gate_o,
    output        pm_wakeup_o,
    output        pm_lvolt_o
);

`include "or1200_defines.v"

  // Internal wiring between CPU and peripherals/BIUs (structural)
  wire ic_en, dc_en, immu_en, dmmu_en, supv;
  wire [31:0] icpu_adr_o, dcpu_adr_o;
  wire icpu_cycstb_o, dcpu_cycstb_o;
  wire dcpu_we_o;
  wire [3:0] icpu_sel_o, dcpu_sel_o;
  wire [3:0] icpu_tag_o, dcpu_tag_o;
  wire [31:0] dcpu_dat_o;

  // Debug internal interface
  wire du_stall;
  wire [31:0] du_addr;
  wire [31:0] du_dat_du;
  wire du_read, du_write;
  wire [13:0] du_dsr;
  wire du_hwbkpt;
  wire [12:0] du_except;
  wire [31:0] du_dat_cpu;

  // SPR bus
  wire [31:0] spr_addr;
  wire [31:0] spr_dat_cpu;
  wire [31:0] spr_cs;
  wire spr_we;

  // SPR return data buses from units
  wire [31:0] spr_dat_pic, spr_dat_tt, spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du;

  // PIC/TT signals
  wire sig_int, sig_tick;
  wire pic_wakeup;

  // CPU instantiation
  wire [31:0] ex_insn, id_pc, spr_dat_npc, rf_dataw;
  wire ex_freeze;
  wire [2:0] branch_op;
  or1200_cpu u_cpu(
    .clk(clk_i),
    .rst(rst_i),
    .ic_en(ic_en),
    .icpu_adr_o(icpu_adr_o),
    .icpu_cycstb_o(icpu_cycstb_o),
    .icpu_sel_o(icpu_sel_o),
    .icpu_tag_o(icpu_tag_o),
    .icpu_dat_i(iwb_dat_i),
    .icpu_ack_i(iwb_ack_i),
    .icpu_rty_i(iwb_rty_i),
    .icpu_err_i(iwb_err_i),
    .icpu_adr_i(iwb_adr_o),
    .icpu_tag_i(4'd0),
    .immu_en(immu_en),
    .ex_insn(ex_insn),
    .ex_freeze(ex_freeze),
    .id_pc(id_pc),
    .branch_op(branch_op),
    .spr_dat_npc(spr_dat_npc),
    .rf_dataw(rf_dataw),
    .du_stall(du_stall),
    .du_addr(du_addr),
    .du_dat_du(du_dat_du),
    .du_read(du_read),
    .du_write(du_write),
    .du_dsr(du_dsr),
    .du_hwbkpt(du_hwbkpt),
    .du_except(du_except),
    .du_dat_cpu(du_dat_cpu),
    .dc_en(dc_en),
    .dcpu_adr_o(dcpu_adr_o),
    .dcpu_cycstb_o(dcpu_cycstb_o),
    .dcpu_we_o(dcpu_we_o),
    .dcpu_sel_o(dcpu_sel_o),
    .dcpu_tag_o(dcpu_tag_o),
    .dcpu_dat_o(dcpu_dat_o),
    .dcpu_dat_i(dwb_dat_i),
    .dcpu_ack_i(dwb_ack_i),
    .dcpu_rty_i(dwb_rty_i),
    .dcpu_err_i(dwb_err_i),
    .dcpu_tag_i(4'd0),
    .dmmu_en(dmmu_en),
    .sig_int(sig_int),
    .sig_tick(sig_tick),
    .supv(supv),
    .spr_addr(spr_addr),
    .spr_dat_cpu(spr_dat_cpu),
    .spr_dat_pic(spr_dat_pic),
    .spr_dat_tt(spr_dat_tt),
    .spr_dat_pm(spr_dat_pm),
    .spr_dat_dmmu(spr_dat_dmmu),
    .spr_dat_immu(spr_dat_immu),
    .spr_dat_du(spr_dat_du),
    .spr_cs(spr_cs),
    .spr_we(spr_we)
  );

  // Debug unit instantiation
  or1200_du u_du(
    .clk(clk_i),
    .rst(rst_i),
    .dcpu_cycstb_i(dcpu_cycstb_o),
    .dcpu_we_i(dcpu_we_o),
    .dcpu_adr_i(dcpu_adr_o),
    .dcpu_dat_lsu(dcpu_dat_o),
    .dcpu_dat_dc(dwb_dat_i),
    .icpu_cycstb_i(icpu_cycstb_o),
    .ex_freeze(ex_freeze),
    .branch_op(branch_op),
    .ex_insn(ex_insn),
    .id_pc(id_pc),
    .spr_dat_npc(spr_dat_npc),
    .rf_dataw(rf_dataw),
    .du_dsr(du_dsr),
    .du_stall(du_stall),
    .du_addr(du_addr),
    .du_dat_i(du_dat_cpu),
    .du_dat_o(du_dat_du),
    .du_read(du_read),
    .du_write(du_write),
    .du_except(du_except),
    .du_hwbkpt(du_hwbkpt),
    .spr_cs(spr_cs[`OR1200_SPR_GROUP_DU]),
    .spr_write(spr_we),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_du),
    .dbg_stall_i(dbg_stall_i),
    .dbg_ewt_i(dbg_ewt_i),
    .dbg_lss_o(dbg_lss_o),
    .dbg_is_o(dbg_is_o),
    .dbg_wp_o(dbg_wp_o),
    .dbg_bp_o(dbg_bp_o),
    .dbg_stb_i(dbg_stb_i),
    .dbg_we_i(dbg_we_i),
    .dbg_adr_i(dbg_adr_i),
    .dbg_dat_i(dbg_dat_i),
    .dbg_dat_o(dbg_dat_o),
    .dbg_ack_o(dbg_ack_o)
  );

  // PIC
  or1200_pic u_pic(
    .clk(clk_i),
    .rst(rst_i),
    .spr_cs(spr_cs[`OR1200_SPR_GROUP_PIC]),
    .spr_write(spr_we),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pic),
    .pic_wakeup(pic_wakeup),
    .intr(sig_int),
    .pic_int(pic_ints_i[19:0])
  );

  // Tick timer
  or1200_tt u_tt(
    .clk(clk_i),
    .rst(rst_i),
    .du_stall(du_stall),
    .spr_cs(spr_cs[`OR1200_SPR_GROUP_TT]),
    .spr_write(spr_we),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_tt),
    .intr(sig_tick)
  );

  // Power management
  or1200_pm u_pm(
    .clk(clk_i),
    .rst(rst_i),
    .spr_write(spr_we),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pm),
    .pic_wakeup(pic_wakeup),
    .pm_cpustall(pm_cpustall_i),
    .pm_clksd(pm_clksd_o),
    .pm_dc_gate(pm_dc_gate_o),
    .pm_ic_gate(pm_ic_gate_o),
    .pm_dmmu_gate(pm_dmmu_gate_o),
    .pm_immu_gate(pm_immu_gate_o),
    .pm_tt_gate(pm_tt_gate_o),
    .pm_cpu_gate(pm_cpu_gate_o),
    .pm_wakeup(pm_wakeup_o),
    .pm_lvolt(pm_lvolt_o)
  );

  // BIUs: connect CPU internal buses directly as BIU requests.
  // Instruction: use iwb_biu to drive external iwb_*.
  or1200_iwb_biu u_iwb(
    .clk(clk_i),
    .rst(rst_i),
    .clmode(clmode_i),
    .wb_clk_i(clk_i),
    .wb_rst_i(rst_i),
    .wb_ack_i(iwb_ack_i),
    .wb_err_i(iwb_err_i),
    .wb_rty_i(iwb_rty_i),
    .wb_dat_i(iwb_dat_i),
    .wb_cyc_o(iwb_cyc_o),
    .wb_adr_o(iwb_adr_o),
    .wb_stb_o(iwb_stb_o),
    .wb_we_o(iwb_we_o),
    .wb_sel_o(iwb_sel_o),
    .wb_dat_o(iwb_dat_o),
`ifdef OR1200_WB_CAB
    .wb_cab_o(iwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .wb_cti_o(iwb_cti_o),
    .wb_bte_o(iwb_bte_o),
`endif
    .biu_dat_i(32'd0),
    .biu_adr_i(icpu_adr_o),
    .biu_cyc_i(icpu_cycstb_o),
    .biu_stb_i(icpu_cycstb_o),
    .biu_we_i(1'b0),
    .biu_sel_i(icpu_sel_o),
    .biu_cab_i(1'b0),
    .biu_dat_o(),
    .biu_ack_o(),
    .biu_err_o()
  );

  // Data: wb_biu to drive external dwb_*
  or1200_wb_biu u_dwb(
    .clk(clk_i),
    .rst(rst_i),
    .clmode(clmode_i),
    .wb_clk_i(clk_i),
    .wb_rst_i(rst_i),
    .wb_ack_i(dwb_ack_i),
    .wb_err_i(dwb_err_i),
    .wb_rty_i(dwb_rty_i),
    .wb_dat_i(dwb_dat_i),
    .wb_cyc_o(dwb_cyc_o),
    .wb_adr_o(dwb_adr_o),
    .wb_stb_o(dwb_stb_o),
    .wb_we_o(dwb_we_o),
    .wb_sel_o(dwb_sel_o),
    .wb_dat_o(dwb_dat_o),
`ifdef OR1200_WB_CAB
    .wb_cab_o(dwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .wb_cti_o(dwb_cti_o),
    .wb_bte_o(dwb_bte_o),
`endif
    .biu_dat_i(dcpu_dat_o),
    .biu_adr_i(dcpu_adr_o),
    .biu_cyc_i(dcpu_cycstb_o),
    .biu_stb_i(dcpu_cycstb_o),
    .biu_we_i(dcpu_we_o),
    .biu_sel_i(dcpu_sel_o),
    .biu_cab_i(1'b0),
    .biu_dat_o(),
    .biu_ack_o(),
    .biu_err_o()
  );

  // Unimplemented blocks in this top wrapper: tie their SPR readbacks to zero.
  assign spr_dat_dmmu = 32'd0;
  assign spr_dat_immu = 32'd0;

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i;
  wire _mbist_unused = ^mbist_ctrl_i;
`endif

endmodule

