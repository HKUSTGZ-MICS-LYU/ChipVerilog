`timescale 1ns / 1ps

module or1200_top
#(
    parameter PPIC_INTS = 32
)
(
    // System
    input clk_i,
    input rst_i,
    input [PPIC_INTS-1:0] pic_ints_i,
    input [1:0] clmode_i,

    // Instruction WISHBONE INTERFACE
    input iwb_ack_i,
    input iwb_err_i,
    input iwb_rty_i,
    input [31:0] iwb_dat_i,
    output iwb_cyc_o,
    output [31:0] iwb_adr_o,
    output iwb_stb_o,
    output iwb_we_o,
    output [3:0] iwb_sel_o,
    output [31:0] iwb_dat_o,
`ifdef OR1200_WB_CAB
    output iwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] iwb_cti_o,
    output [1:0] iwb_bte_o,
`endif

    // Data WISHBONE INTERFACE
    input dwb_ack_i,
    input dwb_err_i,
    input dwb_rty_i,
    input [31:0] dwb_dat_i,
    output dwb_cyc_o,
    output [31:0] dwb_adr_o,
    output dwb_stb_o,
    output dwb_we_o,
    output [3:0] dwb_sel_o,
    output [31:0] dwb_dat_o,
`ifdef OR1200_WB_CAB
    output dwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] dwb_cti_o,
    output [1:0] dwb_bte_o,
