module or1200_top
#(
    parameter ppic_ints = 1
)
(
    input clk_i,
    input rst_i,
    input [ppic_ints-1:0] pic_ints_i,
    input [1:0] clmode_i,
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
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
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

wire iwb_clk;
wire iwb_rst;
wire dwb_clk;
wire dwb_rst;
assign iwb_clk = clk_i;
assign iwb_rst = rst_i;
assign dwb_clk = clk_i;
assign dwb_rst = rst_i;

wire [31:0] icpu_adr;
wire icpu_cycstb;
wire [3:0] icpu_sel;
wire [3:0] icpu_tag;
wire [31:0] icpu_dat;
wire icpu_ack;
wire icpu_err;
wire icpu_rty;

wire [31:0] dcpu_adr;
wire dcpu_cycstb;
wire dcpu_we;
wire [3:0] dcpu_sel;
wire [3:0] dcpu_tag;
wire [31:0] dcpu_dat_o;
wire [31:0] dcpu_dat_i;
wire dcpu_ack;
wire dcpu_err;
wire dcpu_rty;

wire [31:0] spr_addr;
wire [31:0] spr_dat_cpu;
wire spr_we;
wire [10:0] spr_cs;
wire [31:0] spr_dat_immu;
wire [31:0] spr_dat_dmmu;
wire [31:0] spr_dat_ic;
wire [31:0] spr_dat_dc;
wire [31:0] spr_dat_du;
wire [31:0] spr_dat_pic;
wire [31:0] spr_dat_tt;
wire [31:0] spr_dat_pm;

wire immu_spr_cs;
wire dmmu_spr_cs;
wire ic_spr_cs;
wire dc_spr_cs;
wire du_spr_cs;
wire pic_spr_cs;
wire tt_spr_cs;
assign immu_spr_cs = spr_cs[2];
assign dmmu_spr_cs = spr_cs[1];
assign ic_spr_cs = spr_cs[4];
assign dc_spr_cs = spr_cs[3];
assign du_spr_cs = spr_cs[6];
assign pic_spr_cs = spr_cs[9];
assign tt_spr_cs = spr_cs[10];

wire sig_int;
wire sig_tick;
wire pic_wakeup;

wire du_stall;
wire [31:0] du_addr;
wire [31:0] du_dat_du;
wire [31:0] du_dat_cpu;
wire du_read;
wire du_write;
wire du_except;
wire du_hwbkpt;

wire [31:0] immu_qmem_adr;
wire immu_qmem_cycstb;
wire [3:0] immu_qmem_sel;
wire [3:0] immu_qmem_tag;
wire [31:0] qmem_immu_dat;
wire qmem_immu_ack;
wire qmem_immu_err;
wire qmem_immu_rty;

wire [31:0] qmem_ic_adr;
wire qmem_ic_cycstb;
wire [3:0] qmem_ic_sel;
wire [3:0] qmem_ic_tag;
wire [31:0] ic_qmem_dat;
wire ic_qmem_ack;
wire ic_qmem_err;
wire ic_qmem_rty;

wire [31:0] ic_biu_adr;
wire ic_biu_cyc;
wire ic_biu_stb;
wire ic_biu_we;
wire [3:0] ic_biu_sel;
wire [31:0] ic_biu_dat_o;
wire [31:0] biu_ic_dat_i;
wire biu_ic_ack_i;
wire biu_ic_err_i;
wire biu_ic_rty_i;

wire [31:0] dmmu_qmem_adr;
wire dmmu_qmem_cycstb;
wire dmmu_qmem_we;
wire [3:0] dmmu_qmem_sel;
wire [3:0] dmmu_qmem_tag;
wire qmem_dmmu_ack;
wire qmem_dmmu_err;
wire qmem_dmmu_rty;

wire [31:0] qmem_dc_adr;
wire qmem_dc_cycstb;
wire qmem_dc_we;
wire [3:0] qmem_dc_sel;
wire [3:0] qmem_dc_tag;
wire [31:0] qmem_dc_dat_o;
wire [31:0] dc_qmem_dat_i;
wire dc_qmem_ack;
wire dc_qmem_err;
wire dc_qmem_rty;

wire [31:0] dc_sb_adr;
wire dc_sb_cyc;
wire dc_sb_stb;
wire dc_sb_we;
wire [3:0] dc_sb_sel;
wire [31:0] dc_sb_dat_o;
wire [31:0] sb_dc_dat_i;
wire sb_dc_ack_i;
wire sb_dc_err_i;
wire sb_dc_rty_i;

wire [31:0] sb_biu_adr;
wire sb_biu_cyc;
wire sb_biu_stb;
wire sb_biu_we;
wire [3:0] sb_biu_sel;
wire [31:0] sb_biu_dat_o;
wire [31:0] biu_sb_dat_i;
wire biu_sb_ack_i;
wire biu_sb_err_i;
wire biu_sb_rty_i;

`ifdef OR1200_BIST
wire mbist_immu_to_ic;
wire mbist_ic_to_qmem;
wire mbist_qmem_to_dmmu;
wire mbist_dmmu_to_dc;
`endif

or1200_cpu u_cpu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .icpu_adr_o(icpu_adr),
    .icpu_cycstb_o(icpu_cycstb),
    .icpu_sel_o(icpu_sel),
    .icpu_tag_o(icpu_tag),
    .icpu_dat_i(icpu_dat),
    .icpu_ack_i(icpu_ack),
    .icpu_err_i(icpu_err),
    .icpu_rty_i(icpu_rty),
    .dcpu_adr_o(dcpu_adr),
    .dcpu_cycstb_o(dcpu_cycstb),
    .dcpu_we_o(dcpu_we),
    .dcpu_sel_o(dcpu_sel),
    .dcpu_tag_o(dcpu_tag),
    .dcpu_dat_o(dcpu_dat_o),
    .dcpu_dat_i(dcpu_dat_i),
    .dcpu_ack_i(dcpu_ack),
    .dcpu_err_i(dcpu_err),
    .dcpu_rty_i(dcpu_rty),
    .spr_addr_o(spr_addr),
    .spr_dat_o(spr_dat_cpu),
    .spr_we_o(spr_we),
    .spr_cs_o(spr_cs),
    .spr_dat_immu_i(spr_dat_immu),
    .spr_dat_dmmu_i(spr_dat_dmmu),
    .spr_dat_ic_i(spr_dat_ic),
    .spr_dat_dc_i(spr_dat_dc),
    .spr_dat_du_i(spr_dat_du),
    .spr_dat_pic_i(spr_dat_pic),
    .spr_dat_tt_i(spr_dat_tt),
    .spr_dat_pm_i(spr_dat_pm),
    .sig_int_i(sig_int),
    .sig_tick_i(sig_tick),
    .du_stall_i(du_stall),
    .du_addr_i(du_addr),
    .du_dat_du_i(du_dat_du),
    .du_read_i(du_read),
    .du_write_i(du_write),
    .du_except_i(du_except),
    .du_hwbkpt_i(du_hwbkpt),
    .du_dat_cpu_o(du_dat_cpu),
    .dbg_lss_o(dbg_lss_o),
    .dbg_is_o(dbg_is_o),
    .dbg_wp_o(dbg_wp_o),
    .dbg_bp_o(dbg_bp_o)
);

