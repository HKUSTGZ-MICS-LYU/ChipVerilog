`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_top #(
    parameter ppic_ints = 20
) (
    // System
    input                    clk_i,
    input                    rst_i,
    input  [ppic_ints-1:0]   pic_ints_i,
    input  [1:0]             clmode_i,

    // Instruction WISHBONE interface
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

    // Data WISHBONE interface
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
    input                                mbist_si_i,
    output                               mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
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

    //--------------------------------------------------------------------------
    // Clock / Reset: Wishbone BIUs share top-level clk/rst
    //--------------------------------------------------------------------------
    wire clk = clk_i;
    wire rst = rst_i;
    wire iwb_clk = clk_i;
    wire iwb_rst = rst_i;
    wire dwb_clk = clk_i;
    wire dwb_rst = rst_i;

    //--------------------------------------------------------------------------
    // MBIST scan chain wires
    // Order: mbist_si_i → IMMU → IC → QMEM → DMMU → DC → mbist_so_o
    //--------------------------------------------------------------------------
`ifdef OR1200_BIST
    wire mbist_immu_so, mbist_ic_so, mbist_qmem_so, mbist_dmmu_so;
`endif

    //--------------------------------------------------------------------------
    // CPU core <-> IMMU instruction interface
    //--------------------------------------------------------------------------
    wire [31:0] icpu_adr_cpu;
    wire        icpu_cycstb_cpu;
    wire [3:0]  icpu_sel_cpu;
    wire [3:0]  icpu_tag_cpu;
    wire [31:0] icpu_dat_cpu;
    wire        icpu_ack_cpu;
    wire        icpu_rty_cpu;
    wire        icpu_err_cpu;
    wire [31:0] icpu_adr_immu;
    wire [3:0]  icpu_tag_immu;

    //--------------------------------------------------------------------------
    // IMMU <-> QMEM instruction interface
    //--------------------------------------------------------------------------
    wire [31:0] qmemimmu_adr;
    wire        qmemimmu_cycstb;
    wire        qmemimmu_ci;
    wire [31:0] qmemimmu_dat;
    wire        qmemimmu_ack;
    wire        qmemimmu_rty;
    wire        qmemimmu_err;
    wire [3:0]  qmemimmu_tag;
    wire [3:0]  qmemicpu_sel;
    wire [3:0]  qmemicpu_tag;

    //--------------------------------------------------------------------------
    // QMEM <-> IC interface
    //--------------------------------------------------------------------------
    wire [31:0] icqmem_adr;
    wire        icqmem_cycstb;
    wire        icqmem_ci;
    wire [3:0]  icqmem_sel;
    wire [3:0]  icqmem_tag;
    wire [31:0] icqmem_dat_ic;
    wire        icqmem_ack_ic;
    wire        icqmem_rty_ic;
    wire        icqmem_err_ic;
    wire [3:0]  icqmem_tag_ic;

    //--------------------------------------------------------------------------
    // IC <-> IWB BIU interface
    //--------------------------------------------------------------------------
    wire [31:0] icbiu_adr;
    wire        icbiu_cyc;
    wire        icbiu_stb;
    wire        icbiu_we;
    wire [3:0]  icbiu_sel;
    wire        icbiu_cab;
    wire [31:0] icbiu_dat_ic;
    wire [31:0] icbiu_dat_wb;
    wire        icbiu_ack;
    wire        icbiu_err;

    //--------------------------------------------------------------------------
    // CPU core <-> DMMU data interface
    //--------------------------------------------------------------------------
    wire [31:0] dcpu_adr_cpu;
    wire        dcpu_cycstb_cpu;
    wire        dcpu_we_cpu;
    wire [3:0]  dcpu_sel_cpu;
    wire [3:0]  dcpu_tag_cpu;
    wire [31:0] dcpu_dat_cpu;
    wire [31:0] dcpu_dat_dc;
    wire        dcpu_ack_dc;
    wire        dcpu_rty_dc;
    wire        dcpu_err_dc;
    wire [3:0]  dcpu_tag_dc;

    //--------------------------------------------------------------------------
    // DMMU <-> QMEM data interface
    //--------------------------------------------------------------------------
    wire [31:0] qmemdmmu_adr;
    wire        qmemdmmu_cycstb;
    wire        qmemdmmu_ci;
    wire [31:0] qmemdcpu_dat;
    wire        qmemdcpu_ack;
    wire        qmemdcpu_rty;
    wire        qmemdmmu_err;
    wire [3:0]  qmemdmmu_tag;
    wire        qmemdcpu_we;
    wire [3:0]  qmemdcpu_sel;
    wire [3:0]  qmemdcpu_tag;
    wire [31:0] qmemdcpu_dat_i;

    //--------------------------------------------------------------------------
    // QMEM <-> DC interface
    //--------------------------------------------------------------------------
    wire [31:0] dcqmem_adr;
    wire        dcqmem_cycstb;
    wire        dcqmem_ci;
    wire        dcqmem_we;
    wire [3:0]  dcqmem_sel;
    wire [3:0]  dcqmem_tag;
    wire [31:0] dcqmem_dat_o;
    wire [31:0] dcqmem_dat_i;
    wire        dcqmem_ack;
    wire        dcqmem_rty;
    wire        dcqmem_err;
    wire [3:0]  dcqmem_tag_i;

    //--------------------------------------------------------------------------
    // DC <-> Store Buffer interface
    //--------------------------------------------------------------------------
    wire [31:0] dcsb_adr;
    wire        dcsb_cyc;
    wire        dcsb_stb;
    wire        dcsb_we;
    wire [3:0]  dcsb_sel;
    wire        dcsb_cab;
    wire [31:0] dcsb_dat_o;
    wire [31:0] dcsb_dat_i;
    wire        dcsb_ack;
    wire        dcsb_err;

    //--------------------------------------------------------------------------
    // SB <-> DWB BIU interface
    //--------------------------------------------------------------------------
    wire [31:0] sbbiu_adr;
    wire        sbbiu_cyc;
    wire        sbbiu_stb;
    wire        sbbiu_we;
    wire [3:0]  sbbiu_sel;
    wire        sbbiu_cab;
    wire [31:0] sbbiu_dat_o;
    wire [31:0] sbbiu_dat_i;
    wire        sbbiu_ack;
    wire        sbbiu_err;

    //--------------------------------------------------------------------------
    // SPR bus
    //--------------------------------------------------------------------------
    wire [31:0] spr_addr;
    wire [31:0] spr_dat_cpu;
    wire [31:0] spr_cs;
    wire        spr_we;
    wire [31:0] spr_dat_pic;
    wire [31:0] spr_dat_tt;
    wire [31:0] spr_dat_pm;
    wire [31:0] spr_dat_dmmu;
    wire [31:0] spr_dat_immu;
    wire [31:0] spr_dat_du;

    //--------------------------------------------------------------------------
    // Debug unit <-> CPU
    //--------------------------------------------------------------------------
    wire        du_stall;
    wire [31:0] du_addr;
    wire [31:0] du_dat_du;
    wire [31:0] du_dat_cpu;
    wire        du_read;
    wire        du_write;
    wire [13:0] du_dsr;
    wire        du_hwbkpt;
    wire [12:0] du_except;

    //--------------------------------------------------------------------------
    // CPU core outputs
    //--------------------------------------------------------------------------
    wire        ic_en;
    wire        dc_en;
    wire        immu_en;
    wire        dmmu_en;
    wire        supv;
    wire [31:0] ex_insn;
    wire        ex_freeze;
    wire [31:0] id_pc;
    wire [2:0]  branch_op;
    wire [31:0] spr_dat_npc;
    wire [31:0] rf_dataw;

    //--------------------------------------------------------------------------
    // Interrupt / tick
    //--------------------------------------------------------------------------
    wire sig_int;
    wire sig_tick;
    wire pic_wakeup;

    //==========================================================================
    // CPU core
    //==========================================================================
    or1200_cpu or1200_cpu (
        .clk             (clk),
        .rst             (rst),

        // Instruction interface
        .ic_en           (ic_en),
        .icpu_adr_o      (icpu_adr_cpu),
        .icpu_cycstb_o   (icpu_cycstb_cpu),
        .icpu_sel_o      (icpu_sel_cpu),
        .icpu_tag_o      (icpu_tag_cpu),
        .icpu_dat_i      (icpu_dat_cpu),
        .icpu_ack_i      (icpu_ack_cpu),
        .icpu_rty_i      (icpu_rty_cpu),
        .icpu_err_i      (icpu_err_cpu),
        .icpu_adr_i      (icpu_adr_immu),
        .icpu_tag_i      (icpu_tag_immu),
        .immu_en         (immu_en),

        // Debug unit
        .ex_insn         (ex_insn),
        .ex_freeze       (ex_freeze),
        .id_pc           (id_pc),
        .branch_op       (branch_op),
        .spr_dat_npc     (spr_dat_npc),
        .rf_dataw        (rf_dataw),
        .du_stall        (du_stall),
        .du_addr         (du_addr),
        .du_dat_du       (du_dat_du),
        .du_read         (du_read),
        .du_write        (du_write),
        .du_dsr          (du_dsr),
        .du_hwbkpt       (du_hwbkpt),
        .du_except       (du_except),
        .du_dat_cpu      (du_dat_cpu),

        // Data interface
        .dc_en           (dc_en),
        .dcpu_adr_o      (dcpu_adr_cpu),
        .dcpu_cycstb_o   (dcpu_cycstb_cpu),
        .dcpu_we_o       (dcpu_we_cpu),
        .dcpu_sel_o      (dcpu_sel_cpu),
        .dcpu_tag_o      (dcpu_tag_cpu),
        .dcpu_dat_o      (dcpu_dat_cpu),
        .dcpu_dat_i      (dcpu_dat_dc),
        .dcpu_ack_i      (dcpu_ack_dc),
        .dcpu_rty_i      (dcpu_rty_dc),
        .dcpu_err_i      (dcpu_err_dc),
        .dcpu_tag_i      (dcpu_tag_dc),
        .dmmu_en         (dmmu_en),

        // Interrupts
        .sig_int         (sig_int),
        .sig_tick        (sig_tick),

        // SPR
        .supv            (supv),
        .spr_addr        (spr_addr),
        .spr_dat_cpu     (spr_dat_cpu),
        .spr_dat_pic     (spr_dat_pic),
        .spr_dat_tt      (spr_dat_tt),
        .spr_dat_pm      (spr_dat_pm),
        .spr_dat_dmmu    (spr_dat_dmmu),
        .spr_dat_immu    (spr_dat_immu),
        .spr_dat_du      (spr_dat_du),
        .spr_cs          (spr_cs),
        .spr_we          (spr_we)
    );

    //==========================================================================
    // Instruction MMU
    //==========================================================================
    or1200_immu_top or1200_immu (
        .clk             (clk),
        .rst             (rst),
        .ic_en           (ic_en),
        .immu_en         (immu_en),
        .supv            (supv),
        .icpu_adr_i      (icpu_adr_cpu),
        .icpu_cycstb_i   (icpu_cycstb_cpu),
        .icpu_adr_o      (icpu_adr_immu),
        .icpu_tag_o      (icpu_tag_immu),
        .icpu_rty_o      (icpu_rty_cpu),
        .icpu_err_o      (icpu_err_cpu),
        .spr_cs          (spr_cs[2]),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_immu),
`ifdef OR1200_BIST
        .mbist_si_i      (mbist_si_i),
        .mbist_so_o      (mbist_immu_so),
        .mbist_ctrl_i    (mbist_ctrl_i),