`endif

    // External Debug Interface
    input dbg_stall_i,
    input dbg_ewt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Power Management
    input pm_cpustall_i,
    output [3:0] pm_clksd_o,
    output pm_dc_gate_o,
    output pm_ic_gate_o,
    output pm_dmmu_gate_o,
    output pm_immu_gate_o,
    output pm_tt_gate_o,
    output pm_cpu_gate_o,
    output pm_wakeup_o,
    output pm_lvolt_o
);

//---------------------------------------------------------------------------
// Internal wire declarations
//---------------------------------------------------------------------------
// SPR bus from CPU
wire [31:0] spr_addr;
wire [31:0] spr_dat_cpu;
wire spr_we;
wire [31:0] spr_cs;

// SPR data returns from various modules
wire [31:0] spr_dat_immu;
wire [31:0] spr_dat_dmmu;
wire [31:0] spr_dat_ic;
wire [31:0] spr_dat_dc;
wire [31:0] spr_dat_du;
wire [31:0] spr_dat_pic;
wire [31:0] spr_dat_tt;
wire [31:0] spr_dat_pm;

// SPR chip selects (decoded)
wire spr_cs_immu;
wire spr_cs_dmmu;
wire spr_cs_ic;
wire spr_cs_dc;
wire spr_cs_du;
wire spr_cs_pic;
wire spr_cs_tt;

assign spr_cs_immu = spr_cs[2];
assign spr_cs_dmmu = spr_cs[1];
assign spr_cs_ic   = spr_cs[4];
assign spr_cs_dc   = spr_cs[3];
assign spr_cs_du   = spr_cs[6];
assign spr_cs_pic  = spr_cs[9];
assign spr_cs_tt   = spr_cs[10];

// CPU instruction-side interface to IMMU/IC/QMEM
wire [31:0] ic_addr;
wire        ic_en;
wire [3:0]  ic_sel;
wire [3:0]  ic_tag;
wire [31:0] ic_dat_o;
wire [31:0] ic_dat_i;
wire        ic_ack;
wire        ic_err;
wire        ic_rty;

// CPU data-side interface to DMMU/DC/QMEM
wire [31:0] dc_addr;
wire        dc_we;
wire [3:0]  dc_sel;
wire [3:0]  dc_tag;
wire [31:0] dc_dat_o;
wire [31:0] dc_dat_i;
wire        dc_ack;
wire        dc_err;
wire        dc_rty;

// IMMU internal connections to IC side
wire [31:0] immu_ic_addr;
wire        immu_ic_en;
wire [3:0]  immu_ic_sel;
wire [3:0]  immu_ic_tag;
wire [31:0] immu_ic_dat;
wire        immu_ic_ack;
wire        immu_ic_err;
wire        immu_ic_rty;
wire        immu_except;
wire        immu_retry;

// DMMU internal connections to DC side
wire [31:0] dmmu_dc_addr;
wire        dmmu_dc_we;
wire [3:0]  dmmu_dc_sel;
wire [3:0]  dmmu_dc_tag;
wire [31:0] dmmu_dc_dat;
wire        dmmu_dc_ack;
wire        dmmu_dc_err;
wire        dmmu_dc_rty;
wire        dmmu_except;
wire        dmmu_retry;

// QMEM instruction side (between IMMU and IC)
wire [31:0] qmem_ic_addr;
wire        qmem_ic_en;
wire [3:0]  qmem_ic_sel;
wire [3:0]  qmem_ic_tag;
wire [31:0] qmem_ic_dat_o;
wire [31:0] qmem_ic_dat_i;
wire        qmem_ic_ack;
wire        qmem_ic_err;
wire        qmem_ic_rty;

// QMEM data side (between DMMU and DC)
wire [31:0] qmem_dc_addr;
wire        qmem_dc_we;
wire [3:0]  qmem_dc_sel;
wire [3:0]  qmem_dc_tag;
wire [31:0] qmem_dc_dat_o;
wire [31:0] qmem_dc_dat_i;
wire        qmem_dc_ack;
wire        qmem_dc_err;
wire        qmem_dc_rty;

// IC to IWB BIU signals
wire [31:0] iwb_biu_addr;
wire [31:0] iwb_biu_dat_o;
wire [31:0] iwb_biu_dat_i;
wire        iwb_biu_cyc;
wire        iwb_biu_stb;
wire        iwb_biu_we;
wire [3:0]  iwb_biu_sel;
wire        iwb_biu_ack;
wire        iwb_biu_err;
wire        iwb_biu_rty;
`ifdef OR1200_WB_CAB
wire        iwb_biu_cab;
`endif
`ifdef OR1200_WB_B3
wire [2:0]  iwb_biu_cti;
wire [1:0]  iwb_biu_bte;
`endif

// DC to Store Buffer signals
wire [31:0] dc_sb_addr;
wire [31:0] dc_sb_dat_o;
wire [31:0] dc_sb_dat_i;
wire        dc_sb_cyc;
wire        dc_sb_stb;
wire        dc_sb_we;
wire [3:0]  dc_sb_sel;
wire        dc_sb_ack;
wire        dc_sb_err;
wire        dc_sb_rty;

// Store Buffer to DWB BIU signals
wire [31:0] sb_dwb_addr;
wire [31:0] sb_dwb_dat_o;
wire [31:0] sb_dwb_dat_i;
wire        sb_dwb_cyc;
wire        sb_dwb_stb;
wire        sb_dwb_we;
wire [3:0]  sb_dwb_sel;
wire        sb_dwb_ack;
wire        sb_dwb_err;
wire        sb_dwb_rty;
`ifdef OR1200_WB_CAB
wire        sb_dwb_cab;
`endif
`ifdef OR1200_WB_B3
wire [2:0]  sb_dwb_cti;
wire [1:0]  sb_dwb_bte;
`endif

// Debug Unit internal signals
wire        du_stall;
wire [31:0] du_addr;
wire [31:0] du_dat_du;
wire        du_read;
wire        du_write;
wire        du_except;
wire        du_hwbkpt;
wire [3:0]  du_dbg_lss;
wire [1:0]  du_dbg_is;
wire [10:0] du_dbg_wp;
wire        du_dbg_bp;
wire [31:0] du_dbg_dat;
wire        du_dbg_ack;

// PIC internal signals
wire        sig_int;
wire        pic_wakeup;

// Tick Timer internal signals
wire        sig_tick;

// Power Management internal signals
wire [3:0]  pm_clksd;
wire        pm_dc_gate;
wire        pm_ic_gate;
wire        pm_dmmu_gate;
wire        pm_immu_gate;
wire        pm_tt_gate;
wire        pm_cpu_gate;
wire        pm_wakeup;
wire        pm_lvolt;

`ifdef OR1200_BIST
// MBIST chain wires
wire mbist_si_immu;
wire mbist_so_immu;
wire mbist_si_ic;
wire mbist_so_ic;
wire mbist_si_qmem;
wire mbist_so_qmem;
wire mbist_si_dmmu;
wire mbist_so_dmmu;
wire mbist_si_dc;
wire mbist_so_dc;

