module or1200_sprs(
    input clk,
    input rst,
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
    output reg [15:0] sr,
    input [31:0] spr_dat_cfgr,
    input [31:0] spr_dat_rf,
    input [31:0] spr_dat_npc,
    input [31:0] spr_dat_ppc,
    input [31:0] spr_dat_mac,
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

localparam [3:0] OR1200_ALUOP_MTSR = 4'he;
localparam [3:0] OR1200_ALUOP_MFSR = 4'hf;
localparam [2:0] OR1200_BRANCHOP_RFE = 3'b100;

localparam [4:0] OR1200_SPR_GROUP_SYS  = 5'd0;
localparam [4:0] OR1200_SPR_GROUP_DMMU = 5'd1;
localparam [4:0] OR1200_SPR_GROUP_IMMU = 5'd2;
localparam [4:0] OR1200_SPR_GROUP_MAC  = 5'd5;
localparam [4:0] OR1200_SPR_GROUP_DU   = 5'd6;
localparam [4:0] OR1200_SPR_GROUP_PM   = 5'd8;
localparam [4:0] OR1200_SPR_GROUP_PIC  = 5'd9;
localparam [4:0] OR1200_SPR_GROUP_TT   = 5'd10;

localparam [10:0] OR1200_SPR_NPC  = 11'h010;
localparam [10:0] OR1200_SPR_SR   = 11'h011;
localparam [10:0] OR1200_SPR_PPC  = 11'h012;
localparam [10:0] OR1200_SPR_EPCR = 11'h020;
localparam [10:0] OR1200_SPR_EEAR = 11'h030;
localparam [10:0] OR1200_SPR_ESR  = 11'h040;

localparam [15:0] OR1200_SR_RESET = 16'hC001;

wire du_access;
wire [3:0] sprs_op;
wire read_spr;
wire write_spr;
wire [31:0] unqualified_cs;
wire rfe;
wire cfgr_sel;
wire rf_sel;
wire npc_sel;
wire ppc_sel;
wire sr_sel;
wire epcr_sel;
wire eear_sel;
wire esr_sel;
wire [31:0] sys_data;

reg [31:0] to_wbmux_r;

assign du_access = du_read | du_write;
assign sprs_op = du_write ? OR1200_ALUOP_MTSR :
                 du_read  ? OR1200_ALUOP_MFSR :
                            alu_op;

assign spr_addr = du_access ? du_addr : (addrbase | {16'h0000, addrofs});
assign spr_dat_o = du_write ? du_dat_du : dat_i;
assign du_dat_cpu = du_write ? du_dat_du :
                    du_read  ? to_wbmux :
                               dat_i;

assign write_spr = (sprs_op == OR1200_ALUOP_MTSR);
assign read_spr = (sprs_op == OR1200_ALUOP_MFSR);

assign unqualified_cs = 32'h0000_0001 << spr_addr[15:11];
assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};
assign spr_we = du_write | write_spr;

assign cfgr_sel = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:4] == 7'd0);
assign rf_sel   = spr_cs[OR1200_SPR_GROUP_SYS] & spr_addr[10];
assign npc_sel  = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_NPC);
assign ppc_sel  = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_PPC);
assign sr_sel   = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_SR);
assign epcr_sel = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_EPCR);
assign eear_sel = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_EEAR);
assign esr_sel  = spr_cs[OR1200_SPR_GROUP_SYS] & (spr_addr[10:0] == OR1200_SPR_ESR);

assign rfe = (branch_op == OR1200_BRANCHOP_RFE);

assign pc_we   = write_spr & (npc_sel | ppc_sel);
assign epcr_we = write_spr & epcr_sel;
assign eear_we = write_spr & eear_sel;
assign esr_we  = write_spr & esr_sel;
assign sr_we   = (write_spr & sr_sel) | rfe | flag_we | cy_we;

assign to_sr[15:11] = rfe ? esr[15:11] :
                      (write_spr & sr_sel) ? {1'b1, spr_dat_o[14:11]} :
                      sr[15:11];
assign to_sr[10] = rfe ? esr[10] :
                   cy_we ? cyforw :
                   (write_spr & sr_sel) ? spr_dat_o[10] :
                   sr[10];
assign to_sr[9] = rfe ? esr[9] :
                  flag_we ? flagforw :
                  (write_spr & sr_sel) ? spr_dat_o[9] :
                  sr[9];
assign to_sr[8:0] = rfe ? esr[8:0] :
                    (write_spr & sr_sel) ? spr_dat_o[8:0] :
                    sr[8:0];

always @(posedge clk or posedge rst) begin
    if (rst)
        sr <= OR1200_SR_RESET;
    else if (except_started)
        sr <= {sr[15:7], 1'b0, 1'b0, sr[4:3], 1'b0, 1'b0, 1'b1};
    else if (sr_we)
        sr <= to_sr;
end

assign flag = sr[9];
assign carry = sr[10];

assign sys_data =
    ({32{read_spr & cfgr_sel}} & spr_dat_cfgr) |
    ({32{read_spr & rf_sel}}   & spr_dat_rf)   |
    ({32{read_spr & npc_sel}}  & spr_dat_npc)  |
    ({32{read_spr & ppc_sel}}  & spr_dat_ppc)  |
    ({32{read_spr & sr_sel}}   & {16'h0000, sr}) |
    ({32{read_spr & epcr_sel}} & epcr) |
    ({32{read_spr & eear_sel}} & eear) |
    ({32{read_spr & esr_sel}}  & {16'h0000, esr});

always @* begin
    to_wbmux_r = 32'h0000_0000;
    if (read_spr) begin
        case (spr_addr[15:11])
            OR1200_SPR_GROUP_TT:   to_wbmux_r = spr_dat_tt;
            OR1200_SPR_GROUP_PIC:  to_wbmux_r = spr_dat_pic;
            OR1200_SPR_GROUP_PM:   to_wbmux_r = spr_dat_pm;
            OR1200_SPR_GROUP_DMMU: to_wbmux_r = spr_dat_dmmu;
            OR1200_SPR_GROUP_IMMU: to_wbmux_r = spr_dat_immu;
            OR1200_SPR_GROUP_MAC:  to_wbmux_r = spr_dat_mac;
            OR1200_SPR_GROUP_DU:   to_wbmux_r = spr_dat_du;
            OR1200_SPR_GROUP_SYS:  to_wbmux_r = sys_data;
            default:               to_wbmux_r = 32'h0000_0000;
        endcase
    end
end

assign to_wbmux = to_wbmux_r;

endmodule
