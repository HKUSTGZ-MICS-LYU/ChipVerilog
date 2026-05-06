// or1200_top.v - Top-level integration of the OR1200 processor system
// This module instantiates and connects all major submodules of the OR1200.

module or1200_top(
    // System
    input clk_i,
    input rst_i,
    input [19:0] pic_ints_i,
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

    // ================================================================
    // Internal wire and bus declarations
    // ================================================================

    // WISHBONE clock/reset connections
    wire iwb_clk_i;
    wire iwb_rst_i;
    wire dwb_clk_i;
    wire dwb_rst_i;

    assign iwb_clk_i = clk_i;
    assign iwb_rst_i = rst_i;
    assign dwb_clk_i = clk_i;
    assign dwb_rst_i = rst_i;

    // ----------------------------------------------------------------
    // CPU <-> Instruction side signals
    wire [31:0] cpu_insn_adr;
    wire [31:0] cpu_insn_data;
    wire cpu_insn_cyc;
    wire cpu_insn_stb;
    wire cpu_insn_we;
    wire [3:0]  cpu_insn_sel;
    wire [2:0]  cpu_insn_tag;

    // ----------------------------------------------------------------
    // IMMU <-> CPU / QMEM signals
    wire [31:0] immu_insn_adr;
    wire [31:0] immu_insn_data;
    wire immu_insn_cyc;
    wire immu_insn_stb;
    wire immu_insn_we;
    wire [3:0]  immu_insn_sel;
    wire [2:0]  immu_insn_tag;
    wire immu_insn_err;
    wire immu_insn_ack;
    wire immu_insn_rty;

    // ----------------------------------------------------------------
    // QMEM <-> ICache signals
    wire [31:0] qmem_ic_adr;
    wire [31:0] qmem_ic_data;
    wire qmem_ic_cyc;
    wire qmem_ic_stb;
    wire qmem_ic_we;
    wire [3:0]  qmem_ic_sel;
    wire [2:0]  qmem_ic_tag;
    wire qmem_ic_ack;
    wire qmem_ic_err;
    wire qmem_ic_rty;

    // ----------------------------------------------------------------
    // ICache <-> IWishbone BIU signals
    wire [31:0] ic_biu_adr;
    wire [31:0] ic_biu_dat_i;
    wire [31:0] ic_biu_dat_o;
    wire ic_biu_cyc;
    wire ic_biu_stb;
    wire ic_biu_we;
    wire [3:0]  ic_biu_sel;
    wire ic_biu_ack;
    wire ic_biu_err;
    wire ic_biu_rty;
`ifdef OR1200_WB_CAB
    wire ic_biu_cab;
`endif
`ifdef OR1200_WB_B3
    wire [2:0] ic_biu_cti;
    wire [1:0] ic_biu_bte;
`endif

    // ----------------------------------------------------------------
    // CPU <-> Data side signals
    wire [31:0] cpu_data_adr;
    wire [31:0] cpu_data_dat_i;
    wire [31:0] cpu_data_dat_o;
    wire cpu_data_cyc;
    wire cpu_data_stb;
    wire cpu_data_we;
    wire [3:0]  cpu_data_sel;
    wire [2:0]  cpu_data_tag;

    // ----------------------------------------------------------------
    // DMMU <-> CPU / QMEM signals
    wire [31:0] dmmu_data_adr;
    wire [31:0] dmmu_data_dat_i;
    wire [31:0] dmmu_data_dat_o;
    wire dmmu_data_cyc;
    wire dmmu_data_stb;
    wire dmmu_data_we;
    wire [3:0]  dmmu_data_sel;
    wire [2:0]  dmmu_data_tag;
    wire dmmu_data_err;
    wire dmmu_data_ack;
    wire dmmu_data_rty;

    // ----------------------------------------------------------------
    // QMEM <-> DCache signals
    wire [31:0] qmem_dc_adr;
    wire [31:0] qmem_dc_dat_i;
    wire [31:0] qmem_dc_dat_o;
    wire qmem_dc_cyc;
    wire qmem_dc_stb;
    wire qmem_dc_we;
    wire [3:0]  qmem_dc_sel;
    wire [2:0]  qmem_dc_tag;
    wire qmem_dc_ack;
    wire qmem_dc_err;
    wire qmem_dc_rty;

    // ----------------------------------------------------------------
    // DCache <-> Store Buffer signals
    wire [31:0] dc_sb_adr;
    wire [31:0] dc_sb_dat_i;
    wire [31:0] dc_sb_dat_o;
    wire dc_sb_cyc;
    wire dc_sb_stb;
    wire dc_sb_we;
    wire [3:0]  dc_sb_sel;
    wire dc_sb_ack;
    wire dc_sb_err;
    wire dc_sb_rty;

    // ----------------------------------------------------------------
    // Store Buffer <-> DWishbone BIU signals
    wire [31:0] sb_biu_adr;
    wire [31:0] sb_biu_dat_i;
    wire [31:0] sb_biu_dat_o;
    wire sb_biu_cyc;
    wire sb_biu_stb;
    wire sb_biu_we;
    wire [3:0]  sb_biu_sel;
    wire sb_biu_ack;
    wire sb_biu_err;
    wire sb_biu_rty;
`ifdef OR1200_WB_CAB
    wire sb_biu_cab;
`endif
`ifdef OR1200_WB_B3
    wire [2:0] sb_biu_cti;
    wire [1:0] sb_biu_bte;
`endif

    // ----------------------------------------------------------------
    // SPR bus signals
    wire [15:0] spr_addr;
    wire [31:0] spr_dat_cpu;
    wire spr_we;
    wire [31:0] spr_cs;

    // SPR return data from units
    wire [31:0] spr_dat_immu;
    wire [31:0] spr_dat_dmmu;
    wire [31:0] spr_dat_ic;
    wire [31:0] spr_dat_dc;
    wire [31:0] spr_dat_du;
    wire [31:0] spr_dat_pic;
    wire [31:0] spr_dat_tt;
    wire [31:0] spr_dat_pm;

    // ----------------------------------------------------------------
    // Interrupt signals
    wire sig_int;
    wire sig_tick;

    // ----------------------------------------------------------------
    // Debug Unit <-> CPU signals
    wire du_stall;
    wire [31:0] du_addr;
    wire [31:0] du_dat_du;
    wire du_read;
    wire du_write;
    wire [5:0] du_except;
    wire [11:0] du_hwbkpt;

    // ================================================================
    // Instantiate OR1200 CPU
    // ================================================================
    or1200_cpu u_or1200_cpu (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        // Instruction interface
        .insn_adr_o     (cpu_insn_adr),
        .insn_dat_i     (cpu_insn_data),
        .insn_cyc_o     (cpu_insn_cyc),
        .insn_stb_o     (cpu_insn_stb),
        .insn_we_o      (cpu_insn_we),
        .insn_sel_o     (cpu_insn_sel),
        .insn_tag_o     (cpu_insn_tag),
        // Data interface
        .data_adr_o     (cpu_data_adr),
        .data_dat_i     (cpu_data_dat_i),
        .data_dat_o     (cpu_data_dat_o),
        .data_cyc_o     (cpu_data_cyc),
        .data_stb_o     (cpu_data_stb),
        .data_we_o      (cpu_data_we),
        .data_sel_o     (cpu_data_sel),
        .data_tag_o     (cpu_data_tag),
        // SPR interface
        .spr_addr_o     (spr_addr),
        .spr_dat_o      (spr_dat_cpu),
        .spr_we_o       (spr_we),
        .spr_cs_o       (spr_cs),
        .spr_dat_i      (spr_dat_immu | spr_dat_dmmu | spr_dat_ic |
                         spr_dat_dc | spr_dat_du | spr_dat_pic |
                         spr_dat_tt | spr_dat_pm),
        // Interrupts
        .sig_int_i      (sig_int),
        .sig_tick_i     (sig_tick),
        // Debug interface
        .du_stall_i     (du_stall),
        .du_addr_i      (du_addr),
        .du_dat_i       (du_dat_du),
        .du_read_i      (du_read),
        .du_write_i     (du_write),
        .du_except_o    (du_except),
        .du_hwbkpt_o    (du_hwbkpt)
    );

    // ================================================================
    // Instantiate Instruction MMU
    // ================================================================
    or1200_immu_top u_or1200_immu (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .cpu_adr_i      (cpu_insn_adr),
        .cpu_cyc_i      (cpu_insn_cyc),
        .cpu_stb_i      (cpu_insn_stb),
        .cpu_we_i       (cpu_insn_we),
        .cpu_sel_i      (cpu_insn_sel),
        .cpu_tag_i      (cpu_insn_tag),
        .cpu_dat_i      (32'h0),
        .cpu_dat_o      (cpu_insn_data),
        .mmu_adr_o      (immu_insn_adr),
        .mmu_cyc_o      (immu_insn_cyc),
        .mmu_stb_o      (immu_insn_stb),
        .mmu_we_o       (immu_insn_we),
        .mmu_sel_o      (immu_insn_sel),
        .mmu_tag_o      (immu_insn_tag),
        .mmu_dat_o      (),
        .mmu_dat_i      (immu_insn_data),
        .mmu_err_i      (immu_insn_err),
        .mmu_ack_i      (immu_insn_ack),
        .mmu_rty_i      (immu_insn_rty),
        .spr_cs_i       (spr_cs[2]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_immu)
    );

    // ================================================================
    // Instantiate Instruction QMEM
    // ================================================================
    or1200_qmem_top u_or1200_qmem_insn (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .qmem_adr_i     (immu_insn_adr),
        .qmem_cyc_i     (immu_insn_cyc),
        .qmem_stb_i     (immu_insn_stb),
        .qmem_we_i      (immu_insn_we),
        .qmem_sel_i     (immu_insn_sel),
        .qmem_tag_i     (immu_insn_tag),
        .qmem_dat_i     (32'h0),
        .qmem_dat_o     (immu_insn_data),
        .qmem_err_o     (immu_insn_err),
        .qmem_ack_o     (immu_insn_ack),
        .qmem_rty_o     (immu_insn_rty),
        .icpu_adr_o     (qmem_ic_adr),
        .icpu_cyc_o     (qmem_ic_cyc),
        .icpu_stb_o     (qmem_ic_stb),
        .icpu_we_o      (qmem_ic_we),
        .icpu_sel_o     (qmem_ic_sel),
        .icpu_tag_o     (qmem_ic_tag),
        .icpu_dat_o     (),
        .icpu_dat_i     (qmem_ic_data),
        .icpu_ack_i     (qmem_ic_ack),
        .icpu_err_i     (qmem_ic_err),
        .icpu_rty_i     (qmem_ic_rty)
    );

    // ================================================================
    // Instantiate Instruction Cache
    // ================================================================
    or1200_ic_top u_or1200_ic (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .icpu_adr_i     (qmem_ic_adr),
        .icpu_cyc_i     (qmem_ic_cyc),
        .icpu_stb_i     (qmem_ic_stb),
        .icpu_we_i      (qmem_ic_we),
        .icpu_sel_i     (qmem_ic_sel),
        .icpu_tag_i     (qmem_ic_tag),
        .icpu_dat_i     (32'h0),
        .icpu_dat_o     (qmem_ic_data),
        .icpu_ack_o     (qmem_ic_ack),
        .icpu_err_o     (qmem_ic_err),
        .icpu_rty_o     (qmem_ic_rty),
        .biu_adr_o      (ic_biu_adr),
        .biu_cyc_o      (ic_biu_cyc),
        .biu_stb_o      (ic_biu_stb),
        .biu_we_o       (ic_biu_we),
        .biu_sel_o      (ic_biu_sel),
        .biu_dat_o      (ic_biu_dat_o),
        .biu_dat_i      (ic_biu_dat_i),
        .biu_ack_i      (ic_biu_ack),
        .biu_err_i      (ic_biu_err),
        .biu_rty_i      (ic_biu_rty),
`ifdef OR1200_WB_CAB
        .biu_cab_o      (ic_biu_cab),
`endif
`ifdef OR1200_WB_B3
        .biu_cti_o      (ic_biu_cti),
        .biu_bte_o      (ic_biu_bte),
`endif
        .spr_cs_i       (spr_cs[4]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_ic)
    );

    // ================================================================
    // Instantiate Instruction Wishbone BIU
    // ================================================================
    or1200_wb_biu u_or1200_iwb_biu (
        .clk_i          (iwb_clk_i),
        .rst_i          (iwb_rst_i),
        .clmode_i       (clmode_i),
        .biu_adr_i      (ic_biu_adr),
        .biu_cyc_i      (ic_biu_cyc),
        .biu_stb_i      (ic_biu_stb),
        .biu_we_i       (ic_biu_we),
        .biu_sel_i      (ic_biu_sel),
        .biu_dat_i      (ic_biu_dat_o),
        .biu_dat_o      (ic_biu_dat_i),
        .biu_ack_o      (ic_biu_ack),
        .biu_err_o      (ic_biu_err),
        .biu_rty_o      (ic_biu_rty),
`ifdef OR1200_WB_CAB
        .biu_cab_i      (ic_biu_cab),
`endif
`ifdef OR1200_WB_B3
        .biu_cti_i      (ic_biu_cti),
        .biu_bte_i      (ic_biu_bte),
`endif
        .wb_cyc_o       (iwb_cyc_o),
        .wb_adr_o       (iwb_adr_o),
        .wb_stb_o       (iwb_stb_o),
        .wb_we_o        (iwb_we_o),
        .wb_sel_o       (iwb_sel_o),
        .wb_dat_o       (iwb_dat_o),
        .wb_dat_i       (iwb_dat_i),
        .wb_ack_i       (iwb_ack_i),
        .wb_err_i       (iwb_err_i),
        .wb_rty_i       (iwb_rty_i)
`ifdef OR1200_WB_CAB
        ,.wb_cab_o      (iwb_cab_o)
`endif
`ifdef OR1200_WB_B3
        ,.wb_cti_o      (iwb_cti_o),
        .wb_bte_o       (iwb_bte_o)
`endif
    );

    // ================================================================
    // Instantiate Data MMU
    // ================================================================
    or1200_dmmu_top u_or1200_dmmu (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .cpu_adr_i      (cpu_data_adr),
        .cpu_cyc_i      (cpu_data_cyc),
        .cpu_stb_i      (cpu_data_stb),
        .cpu_we_i       (cpu_data_we),
        .cpu_sel_i      (cpu_data_sel),
        .cpu_tag_i      (cpu_data_tag),
        .cpu_dat_i      (cpu_data_dat_o),
        .cpu_dat_o      (cpu_data_dat_i),
        .mmu_adr_o      (dmmu_data_adr),
        .mmu_cyc_o      (dmmu_data_cyc),
        .mmu_stb_o      (dmmu_data_stb),
        .mmu_we_o       (dmmu_data_we),
        .mmu_sel_o      (dmmu_data_sel),
        .mmu_tag_o      (dmmu_data_tag),
        .mmu_dat_o      (dmmu_data_dat_o),
        .mmu_dat_i      (dmmu_data_dat_i),
        .mmu_err_i      (dmmu_data_err),
        .mmu_ack_i      (dmmu_data_ack),
        .mmu_rty_i      (dmmu_data_rty),
        .spr_cs_i       (spr_cs[1]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_dmmu)
    );

    // ================================================================
    // Instantiate Data QMEM
    // ================================================================
    or1200_qmem_top u_or1200_qmem_data (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .qmem_adr_i     (dmmu_data_adr),
        .qmem_cyc_i     (dmmu_data_cyc),
        .qmem_stb_i     (dmmu_data_stb),
        .qmem_we_i      (dmmu_data_we),
        .qmem_sel_i     (dmmu_data_sel),
        .qmem_tag_i     (dmmu_data_tag),
        .qmem_dat_i     (dmmu_data_dat_o),
        .qmem_dat_o     (dmmu_data_dat_i),
        .qmem_err_o     (dmmu_data_err),
        .qmem_ack_o     (dmmu_data_ack),
        .qmem_rty_o     (dmmu_data_rty),
        .icpu_adr_o     (qmem_dc_adr),
        .icpu_cyc_o     (qmem_dc_cyc),
        .icpu_stb_o     (qmem_dc_stb),
        .icpu_we_o      (qmem_dc_we),
        .icpu_sel_o     (qmem_dc_sel),
        .icpu_tag_o     (qmem_dc_tag),
        .icpu_dat_o     (qmem_dc_dat_o),
        .icpu_dat_i     (qmem_dc_dat_i),
        .icpu_ack_i     (qmem_dc_ack),
        .icpu_err_i     (qmem_dc_err),
        .icpu_rty_i     (qmem_dc_rty)
    );

    // ================================================================
    // Instantiate Data Cache
    // ================================================================
    or1200_dc_top u_or1200_dc (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .dcpu_adr_i     (qmem_dc_adr),
        .dcpu_cyc_i     (qmem_dc_cyc),
        .dcpu_stb_i     (qmem_dc_stb),
        .dcpu_we_i      (qmem_dc_we),
        .dcpu_sel_i     (qmem_dc_sel),
        .dcpu_tag_i     (qmem_dc_tag),
        .dcpu_dat_i     (qmem_dc_dat_o),
        .dcpu_dat_o     (qmem_dc_dat_i),
        .dcpu_ack_o     (qmem_dc_ack),
        .dcpu_err_o     (qmem_dc_err),
        .dcpu_rty_o     (qmem_dc_rty),
        .sb_adr_o       (dc_sb_adr),
        .sb_cyc_o       (dc_sb_cyc),
        .sb_stb_o       (dc_sb_stb),
        .sb_we_o        (dc_sb_we),
        .sb_sel_o       (dc_sb_sel),
        .sb_dat_o       (dc_sb_dat_o),
        .sb_dat_i       (dc_sb_dat_i),
        .sb_ack_i       (dc_sb_ack),
        .sb_err_i       (dc_sb_err),
        .sb_rty_i       (dc_sb_rty),
        .spr_cs_i       (spr_cs[3]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_dc)
    );

    // ================================================================
    // Instantiate Store Buffer
    // ================================================================
    or1200_sb u_or1200_sb (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .sb_adr_i       (dc_sb_adr),
        .sb_cyc_i       (dc_sb_cyc),
        .sb_stb_i       (dc_sb_stb),
        .sb_we_i        (dc_sb_we),
        .sb_sel_i       (dc_sb_sel),
        .sb_dat_i       (dc_sb_dat_o),
        .sb_dat_o       (dc_sb_dat_i),
        .sb_ack_o       (dc_sb_ack),
        .sb_err_o       (dc_sb_err),
        .sb_rty_o       (dc_sb_rty),
        .biu_adr_o      (sb_biu_adr),
        .biu_cyc_o      (sb_biu_cyc),
        .biu_stb_o      (sb_biu_stb),
        .biu_we_o       (sb_biu_we),
        .biu_sel_o      (sb_biu_sel),
        .biu_dat_o      (sb_biu_dat_o),
        .biu_dat_i      (sb_biu_dat_i),
        .biu_ack_i      (sb_biu_ack),
        .biu_err_i      (sb_biu_err),
        .biu_rty_i      (sb_biu_rty)
`ifdef OR1200_WB_CAB
        ,.biu_cab_o     (sb_biu_cab)
`endif
`ifdef OR1200_WB_B3
        ,.biu_cti_o     (sb_biu_cti),
        .biu_bte_o      (sb_biu_bte)
`endif
    );

    // ================================================================
    // Instantiate Data Wishbone BIU
    // ================================================================
    or1200_wb_biu u_or1200_dwb_biu (
        .clk_i          (dwb_clk_i),
        .rst_i          (dwb_rst_i),
        .clmode_i       (clmode_i),
        .biu_adr_i      (sb_biu_adr),
        .biu_cyc_i      (sb_biu_cyc),
        .biu_stb_i      (sb_biu_stb),
        .biu_we_i       (sb_biu_we),
        .biu_sel_i      (sb_biu_sel),
        .biu_dat_i      (sb_biu_dat_o),
        .biu_dat_o      (sb_biu_dat_i),
        .biu_ack_o      (sb_biu_ack),
        .biu_err_o      (sb_biu_err),
        .biu_rty_o      (sb_biu_rty),
`ifdef OR1200_WB_CAB
        .biu_cab_i      (sb_biu_cab),
`endif
`ifdef OR1200_WB_B3
        .biu_cti_i      (sb_biu_cti),
        .biu_bte_i      (sb_biu_bte),
`endif
        .wb_cyc_o       (dwb_cyc_o),
        .wb_adr_o       (dwb_adr_o),
        .wb_stb_o       (dwb_stb_o),
        .wb_we_o        (dwb_we_o),
        .wb_sel_o       (dwb_sel_o),
        .wb_dat_o       (dwb_dat_o),
        .wb_dat_i       (dwb_dat_i),
        .wb_ack_i       (dwb_ack_i),
        .wb_err_i       (dwb_err_i),
        .wb_rty_i       (dwb_rty_i)
`ifdef OR1200_WB_CAB
        ,.wb_cab_o      (dwb_cab_o)
`endif
`ifdef OR1200_WB_B3
        ,.wb_cti_o      (dwb_cti_o),
        .wb_bte_o       (dwb_bte_o)
`endif
    );

    // ================================================================
    // Instantiate Debug Unit
    // ================================================================
    or1200_du u_or1200_du (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .dbg_stall_i    (dbg_stall_i),
        .dbg_ewt_i      (dbg_ewt_i),
        .dbg_stb_i      (dbg_stb_i),
        .dbg_we_i       (dbg_we_i),
        .dbg_adr_i      (dbg_adr_i),
        .dbg_dat_i      (dbg_dat_i),
        .dbg_dat_o      (dbg_dat_o),
        .dbg_ack_o      (dbg_ack_o),
        .dbg_lss_o      (dbg_lss_o),
        .dbg_is_o       (dbg_is_o),
        .dbg_wp_o       (dbg_wp_o),
        .dbg_bp_o       (dbg_bp_o),
        .du_stall_o     (du_stall),
        .du_addr_o      (du_addr),
        .du_dat_o       (du_dat_du),
        .du_read_o      (du_read),
        .du_write_o     (du_write),
        .du_except_i    (du_except),
        .du_hwbkpt_i    (du_hwbkpt),
        .spr_cs_i       (spr_cs[6]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_du)
    );

    // ================================================================
    // Instantiate Programmable Interrupt Controller
    // ================================================================
    or1200_pic u_or1200_pic (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .pic_ints_i     (pic_ints_i),
        .sig_int_o      (sig_int),
        .pic_wakeup_o   (pic_wakeup),
        .spr_cs_i       (spr_cs[9]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_pic)
    );

    // ================================================================
    // Instantiate Tick Timer
    // ================================================================
    or1200_ticktimer u_or1200_ticktimer (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .sig_tick_o     (sig_tick),
        .spr_cs_i       (spr_cs[10]),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_tt)
    );

    // ================================================================
    // Instantiate Power Management Unit
    // ================================================================
    or1200_pm u_or1200_pm (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .pm_cpustall_i  (pm_cpustall_i),
        .pic_wakeup_i   (pic_wakeup),
        .spr_write_i    (spr_we),
        .spr_addr_i     (spr_addr),
        .spr_dat_i      (spr_dat_cpu),
        .spr_dat_o      (spr_dat_pm),
        .pm_clksd_o     (pm_clksd_o),
        .pm_dc_gate_o   (pm_dc_gate_o),
        .pm_ic_gate_o   (pm_ic_gate_o),
        .pm_dmmu_gate_o (pm_dmmu_gate_o),
        .pm_immu_gate_o (pm_immu_gate_o),
        .pm_tt_gate_o   (pm_tt_gate_o),
        .pm_cpu_gate_o  (pm_cpu_gate_o),
        .pm_wakeup_o    (pm_wakeup_o),
        .pm_lvolt_o     (pm_lvolt_o)
    );

    // ================================================================
    // MBIST scan chain connection (if enabled)
    // ================================================================
`ifdef OR1200_BIST
    wire mbist_immu_so;
    wire mbist_ic_so;
    wire mbist_qmem_so;
    wire mbist_dmmu_so;

    // IMMU MBIST
    or1200_immu_mbist u_immu_mbist (
        .mbist_si_i     (mbist_si_i),
        .mbist_so_o     (mbist_immu_so),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );

    // IC MBIST
    or1200_ic_mbist u_ic_mbist (
        .mbist_si_i     (mbist_immu_so),
        .mbist_so_o     (mbist_ic_so),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );

    // QMEM MBIST
    or1200_qmem_mbist u_qmem_mbist (
        .mbist_si_i     (mbist_ic_so),
        .mbist_so_o     (mbist_qmem_so),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );

    // DMMU MBIST
    or1200_dmmu_mbist u_dmmu_mbist (
        .mbist_si_i     (mbist_qmem_so),
        .mbist_so_o     (mbist_dmmu_so),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );

    // DC MBIST
    or1200_dc_mbist u_dc_mbist (
        .mbist_si_i     (mbist_dmmu_so),
        .mbist_so_o     (mbist_so_o),
        .mbist_ctrl_i   (mbist_ctrl_i)
    );
`endif

endmodule