assign mbist_si_immu = mbist_si_i;
assign mbist_so_o = mbist_so_dc;
`endif

//---------------------------------------------------------------------------
// CPU core instantiation
//---------------------------------------------------------------------------
or1200_cpu cpu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // SPR interface
    .spr_addr(spr_addr),
    .spr_dat_cpu(spr_dat_cpu),
    .spr_we(spr_we),
    .spr_cs(spr_cs),
    .spr_dat_immu(spr_dat_immu),
    .spr_dat_dmmu(spr_dat_dmmu),
    .spr_dat_ic(spr_dat_ic),
    .spr_dat_dc(spr_dat_dc),
    .spr_dat_du(spr_dat_du),
    .spr_dat_pic(spr_dat_pic),
    .spr_dat_tt(spr_dat_tt),
    .spr_dat_pm(spr_dat_pm),
    // Instruction side to IMMU/IC
    .ic_addr(ic_addr),
    .ic_en(ic_en),
    .ic_sel(ic_sel),
    .ic_tag(ic_tag),
    .ic_dat_o(ic_dat_o),
    .ic_dat_i(ic_dat_i),
    .ic_ack(ic_ack),
    .ic_err(ic_err),
    .ic_rty(ic_rty),
    // Data side to DMMU/DC
    .dc_addr(dc_addr),
    .dc_we(dc_we),
    .dc_sel(dc_sel),
    .dc_tag(dc_tag),
    .dc_dat_o(dc_dat_o),
    .dc_dat_i(dc_dat_i),
    .dc_ack(dc_ack),
    .dc_err(dc_err),
    .dc_rty(dc_rty),
    // Debug interface
    .du_stall(du_stall),
    .du_addr(du_addr),
    .du_dat_du(du_dat_du),
    .du_read(du_read),
    .du_write(du_write),
    .du_except(du_except),
    .du_hwbkpt(du_hwbkpt),
    // Interrupts
    .sig_int(sig_int),
    .sig_tick(sig_tick),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// IMMU instantiation
//---------------------------------------------------------------------------
or1200_immu immu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // CPU interface
    .cpu_addr(ic_addr),
    .cpu_en(ic_en),
    .cpu_sel(ic_sel),
    .cpu_tag(ic_tag),
    .cpu_dat_i(ic_dat_i),   // from CPU to IMMU
    .cpu_dat_o(ic_dat_o),   // to CPU from IMMU
    .cpu_ack(ic_ack),
    .cpu_err(ic_err),
    .cpu_rty(ic_rty),
    // QMEM/IC interface
    .qmem_addr(imm_ic_addr),
    .qmem_en(imm_ic_en),
    .qmem_sel(imm_ic_sel),
    .qmem_tag(imm_ic_tag),
    .qmem_dat_o(imm_ic_dat), // to QMEM
    .qmem_ack(imm_ic_ack),
    .qmem_err(imm_ic_err),
    .qmem_rty(imm_ic_rty),
    .except(immu_except),
    .retry(immu_retry),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_immu),
    .spr_we(spr_we),
    .spr_cs(spr_cs_immu),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_immu),
    .mbist_so_o(mbist_so_immu),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// DMMU instantiation
//---------------------------------------------------------------------------
or1200_dmmu dmmu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // CPU interface
    .cpu_addr(dc_addr),
    .cpu_we(dc_we),
    .cpu_sel(dc_sel),
    .cpu_tag(dc_tag),
    .cpu_dat_o(dc_dat_o),
    .cpu_dat_i(dc_dat_i),
    .cpu_ack(dc_ack),
    .cpu_err(dc_err),
    .cpu_rty(dc_rty),
    // QMEM/DC interface
    .qmem_addr(dmmu_dc_addr),
    .qmem_we(dmmu_dc_we),
    .qmem_sel(dmmu_dc_sel),
    .qmem_tag(dmmu_dc_tag),
    .qmem_dat_o(dmmu_dc_dat),
    .qmem_ack(dmmu_dc_ack),
    .qmem_err(dmmu_dc_err),
    .qmem_rty(dmmu_dc_rty),
    .except(dmmu_except),
    .retry(dmmu_retry),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dmmu),
    .spr_we(spr_we),
    .spr_cs(spr_cs_dmmu),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_dmmu),
    .mbist_so_o(mbist_so_dmmu),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// QMEM (Instruction side)
//---------------------------------------------------------------------------
or1200_qmem i_qmem (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // IMMU side
    .immu_addr(imm_ic_addr),
    .immu_en(imm_ic_en),
    .immu_sel(imm_ic_sel),
    .immu_tag(imm_ic_tag),
    .immu_dat_o(imm_ic_dat),
    .immu_ack(imm_ic_ack),
    .immu_err(imm_ic_err),
    .immu_rty(imm_ic_rty),
    // IC side
    .ic_addr(qmem_ic_addr),
    .ic_en(qmem_ic_en),
    .ic_sel(qmem_ic_sel),
    .ic_tag(qmem_ic_tag),
    .ic_dat_o(ic_dat_i),
    .ic_dat_i(qmem_ic_dat_o),   // data from IC to qmem
    .ic_ack(qmem_ic_ack),
    .ic_err(qmem_ic_err),
    .ic_rty(qmem_ic_rty),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_qmem),
    .mbist_so_o(mbist_so_qmem),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// QMEM (Data side)
//---------------------------------------------------------------------------
or1200_qmem d_qmem (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // DMMU side
    .immu_addr(dmmu_dc_addr),
    .immu_we(dmmu_dc_we),
    .immu_sel(dmmu_dc_sel),
    .immu_tag(dmmu_dc_tag),
    .immu_dat_o(dmmu_dc_dat),
    .immu_ack(dmmu_dc_ack),
    .immu_err(dmmu_dc_err),
    .immu_rty(dmmu_dc_rty),
    // DC side
    .ic_addr(qmem_dc_addr),
    .ic_we(qmem_dc_we),
    .ic_sel(qmem_dc_sel),
    .ic_tag(qmem_dc_tag),
    .ic_dat_o(dc_dat_i),       // data from DC to qmem
    .ic_dat_i(qmem_dc_dat_o),  // data from qmem to DC
    .ic_ack(qmem_dc_ack),
    .ic_err(qmem_dc_err),
    .ic_rty(qmem_dc_rty),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_qmem), // chained
    .mbist_so_o(mbist_so_qmem),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// Instruction Cache (IC)
//---------------------------------------------------------------------------
or1200_ic ic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // QMEM / IMMU side
    .qmem_addr(qmem_ic_addr),
    .qmem_en(qmem_ic_en),
    .qmem_sel(qmem_ic_sel),
    .qmem_tag(qmem_ic_tag),
    .qmem_dat_o(qmem_ic_dat_o),   // to QMEM
    .qmem_dat_i(qmem_ic_dat_i),
    .qmem_ack(qmem_ic_ack),
    .qmem_err(qmem_ic_err),
    .qmem_rty(qmem_ic_rty),
    // IWB BIU side
    .iwb_addr(iwb_biu_addr),
    .iwb_dat_o(iwb_biu_dat_o),
    .iwb_dat_i(iwb_biu_dat_i),
    .iwb_cyc(iwb_biu_cyc),
    .iwb_stb(iwb_biu_stb),
    .iwb_we(iwb_biu_we),
    .iwb_sel(iwb_biu_sel),
    .iwb_ack(iwb_biu_ack),
    .iwb_err(iwb_biu_err),
    .iwb_rty(iwb_biu_rty),
`ifdef OR1200_WB_CAB
    .iwb_cab(iwb_biu_cab),
