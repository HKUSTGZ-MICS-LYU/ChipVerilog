module or1200_top #(parameter ppic_ints = 1) (
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

wire iwb_clk_int = clk_i;
wire iwb_rst_int = rst_i;
wire dwb_clk_int = clk_i;
wire dwb_rst_int = rst_i;

wire [31:0] cpu_i_adr;
wire cpu_i_req;
wire [3:0] cpu_i_sel;
wire [3:0] cpu_i_tag;
wire [31:0] cpu_i_dat;
wire cpu_i_ack;
wire cpu_i_err;
wire cpu_i_rty;

wire [31:0] immu_i_adr;
wire immu_i_req;
wire [3:0] immu_i_sel;
wire [3:0] immu_i_tag;
wire [31:0] immu_i_dat;
wire immu_i_ack;
wire immu_i_err;
wire immu_i_rty;

wire [31:0] qmem_i_adr;
wire qmem_i_req;
wire [3:0] qmem_i_sel;
wire [3:0] qmem_i_tag;
wire [31:0] qmem_i_dat;
wire qmem_i_ack;
wire qmem_i_err;
wire qmem_i_rty;

wire ic_wb_cyc;
wire [31:0] ic_wb_adr;
wire ic_wb_stb;
wire ic_wb_we;
wire [3:0] ic_wb_sel;
wire [31:0] ic_wb_dat_o;
wire [31:0] ic_wb_dat_i;
wire ic_wb_ack;
wire ic_wb_err;
wire ic_wb_rty;

wire [31:0] cpu_d_adr;
wire cpu_d_req;
wire cpu_d_we;
wire [3:0] cpu_d_sel;
wire [3:0] cpu_d_tag;
wire [31:0] cpu_d_dat_o;
wire [31:0] cpu_d_dat_i;
wire cpu_d_ack;
wire cpu_d_err;
wire cpu_d_rty;

wire [31:0] dmmu_d_adr;
wire dmmu_d_req;
wire dmmu_d_we;
wire [3:0] dmmu_d_sel;
wire [3:0] dmmu_d_tag;
wire [31:0] dmmu_d_dat_i;
wire dmmu_d_ack;
wire dmmu_d_err;
wire dmmu_d_rty;

wire [31:0] qmem_d_adr;
wire qmem_d_req;
wire qmem_d_we;
wire [3:0] qmem_d_sel;
wire [3:0] qmem_d_tag;
wire [31:0] qmem_d_dat_o;
wire [31:0] qmem_d_dat_i;
wire qmem_d_ack;
wire qmem_d_err;
wire qmem_d_rty;

wire dc_wb_cyc;
wire [31:0] dc_wb_adr;
wire dc_wb_stb;
wire dc_wb_we;
wire [3:0] dc_wb_sel;
wire [31:0] dc_wb_dat_o;
wire [31:0] dc_wb_dat_i;
wire dc_wb_ack;
wire dc_wb_err;
wire dc_wb_rty;

wire sb_wb_cyc;
wire [31:0] sb_wb_adr;
wire sb_wb_stb;
wire sb_wb_we;
wire [3:0] sb_wb_sel;
wire [31:0] sb_wb_dat_o;
wire [31:0] sb_wb_dat_i;
wire sb_wb_ack;
wire sb_wb_err;
wire sb_wb_rty;

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
wire [31:0] spr_dat_mux;

wire du_stall;
wire [31:0] du_addr;
wire [31:0] du_dat_du;
wire du_read;
wire du_write;
wire du_except;
wire du_hwbkpt;

wire sig_int;
wire sig_tick;
wire pic_wakeup;

`ifdef OR1200_BIST
wire mbist_immu_so;
wire mbist_ic_so;
wire mbist_qmem_so;
wire mbist_dmmu_so;
`endif

assign spr_dat_mux = spr_cs[2]  ? spr_dat_immu :
                     spr_cs[1]  ? spr_dat_dmmu :
                     spr_cs[4]  ? spr_dat_ic   :
                     spr_cs[3]  ? spr_dat_dc   :
                     spr_cs[6]  ? spr_dat_du   :
                     spr_cs[9]  ? spr_dat_pic  :
                     spr_cs[10] ? spr_dat_tt   :
                                  spr_dat_pm;

