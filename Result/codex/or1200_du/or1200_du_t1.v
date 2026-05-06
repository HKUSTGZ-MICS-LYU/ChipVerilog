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

assign du_stall = dbg_stall_i;
assign du_addr = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i & dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_wp_o = 11'b000_0000_0000;

reg dbg_ack_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_r <= 1'b0;
    else
        dbg_ack_r <= dbg_stb_i;
end
assign dbg_ack_o = dbg_ack_r;

`ifndef OR1200_DU_STATUS_UNIMPLEMENTED
assign dbg_lss_o = {2'b00, dcpu_cycstb_i, dcpu_cycstb_i & dcpu_we_i};
assign dbg_is_o = {1'b0, icpu_cycstb_i[0]};
`else
reg dbg_is_toggle;
always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_is_toggle <= 1'b0;
    else if (icpu_cycstb_i[0])
        dbg_is_toggle <= ~dbg_is_toggle;
end
assign dbg_lss_o = 4'b0000;
assign dbg_is_o = {dbg_is_toggle, icpu_cycstb_i[0]};
`endif

`ifdef OR1200_DU_IMPLEMENTED
localparam [10:0] ADDR_DMR1    = 11'h000;
localparam [10:0] ADDR_DMR2    = 11'h001;
localparam [10:0] ADDR_DSR     = 11'h002;
localparam [10:0] ADDR_DRR     = 11'h003;
localparam [10:0] ADDR_DVR0    = 11'h010;
localparam [10:0] ADDR_DVR1    = 11'h011;
localparam [10:0] ADDR_DVR2    = 11'h012;
localparam [10:0] ADDR_DVR3    = 11'h013;
localparam [10:0] ADDR_DVR4    = 11'h014;
localparam [10:0] ADDR_DVR5    = 11'h015;
localparam [10:0] ADDR_DVR6    = 11'h016;
localparam [10:0] ADDR_DVR7    = 11'h017;
localparam [10:0] ADDR_DCR0    = 11'h020;
localparam [10:0] ADDR_DCR1    = 11'h021;
localparam [10:0] ADDR_DCR2    = 11'h022;
localparam [10:0] ADDR_DCR3    = 11'h023;
localparam [10:0] ADDR_DCR4    = 11'h024;
localparam [10:0] ADDR_DCR5    = 11'h025;
localparam [10:0] ADDR_DCR6    = 11'h026;
localparam [10:0] ADDR_DCR7    = 11'h027;
localparam [10:0] ADDR_DWCR0   = 11'h030;
localparam [10:0] ADDR_DWCR1   = 11'h031;
localparam [10:0] ADDR_TB_ADDR = 11'h040;
localparam [10:0] ADDR_TB_NPC  = 11'h041;
localparam [10:0] ADDR_TB_INSN = 11'h042;
localparam [10:0] ADDR_TB_DATA = 11'h043;
localparam [10:0] ADDR_TB_TIME = 11'h044;

wire [10:0] spr_index = spr_addr[10:0];
wire dmr1_sel = spr_cs & (spr_index == ADDR_DMR1);
wire dmr2_sel = spr_cs & (spr_index == ADDR_DMR2);
wire dsr_sel  = spr_cs & (spr_index == ADDR_DSR);
wire drr_sel  = spr_cs & (spr_index == ADDR_DRR);

reg [31:0] dmr1;
reg [31:0] dmr2;
reg [13:0] dsr;
reg [13:0] drr;
reg dbg_bp_r;