`endif
        .qmemimmu_rty_i  (qmemimmu_rty),
        .qmemimmu_err_i  (qmemimmu_err),
        .qmemimmu_tag_i  (qmemimmu_tag),
        .qmemimmu_adr_o  (qmemimmu_adr),
        .qmemimmu_cycstb_o(qmemimmu_cycstb),
        .qmemimmu_ci_o   (qmemimmu_ci)
    );

    //==========================================================================
    // QMEM
    //==========================================================================
    or1200_qmem_top or1200_qmem (
        .clk             (clk),
        .rst             (rst),
`ifdef OR1200_BIST
        .mbist_si_i      (mbist_ic_so),
        .mbist_so_o      (mbist_qmem_so),
        .mbist_ctrl_i    (mbist_ctrl_i),
`endif
        // Instruction side (IMMU → QMEM → IC)
        .qmemimmu_adr_i  (qmemimmu_adr),
        .qmemimmu_cycstb_i(qmemimmu_cycstb),
        .qmemimmu_ci_i   (qmemimmu_ci),
        .qmemicpu_sel_i  (icpu_sel_cpu),
        .qmemicpu_tag_i  (icpu_tag_cpu),
        .qmemicpu_dat_o  (icpu_dat_cpu),
        .qmemicpu_ack_o  (icpu_ack_cpu),
        .qmemimmu_rty_o  (qmemimmu_rty),
        .qmemimmu_err_o  (qmemimmu_err),
        .qmemimmu_tag_o  (qmemimmu_tag),
        .icqmem_adr_o    (icqmem_adr),
        .icqmem_cycstb_o (icqmem_cycstb),
        .icqmem_ci_o     (icqmem_ci),
        .icqmem_sel_o    (icqmem_sel),
        .icqmem_tag_o    (icqmem_tag),
        .icqmem_dat_i    (icqmem_dat_ic),
        .icqmem_ack_i    (icqmem_ack_ic),
        .icqmem_rty_i    (icqmem_rty_ic),
        .icqmem_err_i    (icqmem_err_ic),
        .icqmem_tag_i    (icqmem_tag_ic),
        // Data side (DMMU → QMEM → DC)
        .qmemdmmu_adr_i  (qmemdmmu_adr),
        .qmemdmmu_cycstb_i(qmemdmmu_cycstb),
        .qmemdmmu_ci_i   (qmemdmmu_ci),
        .qmemdcpu_we_i   (qmemdcpu_we),
        .qmemdcpu_sel_i  (qmemdcpu_sel),
        .qmemdcpu_tag_i  (qmemdcpu_tag),
        .qmemdcpu_dat_i  (qmemdcpu_dat_i),
        .qmemdcpu_dat_o  (qmemdcpu_dat),
        .qmemdcpu_ack_o  (qmemdcpu_ack),
        .qmemdcpu_rty_o  (qmemdcpu_rty),
        .qmemdmmu_err_o  (qmemdmmu_err),
        .qmemdmmu_tag_o  (qmemdmmu_tag),
        .dcqmem_adr_o    (dcqmem_adr),
        .dcqmem_cycstb_o (dcqmem_cycstb),
        .dcqmem_ci_o     (dcqmem_ci),
        .dcqmem_we_o     (dcqmem_we),
        .dcqmem_sel_o    (dcqmem_sel),
        .dcqmem_tag_o    (dcqmem_tag),
        .dcqmem_dat_o    (dcqmem_dat_o),
        .dcqmem_dat_i    (dcqmem_dat_i),
        .dcqmem_ack_i    (dcqmem_ack),
        .dcqmem_rty_i    (dcqmem_rty),
        .dcqmem_err_i    (dcqmem_err),
        .dcqmem_tag_i    (dcqmem_tag_i)
    );

    //==========================================================================
    // Instruction Cache
    //==========================================================================
    or1200_ic_top or1200_ic (
        .clk             (clk),
        .rst             (rst),
        .ic_en           (ic_en),
        .icqmem_adr_i    (icqmem_adr),
        .icqmem_cycstb_i (icqmem_cycstb),
        .icqmem_ci_i     (icqmem_ci),
        .icqmem_sel_i    (icqmem_sel),
        .icqmem_tag_i    (icqmem_tag),
        .icqmem_dat_o    (icqmem_dat_ic),
        .icqmem_ack_o    (icqmem_ack_ic),
        .icqmem_rty_o    (icqmem_rty_ic),
        .icqmem_err_o    (icqmem_err_ic),
        .icqmem_tag_o    (icqmem_tag_ic),
`ifdef OR1200_BIST
        .mbist_si_i      (mbist_immu_so),
        .mbist_so_o      (mbist_ic_so),
        .mbist_ctrl_i    (mbist_ctrl_i),
