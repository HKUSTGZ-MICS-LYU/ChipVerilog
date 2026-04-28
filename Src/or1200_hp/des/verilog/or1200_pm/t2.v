`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_pm (
    input         clk,
    input         rst,
    input         pic_wakeup,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    output [3:0]  pm_clksd,
    input         pm_cpustall,
    output        pm_dc_gate,
    output        pm_ic_gate,
    output        pm_dmmu_gate,
    output        pm_immu_gate,
    output        pm_tt_gate,
    output        pm_cpu_gate,
    output        pm_wakeup,
    output        pm_lvolt
);

`ifdef OR1200_PM_IMPLEMENTED

    //--------------------------------------------------------------------------
    // PMR fields
    //--------------------------------------------------------------------------
    reg [3:0] sdf;    // [3:0]  clock slow-down factor
    reg       dme;    // [4]    doze mode enable
    reg       sme;    // [5]    sleep mode enable
    reg       dcge;   // [6]    dynamic clock-gating enable (TODO: unused in outputs)

    //--------------------------------------------------------------------------
    // PMR address select
    //--------------------------------------------------------------------------
`ifdef OR1200_PM_PARTIAL_DECODING
    wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM);
`else
    wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM) &&
                  (spr_addr[10:0]  == `OR1200_PM_OFS_PMR);
`endif

    //--------------------------------------------------------------------------
    // PMR sequential update
    // Priority: rst > PMR write > pic_wakeup clear > hold
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sdf  <= 4'h0;
            dme  <= 1'b0;
            sme  <= 1'b0;
            dcge <= 1'b0;
        end else if (pmr_sel & spr_write) begin
            // Software write: load all PMR fields from spr_dat_i
            sdf  <= spr_dat_i[3:0];
            dme  <= spr_dat_i[4];
            sme  <= spr_dat_i[5];
            dcge <= spr_dat_i[6];
        end else if (pic_wakeup) begin
            // PIC wakeup: exit doze/sleep by clearing dme and sme only
            // sdf and dcge retain their values
            dme <= 1'b0;
            sme <= 1'b0;
        end
        // else: all fields hold previous values
    end

    //--------------------------------------------------------------------------
    // Combinational output generation
    //--------------------------------------------------------------------------

    // Clock slowdown factor: directly from sdf
    assign pm_clksd = sdf;

    // CPU gate: doze or sleep mode active, no wakeup
    assign pm_cpu_gate = (dme | sme) & ~pic_wakeup;

    // DCache, ICache, DMMU, IMMU: follow CPU gate identically
    assign pm_dc_gate   = pm_cpu_gate;
    assign pm_ic_gate   = pm_cpu_gate;
    assign pm_dmmu_gate = pm_cpu_gate;
    assign pm_immu_gate = pm_cpu_gate;

    // Tick Timer: only in sleep mode (not doze mode alone), no wakeup
    assign pm_tt_gate = sme & ~pic_wakeup;

    // Wakeup: directly from PIC wakeup
    assign pm_wakeup = pic_wakeup;

    // Low voltage: CPU gated or externally stalled
    assign pm_lvolt = pm_cpu_gate | pm_cpustall;

    //--------------------------------------------------------------------------
    // SPR read data
    //--------------------------------------------------------------------------
`ifdef OR1200_PM_READREGS
    assign spr_dat_o[3:0] = sdf;
    assign spr_dat_o[4]   = dme;
    assign spr_dat_o[5]   = sme;
    assign spr_dat_o[6]   = dcge;
`ifdef OR1200_PM_UNUSED_ZERO
    assign spr_dat_o[31:7] = 25'h0;
`endif
`endif

`else   // OR1200_PM_IMPLEMENTED not defined

    //--------------------------------------------------------------------------
    // PM not implemented: fixed inactive state
    //--------------------------------------------------------------------------
    assign pm_clksd    = 4'b0000;
    assign pm_cpu_gate = 1'b0;
    assign pm_dc_gate  = 1'b0;
    assign pm_ic_gate  = 1'b0;
    assign pm_dmmu_gate= 1'b0;
    assign pm_immu_gate= 1'b0;
    assign pm_tt_gate  = 1'b0;
    assign pm_wakeup   = 1'b1;   // always wakeup/de-gated
    assign pm_lvolt    = 1'b0;

`ifdef OR1200_PM_READREGS
    assign spr_dat_o[3:0] = 4'h0;
    assign spr_dat_o[4]   = 1'b0;
    assign spr_dat_o[5]   = 1'b0;
    assign spr_dat_o[6]   = 1'b0;
`ifdef OR1200_PM_UNUSED_ZERO
    assign spr_dat_o[31:7] = 25'h0;
`endif
`endif

`endif  // OR1200_PM_IMPLEMENTED

endmodule