`endif
`ifdef OR1200_WB_B3
    .iwb_cti(iwb_biu_cti),
    .iwb_bte(iwb_biu_bte),
`endif
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_ic),
    .spr_we(spr_we),
    .spr_cs(spr_cs_ic),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_ic),
    .mbist_so_o(mbist_so_ic),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// Data Cache (DC)
//---------------------------------------------------------------------------
or1200_dc dc (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // QMEM / DMMU side
    .qmem_addr(qmem_dc_addr),
    .qmem_we(qmem_dc_we),
    .qmem_sel(qmem_dc_sel),
    .qmem_tag(qmem_dc_tag),
    .qmem_dat_o(qmem_dc_dat_o),   // to QMEM
    .qmem_dat_i(qmem_dc_dat_i),
    .qmem_ack(qmem_dc_ack),
    .qmem_err(qmem_dc_err),
    .qmem_rty(qmem_dc_rty),
    // Store Buffer side
    .sb_addr(dc_sb_addr),
    .sb_dat_o(dc_sb_dat_o),
    .sb_dat_i(dc_sb_dat_i),
    .sb_cyc(dc_sb_cyc),
    .sb_stb(dc_sb_stb),
    .sb_we(dc_sb_we),
    .sb_sel(dc_sb_sel),
    .sb_ack(dc_sb_ack),
    .sb_err(dc_sb_err),
    .sb_rty(dc_sb_rty),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dc),
    .spr_we(spr_we),
    .spr_cs(spr_cs_dc),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_dc),
    .mbist_so_o(mbist_so_dc),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .*
);

//---------------------------------------------------------------------------
// Store Buffer
//---------------------------------------------------------------------------
or1200_sb sb (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // DC side
    .dc_addr(dc_sb_addr),
    .dc_dat_o(dc_sb_dat_o),
    .dc_dat_i(dc_sb_dat_i),
    .dc_cyc(dc_sb_cyc),
    .dc_stb(dc_sb_stb),
    .dc_we(dc_sb_we),
    .dc_sel(dc_sb_sel),
    .dc_ack(dc_sb_ack),
    .dc_err(dc_sb_err),
    .dc_rty(dc_sb_rty),
    // DWB BIU side
    .dwb_addr(sb_dwb_addr),
    .dwb_dat_o(sb_dwb_dat_o),
    .dwb_dat_i(sb_dwb_dat_i),
    .dwb_cyc(sb_dwb_cyc),
    .dwb_stb(sb_dwb_stb),
    .dwb_we(sb_dwb_we),
    .dwb_sel(sb_dwb_sel),
    .dwb_ack(sb_dwb_ack),
    .dwb_err(sb_dwb_err),
    .dwb_rty(sb_dwb_rty),
`ifdef OR1200_WB_CAB
    .dwb_cab(sb_dwb_cab),