`endif
        .spr_cs          (spr_cs[4]),
        .spr_write       (spr_we),
        .spr_dat_i       (spr_dat_cpu),
        .icbiu_dat_o     (icbiu_dat_ic),
        .icbiu_adr_o     (icbiu_adr),
        .icbiu_cyc_o     (icbiu_cyc),
        .icbiu_stb_o     (icbiu_stb),
        .icbiu_we_o      (icbiu_we),
        .icbiu_sel_o     (icbiu_sel),
        .icbiu_cab_o     (icbiu_cab),
        .icbiu_dat_i     (icbiu_dat_wb),
        .icbiu_ack_i     (icbiu_ack),
        .icbiu_err_i     (icbiu_err)
    );

    //==========================================================================
    // Instruction Wishbone BIU
    //==========================================================================
    or1200_iwb_biu or1200_iwb_biu (
        .clk             (clk),
        .rst             (rst),
        .clmode          (clmode_i),
        .wb_clk_i        (iwb_clk),
        .wb_rst_i        (iwb_rst),
        .wb_ack_i        (iwb_ack_i),
        .wb_err_i        (iwb_err_i),
        .wb_rty_i        (iwb_rty_i),
        .wb_dat_i        (iwb_dat_i),
        .wb_cyc_o        (iwb_cyc_o),
        .wb_adr_o        (iwb_adr_o),
        .wb_stb_o        (iwb_stb_o),
        .wb_we_o         (iwb_we_o),
        .wb_sel_o        (iwb_sel_o),
        .wb_dat_o        (iwb_dat_o),
`ifdef OR1200_WB_CAB
        .wb_cab_o        (iwb_cab_o),
