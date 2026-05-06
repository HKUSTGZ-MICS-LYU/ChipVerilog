module or1200_sprs #(
    parameter [3:0] ALUOP_MTSR = 4'he,
    parameter [3:0] ALUOP_MFSR = 4'hf,
    parameter [2:0] BRANCHOP_RFE = 3'd6,
    parameter [15:0] SR_RESET_VALUE = 16'h8001,
    parameter [4:0] SPR_GROUP_SYS  = 5'd0,
    parameter [4:0] SPR_GROUP_DMMU = 5'd1,
    parameter [4:0] SPR_GROUP_IMMU = 5'd2,
    parameter [4:0] SPR_GROUP_MAC  = 5'd5,
    parameter [4:0] SPR_GROUP_DU   = 5'd6,
    parameter [4:0] SPR_GROUP_PM   = 5'd8,
    parameter [4:0] SPR_GROUP_PIC  = 5'd9,
    parameter [4:0] SPR_GROUP_TT   = 5'd10,
    parameter [15:0] SPR_SYS_NPC  = 16'h0010,
    parameter [15:0] SPR_SYS_SR   = 16'h0011,
    parameter [15:0] SPR_SYS_PPC  = 16'h0012,
    parameter [15:0] SPR_SYS_EPCR = 16'h0020,
    parameter [15:0] SPR_SYS_EEAR = 16'h0030,
    parameter [15:0] SPR_SYS_ESR  = 16'h0040,
    parameter [6:0] SPR_SYS_CFGR_REGION = 7'h00,
    parameter [5:0] SPR_SYS_RF_REGION   = 6'h20
)(
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
    output [15:0] sr,
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

reg [15:0] sr;
reg read_spr;
reg write_spr;
reg [31:0] to_wbmux_r;

wire du_access;
wire [3:0] sprs_op;
wire rfe;
wire [31:0] unqualified_cs;
wire sys_group_sel;
wire cfgr_sel;
wire rf_sel;
wire npc_sel;
wire ppc_sel;
wire sr_sel;
wire epcr_sel;
wire eear_sel;
wire esr_sel;
wire mtsr_to_sr;
wire [31:0] sys_data;

assign du_access = du_read | du_write;
assign sprs_op = du_write ? ALUOP_MTSR :
                 du_read  ? ALUOP_MFSR :
                            alu_op;
assign rfe = (branch_op == BRANCHOP_RFE);

assign spr_addr = du_access ? du_addr : (addrbase | {16'h0000, addrofs});
assign spr_dat_o = du_write ? du_dat_du : dat_i;
assign du_dat_cpu = du_write ? du_dat_du :
                    du_read  ? to_wbmux_r :
                               dat_i;

assign unqualified_cs = 32'h0000_0001 << spr_addr[15:11];
assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};
assign spr_we = du_write | write_spr;
assign to_wbmux = to_wbmux_r;

assign sys_group_sel = spr_cs[0];
assign cfgr_sel = sys_group_sel & (spr_addr[10:4] == SPR_SYS_CFGR_REGION);
assign rf_sel   = sys_group_sel & (spr_addr[10:5] == SPR_SYS_RF_REGION);
assign npc_sel  = sys_group_sel & (spr_addr[15:0] == SPR_SYS_NPC);
assign ppc_sel  = sys_group_sel & (spr_addr[15:0] == SPR_SYS_PPC);
assign sr_sel   = sys_group_sel & (spr_addr[15:0] == SPR_SYS_SR);
assign epcr_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_EPCR);
assign eear_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_EEAR);
assign esr_sel  = sys_group_sel & (spr_addr[15:0] == SPR_SYS_ESR);

assign pc_we   = write_spr & (npc_sel | ppc_sel);
assign epcr_we = write_spr & epcr_sel;
assign eear_we = write_spr & eear_sel;
assign esr_we  = write_spr & esr_sel;

assign mtsr_to_sr = write_spr & sr_sel;
assign sr_we = mtsr_to_sr | rfe | flag_we | cy_we;

assign to_sr = {
    rfe ? esr[15:11] : (mtsr_to_sr ? {1'b1, spr_dat_o[14:11]} : sr[15:11]),
    rfe ? esr[10]    : (cy_we ? cyforw : (mtsr_to_sr ? spr_dat_o[10] : sr[10])),
    rfe ? esr[9]     : (flag_we ? flagforw : (mtsr_to_sr ? spr_dat_o[9] : sr[9])),
    rfe ? esr[8:0]   : (mtsr_to_sr ? spr_dat_o[8:0] : sr[8:0])
};

assign sys_data =
    ({32{read_spr & cfgr_sel}} & spr_dat_cfgr) |
    ({32{read_spr & rf_sel}}   & spr_dat_rf)   |
    ({32{read_spr & npc_sel}}  & spr_dat_npc)  |
    ({32{read_spr & ppc_sel}}  & spr_dat_ppc)  |
    ({32{read_spr & sr_sel}}   & {16'h0000, sr}) |
    ({32{read_spr & epcr_sel}} & epcr)         |
    ({32{read_spr & eear_sel}} & eear)         |
    ({32{read_spr & esr_sel}}  & {16'h0000, esr});

assign flag = sr[9];
assign carry = sr[10];

always @* begin
    read_spr = 1'b0;
    write_spr = 1'b0;
    to_wbmux_r = 32'h0000_0000;

    case (sprs_op)
        ALUOP_MTSR: begin
            write_spr = 1'b1;
        end
        ALUOP_MFSR: begin
            read_spr = 1'b1;
            case (spr_addr[15:11])
                SPR_GROUP_SYS:  to_wbmux_r = sys_data;
                SPR_GROUP_TT:   to_wbmux_r = spr_dat_tt;
                SPR_GROUP_PIC:  to_wbmux_r = spr_dat_pic;
                SPR_GROUP_PM:   to_wbmux_r = spr_dat_pm;
                SPR_GROUP_DMMU: to_wbmux_r = spr_dat_dmmu;
                SPR_GROUP_IMMU: to_wbmux_r = spr_dat_immu;
                SPR_GROUP_MAC:  to_wbmux_r = spr_dat_mac;
                SPR_GROUP_DU:   to_wbmux_r = spr_dat_du;
                default:        to_wbmux_r = 32'h0000_0000;
            endcase
        end
        default: begin
            to_wbmux_r = 32'h0000_0000;
        end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst)
        sr <= SR_RESET_VALUE;
    else if (except_started)
        sr <= {sr[15:7], 1'b0, 1'b0, sr[4:3], 1'b0, 1'b0, 1'b1};
    else if (sr_we)
        sr <= to_sr;
end

endmodule
