`include "or1200_defines.v"
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
    output reg [31:0] spr_dat_o,
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
    output reg dbg_ack_o
);

reg [24:0] dmr1;
reg [23:0] dmr2;
reg [13:0] dsr;
reg [13:0] drr;
`ifdef OR1200_DU_HWBKPTS
reg [31:0] dvr[0:`OR1200_DU_DVRDCR_PAIRS-1];
reg [7:0]  dcr[0:`OR1200_DU_DVRDCR_PAIRS-1];
`endif
reg [31:0] dwcr0;
reg [31:0] dwcr1;
reg dbg_bp_r;
reg stepping;
reg [10:0] dbg_wp_vec_r;
integer i;
reg [13:0] drr_next;
reg [10:0] dbg_wp_vec_next;
reg dbg_bp_next;
reg watchpoint_hit;

wire [13:0] except_stop;
wire single_step_trig;
wire break_trig;
wire watchpoint_stop;
wire debug_event;
wire [10:0] wp_match;
`ifndef OR1200_DU_HWBKPTS
assign wp_match = 11'h000;
`endif

assign except_stop = {1'b0, du_except};
assign du_dsr = dsr;
assign du_addr = dbg_adr_i;
assign du_dat_o = dbg_dat_i;
assign du_read = dbg_stb_i & ~dbg_we_i;
assign du_write = dbg_stb_i &  dbg_we_i;
assign dbg_dat_o = du_dat_i;
assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, 2'b00};
assign dbg_is_o  = {icpu_cycstb_i[0], ex_freeze};
assign dbg_wp_o  = dbg_wp_vec_r;
assign dbg_bp_o  = dbg_bp_r;
assign single_step_trig = dmr1[`OR1200_DU_DMR1_ST] & ~ex_freeze;
assign break_trig = (branch_op == `OR1200_BRANCHOP_RFE) & dsr[`OR1200_DU_DSR_BE];
`ifdef OR1200_DU_HWBKPTS
assign watchpoint_stop = watchpoint_hit & dmr2[`OR1200_DU_DMR2_WCE0];
`else
assign watchpoint_stop = 1'b0;
`endif
assign debug_event = (|(except_stop & dsr)) | watchpoint_stop | single_step_trig | dbg_ewt_i | break_trig;
assign du_hwbkpt = dbg_bp_r | watchpoint_stop | dbg_ewt_i;
assign du_stall  = dbg_stall_i | debug_event;