or1200_immu_top u_immu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(icpu_adr),
    .cpu_cycstb_i(icpu_cycstb),
    .cpu_sel_i(icpu_sel),
    .cpu_tag_i(icpu_tag),
    .cpu_dat_o(icpu_dat),
    .cpu_ack_o(icpu_ack),
    .cpu_err_o(icpu_err),
    .cpu_rty_o(icpu_rty),
    .qmem_adr_o(immu_qmem_adr),
    .qmem_cycstb_o(immu_qmem_cycstb),
    .qmem_sel_o(immu_qmem_sel),
    .qmem_tag_o(immu_qmem_tag),
    .qmem_dat_i(qmem_immu_dat),
    .qmem_ack_i(qmem_immu_ack),
    .qmem_err_i(qmem_immu_err),
    .qmem_rty_i(qmem_immu_rty),
    .spr_cs_i(immu_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_immu)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_immu_to_ic),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_qmem_top u_qmem (
    .i_adr_i(immu_qmem_adr),
    .i_cycstb_i(immu_qmem_cycstb),
    .i_sel_i(immu_qmem_sel),
    .i_tag_i(immu_qmem_tag),
    .i_dat_o(qmem_immu_dat),
    .i_ack_o(qmem_immu_ack),
    .i_err_o(qmem_immu_err),
    .i_rty_o(qmem_immu_rty),
    .ic_adr_o(qmem_ic_adr),
    .ic_cycstb_o(qmem_ic_cycstb),
    .ic_sel_o(qmem_ic_sel),
    .ic_tag_o(qmem_ic_tag),
    .ic_dat_i(ic_qmem_dat),
    .ic_ack_i(ic_qmem_ack),
    .ic_err_i(ic_qmem_err),
    .ic_rty_i(ic_qmem_rty),
    .d_adr_i(dmmu_qmem_adr),
    .d_cycstb_i(dmmu_qmem_cycstb),
    .d_we_i(dmmu_qmem_we),
    .d_sel_i(dmmu_qmem_sel),
    .d_tag_i(dmmu_qmem_tag),
    .d_wdat_i(dcpu_dat_o),
    .d_rdat_o(dcpu_dat_i),
    .d_ack_o(qmem_dmmu_ack),
    .d_err_o(qmem_dmmu_err),
    .d_rty_o(qmem_dmmu_rty),
    .dc_adr_o(qmem_dc_adr),
    .dc_cycstb_o(qmem_dc_cycstb),
    .dc_we_o(qmem_dc_we),
    .dc_sel_o(qmem_dc_sel),
    .dc_tag_o(qmem_dc_tag),
    .dc_wdat_o(qmem_dc_dat_o),
    .dc_rdat_i(dc_qmem_dat_i),
    .dc_ack_i(dc_qmem_ack),
    .dc_err_i(dc_qmem_err),
    .dc_rty_i(dc_qmem_rty)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_ic_to_qmem),
    .mbist_so_o(mbist_qmem_to_dmmu),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_ic_top u_ic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .qmem_adr_i(qmem_ic_adr),
    .qmem_cycstb_i(qmem_ic_cycstb),
    .qmem_sel_i(qmem_ic_sel),
    .qmem_tag_i(qmem_ic_tag),
    .qmem_dat_o(ic_qmem_dat),
    .qmem_ack_o(ic_qmem_ack),
    .qmem_err_o(ic_qmem_err),
    .qmem_rty_o(ic_qmem_rty),
    .biu_adr_o(ic_biu_adr),
    .biu_cyc_o(ic_biu_cyc),
    .biu_stb_o(ic_biu_stb),
    .biu_we_o(ic_biu_we),
    .biu_sel_o(ic_biu_sel),
    .biu_dat_o(ic_biu_dat_o),
    .biu_dat_i(biu_ic_dat_i),
    .biu_ack_i(biu_ic_ack_i),
    .biu_err_i(biu_ic_err_i),
    .biu_rty_i(biu_ic_rty_i),
    .spr_cs_i(ic_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_ic)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_immu_to_ic),
    .mbist_so_o(mbist_ic_to_qmem),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_wb_biu u_iwb_biu (
    .clk_i(iwb_clk),
    .rst_i(iwb_rst),
    .clmode_i(clmode_i),
    .biu_adr_i(ic_biu_adr),
    .biu_cyc_i(ic_biu_cyc),
    .biu_stb_i(ic_biu_stb),
    .biu_we_i(ic_biu_we),
    .biu_sel_i(ic_biu_sel),
    .biu_dat_i(ic_biu_dat_o),
    .biu_dat_o(biu_ic_dat_i),
    .biu_ack_o(biu_ic_ack_i),
    .biu_err_o(biu_ic_err_i),
    .biu_rty_o(biu_ic_rty_i),
    .wb_ack_i(iwb_ack_i),
    .wb_err_i(iwb_err_i),
    .wb_rty_i(iwb_rty_i),
    .wb_dat_i(iwb_dat_i),
    .wb_cyc_o(iwb_cyc_o),
    .wb_adr_o(iwb_adr_o),
    .wb_stb_o(iwb_stb_o),
    .wb_we_o(iwb_we_o),
    .wb_sel_o(iwb_sel_o),
    .wb_dat_o(iwb_dat_o)
`ifdef OR1200_WB_CAB
    ,.wb_cab_o(iwb_cab_o)
`endif
`ifdef OR1200_WB_B3
    ,.wb_cti_o(iwb_cti_o),
    .wb_bte_o(iwb_bte_o)
`endif
);

