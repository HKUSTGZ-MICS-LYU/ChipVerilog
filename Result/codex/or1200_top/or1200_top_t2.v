// Generated from or1200_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_top(
    // System
    input clk_i,
    input rst_i,
    input [19:0] pic_ints_i,
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

reg iwb_cyc_o_r;
reg [31:0] iwb_adr_o_r;
reg iwb_stb_o_r;
reg iwb_we_o_r;
reg [3:0] iwb_sel_o_r;
reg [31:0] iwb_dat_o_r;
`ifdef OR1200_WB_CAB
reg iwb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] iwb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
reg [1:0] iwb_bte_o_r;
`endif
reg dwb_cyc_o_r;
reg [31:0] dwb_adr_o_r;
reg dwb_stb_o_r;
reg dwb_we_o_r;
reg [3:0] dwb_sel_o_r;
reg [31:0] dwb_dat_o_r;
`ifdef OR1200_WB_CAB
reg dwb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] dwb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
reg [1:0] dwb_bte_o_r;
`endif
reg [3:0] dbg_lss_o_r;
reg [1:0] dbg_is_o_r;
reg [10:0] dbg_wp_o_r;
reg dbg_bp_o_r;
reg [31:0] dbg_dat_o_r;
reg dbg_ack_o_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [3:0] pm_clksd_o_r;
reg pm_dc_gate_o_r;
reg pm_ic_gate_o_r;
reg pm_dmmu_gate_o_r;
reg pm_immu_gate_o_r;
reg pm_tt_gate_o_r;
reg pm_cpu_gate_o_r;
reg pm_wakeup_o_r;
reg pm_lvolt_o_r;
assign iwb_cyc_o = iwb_cyc_o_r;
assign iwb_adr_o = iwb_adr_o_r;
assign iwb_stb_o = iwb_stb_o_r;
assign iwb_we_o = iwb_we_o_r;
assign iwb_sel_o = iwb_sel_o_r;
assign iwb_dat_o = iwb_dat_o_r;
`ifdef OR1200_WB_CAB
assign iwb_cab_o = iwb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
assign iwb_cti_o = iwb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
assign iwb_bte_o = iwb_bte_o_r;
`endif
assign dwb_cyc_o = dwb_cyc_o_r;
assign dwb_adr_o = dwb_adr_o_r;
assign dwb_stb_o = dwb_stb_o_r;
assign dwb_we_o = dwb_we_o_r;
assign dwb_sel_o = dwb_sel_o_r;
assign dwb_dat_o = dwb_dat_o_r;
`ifdef OR1200_WB_CAB
assign dwb_cab_o = dwb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
assign dwb_cti_o = dwb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
assign dwb_bte_o = dwb_bte_o_r;
`endif
assign dbg_lss_o = dbg_lss_o_r;
assign dbg_is_o = dbg_is_o_r;
assign dbg_wp_o = dbg_wp_o_r;
assign dbg_bp_o = dbg_bp_o_r;
assign dbg_dat_o = dbg_dat_o_r;
assign dbg_ack_o = dbg_ack_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign pm_clksd_o = pm_clksd_o_r;
assign pm_dc_gate_o = pm_dc_gate_o_r;
assign pm_ic_gate_o = pm_ic_gate_o_r;
assign pm_dmmu_gate_o = pm_dmmu_gate_o_r;
assign pm_immu_gate_o = pm_immu_gate_o_r;
assign pm_tt_gate_o = pm_tt_gate_o_r;
assign pm_cpu_gate_o = pm_cpu_gate_o_r;
assign pm_wakeup_o = pm_wakeup_o_r;
assign pm_lvolt_o = pm_lvolt_o_r;

always @* begin
    iwb_adr_o_r = 32'd0;
    iwb_dat_o_r = 32'd0;
    iwb_sel_o_r = 4'hf;
    iwb_cyc_o_r = 1'b0;
    iwb_stb_o_r = 1'b0;
    iwb_we_o_r = 1'b0;
    dwb_adr_o_r = 32'd0;
    dwb_dat_o_r = 32'd0;
    dwb_sel_o_r = 4'hf;
    dwb_cyc_o_r = 1'b0;
    dwb_stb_o_r = 1'b0;
    dwb_we_o_r = 1'b0;
    dbg_lss_o_r = {dbg_stall_i, dbg_ewt_i, 2'b00};
    dbg_is_o_r = 2'b00;
    dbg_wp_o_r = 11'd0;
    dbg_bp_o_r = 1'b0;
    dbg_dat_o_r = dbg_dat_i;
    dbg_ack_o_r = dbg_stb_i;
    pm_clksd_o_r = 4'd0;
    pm_dc_gate_o_r = pm_cpustall_i;
    pm_ic_gate_o_r = pm_cpustall_i;
    pm_dmmu_gate_o_r = pm_cpustall_i;
    pm_immu_gate_o_r = pm_cpustall_i;
    pm_tt_gate_o_r = pm_cpustall_i;
    pm_cpu_gate_o_r = pm_cpustall_i;
    pm_wakeup_o_r = |pic_ints_i;
    pm_lvolt_o_r = 1'b0;
`ifdef OR1200_WB_CAB
    iwb_cab_o_r = 1'b0;
    dwb_cab_o_r = 1'b0;
`endif
`ifdef OR1200_WB_B3
    iwb_cti_o_r = 3'b000;
    iwb_bte_o_r = 2'b00;
    dwb_cti_o_r = 3'b000;
    dwb_bte_o_r = 2'b00;
`endif
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