or1200_cpu_stub u_cpu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .i_adr_o(cpu_i_adr),
    .i_req_o(cpu_i_req),
    .i_sel_o(cpu_i_sel),
    .i_tag_o(cpu_i_tag),
    .i_dat_i(cpu_i_dat),
    .i_ack_i(cpu_i_ack),
    .i_err_i(cpu_i_err),
    .i_rty_i(cpu_i_rty),
    .d_adr_o(cpu_d_adr),
    .d_req_o(cpu_d_req),
    .d_we_o(cpu_d_we),
    .d_sel_o(cpu_d_sel),
    .d_tag_o(cpu_d_tag),
    .d_dat_o(cpu_d_dat_o),
    .d_dat_i(cpu_d_dat_i),
    .d_ack_i(cpu_d_ack),
    .d_err_i(cpu_d_err),
    .d_rty_i(cpu_d_rty),
    .spr_addr_o(spr_addr),
    .spr_dat_o(spr_dat_cpu),
    .spr_we_o(spr_we),
    .spr_cs_o(spr_cs),
    .spr_dat_i(spr_dat_mux),
    .sig_int_i(sig_int),
    .sig_tick_i(sig_tick),
    .du_stall_i(du_stall),
    .du_addr_i(du_addr),
    .du_dat_i(du_dat_du),
    .du_read_i(du_read),
    .du_write_i(du_write),
    .du_except_i(du_except),
    .du_hwbkpt_i(du_hwbkpt),
    .dbg_lss_o(dbg_lss_o),
    .dbg_is_o(dbg_is_o),
    .dbg_wp_o(dbg_wp_o),
    .dbg_bp_o(dbg_bp_o)
);

or1200_immu_stub u_immu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(cpu_i_adr),
    .cpu_req_i(cpu_i_req),
    .cpu_sel_i(cpu_i_sel),
    .cpu_tag_i(cpu_i_tag),
    .qmem_adr_o(immu_i_adr),
    .qmem_req_o(immu_i_req),
    .qmem_sel_o(immu_i_sel),
    .qmem_tag_o(immu_i_tag),
    .qmem_dat_i(immu_i_dat),
    .qmem_ack_i(immu_i_ack),
    .qmem_err_i(immu_i_err),
    .qmem_rty_i(immu_i_rty),
    .cpu_dat_o(cpu_i_dat),
    .cpu_ack_o(cpu_i_ack),
    .cpu_err_o(cpu_i_err),
    .cpu_rty_o(cpu_i_rty),
    .spr_cs_i(spr_cs[2]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_immu)
