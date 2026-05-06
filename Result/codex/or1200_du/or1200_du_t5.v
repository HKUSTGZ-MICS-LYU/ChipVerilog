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

localparam [10:0] SPR_DMR1    = 11'h300;
localparam [10:0] SPR_DMR2    = 11'h301;
localparam [10:0] SPR_DSR     = 11'h302;
localparam [10:0] SPR_DRR     = 11'h303;
localparam [10:0] SPR_DVR0    = 11'h310;
localparam [10:0] SPR_DVR1    = 11'h311;
localparam [10:0] SPR_DVR2    = 11'h312;
localparam [10:0] SPR_DVR3    = 11'h313;
localparam [10:0] SPR_DVR4    = 11'h314;
localparam [10:0] SPR_DVR5    = 11'h315;
localparam [10:0] SPR_DVR6    = 11'h316;
localparam [10:0] SPR_DVR7    = 11'h317;
localparam [10:0] SPR_DCR0    = 11'h318;
localparam [10:0] SPR_DCR1    = 11'h319;
localparam [10:0] SPR_DCR2    = 11'h31a;
localparam [10:0] SPR_DCR3    = 11'h31b;
localparam [10:0] SPR_DCR4    = 11'h31c;
localparam [10:0] SPR_DCR5    = 11'h31d;
localparam [10:0] SPR_DCR6    = 11'h31e;
localparam [10:0] SPR_DCR7    = 11'h31f;
localparam [10:0] SPR_DWCR0   = 11'h320;
localparam [10:0] SPR_DWCR1   = 11'h321;
localparam [10:0] SPR_TB_ADDR = 11'h330;
localparam [10:0] SPR_TB_NPC  = 11'h331;
localparam [10:0] SPR_TB_INSN = 11'h332;
localparam [10:0] SPR_TB_DATA = 11'h333;
localparam [10:0] SPR_TB_TIME = 11'h334;

wire [10:0] spr_addr11;
reg dbg_ack_r;

assign spr_addr11 = spr_addr[10:0];
assign du_stall = dbg_stall_i;
assign du_addr = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i & dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_ack_o = dbg_ack_r;
assign dbg_wp_o = 11'b000_0000_0000;

always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_ack_r <= 1'b0;
    else
        dbg_ack_r <= dbg_stb_i;
end

