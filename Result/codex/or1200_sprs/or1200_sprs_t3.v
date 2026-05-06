// Generated from or1200_sprs/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_sprs(
    // Clk & Rst
    input clk,
    input rst,

    // Internal CPU interface
    input flagforw,
    input flag_we,
    output flag,
    input cyforw,
    input cy_we,
    output carry,
    input [31:0] addrbase,
    input [15:0] addrofs,
    input [31:0] dat_i,
    input [3:0] alu_op,
    input [2:0] branch_op,
    input [31:0] epcr,
    input [31:0] eear,
    input [15:0] esr,
    input except_started,
    output [31:0] to_wbmux,
    output epcr_we,
    output eear_we,
    output esr_we,
    output pc_we,
    output sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
    input [31:0] spr_dat_cfgr,
    input [31:0] spr_dat_rf,
    input [31:0] spr_dat_npc,
    input [31:0] spr_dat_ppc,
    input [31:0] spr_dat_mac,

    // From/to other RISC units
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output spr_we,

    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    output [31:0] du_dat_cpu
);

reg flag_r;
reg carry_r;
reg [31:0] to_wbmux_r;
reg epcr_we_r;
reg eear_we_r;
reg esr_we_r;
reg pc_we_r;
reg sr_we_r;
reg [15:0] to_sr_r;
reg [15:0] sr_r;
reg [31:0] spr_addr_r;
reg [31:0] spr_dat_o_r;
reg [31:0] spr_cs_r;
reg spr_we_r;
reg [31:0] du_dat_cpu_r;
assign flag = flag_r;
assign carry = carry_r;
assign to_wbmux = to_wbmux_r;
assign epcr_we = epcr_we_r;
assign eear_we = eear_we_r;
assign esr_we = esr_we_r;
assign pc_we = pc_we_r;
assign sr_we = sr_we_r;
assign to_sr = to_sr_r;
assign sr = sr_r;
assign spr_addr = spr_addr_r;
assign spr_dat_o = spr_dat_o_r;
assign spr_cs = spr_cs_r;
assign spr_we = spr_we_r;
assign du_dat_cpu = du_dat_cpu_r;

reg [31:0] sr_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr_reg <= 32'd0;
    end else begin
        if (flag_we)
            sr_reg[0] <= flagforw;
        if (cy_we)
            sr_reg[1] <= cyforw;
        if (sr_we_r)
            sr_reg[15:0] <= to_sr_r;
    end
end

always @* begin
    flag_r = sr_reg[0];
    carry_r = sr_reg[1];
    spr_cs_r = 32'd0;
    spr_we_r = du_write | (alu_op == 4'hc);
    spr_addr_r = du_read | du_write ? du_addr : (addrbase + addrofs);
    spr_dat_o_r = du_write ? du_dat_du : dat_i;
    du_dat_cpu_r = du_write ? du_dat_du : to_wbmux_r;
    to_wbmux_r = spr_dat_pic | spr_dat_tt | spr_dat_pm | spr_dat_cfgr | spr_dat_rf |
                 spr_dat_npc | spr_dat_ppc | spr_dat_mac | spr_dat_dmmu | spr_dat_immu | spr_dat_du;
    epcr_we_r = except_started;
    eear_we_r = except_started;
    esr_we_r = except_started;
    pc_we_r = (branch_op != 0);
    sr_we_r = flag_we | cy_we;
    to_sr_r = {14'd0, cyforw, flagforw};
    sr_r = sr_reg[15:0];
end

endmodule