`endif
`ifdef OR1200_WB_B3
    .dwb_cti(sb_dwb_cti),
    .dwb_bte(sb_dwb_bte),
`endif
    .*
);

//---------------------------------------------------------------------------
// Instruction Wishbone BIU
//---------------------------------------------------------------------------
or1200_iwb_biu iwb_biu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .clmode_i(clmode_i),
    // IC side
    .ic_addr(iwb_biu_addr),
    .ic_dat_o(iwb_biu_dat_o),
    .ic_dat_i(iwb_biu_dat_i),
    .ic_cyc(iwb_biu_cyc),
    .ic_stb(iwb_biu_stb),
    .ic_we(iwb_biu_we),
    .ic_sel(iwb_biu_sel),
    .ic_ack(iwb_biu_ack),
    .ic_err(iwb_biu_err),
    .ic_rty(iwb_biu_rty),
`ifdef OR1200_WB_CAB
    .ic_cab(iwb_biu_cab),
`endif
`ifdef OR1200_WB_B3
    .ic_cti(iwb_biu_cti),
    .ic_bte(iwb_biu_bte),
`endif
    // External IWB ports
    .iwb_ack_i(iwb_ack_i),
    .iwb_err_i(iwb_err_i),
    .iwb_rty_i(iwb_rty_i),
    .iwb_dat_i(iwb_dat_i),
    .iwb_cyc_o(iwb_cyc_o),
    .iwb_adr_o(iwb_adr_o),
    .iwb_stb_o(iwb_stb_o),
    .iwb_we_o(iwb_we_o),
    .iwb_sel_o(iwb_sel_o),
    .iwb_dat_o(iwb_dat_o),
`ifdef OR1200_WB_CAB
    .iwb_cab_o(iwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .iwb_cti_o(iwb_cti_o),
    .iwb_bte_o(iwb_bte_o),
`endif
    .*
);

//---------------------------------------------------------------------------
// Data Wishbone BIU
//---------------------------------------------------------------------------
or1200_dwb_biu dwb_biu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .clmode_i(clmode_i),
    // Store Buffer side
    .sb_addr(sb_dwb_addr),
    .sb_dat_o(sb_dwb_dat_o),
    .sb_dat_i(sb_dwb_dat_i),
    .sb_cyc(sb_dwb_cyc),
    .sb_stb(sb_dwb_stb),
    .sb_we(sb_dwb_we),
    .sb_sel(sb_dwb_sel),
    .sb_ack(sb_dwb_ack),
    .sb_err(sb_dwb_err),
    .sb_rty(sb_dwb_rty),
`ifdef OR1200_WB_CAB
    .sb_cab(sb_dwb_cab),
`endif
`ifdef OR1200_WB_B3
    .sb_cti(sb_dwb_cti),
    .sb_bte(sb_dwb_bte),
`endif
    // External DWB ports
    .dwb_ack_i(dwb_ack_i),
    .dwb_err_i(dwb_err_i),
    .dwb_rty_i(dwb_rty_i),
    .dwb_dat_i(dwb_dat_i),
    .dwb_cyc_o(dwb_cyc_o),
    .dwb_adr_o(dwb_adr_o),
    .dwb_stb_o(dwb_stb_o),
    .dwb_we_o(dwb_we_o),
    .dwb_sel_o(dwb_sel_o),
    .dwb_dat_o(dwb_dat_o),
`ifdef OR1200_WB_CAB
    .dwb_cab_o(dwb_cab_o),
`endif
`ifdef OR1200_WB_B3
    .dwb_cti_o(dwb_cti_o),
    .dwb_bte_o(dwb_bte_o),
`endif
    .*
);

//---------------------------------------------------------------------------
// Debug Unit
//---------------------------------------------------------------------------
or1200_du du (
    .clk_i(clk_i),
    .rst_i(rst_i),
    // External DBG interface
    .dbg_stall_i(dbg_stall_i),
    .dbg_ewt_i(dbg_ewt_i),
    .dbg_stb_i(dbg_stb_i),
    .dbg_we_i(dbg_we_i),
    .dbg_adr_i(dbg_adr_i),
    .dbg_dat_i(dbg_dat_i),
    .dbg_dat_o(du_dbg_dat),
    .dbg_ack_o(du_dbg_ack),
    .dbg_lss_o(du_dbg_lss),
    .dbg_is_o(du_dbg_is),
    .dbg_wp_o(du_dbg_wp),
    .dbg_bp_o(du_dbg_bp),
    // CPU internal debug interface
    .du_stall(du_stall),
    .du_addr(du_addr),
    .du_dat_du(du_dat_du),
    .du_read(du_read),
    .du_write(du_write),
    .du_except(du_except),
    .du_hwbkpt(du_hwbkpt),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_du),
    .spr_we(spr_we),
    .spr_cs(spr_cs_du),
    .*
);

assign dbg_dat_o = du_dbg_dat;
assign dbg_ack_o = du_dbg_ack;
assign dbg_lss_o = du_dbg_lss;
assign dbg_is_o  = du_dbg_is;
assign dbg_wp_o  = du_dbg_wp;
assign dbg_bp_o  = du_dbg_bp;

//---------------------------------------------------------------------------
// Programmable Interrupt Controller
//---------------------------------------------------------------------------
or1200_pic pic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pic_ints_i(pic_ints_i),
    .sig_int(sig_int),
    .pic_wakeup(pic_wakeup),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pic),
    .spr_we(spr_we),
    .spr_cs(spr_cs_pic),
    .*
);

//---------------------------------------------------------------------------
// Tick Timer
//---------------------------------------------------------------------------
or1200_tt tt (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .sig_tick(sig_tick),
    // SPR
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_tt),
    .spr_we(spr_we),
    .spr_cs(spr_cs_tt),
    .*
);

//---------------------------------------------------------------------------
// Power Management Unit
//---------------------------------------------------------------------------
or1200_pm pm (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pm_cpustall_i(pm_cpustall_i),
    .pic_wakeup(pic_wakeup),
    .pm_clksd_o(pm_clksd),
    .pm_dc_gate_o(pm_dc_gate),
    .pm_ic_gate_o(pm_ic_gate),
    .pm_dmmu_gate_o(pm_dmmu_gate),
    .pm_immu_gate_o(pm_immu_gate),
    .pm_tt_gate_o(pm_tt_gate),
    .pm_cpu_gate_o(pm_cpu_gate),
    .pm_wakeup_o(pm_wakeup),
    .pm_lvolt_o(pm_lvolt),
    // SPR interface (no spr_cs group select)
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pm),
    .spr_we(spr_we),
    .*
);

assign pm_clksd_o   = pm_clksd;
assign pm_dc_gate_o = pm_dc_gate;
assign pm_ic_gate_o = pm_ic_gate;
assign pm_dmmu_gate_o = pm_dmmu_gate;
assign pm_immu_gate_o = pm_immu_gate;
assign pm_tt_gate_o = pm_tt_gate;
assign pm_cpu_gate_o = pm_cpu_gate;
assign pm_wakeup_o  = pm_wakeup;
assign pm_lvolt_o   = pm_lvolt;

endmodule
