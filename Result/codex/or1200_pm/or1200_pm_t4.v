// Generated from or1200_pm/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_pm(
    // RISC Internal Interface
    input clk,
    input rst,
    input pic_wakeup,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    // Power Management Interface
    output [3:0] pm_clksd,
    input pm_cpustall,
    output pm_dc_gate,
    output pm_ic_gate,
    output pm_dmmu_gate,
    output pm_immu_gate,
    output pm_tt_gate,
    output pm_cpu_gate,
    output pm_wakeup,
    output pm_lvolt
);

reg [31:0] spr_dat_o_r;
reg [3:0] pm_clksd_r;
reg pm_dc_gate_r;
reg pm_ic_gate_r;
reg pm_dmmu_gate_r;
reg pm_immu_gate_r;
reg pm_tt_gate_r;
reg pm_cpu_gate_r;
reg pm_wakeup_r;
reg pm_lvolt_r;
assign spr_dat_o = spr_dat_o_r;
assign pm_clksd = pm_clksd_r;
assign pm_dc_gate = pm_dc_gate_r;
assign pm_ic_gate = pm_ic_gate_r;
assign pm_dmmu_gate = pm_dmmu_gate_r;
assign pm_immu_gate = pm_immu_gate_r;
assign pm_tt_gate = pm_tt_gate_r;
assign pm_cpu_gate = pm_cpu_gate_r;
assign pm_wakeup = pm_wakeup_r;
assign pm_lvolt = pm_lvolt_r;

reg [3:0] pmr_sdf;
reg pmr_dme;
reg pmr_sme;
reg pmr_dcge;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pmr_sdf <= 4'd0;
        pmr_dme <= 1'b0;
        pmr_sme <= 1'b0;
        pmr_dcge <= 1'b0;
    end else begin
        if (spr_write) begin
            pmr_sdf <= spr_dat_i[3:0];
            pmr_dme <= spr_dat_i[4];
            pmr_sme <= spr_dat_i[5];
            pmr_dcge <= spr_dat_i[6];
        end
        if (pic_wakeup) begin
            pmr_dme <= 1'b0;
            pmr_sme <= 1'b0;
        end
    end
end

always @* begin
    spr_dat_o_r = {25'd0, pmr_dcge, pmr_sme, pmr_dme, pmr_sdf};
    pm_clksd_r = pmr_sdf;
    pm_dc_gate_r = pmr_dcge & (pmr_dme | pmr_sme);
    pm_ic_gate_r = pm_dc_gate_r;
    pm_dmmu_gate_r = pm_dc_gate_r;
    pm_immu_gate_r = pm_dc_gate_r;
    pm_tt_gate_r = pm_dc_gate_r;
    pm_cpu_gate_r = pm_dc_gate_r | pm_cpustall;
    pm_wakeup_r = pic_wakeup;
    pm_lvolt_r = 1'b0;
end

endmodule
