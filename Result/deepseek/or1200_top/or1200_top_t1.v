// or1200_top.v
// Top-level integration of the OR1200 processor system
module or1200_top(
    // System
    input clk_i,
    input rst_i,
    input [31:0] pic_ints_i,
    input [1:0] clmode_i,

    // Instruction WISHBONE INTERFACE
    //iwb_clk_i, iwb_rst_i,
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
    //dwb_clk_i, dwb_rst_i,
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
    input [3:0] mbist_ctrl_i,
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

// Internal signals
// CPU Instruction-side interface
wire [31:0] icpu_adr_o;
wire [31:0] icpu_dat_i;
wire icpu_cycstb_o;
wire icpu_ack_i;
wire icpu_err_i;
wire icpu_rty_i;
wire [31:0] icpu_tag_o;
wire [3:0] icpu_sel_o;

// CPU Data-side interface
wire [31:0] dcpu_adr_o;
wire [31:0] dcpu_dat_o;
wire [31:0] dcpu_dat_i;
wire dcpu_cycstb_o;
wire dcpu_ack_i;
wire dcpu_err_i;
wire dcpu_rty_i;
wire dcpu_we_o;
wire [3:0] dcpu_sel_o;
wire [31:0] dcpu_tag_o;

// SPR bus
wire [31:0] spr_addr;
wire [31:0] spr_dat_cpu;
wire spr_we;
wire [31:0] spr_cs;
wire [31:0] spr_dat_immu;
wire [31:0] spr_dat_dmmu;
wire [31:0] spr_dat_ic;
wire [31:0] spr_dat_dc;
wire [31:0] spr_dat_du;
wire [31:0] spr_dat_pic;
wire [31:0] spr_dat_tt;
wire [31:0] spr_dat_pm;

// IMMU signals
wire immu_en;
wire [31:0] immu_adr_i;
wire [31:0] immu_adr_o;

// DMMU signals
wire dmmu_en;
wire [31:0] dmmu_adr_i;
wire [31:0] dmmu_adr_o;

// QMEM signals
wire [31:0] qm_ic_adr;
wire [31:0] qm_ic_dat;
wire qm_ic_cycstb;
wire qm_ic_ack;
wire qm_ic_err;
wire qm_ic_rty;
wire [31:0] qm_ic_tag;
wire [3:0] qm_ic_sel;

wire [31:0] qm_dc_adr;
wire [31:0] qm_dc_dat_o;
wire [31:0] qm_dc_dat_i;
wire qm_dc_cycstb;
wire qm_dc_ack;
wire qm_dc_err;
wire qm_dc_rty;
wire qm_dc_we;
wire [31:0] qm_dc_tag;
wire [3:0] qm_dc_sel;

// Instruction Cache to BIU
wire [31:0] ic_biu_adr;
wire [31:0] ic_biu_dat_o;
wire ic_biu_cyc;
wire ic_biu_stb;
wire ic_biu_we;
wire [3:0] ic_biu_sel;
wire [31:0] ic_biu_dat_i;
wire ic_biu_ack;
wire ic_biu_err;
wire ic_biu_rty;

// Data Cache to Store Buffer
wire [31:0] dc_sb_adr;
wire [31:0] dc_sb_dat_o;
wire dc_sb_cyc;
wire dc_sb_stb;
wire dc_sb_we;
wire [3:0] dc_sb_sel;
wire [31:0] dc_sb_dat_i;
wire dc_sb_ack;
wire dc_sb_err;
wire dc_sb_rty;

// Store Buffer to BIU
wire [31:0] sb_biu_adr;
wire [31:0] sb_biu_dat_o;
wire sb_biu_cyc;
wire sb_biu_stb;
wire sb_biu_we;
wire [3:0] sb_biu_sel;
wire [31:0] sb_biu_dat_i;
wire sb_biu_ack;
wire sb_biu_err;
wire sb_biu_rty;

// Debug Unit signals
wire [31:0] du_addr;
wire [31:0] du_dat_du;
wire du_read;
wire du_write;
wire du_except;
wire du_hwbkpt;
wire du_stall;

// Interrupt/Timer signals
wire sig_int;
wire sig_tick;
wire pic_wakeup;

// Power Management signals
wire pm_cpu_stall;

// MBIST scan chain
`ifdef OR1200_BIST
wire mbist_ic_si;
wire mbist_ic_so;
wire mbist_qm_si;
wire mbist_qm_so;
wire mbist_dmmu_si;
wire mbist_dmmu_so;
wire mbist_dc_si;
`endif

// Instantiate CPU core
or1200_cpu u_or1200_cpu (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    // Instruction side
    .icpu_adr_o    (icpu_adr_o),
    .icpu_dat_i    (icpu_dat_i),
    .icpu_cycstb_o (icpu_cycstb_o),
    .icpu_ack_i    (icpu_ack_i),
    .icpu_err_i    (icpu_err_i),
    .icpu_rty_i    (icpu_rty_i),
    .icpu_tag_o    (icpu_tag_o),
    .icpu_sel_o    (icpu_sel_o),

    // Data side
    .dcpu_adr_o    (dcpu_adr_o),
    .dcpu_dat_o    (dcpu_dat_o),
    .dcpu_dat_i    (dcpu_dat_i),
    .dcpu_cycstb_o (dcpu_cycstb_o),
    .dcpu_ack_i    (dcpu_ack_i),
    .dcpu_err_i    (dcpu_err_i),
    .dcpu_rty_i    (dcpu_rty_i),
    .dcpu_we_o     (dcpu_we_o),
    .dcpu_sel_o    (dcpu_sel_o),
    .dcpu_tag_o    (dcpu_tag_o),

    // SPR
    .spr_addr     (spr_addr),
    .spr_dat_cpu  (spr_dat_cpu),
    .spr_we       (spr_we),
    .spr_cs       (spr_cs),
    .spr_dat_immu (spr_dat_immu),
    .spr_dat_dmmu (spr_dat_dmmu),
    .spr_dat_ic   (spr_dat_ic),
    .spr_dat_dc   (spr_dat_dc),
    .spr_dat_du   (spr_dat_du),
    .spr_dat_pic  (spr_dat_pic),
    .spr_dat_tt   (spr_dat_tt),
    .spr_dat_pm   (spr_dat_pm),

    // Interrupts
    .sig_int  (sig_int),
    .sig_tick (sig_tick),

    // Debug
    .du_addr    (du_addr),
    .du_dat_du  (du_dat_du),
    .du_read    (du_read),
    .du_write   (du_write),
    .du_except  (du_except),
    .du_hwbkpt  (du_hwbkpt),
    .du_stall   (du_stall)
);

// Instantiate IMMU
or1200_immu_top u_or1200_immu (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_adr_i  (icpu_adr_o),
    .cpu_cycstb_i (icpu_cycstb_o),
    .cpu_sel_i  (icpu_sel_o),
    .cpu_tag_i  (icpu_tag_o),

    .cpu_ack_o  (icpu_ack_i),
    .cpu_err_o  (icpu_err_i),
    .cpu_rty_o  (icpu_rty_i),

    .qm_adr_o   (qm_ic_adr),
    .qm_cycstb_o (qm_ic_cycstb),
    .qm_sel_o   (qm_ic_sel),
    .qm_tag_o   (qm_ic_tag),

    .qm_ack_i   (qm_ic_ack),
    .qm_err_i   (qm_ic_err),
    .qm_rty_i   (qm_ic_rty),

    .spr_cs_i   (spr_cs[2]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_immu),

`ifdef OR1200_BIST
    .mbist_si_i (mbist_si_i),
    .mbist_so_o (mbist_ic_si),
    .mbist_ctrl_i (mbist_ctrl_i),
`endif
    .pm_clksd_o (),
    .pm_gate_o  (pm_immu_gate_o)
);

// Instantiate QMEM
or1200_qmem_top u_or1200_qmem (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .icpu_adr_i (qm_ic_adr),
    .icpu_cycstb_i (qm_ic_cycstb),
    .icpu_sel_i (qm_ic_sel),
    .icpu_tag_i (qm_ic_tag),
    .icpu_ack_o (qm_ic_ack),
    .icpu_err_o (qm_ic_err),
    .icpu_rty_o (qm_ic_rty),

    .dcpu_adr_i (qm_dc_adr),
    .dcpu_dat_i (qm_dc_dat_o),
    .dcpu_cycstb_i (qm_dc_cycstb),
    .dcpu_we_i  (qm_dc_we),
    .dcpu_sel_i (qm_dc_sel),
    .dcpu_tag_i (qm_dc_tag),
    .dcpu_ack_o (qm_dc_ack),
    .dcpu_err_o (qm_dc_err),
    .dcpu_rty_o (qm_dc_rty),
    .dcpu_dat_o (qm_dc_dat_i),

    .ic_biu_adr_o (qm_ic_adr_cache),
    .ic_biu_dat_i (qm_ic_dat),
    .ic_biu_cycstb_o (qm_ic_cycstb_cache),
    .ic_biu_ack_i (qm_ic_ack_cache),
    .ic_biu_err_i (qm_ic_err_cache),
    .ic_biu_rty_i (qm_ic_rty_cache),
    .ic_biu_tag_o (qm_ic_tag_cache),
    .ic_biu_sel_o (qm_ic_sel_cache),

    .dc_biu_adr_o (qm_dc_adr_cache),
    .dc_biu_dat_o (qm_dc_dat_o_cache),
    .dc_biu_cycstb_o (qm_dc_cycstb_cache),
    .dc_biu_we_o  (qm_dc_we_cache),
    .dc_biu_sel_o (qm_dc_sel_cache),
    .dc_biu_tag_o (qm_dc_tag_cache),
    .dc_biu_ack_i (qm_dc_ack_cache),
    .dc_biu_err_i (qm_dc_err_cache),
    .dc_biu_rty_i (qm_dc_rty_cache),
    .dc_biu_dat_i (qm_dc_dat_i_cache),

`ifdef OR1200_BIST
    .mbist_si_i (mbist_ic_so),
    .mbist_so_o (mbist_qm_si),
    .mbist_ctrl_i (mbist_ctrl_i),
`endif
    .pm_clksd_o (),
    .pm_gate_o  ()
);

// Instantiate DMMU
or1200_dmmu_top u_or1200_dmmu (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_adr_i  (dcpu_adr_o),
    .cpu_cycstb_i (dcpu_cycstb_o),
    .cpu_we_i   (dcpu_we_o),
    .cpu_sel_i  (dcpu_sel_o),
    .cpu_tag_i  (dcpu_tag_o),

    .cpu_ack_o  (dcpu_ack_i),
    .cpu_err_o  (dcpu_err_i),
    .cpu_rty_o  (dcpu_rty_i),

    .qm_adr_o   (qm_dc_adr),
    .qm_cycstb_o (qm_dc_cycstb),
    .qm_we_o    (qm_dc_we),
    .qm_sel_o   (qm_dc_sel),
    .qm_tag_o   (qm_dc_tag),

    .qm_ack_i   (qm_dc_ack),
    .qm_err_i   (qm_dc_err),
    .qm_rty_i   (qm_dc_rty),

    .spr_cs_i   (spr_cs[1]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_dmmu),

`ifdef OR1200_BIST
    .mbist_si_i (mbist_qm_so),
    .mbist_so_o (mbist_dmmu_si),
    .mbist_ctrl_i (mbist_ctrl_i),
`endif
    .pm_clksd_o (),
    .pm_gate_o  (pm_dmmu_gate_o)
);

// Instantiate Instruction Cache
or1200_ic_top u_or1200_ic (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_adr_i  (qm_ic_adr_cache),
    .cpu_cycstb_i (qm_ic_cycstb_cache),
    .cpu_sel_i  (qm_ic_sel_cache),
    .cpu_tag_i  (qm_ic_tag_cache),
    .cpu_ack_o  (qm_ic_ack_cache),
    .cpu_err_o  (qm_ic_err_cache),
    .cpu_rty_o  (qm_ic_rty_cache),
    .cpu_dat_o  (qm_ic_dat),

    .biu_adr_o  (ic_biu_adr),
    .biu_dat_o  (ic_biu_dat_o),
    .biu_cyc_o  (ic_biu_cyc),
    .biu_stb_o  (ic_biu_stb),
    .biu_we_o   (ic_biu_we),
    .biu_sel_o  (ic_biu_sel),
    .biu_dat_i  (ic_biu_dat_i),
    .biu_ack_i  (ic_biu_ack),
    .biu_err_i  (ic_biu_err),
    .biu_rty_i  (ic_biu_rty),

    .spr_cs_i   (spr_cs[4]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_ic),

`ifdef OR1200_BIST
    .mbist_si_i (mbist_ic_si),
    .mbist_so_o (mbist_ic_so),
    .mbist_ctrl_i (mbist_ctrl_i),
`endif
    .pm_clksd_o (),
    .pm_gate_o  (pm_ic_gate_o)
);

// Instantiate Data Cache
or1200_dc_top u_or1200_dc (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_adr_i  (qm_dc_adr_cache),
    .cpu_dat_i  (qm_dc_dat_o_cache),
    .cpu_cycstb_i (qm_dc_cycstb_cache),
    .cpu_we_i   (qm_dc_we_cache),
    .cpu_sel_i  (qm_dc_sel_cache),
    .cpu_tag_i  (qm_dc_tag_cache),
    .cpu_ack_o  (qm_dc_ack_cache),
    .cpu_err_o  (qm_dc_err_cache),
    .cpu_rty_o  (qm_dc_rty_cache),
    .cpu_dat_o  (qm_dc_dat_i_cache),

    .biu_adr_o  (dc_sb_adr),
    .biu_dat_o  (dc_sb_dat_o),
    .biu_cyc_o  (dc_sb_cyc),
    .biu_stb_o  (dc_sb_stb),
    .biu_we_o   (dc_sb_we),
    .biu_sel_o  (dc_sb_sel),
    .biu_dat_i  (dc_sb_dat_i),
    .biu_ack_i  (dc_sb_ack),
    .biu_err_i  (dc_sb_err),
    .biu_rty_i  (dc_sb_rty),

    .spr_cs_i   (spr_cs[3]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_dc),

`ifdef OR1200_BIST
    .mbist_si_i (mbist_dmmu_so),
    .mbist_so_o (mbist_dc_si),
    .mbist_ctrl_i (mbist_ctrl_i),
`endif
    .pm_clksd_o (),
    .pm_gate_o  (pm_dc_gate_o)
);

// Instantiate Store Buffer
or1200_sb_top u_or1200_sb (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .dc_adr_i   (dc_sb_adr),
    .dc_dat_i   (dc_sb_dat_o),
    .dc_cyc_i   (dc_sb_cyc),
    .dc_stb_i   (dc_sb_stb),
    .dc_we_i    (dc_sb_we),
    .dc_sel_i   (dc_sb_sel),
    .dc_dat_o   (dc_sb_dat_i),
    .dc_ack_o   (dc_sb_ack),
    .dc_err_o   (dc_sb_err),
    .dc_rty_o   (dc_sb_rty),

    .biu_adr_o  (sb_biu_adr),
    .biu_dat_o  (sb_biu_dat_o),
    .biu_cyc_o  (sb_biu_cyc),
    .biu_stb_o  (sb_biu_stb),
    .biu_we_o   (sb_biu_we),
    .biu_sel_o  (sb_biu_sel),
    .biu_dat_i  (sb_biu_dat_i),
    .biu_ack_i  (sb_biu_ack),
    .biu_err_i  (sb_biu_err),
    .biu_rty_i  (sb_biu_rty)
);

// Instantiate Instruction Wishbone BIU
or1200_wb_biu u_iwb_biu (
    .clk_i      (clk_i),
    .rst_i      (rst_i),
    .clmode_i   (clmode_i),

    .core_cyc_i (ic_biu_cyc),
    .core_stb_i (ic_biu_stb),
    .core_we_i  (ic_biu_we),
    .core_adr_i (ic_biu_adr),
    .core_dat_i (ic_biu_dat_o),
    .core_sel_i (ic_biu_sel),
    .core_dat_o (ic_biu_dat_i),
    .core_ack_o (ic_biu_ack),
    .core_err_o (ic_biu_err),
    .core_rty_o (ic_biu_rty),

    .wb_cyc_o   (iwb_cyc_o),
    .wb_stb_o   (iwb_stb_o),
    .wb_we_o    (iwb_we_o),
    .wb_adr_o   (iwb_adr_o),
    .wb_dat_o   (iwb_dat_o),
    .wb_sel_o   (iwb_sel_o),
    .wb_dat_i   (iwb_dat_i),
    .wb_ack_i   (iwb_ack_i),
    .wb_err_i   (iwb_err_i),
    .wb_rty_i   (iwb_rty_i)
`ifdef OR1200_WB_CAB
    ,
    .wb_cab_o   (iwb_cab_o)
`endif
`ifdef OR1200_WB_B3
    ,
    .wb_cti_o   (iwb_cti_o),
    .wb_bte_o   (iwb_bte_o)
`endif
);

// Instantiate Data Wishbone BIU
or1200_wb_biu u_dwb_biu (
    .clk_i      (clk_i),
    .rst_i      (rst_i),
    .clmode_i   (clmode_i),

    .core_cyc_i (sb_biu_cyc),
    .core_stb_i (sb_biu_stb),
    .core_we_i  (sb_biu_we),
    .core_adr_i (sb_biu_adr),
    .core_dat_i (sb_biu_dat_o),
    .core_sel_i (sb_biu_sel),
    .core_dat_o (sb_biu_dat_i),
    .core_ack_o (sb_biu_ack),
    .core_err_o (sb_biu_err),
    .core_rty_o (sb_biu_rty),

    .wb_cyc_o   (dwb_cyc_o),
    .wb_stb_o   (dwb_stb_o),
    .wb_we_o    (dwb_we_o),
    .wb_adr_o   (dwb_adr_o),
    .wb_dat_o   (dwb_dat_o),
    .wb_sel_o   (dwb_sel_o),
    .wb_dat_i   (dwb_dat_i),
    .wb_ack_i   (dwb_ack_i),
    .wb_err_i   (dwb_err_i),
    .wb_rty_i   (dwb_rty_i)
`ifdef OR1200_WB_CAB
    ,
    .wb_cab_o   (dwb_cab_o)
`endif
`ifdef OR1200_WB_B3
    ,
    .wb_cti_o   (dwb_cti_o),
    .wb_bte_o   (dwb_bte_o)
`endif
);

// Instantiate Debug Unit
or1200_du u_or1200_du (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_addr_i (du_addr),
    .cpu_dat_i  (du_dat_du),
    .cpu_read_i (du_read),
    .cpu_write_i (du_write),
    .cpu_except_i (du_except),
    .cpu_hwbkpt_i (du_hwbkpt),

    .cpu_stall_o (du_stall),

    .dbg_stall_i (dbg_stall_i),
    .dbg_ewt_i   (dbg_ewt_i),
    .dbg_lss_o   (dbg_lss_o),
    .dbg_is_o    (dbg_is_o),
    .dbg_wp_o    (dbg_wp_o),
    .dbg_bp_o    (dbg_bp_o),
    .dbg_stb_i   (dbg_stb_i),
    .dbg_we_i    (dbg_we_i),
    .dbg_adr_i   (dbg_adr_i),
    .dbg_dat_i   (dbg_dat_i),
    .dbg_dat_o   (dbg_dat_o),
    .dbg_ack_o   (dbg_ack_o),

    .spr_cs_i   (spr_cs[6]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_du)
);

// Instantiate Programmable Interrupt Controller
or1200_pic u_or1200_pic (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .pic_ints_i (pic_ints_i),
    .sig_int_o  (sig_int),
    .pic_wakeup_o (pic_wakeup),

    .spr_cs_i   (spr_cs[9]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_pic)
);

// Instantiate Tick Timer
or1200_tt u_or1200_tt (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .intr_o     (sig_tick),

    .spr_cs_i   (spr_cs[10]),
    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_tt),

    .pm_gate_o  (pm_tt_gate_o)
);

// Instantiate Power Management Unit
or1200_pm u_or1200_pm (
    .clk_i      (clk_i),
    .rst_i      (rst_i),

    .cpu_stall_i (pm_cpustall_i),
    .pic_wakeup_i (pic_wakeup),

    .spr_write_i (spr_we),
    .spr_addr_i (spr_addr),
    .spr_dat_i  (spr_dat_cpu),
    .spr_dat_o  (spr_dat_pm),

    .pm_clksd_o   (pm_clksd_o),
    .pm_dc_gate_o (pm_dc_gate_o),
    .pm_ic_gate_o (pm_ic_gate_o),
    .pm_dmmu_gate_o (pm_dmmu_gate_o),
    .pm_immu_gate_o (pm_immu_gate_o),
    .pm_tt_gate_o (pm_tt_gate_o),
    .pm_cpu_gate_o (pm_cpu_gate_o),
    .pm_wakeup_o  (pm_wakeup_o),
    .pm_lvolt_o   (pm_lvolt_o)
);

// MBIST scan chain connection
`ifdef OR1200_BIST
assign mbist_so_o = mbist_dc_si;
`endif

endmodule
