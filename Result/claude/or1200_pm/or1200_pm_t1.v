// Generated from: Description/or1200_pm_description.txt
module or1200_pm(
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

`include "or1200_defines.v"

`ifdef OR1200_PM_IMPLEMENTED
  reg [3:0] sdf;
  reg dme, sme, dcge;

`ifdef OR1200_PM_PARTIAL_DECODING
  wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM);
`else
  wire pmr_sel = (spr_addr[15:11] == `OR1200_SPRGRP_PM) &&
                 (spr_addr[10:0]  == `OR1200_PM_OFS_PMR);
`endif

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      sdf  <= 4'd0;
      dme  <= 1'b0;
      sme  <= 1'b0;
      dcge <= 1'b0;
    end else if (pmr_sel && spr_write) begin
      sdf  <= spr_dat_i[3:0];
      dme  <= spr_dat_i[4];
      sme  <= spr_dat_i[5];
      dcge <= spr_dat_i[6];
    end else if (pic_wakeup) begin
      dme  <= 1'b0;
      sme  <= 1'b0;
    end
  end

  assign pm_clksd = sdf;
  assign pm_wakeup = pic_wakeup;

  wire cpu_gate = (dme | sme) & ~pic_wakeup;
  assign pm_cpu_gate  = cpu_gate;
  assign pm_dc_gate   = cpu_gate;
  assign pm_ic_gate   = cpu_gate;
  assign pm_dmmu_gate = cpu_gate;
  assign pm_immu_gate = cpu_gate;
  assign pm_tt_gate   = sme & ~pic_wakeup;
  assign pm_lvolt     = cpu_gate | pm_cpustall;

`ifdef OR1200_PM_READREGS
  reg [31:0] spr_dat_r;
  assign spr_dat_o = spr_dat_r;
  always @* begin
    spr_dat_r = 32'h0;
    spr_dat_r[3:0] = sdf;
    spr_dat_r[4]   = dme;
    spr_dat_r[5]   = sme;
    spr_dat_r[6]   = dcge;
`ifdef OR1200_PM_UNUSED_ZERO
    spr_dat_r[31:7] = 25'd0;
`endif
  end
`endif

  wire _unused = dcge;
`else
  assign pm_clksd = 4'b0;
  assign pm_dc_gate = 1'b0;
  assign pm_ic_gate = 1'b0;
  assign pm_dmmu_gate = 1'b0;
  assign pm_immu_gate = 1'b0;
  assign pm_tt_gate = 1'b0;
  assign pm_cpu_gate = 1'b0;
  assign pm_wakeup = 1'b1;
  assign pm_lvolt = 1'b0;
`ifdef OR1200_PM_READREGS
  assign spr_dat_o = 32'd0;
`endif
`endif

endmodule
