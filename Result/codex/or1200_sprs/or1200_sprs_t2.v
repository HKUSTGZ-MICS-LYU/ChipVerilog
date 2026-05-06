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
    output reg [31:0] to_wbmux,
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
    output reg [31:0] du_dat_cpu
);

`ifdef OR1200_ALUOP_MTSR
localparam [3:0] ALUOP_MTSR = `OR1200_ALUOP_MTSR;
`else
localparam [3:0] ALUOP_MTSR = 4'b1111;
`endif

`ifdef OR1200_ALUOP_MFSR
localparam [3:0] ALUOP_MFSR = `OR1200_ALUOP_MFSR;
`else
localparam [3:0] ALUOP_MFSR = 4'b1110;
`endif

`ifdef OR1200_BRANCHOP_RFE
localparam [2:0] BRANCHOP_RFE = `OR1200_BRANCHOP_RFE;
`else
localparam [2:0] BRANCHOP_RFE = 3'b101;
`endif

`ifdef OR1200_SPR_GROUP_SYS
localparam [4:0] SPR_GROUP_SYS = `OR1200_SPR_GROUP_SYS;
`else
localparam [4:0] SPR_GROUP_SYS = 5'd0;
`endif

`ifdef OR1200_SPR_GROUP_DMMU
localparam [4:0] SPR_GROUP_DMMU = `OR1200_SPR_GROUP_DMMU;
`else
localparam [4:0] SPR_GROUP_DMMU = 5'd1;
`endif

`ifdef OR1200_SPR_GROUP_IMMU
localparam [4:0] SPR_GROUP_IMMU = `OR1200_SPR_GROUP_IMMU;
`else
localparam [4:0] SPR_GROUP_IMMU = 5'd2;
`endif

`ifdef OR1200_SPR_GROUP_MAC
localparam [4:0] SPR_GROUP_MAC = `OR1200_SPR_GROUP_MAC;
`else
localparam [4:0] SPR_GROUP_MAC = 5'd5;
`endif

`ifdef OR1200_SPR_GROUP_DU
localparam [4:0] SPR_GROUP_DU = `OR1200_SPR_GROUP_DU;
`else
localparam [4:0] SPR_GROUP_DU = 5'd6;
`endif

`ifdef OR1200_SPR_GROUP_PM
localparam [4:0] SPR_GROUP_PM = `OR1200_SPR_GROUP_PM;
`else
localparam [4:0] SPR_GROUP_PM = 5'd8;
`endif

`ifdef OR1200_SPR_GROUP_PIC
localparam [4:0] SPR_GROUP_PIC = `OR1200_SPR_GROUP_PIC;
`else
localparam [4:0] SPR_GROUP_PIC = 5'd9;
`endif

`ifdef OR1200_SPR_GROUP_TT
localparam [4:0] SPR_GROUP_TT = `OR1200_SPR_GROUP_TT;
`else
localparam [4:0] SPR_GROUP_TT = 5'd10;
`endif

`ifdef OR1200_SPR_NPC
localparam [15:0] SPR_SYS_NPC = `OR1200_SPR_NPC[15:0];
`else
localparam [15:0] SPR_SYS_NPC = 16'h0010;
`endif

`ifdef OR1200_SPR_PPC
localparam [15:0] SPR_SYS_PPC = `OR1200_SPR_PPC[15:0];
`else
localparam [15:0] SPR_SYS_PPC = 16'h0012;
`endif

`ifdef OR1200_SPR_SR
localparam [15:0] SPR_SYS_SR = `OR1200_SPR_SR[15:0];
`else
localparam [15:0] SPR_SYS_SR = 16'h0011;
`endif

`ifdef OR1200_SPR_EPCR
localparam [15:0] SPR_SYS_EPCR = `OR1200_SPR_EPCR[15:0];
`else
localparam [15:0] SPR_SYS_EPCR = 16'h0020;
`endif

`ifdef OR1200_SPR_EEAR
localparam [15:0] SPR_SYS_EEAR = `OR1200_SPR_EEAR[15:0];
`else
localparam [15:0] SPR_SYS_EEAR = 16'h0030;
`endif

`ifdef OR1200_SPR_ESR
localparam [15:0] SPR_SYS_ESR = `OR1200_SPR_ESR[15:0];
`else
localparam [15:0] SPR_SYS_ESR = 16'h0040;
`endif

`ifdef OR1200_SPR_CFGR_MASK
localparam [15:0] SPR_SYS_CFGR_MASK = `OR1200_SPR_CFGR_MASK[15:0];
`else
localparam [15:0] SPR_SYS_CFGR_MASK = 16'hFFF0;
`endif

`ifdef OR1200_SPR_CFGR_BASE
localparam [15:0] SPR_SYS_CFGR_COMPARE = `OR1200_SPR_CFGR_BASE[15:0];
`else
localparam [15:0] SPR_SYS_CFGR_COMPARE = 16'h0000;
`endif

`ifdef OR1200_SPR_RF_MASK
localparam [15:0] SPR_SYS_RF_MASK = `OR1200_SPR_RF_MASK[15:0];
`else
localparam [15:0] SPR_SYS_RF_MASK = 16'hFC00;
`endif

`ifdef OR1200_SPR_RF_BASE
localparam [15:0] SPR_SYS_RF_COMPARE = `OR1200_SPR_RF_BASE[15:0];
`else
localparam [15:0] SPR_SYS_RF_COMPARE = 16'h0400;
`endif