`endif
`ifdef OR1200_WB_B3
        .wb_cti_o        (iwb_cti_o),
        .wb_bte_o        (iwb_bte_o),
`endif
        .biu_dat_i       (icbiu_dat_ic),
        .biu_adr_i       (icbiu_adr),
        .biu_cyc_i       (icbiu_cyc),
        .biu_stb_i       (icbiu_stb),
        .biu_we_i        (icbiu_we),
        .biu_sel_i       (icbiu_sel),
        .biu_cab_i       (icbiu_cab),
        .biu_dat_o       (icbiu_dat_wb),
        .biu_ack_o       (icbiu_ack),
        .biu_err_o       (icbiu_err)
    );

    //==========================================================================
    // Data MMU
    //==========================================================================
    or1200_dmmu_top or1200_dmmu (
        .clk             (clk),
        .rst             (rst),
        .dc_en           (dc_en),
        .dmmu_en         (dmmu_en),
        .supv            (supv),
        .dcpu_adr_i      (dcpu_adr_cpu),
        .dcpu_cycstb_i   (dcpu_cycstb_cpu),
        .dcpu_we_i       (dcpu_we_cpu),
        .dcpu_tag_o      (dcpu_tag_dc),
        .dcpu_err_o      (dcpu_err_dc),
        .spr_cs          (spr_cs[1]),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_dmmu),
`ifdef OR1200_BIST
        .mbist_si_i      (mbist_qmem_so),
        .mbist_so_o      (mbist_dmmu_so),
        .mbist_ctrl_i    (mbist_ctrl_i),
