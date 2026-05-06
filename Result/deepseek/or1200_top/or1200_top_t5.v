`include "or1200_defines.v"
`include "or1200_pp.v"

module or1200_top (
    // System
    input clk_i,
    input rst_i,
    input [`ppic_ints-1:0] pic_ints_i,
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
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
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

    // Internal wires
    // CPU instruction interface
    wire [31:0] cpu_ivadr;
    wire [31:0] cpu_iaddr;
    wire cpu_ifetch;
    wire [3:0] cpu_ibyteen;
    wire [1:0] cpu_iunit;
    wire [2:0] cpu_itag;
    wire cpu_icer_ack;
    wire cpu_icer_err;
    wire [31:0] cpu_idat;
    wire cpu_ici_ack;
    wire cpu_ici_err;

    // CPU data interface
    wire [31:0] cpu_dvadr;
    wire [31:0] cpu_daddr;
    wire [31:0] cpu_ddat;
    wire [31:0] cpu_ddat_qmem;
    wire cpu_dwe;
    wire [3:0] cpu_dbyteen;
    wire [1:0] cpu_dunit;
    wire [2:0] cpu_dtag;
    wire [31:0] cpu_dqdat;
    wire cpu_dcer_ack;
    wire cpu_dcer_err;
    wire cpu_dci_ack;
    wire cpu_dci_err;
    wire cpu_dci_ack_err;

    // SPR interface
    wire [31:0] cpu_spr_addr;
    wire [31:0] cpu_spr_dat_cpu;
    wire cpu_spr_we;
    wire [31:0] cpu_spr_cs;
    wire [31:0] spr_dat_immu;
    wire [31:0] spr_dat_dmmu;
    wire [31:0] spr_dat_ic;
    wire [31:0] spr_dat_dc;
    wire [31:0] spr_dat_du;
    wire [31:0] spr_dat_pic;
    wire [31:0] spr_dat_tt;
    wire [31:0] spr_dat_pm;

    // Debug interface between CPU and DU
    wire du_stall;
    wire [31:0] du_addr;
    wire [31:0] du_dat_du;
    wire du_read;
    wire du_write;
    wire du_except;
    wire du_hwbkpt;

    // Interrupt / timer
    wire sig_int;
    wire sig_tick;

    // Wishbone BIU internal signals
    wire iwb_clk = clk_i;
    wire iwb_rst = rst_i;
    wire dwb_clk = clk_i;
    wire dwb_rst = rst_i;

    // MBIST chain signals
`ifdef OR1200_BIST
    wire mbist_so_immu;
    wire mbist_so_ic;
    wire mbist_so_qmem;
    wire mbist_so_dmmu;
`endif

    // Power management internal
    wire pic_wakeup;

    // ----------------------------------------------------------------------
    // CPU Core
    // ----------------------------------------------------------------------
    or1200_cpu cpu (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_cpu(cpu_spr_dat_cpu),
        .spr_we(cpu_spr_we),
        .spr_cs(cpu_spr_cs),
        .spr_dat_immu(spr_dat_immu),
        .spr_dat_dmmu(spr_dat_dmmu),
        .spr_dat_ic(spr_dat_ic),
        .spr_dat_dc(spr_dat_dc),
        .spr_dat_du(spr_dat_du),
        .spr_dat_pic(spr_dat_pic),
        .spr_dat_tt(spr_dat_tt),
        .spr_dat_pm(spr_dat_pm),
        .ivadr(cpu_ivadr),
        .iaddr(cpu_iaddr),
        .ifetch(cpu_ifetch),
        .ibyteen(cpu_ibyteen),
        .iunit(cpu_iunit),
        .itag(cpu_itag),
        .icer_ack(cpu_icer_ack),
        .icer_err(cpu_icer_err),
        .idat(cpu_idat),
        .ici_ack(cpu_ici_ack),
        .ici_err(cpu_ici_err),
        .dvadr(cpu_dvadr),
        .daddr(cpu_daddr),
        .ddat(cpu_ddat),
        .ddat_qmem(cpu_ddat_qmem),
        .dwe(cpu_dwe),
        .dbyteen(cpu_dbyteen),
        .dunit(cpu_dunit),
        .dtag(cpu_dtag),
        .dqdat(cpu_dqdat),
        .dcer_ack(cpu_dcer_ack),
        .dcer_err(cpu_dcer_err),
        .dci_ack(cpu_dci_ack),
        .dci_err(cpu_dci_err),
        .dci_ack_err(cpu_dci_ack_err),
        .du_stall(du_stall),
        .du_addr(du_addr),
        .du_dat_du(du_dat_du),
        .du_read(du_read),
        .du_write(du_write),
        .du_except(du_except),
        .du_hwbkpt(du_hwbkpt),
        .sig_int(sig_int),
        .sig_tick(sig_tick)
    );

    // ----------------------------------------------------------------------
    // Instruction Memory Management Unit (IMMU)
    // ----------------------------------------------------------------------
    or1200_immu immu (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_immu),
        .spr_we(cpu_spr_we & cpu_spr_cs[2]),
        .spr_cs(cpu_spr_cs[2]),
        .cpu_ivadr(cpu_ivadr),
        .cpu_iaddr(cpu_iaddr),
        .cpu_ifetch(cpu_ifetch),
        .cpu_ibyteen(cpu_ibyteen),
        .cpu_iunit(cpu_iunit),
        .cpu_itag(cpu_itag),
        .icer_ack(cpu_icer_ack),
        .icer_err(cpu_icer_err),
        .idat(cpu_idat),
        .ici_ack(cpu_ici_ack),
        .ici_err(cpu_ici_err),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_immu),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .qmem_ivadr(),
        .qmem_iaddr(),
        .qmem_ifetch(),
        .qmem_ibyteen(),
        .qmem_iunit(),
        .qmem_itag()
    );

    // ----------------------------------------------------------------------
    // Instruction Cache
    // ----------------------------------------------------------------------
    or1200_ic ic (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_ic),
        .spr_we(cpu_spr_we & cpu_spr_cs[4]),
        .spr_cs(cpu_spr_cs[4]),
        .ic_ivadr(),
        .ic_iaddr(),
        .ic_ifetch(),
        .ic_ibyteen(),
        .ic_iunit(),
        .ic_itag(),
        .iwb_clk_i(iwb_clk),
        .iwb_rst_i(iwb_rst),
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
        .clmode_i(clmode_i),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_so_immu),
        .mbist_so_o(mbist_so_ic),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .qmem_ivadr(),
        .qmem_iaddr(),
        .qmem_ifetch(),
        .qmem_ibyteen(),
        .qmem_iunit(),
        .qmem_itag()
    );

    // ----------------------------------------------------------------------
    // QMEM (Instruction/Data unified? Actually separate I and D interfaces)
    // QMEM sits between CPU/IMMU and IC for instructions, and between CPU/DMMU and DC for data.
    // ----------------------------------------------------------------------
    or1200_qmem qmem (
        .clk(clk_i),
        .rst(rst_i),
        .cpu_ivadr(cpu_ivadr),
        .cpu_iaddr(cpu_iaddr),
        .cpu_ifetch(cpu_ifetch),
        .cpu_ibyteen(cpu_ibyteen),
        .cpu_iunit(cpu_iunit),
        .cpu_itag(cpu_itag),
        .qmem_ivadr(),
        .qmem_iaddr(),
        .qmem_ifetch(),
        .qmem_ibyteen(),
        .qmem_iunit(),
        .qmem_itag(),
        .cpu_dvadr(cpu_dvadr),
        .cpu_daddr(cpu_daddr),
        .cpu_ddat(cpu_ddat),
        .cpu_dwe(cpu_dwe),
        .cpu_dbyteen(cpu_dbyteen),
        .cpu_dunit(cpu_dunit),
        .cpu_dtag(cpu_dtag),
        .cpu_dqdat(cpu_dqdat),
        .qmem_dvadr(),
        .qmem_daddr(),
        .qmem_ddat(),
        .qmem_dqdat(),
        .qmem_dwe(),
        .qmem_dbyteen(),
        .qmem_dunit(),
        .qmem_dtag(),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_so_ic),
        .mbist_so_o(mbist_so_qmem),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
    );

    // ----------------------------------------------------------------------
    // Data Memory Management Unit (DMMU)
    // ----------------------------------------------------------------------
    or1200_dmmu dmmu (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_dmmu),
        .spr_we(cpu_spr_we & cpu_spr_cs[1]),
        .spr_cs(cpu_spr_cs[1]),
        .cpu_dvadr(cpu_dvadr),
        .cpu_daddr(cpu_daddr),
        .cpu_dwe(cpu_dwe),
        .cpu_dbyteen(cpu_dbyteen),
        .cpu_dunit(cpu_dunit),
        .cpu_dtag(cpu_dtag),
        .cpu_ddat(cpu_ddat),
        .cpu_dqdat(cpu_dqdat),
        .dcer_ack(cpu_dcer_ack),
        .dcer_err(cpu_dcer_err),
        .dci_ack(cpu_dci_ack),
        .dci_err(cpu_dci_err),
        .dci_ack_err(cpu_dci_ack_err),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_so_qmem),
        .mbist_so_o(mbist_so_dmmu),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .qmem_dvadr(),
        .qmem_daddr(),
        .qmem_dwe(),
        .qmem_dbyteen(),
        .qmem_dunit(),
        .qmem_dtag(),
        .qmem_ddat(),
        .qmem_dqdat()
    );

    // ----------------------------------------------------------------------
    // Data Cache
    // ----------------------------------------------------------------------
    or1200_dc dc (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_dc),
        .spr_we(cpu_spr_we & cpu_spr_cs[3]),
        .spr_cs(cpu_spr_cs[3]),
        .dc_dvadr(),
        .dc_daddr(),
        .dc_dwe(),
        .dc_dbyteen(),
        .dc_dunit(),
        .dc_dtag(),
        .dc_ddat(),
        .dc_dqdat(),
        .dc_ack(),
        .dc_err(),
        .sb_dvadr(),
        .sb_daddr(),
        .sb_dwe(),
        .sb_dbyteen(),
        .sb_dunit(),
        .sb_dtag(),
        .sb_ddat(),
        .sb_dqdat(),
        .sb_ack(),
        .sb_err(),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_so_dmmu),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
    );

    // ----------------------------------------------------------------------
    // Store Buffer
    // ----------------------------------------------------------------------
    or1200_sb sb (
        .clk(clk_i),
        .rst(rst_i),
        .sb_dvadr(),
        .sb_daddr(),
        .sb_dwe(),
        .sb_dbyteen(),
        .sb_dunit(),
        .sb_dtag(),
        .sb_ddat(),
        .sb_dqdat(),
        .sb_ack(),
        .sb_err(),
        .dwb_clk_i(dwb_clk),
        .dwb_rst_i(dwb_rst),
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
        .clmode_i(clmode_i)
    );

    // ----------------------------------------------------------------------
    // Debug Unit
    // ----------------------------------------------------------------------
    or1200_du du (
        .clk(clk_i),
        .rst(rst_i),
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
        .dbg_ack_o(dbg_ack_o),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_du),
        .spr_we(cpu_spr_we & cpu_spr_cs[6]),
        .spr_cs(cpu_spr_cs[6]),
        .du_stall(du_stall),
        .du_addr(du_addr),
        .du_dat_du(du_dat_du),
        .du_read(du_read),
        .du_write(du_write),
        .du_except(du_except),
        .du_hwbkpt(du_hwbkpt)
    );

    // ----------------------------------------------------------------------
    // Programmable Interrupt Controller
    // ----------------------------------------------------------------------
    or1200_pic pic (
        .clk(clk_i),
        .rst(rst_i),
        .pic_ints_i(pic_ints_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_pic),
        .spr_we(cpu_spr_we & cpu_spr_cs[9]),
        .spr_cs(cpu_spr_cs[9]),
        .sig_int(sig_int),
        .pic_wakeup(pic_wakeup)
    );

    // ----------------------------------------------------------------------
    // Tick Timer
    // ----------------------------------------------------------------------
    or1200_tt tt (
        .clk(clk_i),
        .rst(rst_i),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_tt),
        .spr_we(cpu_spr_we & cpu_spr_cs[10]),
        .spr_cs(cpu_spr_cs[10]),
        .sig_tick(sig_tick)
    );

    // ----------------------------------------------------------------------
    // Power Management Unit
    // ----------------------------------------------------------------------
    or1200_pm pm (
        .clk(clk_i),
        .rst(rst_i),
        .pm_cpustall_i(pm_cpustall_i),
        .pic_wakeup(pic_wakeup),
        .spr_addr(cpu_spr_addr),
        .spr_dat_i(cpu_spr_dat_cpu),
        .spr_dat_o(spr_dat_pm),
        .spr_we(cpu_spr_we),
        .spr_cs(1'b0), // No dedicated spr_cs; PM uses spr_write directly
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