or1200_dmmu_top u_dmmu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(dcpu_adr),
    .cpu_cycstb_i(dcpu_cycstb),
    .cpu_we_i(dcpu_we),
    .cpu_sel_i(dcpu_sel),
    .cpu_tag_i(dcpu_tag),
    .cpu_ack_o(dcpu_ack),
    .cpu_err_o(dcpu_err),
    .cpu_rty_o(dcpu_rty),
    .qmem_adr_o(dmmu_qmem_adr),
    .qmem_cycstb_o(dmmu_qmem_cycstb),
    .qmem_we_o(dmmu_qmem_we),
    .qmem_sel_o(dmmu_qmem_sel),
    .qmem_tag_o(dmmu_qmem_tag),
    .qmem_ack_i(qmem_dmmu_ack),
    .qmem_err_i(qmem_dmmu_err),
    .qmem_rty_i(qmem_dmmu_rty),
    .spr_cs_i(dmmu_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dmmu)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_qmem_to_dmmu),
    .mbist_so_o(mbist_dmmu_to_dc),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_dc_top u_dc (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .qmem_adr_i(qmem_dc_adr),
    .qmem_cycstb_i(qmem_dc_cycstb),
    .qmem_we_i(qmem_dc_we),
    .qmem_sel_i(qmem_dc_sel),
    .qmem_tag_i(qmem_dc_tag),
    .qmem_dat_i(qmem_dc_dat_o),
    .qmem_dat_o(dc_qmem_dat_i),
    .qmem_ack_o(dc_qmem_ack),
    .qmem_err_o(dc_qmem_err),
    .qmem_rty_o(dc_qmem_rty),
    .sb_adr_o(dc_sb_adr),
    .sb_cyc_o(dc_sb_cyc),
    .sb_stb_o(dc_sb_stb),
    .sb_we_o(dc_sb_we),
    .sb_sel_o(dc_sb_sel),
    .sb_dat_o(dc_sb_dat_o),
    .sb_dat_i(sb_dc_dat_i),
    .sb_ack_i(sb_dc_ack_i),
    .sb_err_i(sb_dc_err_i),
    .sb_rty_i(sb_dc_rty_i),
    .spr_cs_i(dc_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dc)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_dmmu_to_dc),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_sb u_sb (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .dc_adr_i(dc_sb_adr),
    .dc_cyc_i(dc_sb_cyc),
    .dc_stb_i(dc_sb_stb),
    .dc_we_i(dc_sb_we),
    .dc_sel_i(dc_sb_sel),
    .dc_dat_i(dc_sb_dat_o),
    .dc_dat_o(sb_dc_dat_i),
    .dc_ack_o(sb_dc_ack_i),
    .dc_err_o(sb_dc_err_i),
    .dc_rty_o(sb_dc_rty_i),
    .biu_adr_o(sb_biu_adr),
    .biu_cyc_o(sb_biu_cyc),
    .biu_stb_o(sb_biu_stb),
    .biu_we_o(sb_biu_we),
    .biu_sel_o(sb_biu_sel),
    .biu_dat_o(sb_biu_dat_o),
    .biu_dat_i(biu_sb_dat_i),
    .biu_ack_i(biu_sb_ack_i),
    .biu_err_i(biu_sb_err_i),
    .biu_rty_i(biu_sb_rty_i)
);