`ifdef OR1200_SR_RESET_VALUE
localparam [15:0] SR_RESET_VALUE = `OR1200_SR_RESET_VALUE[15:0];
`else
localparam [15:0] SR_RESET_VALUE = 16'h8001;
`endif

wire du_access;
wire [3:0] sprs_op;
wire write_spr;
wire read_spr;
wire [31:0] unqualified_cs;
wire rfe;
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
reg [15:0] to_sr_r;

assign du_access = du_read | du_write;
assign sprs_op = du_write ? ALUOP_MTSR : (du_read ? ALUOP_MFSR : alu_op);
assign spr_addr = du_access ? du_addr : (addrbase | {16'h0000, addrofs});
assign spr_dat_o = du_write ? du_dat_du : dat_i;

assign write_spr = (sprs_op == ALUOP_MTSR);
assign read_spr = (sprs_op == ALUOP_MFSR);

assign unqualified_cs = (32'h00000001 << spr_addr[15:11]);
assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};

assign spr_we = du_write | write_spr;

assign rfe = (branch_op == BRANCHOP_RFE);
assign sys_group_sel = spr_cs[SPR_GROUP_SYS];

assign cfgr_sel = sys_group_sel & ((spr_addr[15:0] & SPR_SYS_CFGR_MASK) == SPR_SYS_CFGR_COMPARE);
assign rf_sel = sys_group_sel & ((spr_addr[15:0] & SPR_SYS_RF_MASK) == SPR_SYS_RF_COMPARE);
assign npc_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_NPC);
assign ppc_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_PPC);
assign sr_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_SR);
assign epcr_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_EPCR);
assign eear_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_EEAR);
assign esr_sel = sys_group_sel & (spr_addr[15:0] == SPR_SYS_ESR);

assign pc_we = write_spr & (npc_sel | ppc_sel);
assign epcr_we = write_spr & epcr_sel;
assign eear_we = write_spr & eear_sel;
assign esr_we = write_spr & esr_sel;
assign sr_we = (write_spr & sr_sel) | rfe | flag_we | cy_we;

assign mtsr_to_sr = write_spr & sr_sel;

always @* begin
    if (rfe) begin
        to_sr_r[15:11] = esr[15:11];
    end else if (mtsr_to_sr) begin
        to_sr_r[15] = 1'b1;
        to_sr_r[14:11] = spr_dat_o[14:11];
    end else begin
        to_sr_r[15:11] = sr[15:11];
    end

    if (rfe) begin
        to_sr_r[10] = esr[10];
    end else if (cy_we) begin
        to_sr_r[10] = cyforw;
    end else if (mtsr_to_sr) begin
        to_sr_r[10] = spr_dat_o[10];
    end else begin
        to_sr_r[10] = sr[10];
    end

    if (rfe) begin
        to_sr_r[9] = esr[9];
    end else if (flag_we) begin
        to_sr_r[9] = flagforw;
    end else if (mtsr_to_sr) begin
        to_sr_r[9] = spr_dat_o[9];
    end else begin
        to_sr_r[9] = sr[9];
    end

    if (rfe) begin
        to_sr_r[8:0] = esr[8:0];
    end else if (mtsr_to_sr) begin
        to_sr_r[8:0] = spr_dat_o[8:0];
    end else begin
        to_sr_r[8:0] = sr[8:0];
    end
end

assign to_sr = to_sr_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr <= SR_RESET_VALUE;
    end else if (except_started) begin
        sr[0] <= 1'b1;
        sr[1] <= 1'b0;
        sr[2] <= 1'b0;
        sr[5] <= 1'b0;
        sr[6] <= 1'b0;
    end else if (sr_we) begin
        sr <= to_sr_r;
    end
end

assign flag = sr[9];
assign carry = sr[10];

assign sys_data =
    (spr_dat_cfgr & {32{read_spr & cfgr_sel}}) |
    (spr_dat_rf   & {32{read_spr & rf_sel}})   |
    (spr_dat_npc  & {32{read_spr & npc_sel}})  |
    (spr_dat_ppc  & {32{read_spr & ppc_sel}})  |
    ({16'h0000, sr} & {32{read_spr & sr_sel}}) |
    (epcr         & {32{read_spr & epcr_sel}}) |
    (eear         & {32{read_spr & eear_sel}}) |
    ({16'h0000, esr} & {32{read_spr & esr_sel}});

always @* begin
    if (sprs_op == ALUOP_MFSR) begin
        case (spr_addr[15:11])
            SPR_GROUP_TT:   to_wbmux = spr_dat_tt;
            SPR_GROUP_PIC:  to_wbmux = spr_dat_pic;
            SPR_GROUP_PM:   to_wbmux = spr_dat_pm;
            SPR_GROUP_DMMU: to_wbmux = spr_dat_dmmu;
            SPR_GROUP_IMMU: to_wbmux = spr_dat_immu;
            SPR_GROUP_MAC:  to_wbmux = spr_dat_mac;
            SPR_GROUP_DU:   to_wbmux = spr_dat_du;
            SPR_GROUP_SYS:  to_wbmux = sys_data;
            default:        to_wbmux = 32'h00000000;
        endcase
    end else begin
        to_wbmux = 32'h00000000;
    end
end

always @* begin
    if (du_write) begin
        du_dat_cpu = du_dat_du;
    end else if (du_read) begin
        du_dat_cpu = to_wbmux;
    end else begin
        du_dat_cpu = dat_i;
    end
end

endmodule
