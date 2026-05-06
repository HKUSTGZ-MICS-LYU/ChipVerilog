// Module: or1200_pm
// Power management control logic for OR1200 processor

module or1200_pm (
    // RISC Internal Interface
    input         clk,
    input         rst,
    input         pic_wakeup,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    // Power Management Interface
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

    // Internal state registers
    reg [3:0] sdf;
    reg       dme;
    reg       sme;
    reg       dcge;

    // PMR address select
    wire pmr_sel;
    `ifdef OR1200_PM_PARTIAL_DECODING
        // Partial decoding: only check SPR group
        assign pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM);
    `else
        // Full decoding: check group and offset
        assign pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM) &&
                         (spr_addr[10:0] == `OR1200_PM_OFS_PMR);
    `endif

    // Sequential state update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sdf  <= 4'b0;
            dme  <= 1'b0;
            sme  <= 1'b0;
            dcge <= 1'b0;
        end else if (pmr_sel && spr_write) begin
            sdf  <= spr_dat_i[3:0];
            dme  <= spr_dat_i[4];
            sme  <= spr_dat_i[5];
            dcge <= spr_dat_i[6];
        end else if (pic_wakeup) begin
            dme <= 1'b0;
            sme <= 1'b0;
            // sdf and dcge retain their values
        end
    end

    // Combinational output generation
    assign pm_clksd = sdf;

    assign pm_cpu_gate  = (dme | sme) & ~pic_wakeup;
    assign pm_dc_gate   = pm_cpu_gate;
    assign pm_ic_gate   = pm_cpu_gate;
    assign pm_dmmu_gate = pm_cpu_gate;
    assign pm_immu_gate = pm_cpu_gate;

    assign pm_tt_gate   = sme & ~pic_wakeup;

    assign pm_wakeup = pic_wakeup;
    assign pm_lvolt  = pm_cpu_gate | pm_cpustall;

    // SPR read data
    `ifdef OR1200_PM_READREGS
        assign spr_dat_o[3:0] = sdf;
        assign spr_dat_o[4]   = dme;
        assign spr_dat_o[5]   = sme;
        assign spr_dat_o[6]   = dcge;
        `ifdef OR1200_PM_UNUSED_ZERO
            assign spr_dat_o[31:7] = 25'b0;
        `endif
    `endif

`else // !OR1200_PM_IMPLEMENTED

    // Power management not implemented: fixed outputs
    assign pm_clksd     = 4'b0;
    assign pm_cpu_gate  = 1'b0;
    assign pm_dc_gate   = 1'b0;
    assign pm_ic_gate   = 1'b0;
    assign pm_dmmu_gate = 1'b0;
    assign pm_immu_gate = 1'b0;
    assign pm_tt_gate   = 1'b0;
    assign pm_wakeup    = 1'b1;
    assign pm_lvolt     = 1'b0;

    // SPR read data when PM not implemented
    `ifdef OR1200_PM_READREGS
        assign spr_dat_o[3:0] = 4'b0;
        assign spr_dat_o[4]   = 1'b0;
        assign spr_dat_o[5]   = 1'b0;
        assign spr_dat_o[6]   = 1'b0;
        `ifdef OR1200_PM_UNUSED_ZERO
            assign spr_dat_o[31:7] = 25'b0;
        `endif
    `endif

`endif

endmodule