or1200_wb_biu u_dwb_biu (
    .clk_i(dwb_clk),
    .rst_i(dwb_rst),
    .clmode_i(clmode_i),
    .biu_adr_i(sb_biu_adr),
    .biu_cyc_i(sb_biu_cyc),
    .biu_stb_i(sb_biu_stb),
    .biu_we_i(sb_biu_we),
    .biu_sel_i(sb_biu_sel),
    .biu_dat_i(sb_biu_dat_o),
    .biu_dat_o(biu_sb_dat_i),
    .biu_ack_o(biu_sb_ack_i),
    .biu_err_o(biu_sb_err_i),
    .biu_rty_o(biu_sb_rty_i),
    .wb_ack_i(dwb_ack_i),
    .wb_err_i(dwb_err_i),
    .wb_rty_i(dwb_rty_i),
    .wb_dat_i(dwb_dat_i),
    .wb_cyc_o(dwb_cyc_o),
    .wb_adr_o(dwb_adr_o),
    .wb_stb_o(dwb_stb_o),
    .wb_we_o(dwb_we_o),
    .wb_sel_o(dwb_sel_o),
    .wb_dat_o(dwb_dat_o)
`ifdef OR1200_WB_CAB
    ,.wb_cab_o(dwb_cab_o)
`endif
`ifdef OR1200_WB_B3
    ,.wb_cti_o(dwb_cti_o),
    .wb_bte_o(dwb_bte_o)
`endif
);