`endif
        .qmemdmmu_err_i  (qmemdmmu_err),
        .qmemdmmu_tag_i  (qmemdmmu_tag),
        .qmemdmmu_adr_o  (qmemdmmu_adr),
        .qmemdmmu_cycstb_o(qmemdmmu_cycstb),
        .qmemdmmu_ci_o   (qmemdmmu_ci)
    );

    // DMMU does not pass the full data bus; wire data path directly
    assign dcpu_ack_dc    = qmemdcpu_ack;
    assign dcpu_rty_dc    = qmemdcpu_rty;
    assign dcpu_dat_dc    = qmemdcpu_dat;
    assign qmemdcpu_we    = dcpu_we_cpu;
    assign qmemdcpu_sel   = dcpu_sel_cpu;
    assign qmemdcpu_tag   = dcpu_tag_cpu;
    assign qmemdcpu_dat_i = dcpu_dat_cpu;

    //==========================================================================
    // Data Cache
    //==========================================================================
    or1200_dc_top or1200_dc (
        .clk             (clk),
        .rst             (rst),
        .dc_en           (dc_en),
        .dcqmem_adr_i    (dcqmem_adr),
        .dcqmem_cycstb_i (dcqmem_cycstb),
        .dcqmem_ci_i     (dcqmem_ci),
        .dcqmem_we_i     (dcqmem_we),
        .dcqmem_sel_i    (dcqmem_sel),
        .dcqmem_tag_i    (dcqmem_tag),
        .dcqmem_dat_i    (dcqmem_dat_o),
        .dcqmem_dat_o    (dcqmem_dat_i),
        .dcqmem_ack_o    (dcqmem_ack),
        .dcqmem_rty_o    (dcqmem_rty),
        .dcqmem_err_o    (dcqmem_err),
        .dcqmem_tag_o    (dcqmem_tag_i),
`ifdef OR1200_BIST
        .mbist_si_i      (mbist_dmmu_so),
        .mbist_so_o      (mbist_so_o),
        .mbist_ctrl_i    (mbist_ctrl_i),
