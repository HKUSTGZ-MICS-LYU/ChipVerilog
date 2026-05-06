`include "or1200_defines.v"

module or1200_sprs(
    input               clk,
    input               rst,
    input               flagforw,
    input               flag_we,
    output              flag,
    input               cyforw,
    input               cy_we,
    output              carry,
    input  [31:0]       addrbase,
    input  [15:0]       addrofs,
    input  [31:0]       dat_i,
    input  [3:0]        alu_op,
    input  [2:0]        branch_op,
    input  [31:0]       epcr,
    input  [31:0]       eear,
    input  [15:0]       esr,
    input               except_started,
    output [31:0]       to_wbmux,
    output              epcr_we,
    output              eear_we,
    output              esr_we,
    output              pc_we,
    output              sr_we,
    output [15:0]       to_sr,
    output reg [15:0]   sr,
    input  [31:0]       spr_dat_cfgr,
    input  [31:0]       spr_dat_rf,
    input  [31:0]       spr_dat_npc,
    input  [31:0]       spr_dat_ppc,
    input  [31:0]       spr_dat_mac,
    input  [31:0]       spr_dat_pic,
    input  [31:0]       spr_dat_tt,
    input  [31:0]       spr_dat_pm,
    input  [31:0]       spr_dat_dmmu,
    input  [31:0]       spr_dat_immu,
    input  [31:0]       spr_dat_du,
    output [31:0]       spr_addr,
    output [31:0]       spr_dat_o,
    output [31:0]       spr_cs,
    output              spr_we,
    input  [31:0]       du_addr,
    input  [31:0]       du_dat_du,
    input               du_read,
    input               du_write,
    output [31:0]       du_dat_cpu
);

wire du_access = du_read | du_write;
wire [3:0] sprs_op = du_write ? `OR1200_ALUOP_MTSR : (du_read ? `OR1200_ALUOP_MFSR : alu_op);
wire [31:0] spr_addr_int = du_access ? du_addr : (addrbase + {{16{addrofs[15]}}, addrofs});
wire [31:0] spr_dat_src = du_write ? du_dat_du : dat_i;
wire write_spr = (sprs_op == `OR1200_ALUOP_MTSR);
wire read_spr  = (sprs_op == `OR1200_ALUOP_MFSR);
wire [4:0] spr_group = spr_addr_int[`OR1200_SPR_GROUP_BITS];
reg [31:0] read_dat;
reg [31:0] unqualified_cs;
wire rfe = (branch_op == `OR1200_BRANCHOP_RFE);
wire sr_sel   = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_SR);
wire epcr_sel = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_EPCR);
wire eear_sel = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_EEAR);
wire esr_sel  = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_ESR);
wire npc_sel  = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_NPC);
wire ppc_sel  = (spr_group == `OR1200_SPR_GROUP_SYS) && (spr_addr_int[`OR1200_SPROFS_BITS] == `OR1200_SPR_PPC);

always @* begin
    unqualified_cs = 32'b0;
    unqualified_cs[spr_group] = 1'b1;
end

assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};
assign spr_we = write_spr;
assign spr_addr = spr_addr_int;
assign spr_dat_o = spr_dat_src;
assign flag = sr[`OR1200_SR_F];
assign carry = sr[`OR1200_SR_CY];
assign epcr_we = write_spr & epcr_sel;
assign eear_we = write_spr & eear_sel;
assign esr_we  = write_spr & esr_sel;
assign pc_we   = write_spr & (npc_sel | ppc_sel);
assign sr_we   = (write_spr & sr_sel) | rfe | flag_we | cy_we;

reg [15:0] to_sr_r;
always @* begin
    to_sr_r = sr;
    if (rfe)
        to_sr_r = esr;
    if (write_spr && sr_sel)
        to_sr_r = spr_dat_src[15:0];
    if (flag_we)
        to_sr_r[`OR1200_SR_F] = flagforw;
    if (cy_we)
        to_sr_r[`OR1200_SR_CY] = cyforw;
end
assign to_sr = to_sr_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr <= 16'b0;
        sr[`OR1200_SR_SM]  <= 1'b1;
        sr[`OR1200_SR_EPH] <= `OR1200_SR_EPH_DEF;
    end else if (except_started) begin
        sr[`OR1200_SR_SM]  <= 1'b1;
        sr[`OR1200_SR_TEE] <= 1'b0;
        sr[`OR1200_SR_IEE] <= 1'b0;
        sr[`OR1200_SR_DME] <= 1'b0;
        sr[`OR1200_SR_IME] <= 1'b0;
    end else if (sr_we) begin
        sr <= to_sr_r;
    end
end

always @* begin
    case (spr_group)
        `OR1200_SPR_GROUP_SYS: begin
            case (spr_addr_int[`OR1200_SPROFS_BITS])
                `OR1200_SPR_NPC:  read_dat = spr_dat_npc;
                `OR1200_SPR_PPC:  read_dat = spr_dat_ppc;
                `OR1200_SPR_SR:   read_dat = {16'b0, sr};
                `OR1200_SPR_EPCR: read_dat = epcr;
                `OR1200_SPR_EEAR: read_dat = eear;
                `OR1200_SPR_ESR:  read_dat = {16'b0, esr};
                default:          read_dat = spr_dat_cfgr | spr_dat_rf;
            endcase
        end
        `OR1200_SPR_GROUP_PIC:  read_dat = spr_dat_pic;
        `OR1200_SPR_GROUP_TT:   read_dat = spr_dat_tt;
        `OR1200_SPR_GROUP_PM:   read_dat = spr_dat_pm;
        `OR1200_SPR_GROUP_DMMU: read_dat = spr_dat_dmmu;
        `OR1200_SPR_GROUP_IMMU: read_dat = spr_dat_immu;
        `OR1200_SPR_GROUP_MAC:  read_dat = spr_dat_mac;
        `OR1200_SPR_GROUP_DU:   read_dat = spr_dat_du;
        default:                read_dat = 32'b0;
    endcase
end

assign to_wbmux = read_spr ? read_dat : 32'b0;
assign du_dat_cpu = du_write ? du_dat_du : (du_read ? to_wbmux : dat_i);

endmodule