`ifdef OR1200_BIST
   ,.mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_immu_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_dmmu_stub u_dmmu (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(cpu_d_adr),
    .cpu_req_i(cpu_d_req),
    .cpu_we_i(cpu_d_we),
    .cpu_sel_i(cpu_d_sel),
    .cpu_tag_i(cpu_d_tag),
    .qmem_adr_o(dmmu_d_adr),
    .qmem_req_o(dmmu_d_req),
    .qmem_we_o(dmmu_d_we),
    .qmem_sel_o(dmmu_d_sel),
    .qmem_tag_o(dmmu_d_tag),
    .qmem_dat_i(dmmu_d_dat_i),
    .qmem_ack_i(dmmu_d_ack),
    .qmem_err_i(dmmu_d_err),
    .qmem_rty_i(dmmu_d_rty),
    .cpu_dat_o(cpu_d_dat_i),
    .cpu_ack_o(cpu_d_ack),
    .cpu_err_o(cpu_d_err),
    .cpu_rty_o(cpu_d_rty),
    .spr_cs_i(spr_cs[1]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dmmu)
`ifdef OR1200_BIST
   ,.mbist_si_i(mbist_qmem_so),
    .mbist_so_o(mbist_dmmu_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_qmem_stub u_qmem (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .i_adr_i(immu_i_adr),
    .i_req_i(immu_i_req),
    .i_sel_i(immu_i_sel),
    .i_tag_i(immu_i_tag),
    .i_dat_o(immu_i_dat),
    .i_ack_o(immu_i_ack),
    .i_err_o(immu_i_err),
    .i_rty_o(immu_i_rty),
    .ic_adr_o(qmem_i_adr),
    .ic_req_o(qmem_i_req),
    .ic_sel_o(qmem_i_sel),
    .ic_tag_o(qmem_i_tag),
    .ic_dat_i(qmem_i_dat),
    .ic_ack_i(qmem_i_ack),
    .ic_err_i(qmem_i_err),
    .ic_rty_i(qmem_i_rty),
    .d_adr_i(dmmu_d_adr),
    .d_req_i(dmmu_d_req),
    .d_we_i(dmmu_d_we),
    .d_sel_i(dmmu_d_sel),
    .d_tag_i(dmmu_d_tag),
    .d_dat_i(cpu_d_dat_o),
    .d_dat_o(dmmu_d_dat_i),
    .d_ack_o(dmmu_d_ack),
    .d_err_o(dmmu_d_err),
    .d_rty_o(dmmu_d_rty),
    .dc_adr_o(qmem_d_adr),
    .dc_req_o(qmem_d_req),
    .dc_we_o(qmem_d_we),
    .dc_sel_o(qmem_d_sel),
    .dc_tag_o(qmem_d_tag),
    .dc_dat_o(qmem_d_dat_o),
    .dc_dat_i(qmem_d_dat_i),
    .dc_ack_i(qmem_d_ack),
    .dc_err_i(qmem_d_err),
    .dc_rty_i(qmem_d_rty)
`ifdef OR1200_BIST
   ,.mbist_si_i(mbist_ic_so),
    .mbist_so_o(mbist_qmem_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_ic_stub u_ic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(qmem_i_adr),
    .cpu_req_i(qmem_i_req),
    .cpu_sel_i(qmem_i_sel),
    .cpu_tag_i(qmem_i_tag),
    .cpu_dat_o(qmem_i_dat),
    .cpu_ack_o(qmem_i_ack),
    .cpu_err_o(qmem_i_err),
    .cpu_rty_o(qmem_i_rty),
    .wb_cyc_o(ic_wb_cyc),
    .wb_adr_o(ic_wb_adr),
    .wb_stb_o(ic_wb_stb),
    .wb_we_o(ic_wb_we),
    .wb_sel_o(ic_wb_sel),
    .wb_dat_o(ic_wb_dat_o),
    .wb_dat_i(ic_wb_dat_i),
    .wb_ack_i(ic_wb_ack),
    .wb_err_i(ic_wb_err),
    .wb_rty_i(ic_wb_rty),
    .spr_cs_i(spr_cs[4]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_ic)
`ifdef OR1200_BIST
   ,.mbist_si_i(mbist_immu_so),
    .mbist_so_o(mbist_ic_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_dc_stub u_dc (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .cpu_adr_i(qmem_d_adr),
    .cpu_req_i(qmem_d_req),
    .cpu_we_i(qmem_d_we),
    .cpu_sel_i(qmem_d_sel),
    .cpu_tag_i(qmem_d_tag),
    .cpu_dat_i(qmem_d_dat_o),
    .cpu_dat_o(qmem_d_dat_i),
    .cpu_ack_o(qmem_d_ack),
    .cpu_err_o(qmem_d_err),
    .cpu_rty_o(qmem_d_rty),
    .wb_cyc_o(dc_wb_cyc),
    .wb_adr_o(dc_wb_adr),
    .wb_stb_o(dc_wb_stb),
    .wb_we_o(dc_wb_we),
    .wb_sel_o(dc_wb_sel),
    .wb_dat_o(dc_wb_dat_o),
    .wb_dat_i(dc_wb_dat_i),
    .wb_ack_i(dc_wb_ack),
    .wb_err_i(dc_wb_err),
    .wb_rty_i(dc_wb_rty),
    .spr_cs_i(spr_cs[3]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_dc)
`ifdef OR1200_BIST
   ,.mbist_si_i(mbist_dmmu_so),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_sb_stub u_sb (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .up_cyc_i(dc_wb_cyc),
    .up_adr_i(dc_wb_adr),
    .up_stb_i(dc_wb_stb),
    .up_we_i(dc_wb_we),
    .up_sel_i(dc_wb_sel),
    .up_dat_i(dc_wb_dat_o),
    .up_dat_o(dc_wb_dat_i),
    .up_ack_o(dc_wb_ack),
    .up_err_o(dc_wb_err),
    .up_rty_o(dc_wb_rty),
    .down_cyc_o(sb_wb_cyc),
    .down_adr_o(sb_wb_adr),
    .down_stb_o(sb_wb_stb),
    .down_we_o(sb_wb_we),
    .down_sel_o(sb_wb_sel),
    .down_dat_o(sb_wb_dat_o),
    .down_dat_i(sb_wb_dat_i),
    .down_ack_i(sb_wb_ack),
    .down_err_i(sb_wb_err),
    .down_rty_i(sb_wb_rty)
);

or1200_biu_stub u_iwb_biu (
    .clk_i(iwb_clk_int),
    .rst_i(iwb_rst_int),
    .clmode_i(clmode_i),
    .biu_cyc_i(ic_wb_cyc),
    .biu_adr_i(ic_wb_adr),
    .biu_stb_i(ic_wb_stb),
    .biu_we_i(ic_wb_we),
    .biu_sel_i(ic_wb_sel),
    .biu_dat_i(ic_wb_dat_o),
    .biu_dat_o(ic_wb_dat_i),
    .biu_ack_o(ic_wb_ack),
    .biu_err_o(ic_wb_err),
    .biu_rty_o(ic_wb_rty),
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

or1200_biu_stub u_dwb_biu (
    .clk_i(dwb_clk_int),
    .rst_i(dwb_rst_int),
    .clmode_i(clmode_i),
    .biu_cyc_i(sb_wb_cyc),
    .biu_adr_i(sb_wb_adr),
    .biu_stb_i(sb_wb_stb),
    .biu_we_i(sb_wb_we),
    .biu_sel_i(sb_wb_sel),
    .biu_dat_i(sb_wb_dat_o),
    .biu_dat_o(sb_wb_dat_i),
    .biu_ack_o(sb_wb_ack),
    .biu_err_o(sb_wb_err),
    .biu_rty_o(sb_wb_rty),
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

or1200_du_stub u_du (
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
    .spr_cs_i(spr_cs[6]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_du),
    .du_stall_o(du_stall),
    .du_addr_o(du_addr),
    .du_dat_o(du_dat_du),
    .du_read_o(du_read),
    .du_write_o(du_write),
    .du_except_o(du_except),
    .du_hwbkpt_o(du_hwbkpt)
);

or1200_pic_stub #(.PPIC_INTS(ppic_ints)) u_pic (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pic_ints_i(pic_ints_i),
    .spr_cs_i(spr_cs[9]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_pic),
    .sig_int_o(sig_int),
    .pic_wakeup_o(pic_wakeup)
);

or1200_tt_stub u_tt (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .spr_cs_i(spr_cs[10]),
    .spr_we_i(spr_we),
    .spr_addr_i(spr_addr),
    .spr_dat_i(spr_dat_cpu),
    .spr_dat_o(spr_dat_tt),
    .sig_tick_o(sig_tick)
);

or1200_pm_stub u_pm (
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

module or1200_cpu_stub(
    input clk_i,
    input rst_i,
    output [31:0] i_adr_o,
    output i_req_o,
    output [3:0] i_sel_o,
    output [3:0] i_tag_o,
    input [31:0] i_dat_i,
    input i_ack_i,
    input i_err_i,
    input i_rty_i,
    output [31:0] d_adr_o,
    output d_req_o,
    output d_we_o,
    output [3:0] d_sel_o,
    output [3:0] d_tag_o,
    output [31:0] d_dat_o,
    input [31:0] d_dat_i,
    input d_ack_i,
    input d_err_i,
    input d_rty_i,
    output [31:0] spr_addr_o,
    output [31:0] spr_dat_o,
    output spr_we_o,
    output [10:0] spr_cs_o,
    input [31:0] spr_dat_i,
    input sig_int_i,
    input sig_tick_i,
    input du_stall_i,
    input [31:0] du_addr_i,
    input [31:0] du_dat_i,
    input du_read_i,
    input du_write_i,
    input du_except_i,
    input du_hwbkpt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o
);
assign i_adr_o = 32'b0;
assign i_req_o = 1'b0;
assign i_sel_o = 4'b0;
assign i_tag_o = 4'b0;
assign d_adr_o = 32'b0;
assign d_req_o = 1'b0;
assign d_we_o = 1'b0;
assign d_sel_o = 4'b0;
assign d_tag_o = 4'b0;
assign d_dat_o = 32'b0;
assign spr_addr_o = 32'b0;
assign spr_dat_o = 32'b0;
assign spr_we_o = 1'b0;
assign spr_cs_o = 11'b0;
assign dbg_lss_o = 4'b0;
assign dbg_is_o = 2'b0;
assign dbg_wp_o = 11'b0;
assign dbg_bp_o = 1'b0;
endmodule

module or1200_immu_stub(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_req_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    output [31:0] qmem_adr_o,
    output qmem_req_o,
    output [3:0] qmem_sel_o,
    output [3:0] qmem_tag_o,
    input [31:0] qmem_dat_i,
    input qmem_ack_i,
    input qmem_err_i,
    input qmem_rty_i,
    output [31:0] cpu_dat_o,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign qmem_adr_o = cpu_adr_i;
assign qmem_req_o = cpu_req_i;
assign qmem_sel_o = cpu_sel_i;
assign qmem_tag_o = cpu_tag_i;
assign cpu_dat_o = qmem_dat_i;
assign cpu_ack_o = qmem_ack_i;
assign cpu_err_o = qmem_err_i;
assign cpu_rty_o = qmem_rty_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_dmmu_stub(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_req_i,
    input cpu_we_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    output [31:0] qmem_adr_o,
    output qmem_req_o,
    output qmem_we_o,
    output [3:0] qmem_sel_o,
    output [3:0] qmem_tag_o,
    input [31:0] qmem_dat_i,
    input qmem_ack_i,
    input qmem_err_i,
    input qmem_rty_i,
    output [31:0] cpu_dat_o,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign qmem_adr_o = cpu_adr_i;
assign qmem_req_o = cpu_req_i;
assign qmem_we_o = cpu_we_i;
assign qmem_sel_o = cpu_sel_i;
assign qmem_tag_o = cpu_tag_i;
assign cpu_dat_o = qmem_dat_i;
assign cpu_ack_o = qmem_ack_i;
assign cpu_err_o = qmem_err_i;
assign cpu_rty_o = qmem_rty_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_qmem_stub(
    input clk_i,
    input rst_i,
    input [31:0] i_adr_i,
    input i_req_i,
    input [3:0] i_sel_i,
    input [3:0] i_tag_i,
    output [31:0] i_dat_o,
    output i_ack_o,
    output i_err_o,
    output i_rty_o,
    output [31:0] ic_adr_o,
    output ic_req_o,
    output [3:0] ic_sel_o,
    output [3:0] ic_tag_o,
    input [31:0] ic_dat_i,
    input ic_ack_i,
    input ic_err_i,
    input ic_rty_i,
    input [31:0] d_adr_i,
    input d_req_i,
    input d_we_i,
    input [3:0] d_sel_i,
    input [3:0] d_tag_i,
    input [31:0] d_dat_i,
    output [31:0] d_dat_o,
    output d_ack_o,
    output d_err_o,
    output d_rty_o,
    output [31:0] dc_adr_o,
    output dc_req_o,
    output dc_we_o,
    output [3:0] dc_sel_o,
    output [3:0] dc_tag_o,
    output [31:0] dc_dat_o,
    input [31:0] dc_dat_i,
    input dc_ack_i,
    input dc_err_i,
    input dc_rty_i
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign ic_adr_o = i_adr_i;
assign ic_req_o = i_req_i;
assign ic_sel_o = i_sel_i;
assign ic_tag_o = i_tag_i;
assign i_dat_o = ic_dat_i;
assign i_ack_o = ic_ack_i;
assign i_err_o = ic_err_i;
assign i_rty_o = ic_rty_i;
assign dc_adr_o = d_adr_i;
assign dc_req_o = d_req_i;
assign dc_we_o = d_we_i;
assign dc_sel_o = d_sel_i;
assign dc_tag_o = d_tag_i;
assign dc_dat_o = d_dat_i;
assign d_dat_o = dc_dat_i;
assign d_ack_o = dc_ack_i;
assign d_err_o = dc_err_i;
assign d_rty_o = dc_rty_i;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_ic_stub(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_req_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    output [31:0] cpu_dat_o,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign wb_cyc_o = cpu_req_i;
assign wb_adr_o = cpu_adr_i;
assign wb_stb_o = cpu_req_i;
assign wb_we_o = 1'b0;
assign wb_sel_o = cpu_sel_i;
assign wb_dat_o = 32'b0;
assign cpu_dat_o = wb_dat_i;
assign cpu_ack_o = wb_ack_i;
assign cpu_err_o = wb_err_i;
assign cpu_rty_o = wb_rty_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_dc_stub(
    input clk_i,
    input rst_i,
    input [31:0] cpu_adr_i,
    input cpu_req_i,
    input cpu_we_i,
    input [3:0] cpu_sel_i,
    input [3:0] cpu_tag_i,
    input [31:0] cpu_dat_i,
    output [31:0] cpu_dat_o,
    output cpu_ack_o,
    output cpu_err_o,
    output cpu_rty_o,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o,
    input [31:0] wb_dat_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
assign wb_cyc_o = cpu_req_i;
assign wb_adr_o = cpu_adr_i;
assign wb_stb_o = cpu_req_i;
assign wb_we_o = cpu_we_i;
assign wb_sel_o = cpu_sel_i;
assign wb_dat_o = cpu_dat_i;
assign cpu_dat_o = wb_dat_i;
assign cpu_ack_o = wb_ack_i;
assign cpu_err_o = wb_err_i;
assign cpu_rty_o = wb_rty_i;
assign spr_dat_o = 32'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
endmodule

module or1200_sb_stub(
    input clk_i,
    input rst_i,
    input up_cyc_i,
    input [31:0] up_adr_i,
    input up_stb_i,
    input up_we_i,
    input [3:0] up_sel_i,
    input [31:0] up_dat_i,
    output [31:0] up_dat_o,
    output up_ack_o,
    output up_err_o,
    output up_rty_o,
    output down_cyc_o,
    output [31:0] down_adr_o,
    output down_stb_o,
    output down_we_o,
    output [3:0] down_sel_o,
    output [31:0] down_dat_o,
    input [31:0] down_dat_i,
    input down_ack_i,
    input down_err_i,
    input down_rty_i
);
assign down_cyc_o = up_cyc_i;
assign down_adr_o = up_adr_i;
assign down_stb_o = up_stb_i;
assign down_we_o = up_we_i;
assign down_sel_o = up_sel_i;
assign down_dat_o = up_dat_i;
assign up_dat_o = down_dat_i;
assign up_ack_o = down_ack_i;
assign up_err_o = down_err_i;
assign up_rty_o = down_rty_i;
endmodule

module or1200_biu_stub(
    input clk_i,
    input rst_i,
    input [1:0] clmode_i,
    input biu_cyc_i,
    input [31:0] biu_adr_i,
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
    ,
    output wb_cab_o
`endif
`ifdef OR1200_WB_B3
    ,
    output [2:0] wb_cti_o,
    output [1:0] wb_bte_o
`endif
);
assign wb_cyc_o = biu_cyc_i;
assign wb_adr_o = biu_adr_i;
assign wb_stb_o = biu_stb_i;
assign wb_we_o = biu_we_i;
assign wb_sel_o = biu_sel_i;
assign wb_dat_o = biu_dat_i;
assign biu_dat_o = wb_dat_i;
assign biu_ack_o = wb_ack_i;
assign biu_err_o = wb_err_i;
assign biu_rty_o = wb_rty_i;
`ifdef OR1200_WB_CAB
assign wb_cab_o = 1'b0;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = 3'b000;
assign wb_bte_o = 2'b00;
`endif
endmodule

module or1200_du_stub(
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
    output [31:0] du_dat_o,
    output du_read_o,
    output du_write_o,
    output du_except_o,
    output du_hwbkpt_o
);
assign dbg_dat_o = dbg_dat_i;
assign dbg_ack_o = dbg_stb_i;
assign spr_dat_o = 32'b0;
assign du_stall_o = dbg_stall_i;
assign du_addr_o = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read_o = dbg_stb_i & ~dbg_we_i;
assign du_write_o = dbg_stb_i & dbg_we_i;
assign du_except_o = dbg_ewt_i;
assign du_hwbkpt_o = dbg_stall_i & dbg_ewt_i;
endmodule

module or1200_pic_stub #(parameter PPIC_INTS = 1) (
    input clk_i,
    input rst_i,
    input [PPIC_INTS-1:0] pic_ints_i,
    input spr_cs_i,
    input spr_we_i,
    input [31:0] spr_addr_i,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output sig_int_o,
    output pic_wakeup_o
);
assign sig_int_o = |pic_ints_i;
assign pic_wakeup_o = |pic_ints_i;
assign spr_dat_o = {31'b0, sig_int_o};
endmodule

module or1200_tt_stub(
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

module or1200_pm_stub(
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
assign pm_clksd_o = 4'b0000;
assign pm_dc_gate_o = pm_cpustall_i;
assign pm_ic_gate_o = pm_cpustall_i;
assign pm_dmmu_gate_o = pm_cpustall_i;
assign pm_immu_gate_o = pm_cpustall_i;
assign pm_tt_gate_o = 1'b0;
assign pm_cpu_gate_o = pm_cpustall_i;
assign pm_wakeup_o = pic_wakeup_i;
assign pm_lvolt_o = 1'b0;
endmodule
