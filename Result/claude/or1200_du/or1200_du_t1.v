module or1200_du(
    input clk,
    input rst,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    input [31:0] dcpu_adr_i,
    input [31:0] dcpu_dat_lsu,
    input [31:0] dcpu_dat_dc,
    input icpu_cycstb_i,
    input ex_freeze,
    input [2:0] branch_op,
    input [31:0] ex_insn,
    input [31:0] id_pc,
    input [31:0] spr_dat_npc,
    input [31:0] rf_dataw,
    output [13:0] du_dsr,
    output du_stall,
    output [31:0] du_addr,
    input [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output du_read,
    output du_write,
    input [12:0] du_except,
    output du_hwbkpt,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    input dbg_stall_i,
    input dbg_ewt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o
);

localparam [10:0] SPR_DMR1      = 11'h300;
localparam [10:0] SPR_DMR2      = 11'h301;
localparam [10:0] SPR_DSR       = 11'h302;
localparam [10:0] SPR_DRR       = 11'h303;
localparam [10:0] SPR_DVR0      = 11'h304;
localparam [10:0] SPR_DVR1      = 11'h305;
localparam [10:0] SPR_DVR2      = 11'h306;
localparam [10:0] SPR_DVR3      = 11'h307;
localparam [10:0] SPR_DVR4      = 11'h308;
localparam [10:0] SPR_DVR5      = 11'h309;
localparam [10:0] SPR_DVR6      = 11'h30a;
localparam [10:0] SPR_DVR7      = 11'h30b;
localparam [10:0] SPR_DCR0      = 11'h30c;
localparam [10:0] SPR_DCR1      = 11'h30d;
localparam [10:0] SPR_DCR2      = 11'h30e;
localparam [10:0] SPR_DCR3      = 11'h30f;
localparam [10:0] SPR_DCR4      = 11'h310;
localparam [10:0] SPR_DCR5      = 11'h311;
localparam [10:0] SPR_DCR6      = 11'h312;
localparam [10:0] SPR_DCR7      = 11'h313;
localparam [10:0] SPR_DWCR0     = 11'h314;
localparam [10:0] SPR_DWCR1     = 11'h315;
localparam [10:0] SPR_TBADR     = 11'h318;
localparam [10:0] SPR_TBDATA_NPC= 11'h319;
localparam [10:0] SPR_TBDATA_INS= 11'h31a;
localparam [10:0] SPR_TBDATA_WB = 11'h31b;
localparam [10:0] SPR_TBDATA_TS = 11'h31c;

localparam [31:0] EXCL_NOP = 32'h1500_0000;

wire [13:0] except_stop;
assign except_stop = {1'b0, du_except};

assign du_stall = dbg_stall_i;
assign du_addr  = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read  = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i &  dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_wp_o = 11'b000_0000_0000;

reg dbg_ack_r;
assign dbg_ack_o = dbg_ack_r;

always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_r <= 1'b0;
    else
        dbg_ack_r <= dbg_stb_i;
end

`ifndef OR1200_DU_STATUS_UNIMPLEMENTED
assign dbg_lss_o = {2'b00, dcpu_we_i, dcpu_cycstb_i};
assign dbg_is_o  = {1'b0, icpu_cycstb_i[0]};
`else
assign dbg_lss_o = 4'b0000;
reg [1:0] dbg_is_r;
assign dbg_is_o = dbg_is_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_is_r <= 2'b00;
    else begin
        if (icpu_cycstb_i[0])
            dbg_is_r[0] <= ~dbg_is_r[0];
        if (dcpu_cycstb_i)
            dbg_is_r[1] <= ~dbg_is_r[1];
    end
end
`endif

`ifdef OR1200_DU_IMPLEMENTED
reg [31:0] dmr1;
reg [31:0] dmr2;
reg [13:0] dsr;
reg [13:0] drr;
reg [31:0] dvr0;
reg [31:0] dvr1;
reg [31:0] dvr2;
reg [31:0] dvr3;
reg [31:0] dvr4;
reg [31:0] dvr5;
reg [31:0] dvr6;
reg [31:0] dvr7;
reg [7:0] dcr0;
reg [7:0] dcr1;
reg [7:0] dcr2;
reg [7:0] dcr3;
reg [7:0] dcr4;
reg [7:0] dcr5;
reg [7:0] dcr6;
reg [7:0] dcr7;
reg [31:0] dwcr0;
reg [31:0] dwcr1;

wire sel_dmr1  = spr_cs & (spr_addr[10:0] == SPR_DMR1);
wire sel_dmr2  = spr_cs & (spr_addr[10:0] == SPR_DMR2);
wire sel_dsr   = spr_cs & (spr_addr[10:0] == SPR_DSR);
wire sel_drr   = spr_cs & (spr_addr[10:0] == SPR_DRR);
wire sel_dvr0  = spr_cs & (spr_addr[10:0] == SPR_DVR0);
wire sel_dvr1  = spr_cs & (spr_addr[10:0] == SPR_DVR1);
wire sel_dvr2  = spr_cs & (spr_addr[10:0] == SPR_DVR2);
wire sel_dvr3  = spr_cs & (spr_addr[10:0] == SPR_DVR3);
wire sel_dvr4  = spr_cs & (spr_addr[10:0] == SPR_DVR4);
wire sel_dvr5  = spr_cs & (spr_addr[10:0] == SPR_DVR5);
wire sel_dvr6  = spr_cs & (spr_addr[10:0] == SPR_DVR6);
wire sel_dvr7  = spr_cs & (spr_addr[10:0] == SPR_DVR7);
wire sel_dcr0  = spr_cs & (spr_addr[10:0] == SPR_DCR0);
wire sel_dcr1  = spr_cs & (spr_addr[10:0] == SPR_DCR1);
wire sel_dcr2  = spr_cs & (spr_addr[10:0] == SPR_DCR2);
wire sel_dcr3  = spr_cs & (spr_addr[10:0] == SPR_DCR3);
wire sel_dcr4  = spr_cs & (spr_addr[10:0] == SPR_DCR4);
wire sel_dcr5  = spr_cs & (spr_addr[10:0] == SPR_DCR5);
wire sel_dcr6  = spr_cs & (spr_addr[10:0] == SPR_DCR6);
wire sel_dcr7  = spr_cs & (spr_addr[10:0] == SPR_DCR7);
wire sel_dwcr0 = spr_cs & (spr_addr[10:0] == SPR_DWCR0);
wire sel_dwcr1 = spr_cs & (spr_addr[10:0] == SPR_DWCR1);

assign du_dsr = dsr;

function [31:0] wp_operand;
    input [2:0] tsel;
    begin
        case (tsel)
            3'd1: wp_operand = id_pc;
            3'd2: wp_operand = dcpu_adr_i;
            3'd3: wp_operand = dcpu_adr_i;
            3'd4: wp_operand = dcpu_dat_dc;
            3'd5: wp_operand = dcpu_dat_lsu;
            3'd6: wp_operand = dcpu_adr_i;
            3'd7: wp_operand = dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc;
            default: wp_operand = 32'h0000_0000;
        endcase
    end
endfunction

function wp_strobe;
    input [2:0] tsel;
    begin
        case (tsel)
            3'd0: wp_strobe = 1'b0;
            3'd1: wp_strobe = 1'b1;
            default: wp_strobe = dcpu_cycstb_i;
        endcase
    end
endfunction

function wp_compare;
    input [31:0] lhs;
    input [31:0] rhs;
    input [2:0] rel;
    input sign_ctl;
    reg [31:0] lcmp;
    reg [31:0] rcmp;
    begin
        lcmp = {lhs[31] ^ sign_ctl, lhs[30:0]};
        rcmp = {rhs[31] ^ sign_ctl, rhs[30:0]};
        case (rel)
            3'd0: wp_compare = (lcmp == rcmp);
            3'd1: wp_compare = (lcmp <  rcmp);
            3'd2: wp_compare = (lcmp <= rcmp);
            3'd3: wp_compare = (lcmp >  rcmp);
            3'd4: wp_compare = (lcmp >= rcmp);
            3'd5: wp_compare = (lcmp != rcmp);
            default: wp_compare = 1'b0;
        endcase
    end
endfunction

wire [31:0] op0 = wp_operand(dcr0[7:5]);
wire [31:0] op1 = wp_operand(dcr1[7:5]);
wire [31:0] op2 = wp_operand(dcr2[7:5]);
wire [31:0] op3 = wp_operand(dcr3[7:5]);
wire [31:0] op4 = wp_operand(dcr4[7:5]);
wire [31:0] op5 = wp_operand(dcr5[7:5]);
wire [31:0] op6 = wp_operand(dcr6[7:5]);
wire [31:0] op7 = wp_operand(dcr7[7:5]);

wire mraw0 = wp_strobe(dcr0[7:5]) & wp_compare(op0, dvr0, dcr0[4:2], dcr0[1]);
wire mraw1 = wp_strobe(dcr1[7:5]) & wp_compare(op1, dvr1, dcr1[4:2], dcr1[1]);
wire mraw2 = wp_strobe(dcr2[7:5]) & wp_compare(op2, dvr2, dcr2[4:2], dcr2[1]);
wire mraw3 = wp_strobe(dcr3[7:5]) & wp_compare(op3, dvr3, dcr3[4:2], dcr3[1]);
wire mraw4 = wp_strobe(dcr4[7:5]) & wp_compare(op4, dvr4, dcr4[4:2], dcr4[1]);
wire mraw5 = wp_strobe(dcr5[7:5]) & wp_compare(op5, dvr5, dcr5[4:2], dcr5[1]);
wire mraw6 = wp_strobe(dcr6[7:5]) & wp_compare(op6, dvr6, dcr6[4:2], dcr6[1]);
wire mraw7 = wp_strobe(dcr7[7:5]) & wp_compare(op7, dvr7, dcr7[4:2], dcr7[1]);

wire [1:0] wc0 = dmr1[1:0];
wire [1:0] wc1 = dmr1[3:2];
wire [1:0] wc2 = dmr1[5:4];
wire [1:0] wc3 = dmr1[7:6];
wire [1:0] wc4 = dmr1[9:8];
wire [1:0] wc5 = dmr1[11:10];
wire [1:0] wc6 = dmr1[13:12];
wire [1:0] wc7 = dmr1[15:14];

wire wp0 = (wc0 == 2'b00) ? 1'b0 : mraw0;
wire wp1 = (wc1 == 2'b00) ? 1'b0 : (wc1 == 2'b01) ? mraw1 : (wc1 == 2'b10) ? (mraw1 & wp0) : (mraw1 | wp0);
wire wp2 = (wc2 == 2'b00) ? 1'b0 : (wc2 == 2'b01) ? mraw2 : (wc2 == 2'b10) ? (mraw2 & wp1) : (mraw2 | wp1);
wire wp3 = (wc3 == 2'b00) ? 1'b0 : (wc3 == 2'b01) ? mraw3 : (wc3 == 2'b10) ? (mraw3 & wp2) : (mraw3 | wp2);
wire wp4 = (wc4 == 2'b00) ? 1'b0 : (wc4 == 2'b01) ? mraw4 : (wc4 == 2'b10) ? (mraw4 & wp3) : (mraw4 | wp3);
wire wp5 = (wc5 == 2'b00) ? 1'b0 : (wc5 == 2'b01) ? mraw5 : (wc5 == 2'b10) ? (mraw5 & wp4) : (mraw5 | wp4);
wire wp6 = (wc6 == 2'b00) ? 1'b0 : (wc6 == 2'b01) ? mraw6 : (wc6 == 2'b10) ? (mraw6 & wp5) : (mraw6 | wp5);
wire wp7 = (wc7 == 2'b00) ? 1'b0 : (wc7 == 2'b01) ? mraw7 : (wc7 == 2'b10) ? (mraw7 & wp6) : (mraw7 | wp6);

wire cnt_ev0 = |{wp0, wp1, wp2, wp3, wp4, wp5, wp6, wp7};
wire cnt_ev1 = |{wp0, wp1, wp2, wp3, wp4, wp5, wp6, wp7};
wire cnt0_en = dmr2[16];
wire cnt1_en = dmr2[17];

wire wp8 = (dwcr0[31:16] == dwcr0[15:0]);
wire wp9 = (dwcr1[31:16] == dwcr1[15:0]);
wire wp10 = dbg_ewt_i;
wire [10:0] wp = {wp10, wp9, wp8, wp7, wp6, wp5, wp4, wp3, wp2, wp1, wp0};

`ifdef OR1200_DU_HWBKPTS
assign du_hwbkpt = |(wp & dmr2[10:0]);
`else
assign du_hwbkpt = 1'b0;
`endif

wire except_bp = |except_stop;
wire is_non_nop = (ex_insn != EXCL_NOP);
`ifdef OR1200_DU_SSTEP
wire sstep_bp = dmr1[20] & is_non_nop;
`else
wire sstep_bp = 1'b0;
`endif
`ifdef OR1200_DU_BTRACE
wire btrace_bp = dmr1[21] & is_non_nop & (branch_op != 3'b000);
`else
wire btrace_bp = 1'b0;
`endif

reg dbg_bp_r;
assign dbg_bp_o = dbg_bp_r;

`ifdef OR1200_DU_TB_IMPLEMENTED
reg [31:0] tb_npc [0:255];
reg [31:0] tb_insn [0:255];
reg [31:0] tb_wb [0:255];
reg [31:0] tb_ts [0:255];
reg [7:0] tb_wadr;
reg [7:0] tb_radr;
reg [31:0] tb_timstmp;
wire tb_we = (~ex_freeze) & is_non_nop;
`endif

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr1 <= 32'h0000_0000;
        dmr2 <= 32'h0000_0000;
        dsr <= 14'h0000;
        drr <= 14'h0000;
        dvr0 <= 32'h0000_0000;
        dvr1 <= 32'h0000_0000;
        dvr2 <= 32'h0000_0000;
        dvr3 <= 32'h0000_0000;
        dvr4 <= 32'h0000_0000;
        dvr5 <= 32'h0000_0000;
        dvr6 <= 32'h0000_0000;
        dvr7 <= 32'h0000_0000;
        dcr0 <= 8'h00;
        dcr1 <= 8'h00;
        dcr2 <= 8'h00;
        dcr3 <= 8'h00;
        dcr4 <= 8'h00;
        dcr5 <= 8'h00;
        dcr6 <= 8'h00;
        dcr7 <= 8'h00;
        dwcr0 <= 32'h0000_0000;
        dwcr1 <= 32'h0000_0000;
        dbg_bp_r <= 1'b0;
`ifdef OR1200_DU_TB_IMPLEMENTED
        tb_wadr <= 8'h00;
        tb_radr <= 8'h00;
        tb_timstmp <= 32'h0000_0000;
`endif
    end else begin
        if (spr_write & sel_dmr1) dmr1 <= spr_dat_i;
        if (spr_write & sel_dmr2) dmr2 <= spr_dat_i;
        if (spr_write & sel_dsr)  dsr  <= spr_dat_i[13:0];
        if (spr_write & sel_drr)  drr  <= spr_dat_i[13:0];
        else drr <= drr | except_stop;
        if (spr_write & sel_dvr0) dvr0 <= spr_dat_i;
        if (spr_write & sel_dvr1) dvr1 <= spr_dat_i;
        if (spr_write & sel_dvr2) dvr2 <= spr_dat_i;
        if (spr_write & sel_dvr3) dvr3 <= spr_dat_i;
        if (spr_write & sel_dvr4) dvr4 <= spr_dat_i;
        if (spr_write & sel_dvr5) dvr5 <= spr_dat_i;
        if (spr_write & sel_dvr6) dvr6 <= spr_dat_i;
        if (spr_write & sel_dvr7) dvr7 <= spr_dat_i;
        if (spr_write & sel_dcr0) dcr0 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr1) dcr1 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr2) dcr2 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr3) dcr3 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr4) dcr4 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr5) dcr5 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr6) dcr6 <= spr_dat_i[7:0];
        if (spr_write & sel_dcr7) dcr7 <= spr_dat_i[7:0];

        if (spr_write & sel_dwcr0)
            dwcr0 <= spr_dat_i;
        else if (cnt0_en & cnt_ev0)
            dwcr0[15:0] <= dwcr0[15:0] + 16'h0001;

        if (spr_write & sel_dwcr1)
            dwcr1 <= spr_dat_i;
        else if (cnt1_en & cnt_ev1)
            dwcr1[15:0] <= dwcr1[15:0] + 16'h0001;

        if (!ex_freeze)
            dbg_bp_r <= except_bp | sstep_bp | btrace_bp;
        else
            dbg_bp_r <= except_bp;

`ifdef OR1200_DU_TB_IMPLEMENTED
        if (spr_write & spr_cs & (spr_addr[10:0] == SPR_TBADR))
            tb_radr <= spr_dat_i[7:0];
        if (tb_we) begin
            tb_npc[tb_wadr] <= spr_dat_npc;
            tb_insn[tb_wadr] <= ex_insn;
            tb_wb[tb_wadr] <= rf_dataw;
            tb_ts[tb_wadr] <= tb_timstmp;
            tb_wadr <= tb_wadr + 8'h01;
            tb_timstmp <= tb_timstmp + 32'h0000_0001;
        end
`endif
    end
end

`ifdef OR1200_DU_READREGS
reg [31:0] spr_dat_r;
assign spr_dat_o = spr_dat_r;
always @(*) begin
    case (spr_addr[10:0])
        SPR_DMR1: spr_dat_r = dmr1;
        SPR_DMR2: spr_dat_r = dmr2;
        SPR_DSR:  spr_dat_r = {18'h0, dsr};
        SPR_DRR:  spr_dat_r = {18'h0, drr};
        SPR_DVR0: spr_dat_r = dvr0;
        SPR_DVR1: spr_dat_r = dvr1;
        SPR_DVR2: spr_dat_r = dvr2;
        SPR_DVR3: spr_dat_r = dvr3;
        SPR_DVR4: spr_dat_r = dvr4;
        SPR_DVR5: spr_dat_r = dvr5;
        SPR_DVR6: spr_dat_r = dvr6;
        SPR_DVR7: spr_dat_r = dvr7;
        SPR_DCR0: spr_dat_r = {24'h0, dcr0};
        SPR_DCR1: spr_dat_r = {24'h0, dcr1};
        SPR_DCR2: spr_dat_r = {24'h0, dcr2};
        SPR_DCR3: spr_dat_r = {24'h0, dcr3};
        SPR_DCR4: spr_dat_r = {24'h0, dcr4};
        SPR_DCR5: spr_dat_r = {24'h0, dcr5};
        SPR_DCR6: spr_dat_r = {24'h0, dcr6};
        SPR_DCR7: spr_dat_r = {24'h0, dcr7};
        SPR_DWCR0: spr_dat_r = dwcr0;
        SPR_DWCR1: spr_dat_r = dwcr1;
`ifdef OR1200_DU_TB_IMPLEMENTED
        SPR_TBADR:      spr_dat_r = {24'h0, tb_radr};
        SPR_TBDATA_NPC: spr_dat_r = tb_npc[tb_radr];
        SPR_TBDATA_INS: spr_dat_r = tb_insn[tb_radr];
        SPR_TBDATA_WB:  spr_dat_r = tb_wb[tb_radr];
        SPR_TBDATA_TS:  spr_dat_r = tb_ts[tb_radr];
`endif
        default: spr_dat_r = 32'h0000_0000;
    endcase
end
`else
assign spr_dat_o = 32'h0000_0000;
`endif

`else
assign du_dsr = 14'h0000;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o = 1'b0;
`ifdef OR1200_DU_READREGS
assign spr_dat_o = 32'h0000_0000;
`else
assign spr_dat_o = 32'h0000_0000;
`endif
`endif

endmodule
