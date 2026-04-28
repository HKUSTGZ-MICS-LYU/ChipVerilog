`include "timescale.v"
`include "or1200_defines.v"

module or1200_pm(
    clk, rst,
    pic_wakeup, spr_write, spr_addr, spr_dat_i, spr_dat_o,
    pm_clksd, pm_cpustall,
    pm_dc_gate, pm_ic_gate, pm_dmmu_gate, pm_immu_gate,
    pm_tt_gate, pm_cpu_gate, pm_wakeup, pm_lvolt
);

input         clk, rst;
input         pic_wakeup;
input         spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;
output [3:0]  pm_clksd;
input         pm_cpustall;
output        pm_dc_gate, pm_ic_gate, pm_dmmu_gate, pm_immu_gate;
output        pm_tt_gate, pm_cpu_gate, pm_wakeup, pm_lvolt;

`ifdef OR1200_PM_IMPLEMENTED

reg [3:0] sdf;
reg       dme, sme, dcge;

// PMR address select
`ifdef OR1200_PM_PARTIAL_DECODING
wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM);
`else
wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM) &
               (spr_addr[10:0]  == `OR1200_PM_OFS_PMR);
`endif

// PMR sequential update
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sdf  <= 4'b0;
        dme  <= 1'b0;
        sme  <= 1'b0;
        dcge <= 1'b0;
    end
    else if (pmr_sel & spr_write) begin
        sdf  <= spr_dat_i[3:0];
        dme  <= spr_dat_i[4];
        sme  <= spr_dat_i[5];
        dcge <= spr_dat_i[6];
    end
    else if (pic_wakeup) begin
        dme <= 1'b0;
        sme <= 1'b0;
    end
end

// Combinational outputs
assign pm_clksd    = sdf;
assign pm_cpu_gate = (dme | sme) & ~pic_wakeup;
assign pm_dc_gate  = pm_cpu_gate;
assign pm_ic_gate  = pm_cpu_gate;
assign pm_dmmu_gate = pm_cpu_gate;
assign pm_immu_gate = pm_cpu_gate;
assign pm_tt_gate  = sme & ~pic_wakeup;
assign pm_wakeup   = pic_wakeup;
assign pm_lvolt    = pm_cpu_gate | pm_cpustall;

// SPR read
`ifdef OR1200_PM_READREGS
assign spr_dat_o[3:0] = sdf;
assign spr_dat_o[4]   = dme;
assign spr_dat_o[5]   = sme;
assign spr_dat_o[6]   = dcge;
`ifdef OR1200_PM_UNUSED_ZERO
assign spr_dat_o[31:7] = 25'h0;
`endif
`endif

`else // !OR1200_PM_IMPLEMENTED

assign pm_clksd     = 4'b0;
assign pm_cpu_gate  = 1'b0;
assign pm_dc_gate   = 1'b0;
assign pm_ic_gate   = 1'b0;
assign pm_dmmu_gate = 1'b0;
assign pm_immu_gate = 1'b0;
assign pm_tt_gate   = 1'b0;
assign pm_wakeup    = 1'b1;
assign pm_lvolt     = 1'b0;

`ifdef OR1200_PM_READREGS
assign spr_dat_o[6:0] = 7'h0;
`ifdef OR1200_PM_UNUSED_ZERO
assign spr_dat_o[31:7] = 25'h0;
`endif
`endif

`endif // OR1200_PM_IMPLEMENTED

endmodule