`endif
        .spr_cs          (spr_cs[3]),
        .spr_write       (spr_we),
        .spr_dat_i       (spr_dat_cpu),
        .dcsb_dat_o      (dcsb_dat_o),
        .dcsb_adr_o      (dcsb_adr),
        .dcsb_cyc_o      (dcsb_cyc),
        .dcsb_stb_o      (dcsb_stb),
        .dcsb_we_o       (dcsb_we),
        .dcsb_sel_o      (dcsb_sel),
        .dcsb_cab_o      (dcsb_cab),
        .dcsb_dat_i      (dcsb_dat_i),
        .dcsb_ack_i      (dcsb_ack),
        .dcsb_err_i      (dcsb_err)
    );

    //==========================================================================
    // Store Buffer
    //==========================================================================
    or1200_sb or1200_sb (
        .clk             (clk),
        .rst             (rst),
        .dcsb_dat_i      (dcsb_dat_o),
        .dcsb_adr_i      (dcsb_adr),
        .dcsb_cyc_i      (dcsb_cyc),
        .dcsb_stb_i      (dcsb_stb),
        .dcsb_we_i       (dcsb_we),
        .dcsb_sel_i      (dcsb_sel),
        .dcsb_cab_i      (dcsb_cab),
        .dcsb_dat_o      (dcsb_dat_i),
        .dcsb_ack_o      (dcsb_ack),
        .dcsb_err_o      (dcsb_err),
        .sbbiu_dat_o     (sbbiu_dat_o),
        .sbbiu_adr_o     (sbbiu_adr),
        .sbbiu_cyc_o     (sbbiu_cyc),
        .sbbiu_stb_o     (sbbiu_stb),
        .sbbiu_we_o      (sbbiu_we),
        .sbbiu_sel_o     (sbbiu_sel),
        .sbbiu_cab_o     (sbbiu_cab),
        .sbbiu_dat_i     (sbbiu_dat_i),
        .sbbiu_ack_i     (sbbiu_ack),
        .sbbiu_err_i     (sbbiu_err)
    );

    //==========================================================================
    // Data Wishbone BIU
    //==========================================================================
    or1200_dwb_biu or1200_dwb_biu (
        .clk             (clk),
        .rst             (rst),
        .clmode          (clmode_i),
        .wb_clk_i        (dwb_clk),
        .wb_rst_i        (dwb_rst),
        .wb_ack_i        (dwb_ack_i),
        .wb_err_i        (dwb_err_i),
        .wb_rty_i        (dwb_rty_i),
        .wb_dat_i        (dwb_dat_i),
        .wb_cyc_o        (dwb_cyc_o),
        .wb_adr_o        (dwb_adr_o),
        .wb_stb_o        (dwb_stb_o),
        .wb_we_o         (dwb_we_o),
        .wb_sel_o        (dwb_sel_o),
        .wb_dat_o        (dwb_dat_o),
`ifdef OR1200_WB_CAB
        .wb_cab_o        (dwb_cab_o),