or1200_du u_du (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .dbg_stall_i(dbg_stall_i),
    .dbg_ewt_i(dbg_ewt_i),
    .dbg_stb_i(dbg_stb_i),
    .dbg_we_i(dbg_we_i),
    .dbg_adr_i(dbg_adr_i),
    .dbg_dat_i(dbg_dat_i),
    .dbg_dat_o(dbg_dat_o),
    .dbg_ack_o(dbg_ack_o),
    .spr_cs_i(du_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_du),
    .du_stall_o(du_stall),
    .du_addr_o(du_addr),
    .du_dat_du_o(du_dat_du),
    .du_dat_cpu_i(du_dat_cpu),
    .du_read_o(du_read),
    .du_write_o(du_write),
    .du_except_o(du_except),
    .du_hwbkpt_o(du_hwbkpt)
);

or1200_pic
#(
    .ppic_ints(ppic_ints)
)
u_pic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pic_ints_i(pic_ints_i),
    .spr_cs_i(pic_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pic),
    .sig_int_o(sig_int),
    .pic_wakeup_o(pic_wakeup)
);

or1200_tt u_tt (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .spr_cs_i(tt_spr_cs),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_tt),
    .sig_tick_o(sig_tick)
);

or1200_pm u_pm (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pm_cpustall_i(pm_cpustall_i),
    .pic_wakeup_i(pic_wakeup),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pm),
    .pm_clksd_o(pm_clksd_o),
    .pm_dc_gate_o(pm_dc_gate_o),
    .pm_ic_gate_o(pm_ic_gate_o),
    .pm_dmmu_gate_o(pm_dmmu_gate_o),
    .pm_immu_gate_o(pm_immu_gate_o),
    .pm_tt_gate_o(pm_tt_gate_o),
    .pm_cpu_gate_o(pm_cpu_gate_o),
    .pm_wakeup_o(pm_wakeup_o),
    .pm_lvolt_o(pm_lvolt_o)
);

endmodule

