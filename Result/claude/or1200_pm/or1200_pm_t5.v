module or1200_pm(
    input clk,
    input rst,
    input pic_wakeup,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    
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

    reg [3:0] sdf;
    reg dme;
    reg sme;
    reg dcge;
    
    wire pmr_sel;
    
    assign pmr_sel = (spr_addr[15:11] == 5'b10000);
    
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            sdf <= 4'b0000;
            dme <= 1'b0;
            sme <= 1'b0;
            dcge <= 1'b0;
        end else begin
            if (spr_write && pmr_sel) begin
                sdf <= spr_dat_i[19:16];
                dme <= spr_dat_i[5];
                sme <= spr_dat_i[4];
                dcge <= spr_dat_i[3];
            end else if (pic_wakeup) begin
                dme <= 1'b0;
                sme <= 1'b0;
            end
        end
    end
    
    assign pm_clksd = sdf;
    
    wire pm_cpu_gate_cond;
    assign pm_cpu_gate_cond = (dme | sme) & ~pic_wakeup;
    
    assign pm_cpu_gate = pm_cpu_gate_cond;
    assign pm_dc_gate = pm_cpu_gate_cond;
    assign pm_ic_gate = pm_cpu_gate_cond;
    assign pm_dmmu_gate = pm_cpu_gate_cond;
    assign pm_immu_gate = pm_cpu_gate_cond;
    
    assign pm_tt_gate = sme & ~pic_wakeup;
    
    assign pm_wakeup = pic_wakeup;
    
    assign pm_lvolt = pm_cpu_gate_cond | pm_cpustall;
    
    assign spr_dat_o = pmr_sel ? {12'b0, sdf, 8'b0, dcge, sme, dme, 4'b0} : 32'b0;

endmodule