wire [13:0] except_stop = {1'b0, du_except};
wire execute_valid = |ex_insn;
wire branch_valid = |branch_op;

assign du_dsr = dsr;
assign dbg_bp_o = dbg_bp_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr1 <= 32'd0;
        dmr2 <= 32'd0;
        dsr <= 14'd0;
        drr <= 14'd0;
    end
    else begin
        if (dmr1_sel & spr_write)
            dmr1 <= spr_dat_i;
        if (dmr2_sel & spr_write)
            dmr2 <= spr_dat_i;
        if (dsr_sel & spr_write)
            dsr <= spr_dat_i[13:0];
        if (drr_sel & spr_write)
            drr <= spr_dat_i[13:0];
        else
            drr <= drr | except_stop;
    end
end

`ifdef OR1200_DU_HWBKPTS
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

wire dvr0_sel = spr_cs & (spr_index == ADDR_DVR0);
wire dvr1_sel = spr_cs & (spr_index == ADDR_DVR1);
wire dvr2_sel = spr_cs & (spr_index == ADDR_DVR2);
wire dvr3_sel = spr_cs & (spr_index == ADDR_DVR3);
wire dvr4_sel = spr_cs & (spr_index == ADDR_DVR4);
wire dvr5_sel = spr_cs & (spr_index == ADDR_DVR5);
wire dvr6_sel = spr_cs & (spr_index == ADDR_DVR6);
wire dvr7_sel = spr_cs & (spr_index == ADDR_DVR7);
wire dcr0_sel = spr_cs & (spr_index == ADDR_DCR0);
wire dcr1_sel = spr_cs & (spr_index == ADDR_DCR1);
wire dcr2_sel = spr_cs & (spr_index == ADDR_DCR2);
wire dcr3_sel = spr_cs & (spr_index == ADDR_DCR3);
wire dcr4_sel = spr_cs & (spr_index == ADDR_DCR4);
wire dcr5_sel = spr_cs & (spr_index == ADDR_DCR5);
wire dcr6_sel = spr_cs & (spr_index == ADDR_DCR6);
wire dcr7_sel = spr_cs & (spr_index == ADDR_DCR7);
wire dwcr0_sel = spr_cs & (spr_index == ADDR_DWCR0);
wire dwcr1_sel = spr_cs & (spr_index == ADDR_DWCR1);

function [31:0] du_cmp_src;
    input [2:0] src_sel;
    input dc_we;
    input [31:0] pc;
    input [31:0] adr;
    input [31:0] lsu_dat;
    input [31:0] dc_dat;
    begin
        case (src_sel)
            3'b001: du_cmp_src = pc;
            3'b010: du_cmp_src = adr;
            3'b011: du_cmp_src = adr;
            3'b100: du_cmp_src = dc_dat;
            3'b101: du_cmp_src = lsu_dat;
            3'b110: du_cmp_src = adr;
            3'b111: du_cmp_src = dc_we ? lsu_dat : dc_dat;
            default: du_cmp_src = 32'd0;
        endcase
    end
endfunction

function du_cmp_stb;
    input [2:0] src_sel;
    input dc_cycstb;
    begin
        case (src_sel)
            3'b000: du_cmp_stb = 1'b0;
            3'b001: du_cmp_stb = 1'b1;
            default: du_cmp_stb = dc_cycstb;
        endcase
    end
endfunction

function du_cmp_hit;
    input [31:0] lhs;
    input [31:0] rhs;
    input [2:0] rel;
    input sign_ctl;
    reg [31:0] lhs_adj;
    reg [31:0] rhs_adj;
    begin
        lhs_adj = {lhs[31] ^ sign_ctl, lhs[30:0]};
        rhs_adj = {rhs[31] ^ sign_ctl, rhs[30:0]};
        case (rel)
            3'b000: du_cmp_hit = (lhs_adj == rhs_adj);
            3'b001: du_cmp_hit = (lhs_adj < rhs_adj);
            3'b010: du_cmp_hit = (lhs_adj <= rhs_adj);
            3'b011: du_cmp_hit = (lhs_adj > rhs_adj);
            3'b100: du_cmp_hit = (lhs_adj >= rhs_adj);
            3'b101: du_cmp_hit = (lhs_adj != rhs_adj);
            default: du_cmp_hit = 1'b0;
        endcase
    end
endfunction

function du_chain_wp;
    input [1:0] mode;
    input direct_hit;
    input prev_wp;
    input first_wp;
    begin
        if (first_wp) begin
            if (mode == 2'b11)
                du_chain_wp = 1'b0;
            else
                du_chain_wp = direct_hit;
        end
        else begin
            case (mode)
                2'b00: du_chain_wp = direct_hit;
                2'b01: du_chain_wp = direct_hit & prev_wp;
                2'b10: du_chain_wp = direct_hit | prev_wp;
                default: du_chain_wp = 1'b0;
            endcase
        end
    end
endfunction

wire [31:0] cmp_val0 = du_cmp_src(dcr0[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val1 = du_cmp_src(dcr1[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val2 = du_cmp_src(dcr2[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val3 = du_cmp_src(dcr3[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val4 = du_cmp_src(dcr4[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val5 = du_cmp_src(dcr5[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val6 = du_cmp_src(dcr6[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
wire [31:0] cmp_val7 = du_cmp_src(dcr7[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);

wire cmp_stb0 = du_cmp_stb(dcr0[7:5], dcpu_cycstb_i);
wire cmp_stb1 = du_cmp_stb(dcr1[7:5], dcpu_cycstb_i);
wire cmp_stb2 = du_cmp_stb(dcr2[7:5], dcpu_cycstb_i);
wire cmp_stb3 = du_cmp_stb(dcr3[7:5], dcpu_cycstb_i);
wire cmp_stb4 = du_cmp_stb(dcr4[7:5], dcpu_cycstb_i);
wire cmp_stb5 = du_cmp_stb(dcr5[7:5], dcpu_cycstb_i);
wire cmp_stb6 = du_cmp_stb(dcr6[7:5], dcpu_cycstb_i);
wire cmp_stb7 = du_cmp_stb(dcr7[7:5], dcpu_cycstb_i);

wire match0 = cmp_stb0 & du_cmp_hit(cmp_val0, dvr0, dcr0[3:1], dcr0[4]);
wire match1 = cmp_stb1 & du_cmp_hit(cmp_val1, dvr1, dcr1[3:1], dcr1[4]);
wire match2 = cmp_stb2 & du_cmp_hit(cmp_val2, dvr2, dcr2[3:1], dcr2[4]);
wire match3 = cmp_stb3 & du_cmp_hit(cmp_val3, dvr3, dcr3[3:1], dcr3[4]);
wire match4 = cmp_stb4 & du_cmp_hit(cmp_val4, dvr4, dcr4[3:1], dcr4[4]);
wire match5 = cmp_stb5 & du_cmp_hit(cmp_val5, dvr5, dcr5[3:1], dcr5[4]);
wire match6 = cmp_stb6 & du_cmp_hit(cmp_val6, dvr6, dcr6[3:1], dcr6[4]);
wire match7 = cmp_stb7 & du_cmp_hit(cmp_val7, dvr7, dcr7[3:1], dcr7[4]);

wire wp0_i = du_chain_wp(dmr1[3:2], match0, 1'b0, 1'b1);
wire wp1_i = du_chain_wp(dmr1[5:4], match1, wp0_i, 1'b0);
wire wp2_i = du_chain_wp(dmr1[7:6], match2, wp1_i, 1'b0);
wire wp3_i = du_chain_wp(dmr1[9:8], match3, wp2_i, 1'b0);
wire wp4_i = du_chain_wp(dmr1[11:10], match4, wp3_i, 1'b0);
wire wp5_i = du_chain_wp(dmr1[13:12], match5, wp4_i, 1'b0);
wire wp6_i = du_chain_wp(dmr1[15:14], match6, wp5_i, 1'b0);
wire wp7_i = du_chain_wp(dmr1[17:16], match7, wp6_i, 1'b0);

wire dwcr0_event = dmr2[8] & wp0_i;
wire dwcr1_event = dmr2[9] & wp1_i;
wire dwcr0_match = (dwcr0[31:16] == dwcr0[15:0]);
wire dwcr1_match = (dwcr1[31:16] == dwcr1[15:0]);
wire [10:0] wp = {dbg_ewt_i, dwcr1_match, dwcr0_match, wp7_i, wp6_i, wp5_i, wp4_i, wp3_i, wp2_i, wp1_i, wp0_i};

assign du_hwbkpt = |(wp & dmr2[10:0]);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dvr0 <= 32'd0;
        dvr1 <= 32'd0;
        dvr2 <= 32'd0;
        dvr3 <= 32'd0;
        dvr4 <= 32'd0;
        dvr5 <= 32'd0;
        dvr6 <= 32'd0;
        dvr7 <= 32'd0;
        dcr0 <= 8'd0;
        dcr1 <= 8'd0;
        dcr2 <= 8'd0;
        dcr3 <= 8'd0;
        dcr4 <= 8'd0;
        dcr5 <= 8'd0;
        dcr6 <= 8'd0;
        dcr7 <= 8'd0;
        dwcr0 <= 32'd0;
        dwcr1 <= 32'd0;
    end
    else begin
        if (dvr0_sel & spr_write) dvr0 <= spr_dat_i;
        if (dvr1_sel & spr_write) dvr1 <= spr_dat_i;
        if (dvr2_sel & spr_write) dvr2 <= spr_dat_i;
        if (dvr3_sel & spr_write) dvr3 <= spr_dat_i;
        if (dvr4_sel & spr_write) dvr4 <= spr_dat_i;
        if (dvr5_sel & spr_write) dvr5 <= spr_dat_i;
        if (dvr6_sel & spr_write) dvr6 <= spr_dat_i;
        if (dvr7_sel & spr_write) dvr7 <= spr_dat_i;
        if (dcr0_sel & spr_write) dcr0 <= spr_dat_i[7:0];
        if (dcr1_sel & spr_write) dcr1 <= spr_dat_i[7:0];
        if (dcr2_sel & spr_write) dcr2 <= spr_dat_i[7:0];
        if (dcr3_sel & spr_write) dcr3 <= spr_dat_i[7:0];
        if (dcr4_sel & spr_write) dcr4 <= spr_dat_i[7:0];
        if (dcr5_sel & spr_write) dcr5 <= spr_dat_i[7:0];
        if (dcr6_sel & spr_write) dcr6 <= spr_dat_i[7:0];
        if (dcr7_sel & spr_write) dcr7 <= spr_dat_i[7:0];
        if (dwcr0_sel & spr_write)
            dwcr0 <= spr_dat_i;
        else if (dwcr0_event)
            dwcr0 <= {dwcr0[31:16], dwcr0[15:0] + 16'd1};
        if (dwcr1_sel & spr_write)
            dwcr1 <= spr_dat_i;
        else if (dwcr1_event)
            dwcr1 <= {dwcr1[31:16], dwcr1[15:0] + 16'd1};
    end
end
`else
assign du_hwbkpt = 1'b0;
`endif

`ifdef OR1200_DU_TB_IMPLEMENTED
reg [7:0] tb_waddr;
reg [7:0] tb_raddr;
reg [31:0] tb_tstamp;
reg [31:0] tb_npc_mem [0:255];
reg [31:0] tb_insn_mem [0:255];
reg [31:0] tb_data_mem [0:255];
reg [31:0] tb_time_mem [0:255];
wire tb_addr_sel = spr_cs & (spr_index == ADDR_TB_ADDR);
wire [31:0] tb_npc_rdata = tb_npc_mem[tb_raddr];
wire [31:0] tb_insn_rdata = tb_insn_mem[tb_raddr];
wire [31:0] tb_data_rdata = tb_data_mem[tb_raddr];
wire [31:0] tb_time_rdata = tb_time_mem[tb_raddr];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        tb_waddr <= 8'd0;
        tb_raddr <= 8'd0;
        tb_tstamp <= 32'd0;
    end
    else begin
        if (tb_addr_sel & spr_write)
            tb_raddr <= spr_dat_i[7:0];
        if (!ex_freeze && execute_valid) begin
            tb_npc_mem[tb_waddr] <= spr_dat_npc;
            tb_insn_mem[tb_waddr] <= ex_insn;
            tb_data_mem[tb_waddr] <= rf_dataw;
            tb_time_mem[tb_waddr] <= tb_tstamp;
            tb_waddr <= tb_waddr + 8'd1;
            tb_tstamp <= tb_tstamp + 32'd1;
        end
    end
end
`endif

wire single_step_hit;
wire branch_trace_hit;
`ifdef OR1200_DU_SINGLE_STEP
assign single_step_hit = dmr1[0] & execute_valid;
`else
assign single_step_hit = 1'b0;
`endif
`ifdef OR1200_DU_BRANCH_TRACE
assign branch_trace_hit = dmr1[1] & execute_valid & branch_valid;
`else
assign branch_trace_hit = 1'b0;
`endif
wire dbg_bp_next = (|except_stop) | ((!ex_freeze) & (single_step_hit | branch_trace_hit));

always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_bp_r <= 1'b0;
    else
        dbg_bp_r <= dbg_bp_next;
end

`ifdef OR1200_DU_READREGS
reg [31:0] spr_dat_r;
always @* begin
    spr_dat_r = 32'd0;
    case (spr_index)
        ADDR_DMR1: spr_dat_r = dmr1;
        ADDR_DMR2: spr_dat_r = dmr2;
        ADDR_DSR:  spr_dat_r = {18'd0, dsr};
        ADDR_DRR:  spr_dat_r = {18'd0, drr};
`ifdef OR1200_DU_HWBKPTS
        ADDR_DVR0: spr_dat_r = dvr0;
        ADDR_DVR1: spr_dat_r = dvr1;
        ADDR_DVR2: spr_dat_r = dvr2;
        ADDR_DVR3: spr_dat_r = dvr3;
        ADDR_DVR4: spr_dat_r = dvr4;
        ADDR_DVR5: spr_dat_r = dvr5;
        ADDR_DVR6: spr_dat_r = dvr6;
        ADDR_DVR7: spr_dat_r = dvr7;
        ADDR_DCR0: spr_dat_r = {24'd0, dcr0};
        ADDR_DCR1: spr_dat_r = {24'd0, dcr1};
        ADDR_DCR2: spr_dat_r = {24'd0, dcr2};
        ADDR_DCR3: spr_dat_r = {24'd0, dcr3};
        ADDR_DCR4: spr_dat_r = {24'd0, dcr4};
        ADDR_DCR5: spr_dat_r = {24'd0, dcr5};
        ADDR_DCR6: spr_dat_r = {24'd0, dcr6};
        ADDR_DCR7: spr_dat_r = {24'd0, dcr7};
        ADDR_DWCR0: spr_dat_r = dwcr0;
        ADDR_DWCR1: spr_dat_r = dwcr1;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
        ADDR_TB_ADDR: spr_dat_r = {24'd0, tb_raddr};
        ADDR_TB_NPC:  spr_dat_r = tb_npc_rdata;
        ADDR_TB_INSN: spr_dat_r = tb_insn_rdata;
        ADDR_TB_DATA: spr_dat_r = tb_data_rdata;
        ADDR_TB_TIME: spr_dat_r = tb_time_rdata;
`endif
        default: spr_dat_r = 32'd0;
    endcase
end
assign spr_dat_o = spr_dat_r;
`else
assign spr_dat_o = 32'd0;
`endif

`else
assign du_dsr = 14'd0;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o = 1'b0;
assign spr_dat_o = 32'd0;
`endif

endmodule
