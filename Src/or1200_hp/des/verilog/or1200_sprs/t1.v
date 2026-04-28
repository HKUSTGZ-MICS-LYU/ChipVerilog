`include "timescale.v"
`include "or1200_defines.v"

module or1200_sprs(
    clk, rst,
    flagforw, flag_we, flag,
    cyforw, cy_we, carry,
    addrbase, addrofs, dat_i, alu_op, branch_op,
    epcr, eear, esr, except_started,
    to_wbmux, epcr_we, eear_we, esr_we, pc_we, sr_we, to_sr, sr,
    spr_dat_cfgr, spr_dat_rf, spr_dat_npc, spr_dat_ppc, spr_dat_mac,
    spr_dat_pic, spr_dat_tt, spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du,
    spr_addr, spr_dat_o, spr_cs, spr_we,
    du_addr, du_dat_du, du_read, du_write, du_dat_cpu
);

input         clk, rst;
input         flagforw, flag_we;
output        flag;
input         cyforw, cy_we;
output        carry;
input  [31:0] addrbase;
input  [15:0] addrofs;
input  [31:0] dat_i;
input  [3:0]  alu_op;
input  [2:0]  branch_op;
input  [31:0] epcr, eear;
input  [15:0] esr;
input         except_started;
output [31:0] to_wbmux;
output        epcr_we, eear_we, esr_we, pc_we, sr_we;
output [15:0] to_sr, sr;
input  [31:0] spr_dat_cfgr, spr_dat_rf, spr_dat_npc, spr_dat_ppc, spr_dat_mac;
input  [31:0] spr_dat_pic, spr_dat_tt, spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du;
output [31:0] spr_addr, spr_dat_o, spr_cs;
output        spr_we;
input  [31:0] du_addr, du_dat_du;
input         du_read, du_write;
output [31:0] du_dat_cpu;

// Internal SR register
reg [15:0] sr_r;
assign sr    = sr_r;
assign flag  = sr_r[9];
assign carry = sr_r[10];

// Debug Unit access arbitration
wire du_access = du_read | du_write;

// Effective SPR operation
wire [3:0] sprs_op = du_write ? `OR1200_ALUOP_MTSR :
                     du_read  ? `OR1200_ALUOP_MFSR :
                     alu_op;

wire read_spr  = (sprs_op == `OR1200_ALUOP_MFSR);
wire write_spr = (sprs_op == `OR1200_ALUOP_MTSR);

// SPR address and write data
assign spr_addr  = du_access ? du_addr : addrbase | {16'h0000, addrofs};
assign spr_dat_o = du_write  ? du_dat_du : dat_i;
assign spr_we    = du_write | write_spr;

// Debug Unit data return
assign du_dat_cpu = du_write ? du_dat_du :
                    du_read  ? to_wbmux  :
                    dat_i;

// SPR group chip-select (one-hot on spr_addr[15:11], qualified by read/write)
wire [31:0] unqualified_cs;
assign unqualified_cs = (32'h1 << spr_addr[15:11]);
assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};

// System group internal decode
wire sys_group = spr_cs[`OR1200_SPR_GROUP_SYS];

wire cfgr_sel  = sys_group & (spr_addr[10:4] == `OR1200_SPRGRP_SYS_CFGR);
wire rf_sel    = sys_group & (spr_addr[10:5] == `OR1200_SPR_RF);
wire npc_sel   = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_NPC);
wire ppc_sel   = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_PPC);
wire sr_sel    = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_SR);
wire epcr_sel  = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_EPCR);
wire eear_sel  = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_EEAR);
wire esr_sel   = sys_group & (spr_addr[10:0] == `OR1200_SPRGRP_SYS_ESR);

// System group write enables
assign pc_we   = write_spr & (npc_sel | ppc_sel);
assign epcr_we = write_spr & epcr_sel;
assign eear_we = write_spr & eear_sel;
assign esr_we  = write_spr & esr_sel;

// RFE condition
wire rfe = (branch_op == `OR1200_BRANCHOP_RFE);

// sr_we: SR written by MTSR, RFE, flag/carry update
assign sr_we = (write_spr & sr_sel) | rfe | flag_we | cy_we;

// to_sr: next SR value (without except_started priority)
// bits [15:11]: mode/prefix bits
assign to_sr[15] = rfe ? esr[15] :
                   (write_spr & sr_sel) ? 1'b1 :
                   sr_r[15];
assign to_sr[14:11] = rfe ? esr[14:11] :
                      (write_spr & sr_sel) ? spr_dat_o[14:11] :
                      sr_r[14:11];
// bit [10]: carry
assign to_sr[10] = rfe    ? esr[10] :
                   cy_we  ? cyforw  :
                   (write_spr & sr_sel) ? spr_dat_o[10] :
                   sr_r[10];
// bit [9]: flag
assign to_sr[9]  = rfe     ? esr[9]    :
                   flag_we ? flagforw  :
                   (write_spr & sr_sel) ? spr_dat_o[9] :
                   sr_r[9];
// bits [8:0]
assign to_sr[8:0] = rfe ? esr[8:0] :
                    (write_spr & sr_sel) ? spr_dat_o[8:0] :
                    sr_r[8:0];

// SR register sequential update
always @(posedge clk or posedge rst) begin
    if (rst)
        sr_r <= `OR1200_SR_RESET_VALUE;
    else if (except_started) begin
        // Exception entry: set supv, clear IEE, TEE, DME, IME
        sr_r[0] <= 1'b1;
        sr_r[2] <= 1'b0;
        sr_r[1] <= 1'b0;
        sr_r[5] <= 1'b0;
        sr_r[6] <= 1'b0;
    end
    else if (sr_we)
        sr_r <= to_sr;
end

// sys_data: system group read mux
wire [31:0] sys_data =
    ({32{cfgr_sel & read_spr}} & spr_dat_cfgr) |
    ({32{rf_sel   & read_spr}} & spr_dat_rf)   |
    ({32{npc_sel  & read_spr}} & spr_dat_npc)  |
    ({32{ppc_sel  & read_spr}} & spr_dat_ppc)  |
    ({32{sr_sel   & read_spr}} & {16'h0, sr_r}) |
    ({32{epcr_sel & read_spr}} & epcr)         |
    ({32{eear_sel & read_spr}} & eear)         |
    ({32{esr_sel  & read_spr}} & {16'h0, esr});

// to_wbmux: SPR read data to writeback mux
assign to_wbmux =
    write_spr ? 32'h0 :
    ~read_spr ? 32'h0 :
    (spr_addr[15:11] == `OR1200_SPRGRP_TT)   ? spr_dat_tt   :
    (spr_addr[15:11] == `OR1200_SPRGRP_PIC)  ? spr_dat_pic  :
    (spr_addr[15:11] == `OR1200_SPRGRP_PM)   ? spr_dat_pm   :
    (spr_addr[15:11] == `OR1200_SPRGRP_DMMU) ? spr_dat_dmmu :
    (spr_addr[15:11] == `OR1200_SPRGRP_IMMU) ? spr_dat_immu :
    (spr_addr[15:11] == `OR1200_SPRGRP_MAC)  ? spr_dat_mac  :
    (spr_addr[15:11] == `OR1200_SPRGRP_DU)   ? spr_dat_du   :
    (spr_addr[15:11] == `OR1200_SPRGRP_SYS)  ? sys_data     :
    32'h0;

endmodule