module or1200_cpu(
    input clk_i,
    input rst_i,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_err_i,
    input icpu_rty_i,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_err_i,
    input dcpu_rty_i,
    output [31:0] spr_addr_o,
    output [31:0] spr_dat_o,
    output spr_we_o,
    output [10:0] spr_cs_o,
    input [31:0] spr_dat_immu_i,
    input [31:0] spr_dat_dmmu_i,
    input [31:0] spr_dat_ic_i,
    input [31:0] spr_dat_dc_i,
    input [31:0] spr_dat_du_i,
    input [31:0] spr_dat_pic_i,
    input [31:0] spr_dat_tt_i,
    input [31:0] spr_dat_pm_i,
    input sig_int_i,
    input sig_tick_i,
    input du_stall_i,
    input [31:0] du_addr_i,
    input [31:0] du_dat_du_i,
    input du_read_i,
    input du_write_i,
    input du_except_i,
    input du_hwbkpt_i,
    output [31:0] du_dat_cpu_o,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o
);
assign icpu_adr_o = 32'b0;
assign icpu_cycstb_o = 1'b0;
assign icpu_sel_o = 4'b0000;
assign icpu_tag_o = 4'b0000;
assign dcpu_adr_o = 32'b0;
assign dcpu_cycstb_o = 1'b0;
assign dcpu_we_o = 1'b0;
assign dcpu_sel_o = 4'b0000;
assign dcpu_tag_o = 4'b0000;
assign dcpu_dat_o = 32'b0;
assign spr_addr_o = du_addr_i;
assign spr_dat_o = du_write_i ? du_dat_du_i : 32'b0;
assign spr_we_o = du_write_i & ~du_stall_i;
assign spr_cs_o = 11'b0;
assign du_dat_cpu_o = spr_dat_immu_i | spr_dat_dmmu_i | spr_dat_ic_i | spr_dat_dc_i |
                      spr_dat_du_i | spr_dat_pic_i | spr_dat_tt_i | spr_dat_pm_i;
assign dbg_lss_o = 4'b0000;
assign dbg_is_o = {sig_int_i, sig_tick_i};
assign dbg_wp_o = {11{du_read_i | du_write_i}};
assign dbg_bp_o = du_hwbkpt_i | du_except_i;
endmodule

