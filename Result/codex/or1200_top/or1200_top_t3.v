`include "or1200_defines.v"

module or1200_top(
    input                            clk_i,
    input                            rst_i,
    input  [`OR1200_PIC_INTS-1:0]    pic_ints_i,
    input  [1:0]                     clmode_i,
    input                            iwb_ack_i,
    input                            iwb_err_i,
    input                            iwb_rty_i,
    input  [31:0]                    iwb_dat_i,
    output                           iwb_cyc_o,
    output [31:0]                    iwb_adr_o,
    output                           iwb_stb_o,
    output                           iwb_we_o,
    output [3:0]                     iwb_sel_o,
    output [31:0]                    iwb_dat_o,
`ifdef OR1200_WB_CAB
    output                           iwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]                     iwb_cti_o,
    output [1:0]                     iwb_bte_o,
`endif
    input                            dwb_ack_i,
    input                            dwb_err_i,
    input                            dwb_rty_i,
    input  [31:0]                    dwb_dat_i,
    output                           dwb_cyc_o,
    output [31:0]                    dwb_adr_o,
    output                           dwb_stb_o,
    output                           dwb_we_o,
    output [3:0]                     dwb_sel_o,
    output [31:0]                    dwb_dat_o,
`ifdef OR1200_WB_CAB
    output                           dwb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]                     dwb_cti_o,
    output [1:0]                     dwb_bte_o,
`endif
    input                            dbg_stall_i,
    input                            dbg_ewt_i,
    output [3:0]                     dbg_lss_o,
    output [1:0]                     dbg_is_o,
    output [10:0]                    dbg_wp_o,
    output                           dbg_bp_o,
    input                            dbg_stb_i,
    input                            dbg_we_i,
    input  [31:0]                    dbg_adr_i,
    input  [31:0]                    dbg_dat_i,
    output [31:0]                    dbg_dat_o,
    output                           dbg_ack_o,
`ifdef OR1200_BIST
    input                            mbist_si_i,
    output                           mbist_so_o,
    input  [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input                            pm_cpustall_i,
    output [3:0]                     pm_clksd_o,
    output                           pm_dc_gate_o,
    output                           pm_ic_gate_o,
    output                           pm_dmmu_gate_o,
    output                           pm_immu_gate_o,
    output                           pm_tt_gate_o,
    output                           pm_cpu_gate_o,
    output                           pm_wakeup_o,
    output                           pm_lvolt_o
);

// NOTE:
// This top-level file is a structural compatibility shell derived from the
// uploaded description. A fully functional OR1200 top requires additional
// modules that were not part of the uploaded set (CPU core, I/D cache,
// I/D MMU, debug unit, config block, etc.).
// The wiring below keeps the public top-level interface stable and instantiates
// the uploaded PM/PIC/TT blocks that are self-contained.

wire [31:0] spr_dat_pic;
wire [31:0] spr_dat_tt;
wire [31:0] spr_dat_pm;
wire pic_wakeup;
wire sig_int;
wire sig_tick;

or1200_pic u_pic (
    .clk(clk_i),
    .rst(rst_i),
    .spr_cs(1'b0),
    .spr_write(1'b0),
    .spr_addr(32'b0),
    .spr_dat_i(32'b0),
    .spr_dat_o(spr_dat_pic),
    .pic_wakeup(pic_wakeup),
    .intr(sig_int),
    .pic_int(pic_ints_i)
);

or1200_tt u_tt (
    .clk(clk_i),
    .rst(rst_i),
    .du_stall(dbg_stall_i),
    .spr_cs(1'b0),
    .spr_write(1'b0),
    .spr_addr(32'b0),
    .spr_dat_i(32'b0),
    .spr_dat_o(spr_dat_tt),
    .intr(sig_tick)
);

or1200_pm u_pm (
    .clk(clk_i),
    .rst(rst_i),
    .pic_wakeup(pic_wakeup),
    .spr_write(1'b0),
    .spr_addr(32'b0),
    .spr_dat_i(32'b0),
    .spr_dat_o(spr_dat_pm),
    .pm_clksd(pm_clksd_o),
    .pm_cpustall(pm_cpustall_i),
    .pm_dc_gate(pm_dc_gate_o),
    .pm_ic_gate(pm_ic_gate_o),
    .pm_dmmu_gate(pm_dmmu_gate_o),
    .pm_immu_gate(pm_immu_gate_o),
    .pm_tt_gate(pm_tt_gate_o),
    .pm_cpu_gate(pm_cpu_gate_o),
    .pm_wakeup(pm_wakeup_o),
    .pm_lvolt(pm_lvolt_o)
);

assign iwb_cyc_o = 1'b0;
assign iwb_adr_o = 32'b0;
assign iwb_stb_o = 1'b0;
assign iwb_we_o  = 1'b0;
assign iwb_sel_o = 4'b0;
assign iwb_dat_o = 32'b0;
`ifdef OR1200_WB_CAB
assign iwb_cab_o = 1'b0;
`endif
`ifdef OR1200_WB_B3
assign iwb_cti_o = 3'b111;
assign iwb_bte_o = 2'b00;
`endif
assign dwb_cyc_o = 1'b0;
assign dwb_adr_o = 32'b0;
assign dwb_stb_o = 1'b0;
assign dwb_we_o  = 1'b0;
assign dwb_sel_o = 4'b0;
assign dwb_dat_o = 32'b0;
`ifdef OR1200_WB_CAB
assign dwb_cab_o = 1'b0;
`endif
`ifdef OR1200_WB_B3
assign dwb_cti_o = 3'b111;
assign dwb_bte_o = 2'b00;
`endif
assign dbg_lss_o = 4'b0;
assign dbg_is_o  = 2'b0;
assign dbg_wp_o  = 11'b0;
assign dbg_bp_o  = 1'b0;
assign dbg_dat_o = 32'b0;
assign dbg_ack_o = dbg_stb_i;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

endmodule