`ifdef OR1200_DU_HWBKPTS
genvar gi;
generate
    for (gi = 0; gi < `OR1200_DU_DVRDCR_PAIRS; gi = gi + 1) begin : GEN_WP
        wire match_fetch_addr;
        wire match_lsu_addr;
        wire match_lsu_data;
        assign match_fetch_addr = dcr[gi][`OR1200_DU_DCR_SC] & (id_pc == dvr[gi]);
        assign match_lsu_addr   = dcr[gi][`OR1200_DU_DCR_DP] & dcpu_cycstb_i & (dcpu_adr_i == dvr[gi]);
        assign match_lsu_data   = (dcr[gi][`OR1200_DU_DCR_CT] != 3'b000) ? ((dcpu_dat_lsu == dvr[gi]) | (dcpu_dat_dc == dvr[gi]) | (rf_dataw == dvr[gi])) : 1'b0;
        assign wp_match[gi] = match_fetch_addr | match_lsu_addr | match_lsu_data;
    end
endgenerate
`endif

always @* begin
    drr_next = drr;
    dbg_wp_vec_next = 11'h000;
    dbg_bp_next = 1'b0;
    watchpoint_hit = 1'b0;

    if (except_stop[`OR1200_DU_DSR_WIDTH-1:0] != {`OR1200_DU_DSR_WIDTH{1'b0}})
        drr_next = drr_next | except_stop;

`ifdef OR1200_DU_HWBKPTS
    for (i = 0; i < `OR1200_DU_DVRDCR_PAIRS; i = i + 1) begin
        if (wp_match[i]) begin
            dbg_wp_vec_next[i] = 1'b1;
            watchpoint_hit = 1'b1;
            if (dmr1[`OR1200_DU_DMR1_BT])
                dbg_bp_next = 1'b1;
        end
    end
`endif

    if (single_step_trig)
        drr_next[`OR1200_DU_DRR_TE] = 1'b1;
    if (break_trig)
        drr_next[`OR1200_DU_DRR_BE] = 1'b1;
    if (dbg_ewt_i)
        drr_next[`OR1200_DU_DRR_TE] = 1'b1;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dmr1 <= 25'h0000000;
        dmr2 <= 24'h000000;
        dsr  <= 14'h0000;
        drr  <= 14'h0000;
        dwcr0 <= 32'h0000_0000;
        dwcr1 <= 32'h0000_0000;
        dbg_ack_o <= 1'b0;
        dbg_bp_r <= 1'b0;
        stepping <= 1'b0;
        dbg_wp_vec_r <= 11'h000;
        spr_dat_o <= 32'h0000_0000;
`ifdef OR1200_DU_HWBKPTS
        for (i = 0; i < `OR1200_DU_DVRDCR_PAIRS; i = i + 1) begin
            dvr[i] <= 32'h0000_0000;
            dcr[i] <= 8'h00;
        end
`endif
    end else begin
        dbg_ack_o <= dbg_stb_i;
        dbg_bp_r <= dbg_bp_next;
        dbg_wp_vec_r <= dbg_wp_vec_next;
        drr <= drr_next;
        stepping <= single_step_trig;

        if (spr_cs && spr_write && (spr_addr[`OR1200_SPR_GROUP_BITS] == `OR1200_SPR_GROUP_DU)) begin
            case (spr_addr[10:0])
                `OR1200_DU_DMR1: dmr1 <= spr_dat_i[24:0];
`ifdef OR1200_DU_HWBKPTS
                `OR1200_DU_DMR2: dmr2 <= spr_dat_i[23:0];
                `OR1200_DU_DWCR0: dwcr0 <= spr_dat_i;
                `OR1200_DU_DWCR1: dwcr1 <= spr_dat_i;
`endif
                `OR1200_DU_DSR:  dsr  <= spr_dat_i[13:0];
                `OR1200_DU_DRR:  drr  <= drr & ~spr_dat_i[13:0];
                default: begin
`ifdef OR1200_DU_HWBKPTS
                    for (i = 0; i < `OR1200_DU_DVRDCR_PAIRS; i = i + 1) begin
                        if (spr_addr[10:0] == (`OR1200_DU_DVR0 + i))
                            dvr[i] <= spr_dat_i;
                        if (spr_addr[10:0] == (`OR1200_DU_DCR0 + i))
                            dcr[i] <= spr_dat_i[7:0];
                    end
`endif
                end
            endcase
        end

        spr_dat_o <= 32'h0000_0000;
        if (spr_cs && ~spr_write && (spr_addr[`OR1200_SPR_GROUP_BITS] == `OR1200_SPR_GROUP_DU)) begin
            case (spr_addr[10:0])
                `OR1200_DU_DMR1: spr_dat_o <= {7'h00, dmr1};
`ifdef OR1200_DU_HWBKPTS
                `OR1200_DU_DMR2: spr_dat_o <= {8'h00, dmr2};
                `OR1200_DU_DWCR0: spr_dat_o <= dwcr0;
                `OR1200_DU_DWCR1: spr_dat_o <= dwcr1;
`endif
                `OR1200_DU_DSR:  spr_dat_o <= {18'h0, dsr};
                `OR1200_DU_DRR:  spr_dat_o <= {18'h0, drr};
                default: begin
`ifdef OR1200_DU_HWBKPTS
                    for (i = 0; i < `OR1200_DU_DVRDCR_PAIRS; i = i + 1) begin
                        if (spr_addr[10:0] == (`OR1200_DU_DVR0 + i))
                            spr_dat_o <= dvr[i];
                        if (spr_addr[10:0] == (`OR1200_DU_DCR0 + i))
                            spr_dat_o <= {24'h0, dcr[i]};
                    end
`endif
                end
            endcase
        end
    end
end

endmodule