module or1200_immu_top(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_cycstb_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    output [31:0] cpu_dat_o,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    output [31:0] qmem_adr_o,
    output qmem_cycstb_o,
    output [3:0] qmem_sel_o,
    output [3:0] qmem_tag_o,
    input [31:0] qmem_dat_i,
    input qmem_ack_i,
    input qmem_err_i,
    input qmem_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign cpu_dat_o = qmem_dat_i;
assign cpu_ack_o = qmem_ack_i;
assign cpu_err_o = qmem_err_i;
assign cpu_rty_o = qmem_rty_i;
assign qmem_adr_o = cpu_adr_i;
assign qmem_cycstb_o = cpu_cycstb_i;
assign qmem_sel_o = cpu_sel_i;
assign qmem_tag_o = cpu_tag_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_qmem_top(
    input [31:0] i_adr_i,
    input i_cycstb_i,
    input [3:0] i_sel_i,
    input [3:0] i_tag_i,
    output [31:0] i_dat_o,
    output i_ack_o,
    output i_err_o,
    output i_rty_o,
    output [31:0] ic_adr_o,
    output ic_cycstb_o,
    output [3:0] ic_sel_o,
    output [3:0] ic_tag_o,
    input [31:0] ic_dat_i,
    input ic_ack_i,
    input ic_err_i,
    input ic_rty_i,
    input [31:0] d_adr_i,
    input d_cycstb_i,
    input d_we_i,
    input [3:0] d_sel_i,
    input [3:0] d_tag_i,
    input [31:0] d_wdat_i,
    output [31:0] d_rdat_o,
    output d_ack_o,
    output d_err_o,
    output d_rty_o,
    output [31:0] dc_adr_o,
    output dc_cycstb_o,
    output dc_we_o,
    output [3:0] dc_sel_o,
    output [3:0] dc_tag_o,
    output [31:0] dc_wdat_o,
    input [31:0] dc_rdat_i,
    input dc_ack_i,
    input dc_err_i,
    input dc_rty_i
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign i_dat_o = ic_dat_i;
assign i_ack_o = ic_ack_i;
assign i_err_o = ic_err_i;
assign i_rty_o = ic_rty_i;
assign ic_adr_o = i_adr_i;
assign ic_cycstb_o = i_cycstb_i;
assign ic_sel_o = i_sel_i;
assign ic_tag_o = i_tag_i;
assign d_rdat_o = dc_rdat_i;
assign d_ack_o = dc_ack_i;
assign d_err_o = dc_err_i;
assign d_rty_o = dc_rty_i;
assign dc_adr_o = d_adr_i;
assign dc_cycstb_o = d_cycstb_i;
assign dc_we_o = d_we_i;
assign dc_sel_o = d_sel_i;
assign dc_tag_o = d_tag_i;
assign dc_wdat_o = d_wdat_i;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_ic_top(
    input clk_i,
    input rst_i,
    input [31:0] qmem_adr_i,
    input qmem_cycstb_i,
    input [3:0] qmem_sel_i,
    input [3:0] qmem_tag_i,
    output [31:0] qmem_dat_o,
    output qmem_ack_o,
    output qmem_err_o,
    output qmem_rty_o,
    output [31:0] biu_adr_o,
    output biu_cyc_o,
    output biu_stb_o,
    output biu_we_o,
    output [3:0] biu_sel_o,
    output [31:0] biu_dat_o,
    input [31:0] biu_dat_i,
    input biu_ack_i,
    input biu_err_i,
    input biu_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign qmem_dat_o = biu_dat_i;
assign qmem_ack_o = biu_ack_i;
assign qmem_err_o = biu_err_i;
assign qmem_rty_o = biu_rty_i;
assign biu_adr_o = qmem_adr_i;
assign biu_cyc_o = qmem_cycstb_i;
assign biu_stb_o = qmem_cycstb_i;
assign biu_we_o = 1'b0;
assign biu_sel_o = qmem_sel_i;
assign biu_dat_o = 32'b0;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_wb_biu(
    input clk_i,
    input rst_i,
    input [1:0] clmode_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input [31:0] biu_dat_i,
    output [31:0] biu_dat_o,
    output biu_ack_o,
    output biu_err_o,
    output biu_rty_o,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input [31:0] wb_dat_i,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o
`ifdef OR1200_WB_CAB
    ,output wb_cab_o
`endif
`ifdef OR1200_WB_B3
    ,output [2:0] wb_cti_o,
    output [1:0] wb_bte_o
`endif
);
assign biu_dat_o = wb_dat_i;
assign biu_ack_o = wb_ack_i;
assign biu_err_o = wb_err_i;
assign biu_rty_o = wb_rty_i;
assign wb_cyc_o = biu_cyc_i;
assign wb_adr_o = biu_adr_i;
assign wb_stb_o = biu_stb_i;
assign wb_we_o = biu_we_i;
assign wb_sel_o = biu_sel_i;
assign wb_dat_o = biu_dat_i;
`ifdef OR1200_WB_CAB
assign wb_cab_o = 1'b0;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b00;
`endif
endmodule

module or1200_dmmu_top(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_cycstb_i,
    input cpu_we_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    output [31:0] qmem_adr_o,
    output qmem_cycstb_o,
    output qmem_we_o,
    output [3:0] qmem_sel_o,
    output [3:0] qmem_tag_o,
    input qmem_ack_i,
    input qmem_err_i,
    input qmem_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign cpu_ack_o = qmem_ack_i;
assign cpu_err_o = qmem_err_i;
assign cpu_rty_o = qmem_rty_i;
assign qmem_adr_o = cpu_adr_i;
assign qmem_cycstb_o = cpu_cycstb_i;
assign qmem_we_o = cpu_we_i;
assign qmem_sel_o = cpu_sel_i;
assign qmem_tag_o = cpu_tag_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_dc_top(
    input clk_i,
    input rst_i,
    input [31:0] qmem_adr_i,
    input qmem_cycstb_i,
    input qmem_we_i,
    input [3:0] qmem_sel_i,
    input [3:0] qmem_tag_i,
    input [31:0] qmem_dat_i,
    output [31:0] qmem_dat_o,
    output qmem_ack_o,
    output qmem_err_o,
    output qmem_rty_o,
    output [31:0] sb_adr_o,
    output sb_cyc_o,
    output sb_stb_o,
    output sb_we_o,
    output [3:0] sb_sel_o,
    output [31:0] sb_dat_o,
    input [31:0] sb_dat_i,
    input sb_ack_i,
    input sb_err_i,
    input sb_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign qmem_dat_o = sb_dat_i;
assign qmem_ack_o = sb_ack_i;
assign qmem_err_o = sb_err_i;
assign qmem_rty_o = sb_rty_i;
assign sb_adr_o = qmem_adr_i;
assign sb_cyc_o = qmem_cycstb_i;
assign sb_stb_o = qmem_cycstb_i;
assign sb_we_o = qmem_we_i;
assign sb_sel_o = qmem_sel_i;
assign sb_dat_o = qmem_dat_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_sb(
    input clk_i,
    input rst_i,
    input [31:0] dc_adr_i,
    input dc_cyc_i,
    input dc_stb_i,
    input dc_we_i,
    input [3:0] dc_sel_i,
    input [31:0] dc_dat_i,
    output [31:0] dc_dat_o,
    output dc_ack_o,
    output dc_err_o,
    output dc_rty_o,
    output [31:0] biu_adr_o,
    output biu_cyc_o,
    output biu_stb_o,
    output biu_we_o,
    output [3:0] biu_sel_o,
    output [31:0] biu_dat_o,
    input [31:0] biu_dat_i,
    input biu_ack_i,
    input biu_err_i,
    input biu_rty_i
);
assign dc_dat_o = biu_dat_i;
assign dc_ack_o = biu_ack_i;
assign dc_err_o = biu_err_i;
assign dc_rty_o = biu_rty_i;
assign biu_adr_o = dc_adr_i;
assign biu_cyc_o = dc_cyc_i;
assign biu_stb_o = dc_stb_i;
assign biu_we_o = dc_we_i;
assign biu_sel_o = dc_sel_i;
assign biu_dat_o = dc_dat_i;
endmodule

module or1200_du(
    input clk_i,
    input rst_i,
    input dbg_stall_i,
    input dbg_ewt_i,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output du_stall_o,
    output [31:0] du_addr_o,
    output [31:0] du_dat_du_o,
    input [31:0] du_dat_cpu_i,
    output du_read_o,
    output du_write_o,
    output du_except_o,
    output du_hwbkpt_o
);
assign dbg_dat_o = du_dat_cpu_i;
assign dbg_ack_o = dbg_stb_i;
assign spr_dat_o = 32'b0;
assign du_stall_o = dbg_stall_i;
assign du_addr_o = dbg_adr_i;
assign du_dat_du_o = dbg_dat_i;
assign du_read_o = dbg_stb_i & ~dbg_we_i;
assign du_write_o = dbg_stb_i & dbg_we_i;
assign du_except_o = 1'b0;
assign du_hwbkpt_o = dbg_ewt_i;
endmodule

module or1200_pic
#(
    parameter ppic_ints = 1
)
(
    input clk_i,
    input rst_i,
    input [ppic_ints-1:0] pic_ints_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output sig_int_o,
    output pic_wakeup_o
);
assign spr_dat_o = 32'b0;
assign sig_int_o = |pic_ints_i;
assign pic_wakeup_o = |pic_ints_i;
endmodule

module or1200_tt(
    input clk_i,
    input rst_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output sig_tick_o
);
assign spr_dat_o = 32'b0;
assign sig_tick_o = 1'b0;
endmodule

module or1200_pm(
    input clk_i,
    input rst_i,
    input pm_cpustall_i,
    input pic_wakeup_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
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
assign spr_dat_o = 32'b0;
assign pm_clksd_o = {3'b000, pm_cpustall_i};
assign pm_dc_gate_o = 1'b0;
assign pm_ic_gate_o = 1'b0;
assign pm_dmmu_gate_o = 1'b0;
assign pm_immu_gate_o = 1'b0;
assign pm_tt_gate_o = 1'b0;
assign pm_cpu_gate_o = pm_cpustall_i;
assign pm_wakeup_o = pic_wakeup_i;
assign pm_lvolt_o = 1'b0;
endmodule