`endif
`ifdef OR1200_WB_B3
        .wb_cti_o        (dwb_cti_o),
        .wb_bte_o        (dwb_bte_o),
`endif
        .biu_dat_i       (sbbiu_dat_o),
        .biu_adr_i       (sbbiu_adr),
        .biu_cyc_i       (sbbiu_cyc),
        .biu_stb_i       (sbbiu_stb),
        .biu_we_i        (sbbiu_we),
        .biu_sel_i       (sbbiu_sel),
        .biu_cab_i       (sbbiu_cab),
        .biu_dat_o       (sbbiu_dat_i),
        .biu_ack_o       (sbbiu_ack),
        .biu_err_o       (sbbiu_err)
    );

    //==========================================================================
    // Debug Unit
    //==========================================================================
    or1200_du or1200_du (
        .clk             (clk),
        .rst             (rst),
        .dcpu_cycstb_i   (dcpu_cycstb_cpu),
        .dcpu_we_i       (dcpu_we_cpu),
        .dcpu_adr_i      (dcpu_adr_cpu),
        .dcpu_dat_lsu    (dcpu_dat_cpu),
        .dcpu_dat_dc     (dcpu_dat_dc),
        .icpu_cycstb_i   (icpu_cycstb_cpu),
        .ex_freeze       (ex_freeze),
        .branch_op       (branch_op),
        .ex_insn         (ex_insn),
        .id_pc           (id_pc),
        .spr_dat_npc     (spr_dat_npc),
        .rf_dataw        (rf_dataw),
        .du_dsr          (du_dsr),
        .du_stall        (du_stall),
        .du_addr         (du_addr),
        .du_dat_i        (du_dat_cpu),
        .du_dat_o        (du_dat_du),
        .du_read         (du_read),
        .du_write        (du_write),
        .du_except       (du_except),
        .du_hwbkpt       (du_hwbkpt),
        .spr_cs          (spr_cs[6]),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_du),
        .dbg_stall_i     (dbg_stall_i),
        .dbg_ewt_i       (dbg_ewt_i),
        .dbg_lss_o       (dbg_lss_o),
        .dbg_is_o        (dbg_is_o),
        .dbg_wp_o        (dbg_wp_o),
        .dbg_bp_o        (dbg_bp_o),
        .dbg_stb_i       (dbg_stb_i),
        .dbg_we_i        (dbg_we_i),
        .dbg_adr_i       (dbg_adr_i),
        .dbg_dat_i       (dbg_dat_i),
        .dbg_dat_o       (dbg_dat_o),
        .dbg_ack_o       (dbg_ack_o)
    );

    //==========================================================================
    // PIC
    //==========================================================================
    or1200_pic or1200_pic (
        .clk             (clk),
        .rst             (rst),
        .spr_cs          (spr_cs[9]),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_pic),
        .pic_wakeup      (pic_wakeup),
        .intr            (sig_int),
        .pic_int         (pic_ints_i)
    );

    //==========================================================================
    // Tick Timer
    //==========================================================================
    or1200_tt or1200_tt (
        .clk             (clk),
        .rst             (rst),
        .spr_cs          (spr_cs[10]),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_tt),
        .sig_tick        (sig_tick)
    );

    //==========================================================================
    // Power Management Unit
    //==========================================================================
    or1200_pm or1200_pm (
        .clk             (clk),
        .rst             (rst),
        .pic_wakeup      (pic_wakeup),
        .spr_write       (spr_we),
        .spr_addr        (spr_addr),
        .spr_dat_i       (spr_dat_cpu),
        .spr_dat_o       (spr_dat_pm),
        .pm_clksd_o      (pm_clksd_o),
        .pm_cpustall     (pm_cpustall_i),
        .pm_dc_gate      (pm_dc_gate_o),
        .pm_ic_gate      (pm_ic_gate_o),
        .pm_dmmu_gate    (pm_dmmu_gate_o),
        .pm_immu_gate    (pm_immu_gate_o),
        .pm_tt_gate      (pm_tt_gate_o),
        .pm_cpu_gate     (pm_cpu_gate_o),
        .pm_wakeup       (pm_wakeup_o),
        .pm_lvolt        (pm_lvolt_o)
    );

endmodule