`ifdef OR1200_DU_STATUS_UNIMPLEMENTED
reg dbg_is_toggle_r;

always @(posedge clk or posedge rst) begin
    if (rst)
        dbg_is_toggle_r <= 1'b0;
    else if (icpu_cycstb_i)
        dbg_is_toggle_r <= ~dbg_is_toggle_r;
end

assign dbg_lss_o = 4'b0000;
assign dbg_is_o = {dbg_is_toggle_r, icpu_cycstb_i};
`else
assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, dcpu_cycstb_i & ~dcpu_we_i, 1'b0};
assign dbg_is_o = {icpu_cycstb_i, 1'b0};
`endif

`ifdef OR1200_DU_IMPLEMENTED
reg [31:0] dmr1;
reg [31:0] dmr2;
reg [13:0] dsr;
reg [13:0] drr;
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
wire [31:0] cmp_val0;
wire [31:0] cmp_val1;
wire [31:0] cmp_val2;
wire [31:0] cmp_val3;
wire [31:0] cmp_val4;
wire [31:0] cmp_val5;
wire [31:0] cmp_val6;
wire [31:0] cmp_val7;
wire cmp_stb0;
wire cmp_stb1;
wire cmp_stb2;
wire cmp_stb3;
wire cmp_stb4;
wire cmp_stb5;
wire cmp_stb6;
wire cmp_stb7;
wire match0;
wire match1;
wire match2;
wire match3;
wire match4;
wire match5;
wire match6;
wire match7;
wire [7:0] wp_chain;
wire counter0_match;
wire counter1_match;
wire [10:0] wp_internal;
wire wp_counter_event;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
reg [7:0] tb_addr_reg;
reg [7:0] tb_waddr;
reg [31:0] tb_timstmp;
reg [31:0] tb_npc_mem [0:255];
reg [31:0] tb_insn_mem [0:255];
reg [31:0] tb_data_mem [0:255];
reg [31:0] tb_time_mem [0:255];
wire tb_record_en;
`endif
reg dbg_bp_r;
wire [13:0] except_stop;
wire except_bp;
wire ex_is_nop;
wire step_bp;
wire branch_bp;

function [31:0] adjust_msb;
    input [31:0] value;
    input signed_mode;
    begin
        adjust_msb = {value[31] ^ signed_mode, value[30:0]};
    end
endfunction

function cmp_match_fn;
    input [31:0] lhs;
    input [31:0] rhs;
    input [2:0] op;
    input signed_mode;
    reg [31:0] lhs_adj;
    reg [31:0] rhs_adj;
    begin
        lhs_adj = adjust_msb(lhs, signed_mode);
        rhs_adj = adjust_msb(rhs, signed_mode);
        case (op)
            3'b001: cmp_match_fn = (lhs_adj == rhs_adj);
            3'b010: cmp_match_fn = (lhs_adj < rhs_adj);
            3'b011: cmp_match_fn = (lhs_adj <= rhs_adj);
            3'b100: cmp_match_fn = (lhs_adj > rhs_adj);
            3'b101: cmp_match_fn = (lhs_adj >= rhs_adj);
            3'b110: cmp_match_fn = (lhs_adj != rhs_adj);
            default: cmp_match_fn = 1'b0;
        endcase
    end
endfunction

`ifdef OR1200_DU_HWBKPTS
function [31:0] cmp_value_fn;
    input [2:0] sel;
    input we;
    input [31:0] id_pc_i;
    input [31:0] dcpu_adr_i_i;
    input [31:0] dcpu_dat_lsu_i;
    input [31:0] dcpu_dat_dc_i;
    begin
        case (sel)
            3'b001: cmp_value_fn = id_pc_i;
            3'b010: cmp_value_fn = dcpu_adr_i_i;
            3'b011: cmp_value_fn = dcpu_adr_i_i;
            3'b100: cmp_value_fn = dcpu_dat_dc_i;
            3'b101: cmp_value_fn = dcpu_dat_lsu_i;
            3'b110: cmp_value_fn = dcpu_adr_i_i;
            3'b111: cmp_value_fn = we ? dcpu_dat_lsu_i : dcpu_dat_dc_i;
            default: cmp_value_fn = 32'b0;
        endcase
    end
endfunction

function cmp_strobe_fn;
    input [2:0] sel;
    input cycstb;
    input we;
    begin
        case (sel)
            3'b000: cmp_strobe_fn = 1'b0;
            3'b001: cmp_strobe_fn = 1'b1;
            3'b010: cmp_strobe_fn = cycstb & ~we;
            3'b011: cmp_strobe_fn = cycstb & we;
            3'b100: cmp_strobe_fn = cycstb & ~we;
            3'b101: cmp_strobe_fn = cycstb & we;
            3'b110: cmp_strobe_fn = cycstb;
            3'b111: cmp_strobe_fn = cycstb;
            default: cmp_strobe_fn = 1'b0;
        endcase
    end
endfunction
`endif

assign except_stop = {1'b0, du_except};
assign except_bp = |except_stop;
assign ex_is_nop = (ex_insn == 32'b0);
assign step_bp = dmr1[0] & ~ex_is_nop;
assign branch_bp = dmr1[1] & ~ex_is_nop & (branch_op != 3'b000);
assign du_dsr = dsr;
assign dbg_bp_o = dbg_bp_r;

`ifdef OR1200_DU_HWBKPTS
assign cmp_val0 = cmp_value_fn(dcr0[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val1 = cmp_value_fn(dcr1[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val2 = cmp_value_fn(dcr2[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val3 = cmp_value_fn(dcr3[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val4 = cmp_value_fn(dcr4[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val5 = cmp_value_fn(dcr5[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val6 = cmp_value_fn(dcr6[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_val7 = cmp_value_fn(dcr7[7:5], dcpu_we_i, id_pc, dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc);
assign cmp_stb0 = cmp_strobe_fn(dcr0[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb1 = cmp_strobe_fn(dcr1[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb2 = cmp_strobe_fn(dcr2[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb3 = cmp_strobe_fn(dcr3[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb4 = cmp_strobe_fn(dcr4[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb5 = cmp_strobe_fn(dcr5[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb6 = cmp_strobe_fn(dcr6[7:5], dcpu_cycstb_i, dcpu_we_i);
assign cmp_stb7 = cmp_strobe_fn(dcr7[7:5], dcpu_cycstb_i, dcpu_we_i);
assign match0 = cmp_stb0 & cmp_match_fn(cmp_val0, dvr0, dcr0[3:1], dcr0[4]);
assign match1 = cmp_stb1 & cmp_match_fn(cmp_val1, dvr1, dcr1[3:1], dcr1[4]);
assign match2 = cmp_stb2 & cmp_match_fn(cmp_val2, dvr2, dcr2[3:1], dcr2[4]);
assign match3 = cmp_stb3 & cmp_match_fn(cmp_val3, dvr3, dcr3[3:1], dcr3[4]);
assign match4 = cmp_stb4 & cmp_match_fn(cmp_val4, dvr4, dcr4[3:1], dcr4[4]);
assign match5 = cmp_stb5 & cmp_match_fn(cmp_val5, dvr5, dcr5[3:1], dcr5[4]);
assign match6 = cmp_stb6 & cmp_match_fn(cmp_val6, dvr6, dcr6[3:1], dcr6[4]);
assign match7 = cmp_stb7 & cmp_match_fn(cmp_val7, dvr7, dcr7[3:1], dcr7[4]);
assign wp_chain[0] = (dmr1[17:16] == 2'b00) ? 1'b0 : match0;
assign wp_chain[1] = (dmr1[19:18] == 2'b00) ? 1'b0 :
                     (dmr1[19:18] == 2'b01) ? match1 :
                     (dmr1[19:18] == 2'b10) ? (match1 & wp_chain[0]) :
                                              (match1 | wp_chain[0]);
assign wp_chain[2] = (dmr1[21:20] == 2'b00) ? 1'b0 :
                     (dmr1[21:20] == 2'b01) ? match2 :
                     (dmr1[21:20] == 2'b10) ? (match2 & wp_chain[1]) :
                                              (match2 | wp_chain[1]);
assign wp_chain[3] = (dmr1[23:22] == 2'b00) ? 1'b0 :
                     (dmr1[23:22] == 2'b01) ? match3 :
                     (dmr1[23:22] == 2'b10) ? (match3 & wp_chain[2]) :
                                              (match3 | wp_chain[2]);
assign wp_chain[4] = (dmr1[25:24] == 2'b00) ? 1'b0 :
                     (dmr1[25:24] == 2'b01) ? match4 :
                     (dmr1[25:24] == 2'b10) ? (match4 & wp_chain[3]) :
                                              (match4 | wp_chain[3]);
assign wp_chain[5] = (dmr1[27:26] == 2'b00) ? 1'b0 :
                     (dmr1[27:26] == 2'b01) ? match5 :
                     (dmr1[27:26] == 2'b10) ? (match5 & wp_chain[4]) :
                                              (match5 | wp_chain[4]);
assign wp_chain[6] = (dmr1[29:28] == 2'b00) ? 1'b0 :
                     (dmr1[29:28] == 2'b01) ? match6 :
                     (dmr1[29:28] == 2'b10) ? (match6 & wp_chain[5]) :
                                              (match6 | wp_chain[5]);
assign wp_chain[7] = (dmr1[31:30] == 2'b00) ? 1'b0 :
                     (dmr1[31:30] == 2'b01) ? match7 :
                     (dmr1[31:30] == 2'b10) ? (match7 & wp_chain[6]) :
                                              (match7 | wp_chain[6]);
assign wp_counter_event = |wp_chain;
assign counter0_match = (dwcr0[31:16] == dwcr0[15:0]);
assign counter1_match = (dwcr1[31:16] == dwcr1[15:0]);
assign wp_internal = {dbg_ewt_i, counter1_match, counter0_match, wp_chain};
assign du_hwbkpt = |(wp_internal & dmr2[10:0]);
`else
assign du_hwbkpt = 1'b0;
`endif

`ifdef OR1200_DU_TB_IMPLEMENTED
assign tb_record_en = ~ex_freeze & ~ex_is_nop;
`endif

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr1 <= 32'b0;
        dmr2 <= 32'b0;
        dsr <= 14'b0;
        drr <= 14'b0;
`ifdef OR1200_DU_HWBKPTS
        dvr0 <= 32'b0;
        dvr1 <= 32'b0;
        dvr2 <= 32'b0;
        dvr3 <= 32'b0;
        dvr4 <= 32'b0;
        dvr5 <= 32'b0;
        dvr6 <= 32'b0;
        dvr7 <= 32'b0;
        dcr0 <= 8'b0;
        dcr1 <= 8'b0;
        dcr2 <= 8'b0;
        dcr3 <= 8'b0;
        dcr4 <= 8'b0;
        dcr5 <= 8'b0;
        dcr6 <= 8'b0;
        dcr7 <= 8'b0;
        dwcr0 <= 32'b0;
        dwcr1 <= 32'b0;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
        tb_addr_reg <= 8'b0;
        tb_waddr <= 8'b0;
        tb_timstmp <= 32'b0;
`endif
        dbg_bp_r <= 1'b0;
    end else begin
        if (spr_cs && spr_write && (spr_addr11 == SPR_DMR1))
            dmr1 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DMR2))
            dmr2 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DSR))
            dsr <= spr_dat_i[13:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DRR))
            drr <= spr_dat_i[13:0];
        else
            drr <= drr | except_stop;
`ifdef OR1200_DU_HWBKPTS
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR0))
            dvr0 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR1))
            dvr1 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR2))
            dvr2 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR3))
            dvr3 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR4))
            dvr4 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR5))
            dvr5 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR6))
            dvr6 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DVR7))
            dvr7 <= spr_dat_i;
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR0))
            dcr0 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR1))
            dcr1 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR2))
            dcr2 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR3))
            dcr3 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR4))
            dcr4 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR5))
            dcr5 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR6))
            dcr6 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DCR7))
            dcr7 <= spr_dat_i[7:0];
        if (spr_cs && spr_write && (spr_addr11 == SPR_DWCR0))
            dwcr0 <= spr_dat_i;
        else if (dmr2[12] && wp_counter_event)
            dwcr0 <= {dwcr0[31:16], dwcr0[15:0] + 16'h0001};
        if (spr_cs && spr_write && (spr_addr11 == SPR_DWCR1))
            dwcr1 <= spr_dat_i;
        else if (dmr2[13] && wp_counter_event)
            dwcr1 <= {dwcr1[31:16], dwcr1[15:0] + 16'h0001};
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
        if (spr_cs && spr_write && (spr_addr11 == SPR_TB_ADDR))
            tb_addr_reg <= spr_dat_i[7:0];
        if (tb_record_en) begin
            tb_npc_mem[tb_waddr] <= spr_dat_npc;
            tb_insn_mem[tb_waddr] <= ex_insn;
            tb_data_mem[tb_waddr] <= rf_dataw;
            tb_time_mem[tb_waddr] <= tb_timstmp;
            tb_waddr <= tb_waddr + 8'h01;
            tb_timstmp <= tb_timstmp + 32'h0000_0001;
        end
`endif
        if (ex_freeze)
            dbg_bp_r <= except_bp;
        else
            dbg_bp_r <= except_bp | step_bp | branch_bp;
    end
end

`ifdef OR1200_DU_READREGS
reg [31:0] spr_dat_r;
assign spr_dat_o = spr_dat_r;

always @* begin
    spr_dat_r = 32'b0;
    case (spr_addr11)
        SPR_DMR1: spr_dat_r = dmr1;
        SPR_DMR2: spr_dat_r = dmr2;
        SPR_DSR:  spr_dat_r = {18'b0, dsr};
        SPR_DRR:  spr_dat_r = {18'b0, drr};
`ifdef OR1200_DU_HWBKPTS
        SPR_DVR0: spr_dat_r = dvr0;
        SPR_DVR1: spr_dat_r = dvr1;
        SPR_DVR2: spr_dat_r = dvr2;
        SPR_DVR3: spr_dat_r = dvr3;
        SPR_DVR4: spr_dat_r = dvr4;
        SPR_DVR5: spr_dat_r = dvr5;
        SPR_DVR6: spr_dat_r = dvr6;
        SPR_DVR7: spr_dat_r = dvr7;
        SPR_DCR0: spr_dat_r = {24'b0, dcr0};
        SPR_DCR1: spr_dat_r = {24'b0, dcr1};
        SPR_DCR2: spr_dat_r = {24'b0, dcr2};
        SPR_DCR3: spr_dat_r = {24'b0, dcr3};
        SPR_DCR4: spr_dat_r = {24'b0, dcr4};
        SPR_DCR5: spr_dat_r = {24'b0, dcr5};
        SPR_DCR6: spr_dat_r = {24'b0, dcr6};
        SPR_DCR7: spr_dat_r = {24'b0, dcr7};
        SPR_DWCR0: spr_dat_r = dwcr0;
        SPR_DWCR1: spr_dat_r = dwcr1;
`endif
`ifdef OR1200_DU_TB_IMPLEMENTED
        SPR_TB_ADDR: spr_dat_r = {24'b0, tb_addr_reg};
        SPR_TB_NPC:  spr_dat_r = tb_npc_mem[tb_addr_reg];
        SPR_TB_INSN: spr_dat_r = tb_insn_mem[tb_addr_reg];
        SPR_TB_DATA: spr_dat_r = tb_data_mem[tb_addr_reg];
        SPR_TB_TIME: spr_dat_r = tb_time_mem[tb_addr_reg];
`endif
        default: spr_dat_r = 32'b0;
    endcase
end
`else
assign spr_dat_o = 32'b0;
`endif
`else
assign du_dsr = 14'b0;
assign du_hwbkpt = 1'b0;
assign dbg_bp_o = 1'b0;
assign spr_dat_o = 32'b0;
`endif

endmodule
