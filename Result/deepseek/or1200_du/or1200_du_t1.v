// or1200_du - OR1200 Debug Unit
// Configuration macros handled: OR1200_DU_IMPLEMENTED, OR1200_DU_READREGS,
// OR1200_DU_STATUS_UNIMPLEMENTED, OR1200_DU_HWBKPTS, OR1200_DU_TB_IMPLEMENTED,
// and per-register macros.

`define OR1200_DU_IMPLEMENTED
`define OR1200_DU_READREGS
`define OR1200_DU_HWBKPTS
`define OR1200_DU_TB_IMPLEMENTED
// Per-register macros (all enabled)
`define OR1200_DU_DMR1_IMPLEMENTED
`define OR1200_DU_DMR2_IMPLEMENTED
`define OR1200_DU_DSR_IMPLEMENTED
`define OR1200_DU_DRR_IMPLEMENTED
`define OR1200_DU_DVR0_IMPLEMENTED
`define OR1200_DU_DVR1_IMPLEMENTED
`define OR1200_DU_DVR2_IMPLEMENTED
`define OR1200_DU_DVR3_IMPLEMENTED
`define OR1200_DU_DVR4_IMPLEMENTED
`define OR1200_DU_DVR5_IMPLEMENTED
`define OR1200_DU_DVR6_IMPLEMENTED
`define OR1200_DU_DVR7_IMPLEMENTED
`define OR1200_DU_DCR0_IMPLEMENTED
`define OR1200_DU_DCR1_IMPLEMENTED
`define OR1200_DU_DCR2_IMPLEMENTED
`define OR1200_DU_DCR3_IMPLEMENTED
`define OR1200_DU_DCR4_IMPLEMENTED
`define OR1200_DU_DCR5_IMPLEMENTED
`define OR1200_DU_DCR6_IMPLEMENTED
`define OR1200_DU_DCR7_IMPLEMENTED
`define OR1200_DU_DWCR0_IMPLEMENTED
`define OR1200_DU_DWCR1_IMPLEMENTED

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

    // Debug interface bridging
    assign du_stall = dbg_stall_i;
    assign du_addr  = dbg_adr_i;
    assign du_dat_o = dbg_dat_i;
    assign du_read  = dbg_stb_i & ~dbg_we_i;
    assign du_write = dbg_stb_i & dbg_we_i;
    assign dbg_dat_o = du_dat_i;

    // Acknowledge generation
    reg dbg_ack_r;
    always @(posedge clk or posedge rst) begin
        if (rst)
            dbg_ack_r <= 1'b0;
        else
            dbg_ack_r <= dbg_stb_i;
    end
    assign dbg_ack_o = dbg_ack_r;

    // Status outputs
`ifndef OR1200_DU_STATUS_UNIMPLEMENTED
    assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, dcpu_adr_i[1:0]};
    assign dbg_is_o  = {icpu_cycstb_i, 1'b0};
`else
    // Minimal toggle mechanism
    reg [1:0] is_toggle;
    always @(posedge clk or posedge rst) begin
        if (rst)
            is_toggle <= 2'b00;
        else if (icpu_cycstb_i)
            is_toggle <= ~is_toggle;
    end
    assign dbg_lss_o = 4'b0000;
    assign dbg_is_o  = is_toggle;
`endif

    assign dbg_wp_o = 11'b000_0000_0000;

`ifdef OR1200_DU_IMPLEMENTED
    // Register declarations and selects
    wire [10:0] spr_addr_10 = spr_addr[10:0];
    wire spr_acc = spr_cs;
    wire wr_sel = spr_acc & spr_write;

`ifdef OR1200_DU_DMR1_IMPLEMENTED
    reg [13:0] dmr1;
    wire dmr1_sel = spr_acc & (spr_addr_10 == 11'd16);
`endif
`ifdef OR1200_DU_DMR2_IMPLEMENTED
    reg [13:0] dmr2;
    wire dmr2_sel = spr_acc & (spr_addr_10 == 11'd17);
`endif
`ifdef OR1200_DU_DSR_IMPLEMENTED
    reg [13:0] dsr;
    wire dsr_sel = spr_acc & (spr_addr_10 == 11'd18);
`endif
`ifdef OR1200_DU_DRR_IMPLEMENTED
    reg [13:0] drr;
    wire drr_sel = spr_acc & (spr_addr_10 == 11'd19);
`endif

`ifdef OR1200_DU_DVR0_IMPLEMENTED
    reg [31:0] dvr0;
    wire dvr0_sel = spr_acc & (spr_addr_10 == 11'd20);
`endif
`ifdef OR1200_DU_DVR1_IMPLEMENTED
    reg [31:0] dvr1;
    wire dvr1_sel = spr_acc & (spr_addr_10 == 11'd21);
`endif
`ifdef OR1200_DU_DVR2_IMPLEMENTED
    reg [31:0] dvr2;
    wire dvr2_sel = spr_acc & (spr_addr_10 == 11'd22);
`endif
`ifdef OR1200_DU_DVR3_IMPLEMENTED
    reg [31:0] dvr3;
    wire dvr3_sel = spr_acc & (spr_addr_10 == 11'd23);
`endif
`ifdef OR1200_DU_DVR4_IMPLEMENTED
    reg [31:0] dvr4;
    wire dvr4_sel = spr_acc & (spr_addr_10 == 11'd24);
`endif
`ifdef OR1200_DU_DVR5_IMPLEMENTED
    reg [31:0] dvr5;
    wire dvr5_sel = spr_acc & (spr_addr_10 == 11'd25);
`endif
`ifdef OR1200_DU_DVR6_IMPLEMENTED
    reg [31:0] dvr6;
    wire dvr6_sel = spr_acc & (spr_addr_10 == 11'd26);
`endif
`ifdef OR1200_DU_DVR7_IMPLEMENTED
    reg [31:0] dvr7;
    wire dvr7_sel = spr_acc & (spr_addr_10 == 11'd27);
`endif

`ifdef OR1200_DU_DCR0_IMPLEMENTED
    reg [7:0] dcr0;
    wire dcr0_sel = spr_acc & (spr_addr_10 == 11'd28);
`endif
`ifdef OR1200_DU_DCR1_IMPLEMENTED
    reg [7:0] dcr1;
    wire dcr1_sel = spr_acc & (spr_addr_10 == 11'd29);
`endif
`ifdef OR1200_DU_DCR2_IMPLEMENTED
    reg [7:0] dcr2;
    wire dcr2_sel = spr_acc & (spr_addr_10 == 11'd30);
`endif
`ifdef OR1200_DU_DCR3_IMPLEMENTED
    reg [7:0] dcr3;
    wire dcr3_sel = spr_acc & (spr_addr_10 == 11'd31);
`endif
`ifdef OR1200_DU_DCR4_IMPLEMENTED
    reg [7:0] dcr4;
    wire dcr4_sel = spr_acc & (spr_addr_10 == 11'd32);
`endif
`ifdef OR1200_DU_DCR5_IMPLEMENTED
    reg [7:0] dcr5;
    wire dcr5_sel = spr_acc & (spr_addr_10 == 11'd33);
`endif
`ifdef OR1200_DU_DCR6_IMPLEMENTED
    reg [7:0] dcr6;
    wire dcr6_sel = spr_acc & (spr_addr_10 == 11'd34);
`endif
`ifdef OR1200_DU_DCR7_IMPLEMENTED
    reg [7:0] dcr7;
    wire dcr7_sel = spr_acc & (spr_addr_10 == 11'd35);
`endif

`ifdef OR1200_DU_DWCR0_IMPLEMENTED
    reg [31:0] dwcr0;
    wire dwcr0_sel = spr_acc & (spr_addr_10 == 11'd36);
`endif
`ifdef OR1200_DU_DWCR1_IMPLEMENTED
    reg [31:0] dwcr1;
    wire dwcr1_sel = spr_acc & (spr_addr_10 == 11'd37);
`endif

    // Register reset/write
`ifdef OR1200_DU_DMR1_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dmr1 <= 14'd0;
        else if (wr_sel && dmr1_sel)
            dmr1 <= spr_dat_i[13:0];
    end
`endif
`ifdef OR1200_DU_DMR2_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dmr2 <= 14'd0;
        else if (wr_sel && dmr2_sel)
            dmr2 <= spr_dat_i[13:0];
    end
`endif
`ifdef OR1200_DU_DSR_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dsr <= 14'd0;
        else if (wr_sel && dsr_sel)
            dsr <= spr_dat_i[13:0];
    end
`endif
`ifdef OR1200_DU_DRR_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            drr <= 14'd0;
        else if (wr_sel && drr_sel)
            drr <= spr_dat_i[13:0];
        else
            drr <= drr | except_stop;
    end
`endif

`ifdef OR1200_DU_DVR0_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr0 <= 32'd0;
        else if (wr_sel && dvr0_sel)
            dvr0 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR1_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr1 <= 32'd0;
        else if (wr_sel && dvr1_sel)
            dvr1 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR2_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr2 <= 32'd0;
        else if (wr_sel && dvr2_sel)
            dvr2 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR3_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr3 <= 32'd0;
        else if (wr_sel && dvr3_sel)
            dvr3 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR4_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr4 <= 32'd0;
        else if (wr_sel && dvr4_sel)
            dvr4 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR5_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr5 <= 32'd0;
        else if (wr_sel && dvr5_sel)
            dvr5 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR6_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr6 <= 32'd0;
        else if (wr_sel && dvr6_sel)
            dvr6 <= spr_dat_i;
    end
`endif
`ifdef OR1200_DU_DVR7_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dvr7 <= 32'd0;
        else if (wr_sel && dvr7_sel)
            dvr7 <= spr_dat_i;
    end
`endif

`ifdef OR1200_DU_DCR0_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr0 <= 8'd0;
        else if (wr_sel && dcr0_sel)
            dcr0 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR1_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr1 <= 8'd0;
        else if (wr_sel && dcr1_sel)
            dcr1 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR2_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr2 <= 8'd0;
        else if (wr_sel && dcr2_sel)
            dcr2 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR3_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr3 <= 8'd0;
        else if (wr_sel && dcr3_sel)
            dcr3 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR4_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr4 <= 8'd0;
        else if (wr_sel && dcr4_sel)
            dcr4 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR5_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr5 <= 8'd0;
        else if (wr_sel && dcr5_sel)
            dcr5 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR6_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr6 <= 8'd0;
        else if (wr_sel && dcr6_sel)
            dcr6 <= spr_dat_i[7:0];
    end
`endif
`ifdef OR1200_DU_DCR7_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dcr7 <= 8'd0;
        else if (wr_sel && dcr7_sel)
            dcr7 <= spr_dat_i[7:0];
    end
`endif

`ifdef OR1200_DU_DWCR0_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dwcr0 <= 32'd0;
        else if (wr_sel && dwcr0_sel)
            dwcr0 <= spr_dat_i;
        else if (dmr2[0] && wp[0])
            dwcr0[15:0] <= dwcr0[15:0] + 1'b1;
    end
`endif
`ifdef OR1200_DU_DWCR1_IMPLEMENTED
    always @(posedge clk or posedge rst) begin
        if (rst)
            dwcr1 <= 32'd0;
        else if (wr_sel && dwcr1_sel)
            dwcr1 <= spr_dat_i;
        else if (dmr2[1] && wp[1])
            dwcr1[15:0] <= dwcr1[15:0] + 1'b1;
    end
`endif

    // Exception decode
    wire [13:0] except_stop;
    assign except_stop = {1'b0, du_except};

    // Breakpoint output
    reg dbg_bp_r;
    wire single_step_cond;
    wire branch_trace_cond;

`ifdef OR1200_DU_DMR1_IMPLEMENTED
    assign single_step_cond  = dmr1[0] & (ex_insn != 32'h1500_0000);
    assign branch_trace_cond = dmr1[1] & (branch_op != 3'b000) & (ex_insn != 32'h1500_0000);
`else
    assign single_step_cond  = 1'b0;
    assign branch_trace_cond = 1'b0;
`endif

    always @(posedge clk or posedge rst) begin
        if (rst)
            dbg_bp_r <= 1'b0;
        else if (ex_freeze)
            dbg_bp_r <= |except_stop;
        else
            dbg_bp_r <= |except_stop | single_step_cond | branch_trace_cond;
    end
    assign dbg_bp_o = dbg_bp_r;

    // DSR output
`ifdef OR1200_DU_DSR_IMPLEMENTED
    assign du_dsr = dsr;
`else
    assign du_dsr = 14'd0;
`endif

    // Hardware watchpoints
    wire [7:0] match;
    wire [10:0] wp;
    wire counter_match0, counter_match1;

`ifdef OR1200_DU_HWBKPTS
    // Comparison target selection function
    function [31:0] select_target;
        input [2:0] type_sel;
        input [31:0] dcpu_adr, dcpu_dat_lsu, dcpu_dat_dc;
        input dcpu_we;
        begin
            case (type_sel)
                3'b001: select_target = id_pc;
                3'b010: select_target = dcpu_adr;
                3'b011: select_target = dcpu_adr;
                3'b100: select_target = dcpu_we ? dcpu_dat_lsu : dcpu_dat_dc;
                3'b101: select_target = dcpu_we ? dcpu_dat_lsu : dcpu_dat_dc;
                3'b110: select_target = dcpu_adr;
                3'b111: select_target = dcpu_we ? dcpu_dat_lsu : dcpu_dat_dc;
                default: select_target = 32'd0;
            endcase
        end
    endfunction

    // Comparison strobe function
    function strobe;
        input [2:0] type_sel;
        input icpu_cycstb, dcpu_cycstb;
        begin
            case (type_sel)
                3'b001: strobe = icpu_cycstb;
                3'b010, 3'b011, 3'b100, 3'b101, 3'b110, 3'b111: strobe = dcpu_cycstb;
                default: strobe = 1'b0;
            endcase
        end
    endfunction

    // Per-watchpoint comparison
    wire [31:0] target0, target1, target2, target3, target4, target5, target6, target7;
    wire strobe0, strobe1, strobe2, strobe3, strobe4, strobe5, strobe6, strobe7;
    wire [31:0] dvr_val0, dvr_val1, dvr_val2, dvr_val3, dvr_val4, dvr_val5, dvr_val6, dvr_val7;
    wire [7:0] dcr_val0, dcr_val1, dcr_val2, dcr_val3, dcr_val4, dcr_val5, dcr_val6, dcr_val7;

`ifdef OR1200_DU_DCR0_IMPLEMENTED
    assign dcr_val0 = dcr0;
`else
    assign dcr_val0 = 8'd0;
`endif
`ifdef OR1200_DU_DVR0_IMPLEMENTED
    assign dvr_val0 = dvr0;
`else
    assign dvr_val0 = 32'd0;
`endif
    assign target0 = select_target(dcr_val0[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe0 = strobe(dcr_val0[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR1_IMPLEMENTED
    assign dcr_val1 = dcr1;
`else
    assign dcr_val1 = 8'd0;
`endif
`ifdef OR1200_DU_DVR1_IMPLEMENTED
    assign dvr_val1 = dvr1;
`else
    assign dvr_val1 = 32'd0;
`endif
    assign target1 = select_target(dcr_val1[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe1 = strobe(dcr_val1[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR2_IMPLEMENTED
    assign dcr_val2 = dcr2;
`else
    assign dcr_val2 = 8'd0;
`endif
`ifdef OR1200_DU_DVR2_IMPLEMENTED
    assign dvr_val2 = dvr2;
`else
    assign dvr_val2 = 32'd0;
`endif
    assign target2 = select_target(dcr_val2[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe2 = strobe(dcr_val2[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR3_IMPLEMENTED
    assign dcr_val3 = dcr3;
`else
    assign dcr_val3 = 8'd0;
`endif
`ifdef OR1200_DU_DVR3_IMPLEMENTED
    assign dvr_val3 = dvr3;
`else
    assign dvr_val3 = 32'd0;
`endif
    assign target3 = select_target(dcr_val3[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe3 = strobe(dcr_val3[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR4_IMPLEMENTED
    assign dcr_val4 = dcr4;
`else
    assign dcr_val4 = 8'd0;
`endif
`ifdef OR1200_DU_DVR4_IMPLEMENTED
    assign dvr_val4 = dvr4;
`else
    assign dvr_val4 = 32'd0;
`endif
    assign target4 = select_target(dcr_val4[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe4 = strobe(dcr_val4[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR5_IMPLEMENTED
    assign dcr_val5 = dcr5;
`else
    assign dcr_val5 = 8'd0;
`endif
`ifdef OR1200_DU_DVR5_IMPLEMENTED
    assign dvr_val5 = dvr5;
`else
    assign dvr_val5 = 32'd0;
`endif
    assign target5 = select_target(dcr_val5[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe5 = strobe(dcr_val5[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR6_IMPLEMENTED
    assign dcr_val6 = dcr6;
`else
    assign dcr_val6 = 8'd0;
`endif
`ifdef OR1200_DU_DVR6_IMPLEMENTED
    assign dvr_val6 = dvr6;
`else
    assign dvr_val6 = 32'd0;
`endif
    assign target6 = select_target(dcr_val6[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe6 = strobe(dcr_val6[7:5], icpu_cycstb_i, dcpu_cycstb_i);

`ifdef OR1200_DU_DCR7_IMPLEMENTED
    assign dcr_val7 = dcr7;
`else
    assign dcr_val7 = 8'd0;
`endif
`ifdef OR1200_DU_DVR7_IMPLEMENTED
    assign dvr_val7 = dvr7;
`else
    assign dvr_val7 = 32'd0;
`endif
    assign target7 = select_target(dcr_val7[7:5], dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, dcpu_we_i);
    assign strobe7 = strobe(dcr_val7[7:5], icpu_cycstb_i, dcpu_cycstb_i);

    // Comparison function
    function match_comp;
        input [31:0] target, dvr;
        input [2:0] comp_type;
        input sign_ctl;
        reg [31:0] a, b;
        begin
            a = target;
            b = dvr;
            if (sign_ctl) begin
                a[31] = ~a[31];
                b[31] = ~b[31];
            end
            case (comp_type)
                3'b001: match_comp = (a == b);
                3'b010: match_comp = (a < b);
                3'b011: match_comp = (a <= b);
                3'b100: match_comp = (a > b);
                3'b101: match_comp = (a >= b);
                3'b110: match_comp = (a != b);
                default: match_comp = 1'b0;
            endcase
        end
    endfunction

    assign match[0] = strobe0 & match_comp(target0, dvr_val0, dcr_val0[4:2], dcr_val0[1]);
    assign match[1] = strobe1 & match_comp(target1, dvr_val1, dcr_val1[4:2], dcr_val1[1]);
    assign match[2] = strobe2 & match_comp(target2, dvr_val2, dcr_val2[4:2], dcr_val2[1]);
    assign match[3] = strobe3 & match_comp(target3, dvr_val3, dcr_val3[4:2], dcr_val3[1]);
    assign match[4] = strobe4 & match_comp(target4, dvr_val4, dcr_val4[4:2], dcr_val4[1]);
    assign match[5] = strobe5 & match_comp(target5, dvr_val5, dcr_val5[4:2], dcr_val5[1]);
    assign match[6] = strobe6 & match_comp(target6, dvr_val6, dcr_val6[4:2], dcr_val6[1]);
    assign match[7] = strobe7 & match_comp(target7, dvr_val7, dcr_val7[4:2], dcr_val7[1]);

    // Watchpoint chaining
`ifdef OR1200_DU_DMR1_IMPLEMENTED
    wire [1:0] wp_sel0 = dmr1[3:2];
    wire [1:0] wp_sel1 = dmr1[5:4];
    wire [1:0] wp_sel2 = dmr1[7:6];
    wire [1:0] wp_sel3 = dmr1[9:8];
    wire [1:0] wp_sel4 = dmr1[11:10];
    wire [1:0] wp_sel5 = dmr1[13:12];
    // wp_sel6 and wp_sel7 not in dmr1, use dmr2 or fixed
`ifdef OR1200_DU_DMR2_IMPLEMENTED
    wire [1:0] wp_sel6 = dmr2[3:2];
    wire [1:0] wp_sel7 = dmr2[5:4];
`else
    wire [1:0] wp_sel6 = 2'b00;
    wire [1:0] wp_sel7 = 2'b00;
`endif
`else
    wire [1:0] wp_sel0 = 2'b00;
    wire [1:0] wp_sel1 = 2'b00;
    wire [1:0] wp_sel2 = 2'b00;
    wire [1:0] wp_sel3 = 2'b00;
    wire [1:0] wp_sel4 = 2'b00;
    wire [1:0] wp_sel5 = 2'b00;
    wire [1:0] wp_sel6 = 2'b00;
    wire [1:0] wp_sel7 = 2'b00;
`endif

    function chain;
        input [1:0] sel;
        input direct_match, prev_wp;
        begin
            case (sel)
                2'b01: chain = direct_match;
                2'b10: chain = direct_match & prev_wp;
                2'b11: chain = direct_match | prev_wp;
                default: chain = 1'b0;
            endcase
        end
    endfunction

    assign wp[0] = chain(wp_sel0, match[0], 1'b0);
    assign wp[1] = chain(wp_sel1, match[1], wp[0]);
    assign wp[2] = chain(wp_sel2, match[2], wp[1]);
    assign wp[3] = chain(wp_sel3, match[3], wp[2]);
    assign wp[4] = chain(wp_sel4, match[4], wp[3]);
    assign wp[5] = chain(wp_sel5, match[5], wp[4]);
    assign wp[6] = chain(wp_sel6, match[6], wp[5]);
    assign wp[7] = chain(wp_sel7, match[7], wp[6]);

    // Counter match signals
`ifdef OR1200_DU_DWCR0_IMPLEMENTED
    assign counter_match0 = (dwcr0[31:16] == dwcr0[15:0]) && (dwcr0[31:16] != 16'd0);
`else
    assign counter_match0 = 1'b0;
`endif
`ifdef OR1200_DU_DWCR1_IMPLEMENTED
    assign counter_match1 = (dwcr1[31:16] == dwcr1[15:0]) && (dwcr1[31:16] != 16'd0);
`else
    assign counter_match1 = 1'b0;
`endif

    assign wp[8] = counter_match0;
    assign wp[9] = counter_match1;
    assign wp[10] = dbg_ewt_i;

    // Hardware breakpoint output
`ifdef OR1200_DU_DMR2_IMPLEMENTED
    assign du_hwbkpt = |(wp & dmr2[10:0]);
`else
    assign du_hwbkpt = 1'b0;
`endif
`else
    // No hardware watchpoints
    assign du_hwbkpt = 1'b0;
    wire [10:0] wp = 11'd0;
`endif

    // Trace buffer
`ifdef OR1200_DU_TB_IMPLEMENTED
    reg [7:0] tb_wr_addr;
    reg [31:0] tb_timstmp;
    reg [31:0] tb_pc_ram [0:255];
    reg [31:0] tb_insn_ram [0:255];
    reg [31:0] tb_wb_ram [0:255];
    reg [31:0] tb_stamp_ram [0:255];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tb_wr_addr <= 8'd0;
            tb_timstmp <= 32'd0;
        end else if (!ex_freeze && (ex_insn != 32'h1500_0000)) begin
            tb_pc_ram[tb_wr_addr] <= spr_dat_npc;
            tb_insn_ram[tb_wr_addr] <= ex_insn;
            tb_wb_ram[tb_wr_addr] <= rf_dataw;
            tb_stamp_ram[tb_wr_addr] <= tb_timstmp;
            tb_wr_addr <= tb_wr_addr + 1'b1;
            tb_timstmp <= tb_timstmp + 1'b1;
        end
    end

    // Trace buffer read
    wire tb_sel = spr_acc & (spr_addr_10 >= 11'd64) & (spr_addr_10 <= 11'd67);
    wire [7:0] tb_rd_addr = spr_dat_npc[7:0]; // Use spr_dat_npc as read address
    reg [31:0] tb_rd_data;
    always @* begin
        case (spr_addr_10[1:0])
            2'b00: tb_rd_data = tb_pc_ram[tb_rd_addr];
            2'b01: tb_rd_data = tb_insn_ram[tb_rd_addr];
            2'b10: tb_rd_data = tb_wb_ram[tb_rd_addr];
            2'b11: tb_rd_data = tb_stamp_ram[tb_rd_addr];
        endcase
    end
`else
    wire tb_sel = 1'b0;
    wire [31:0] tb_rd_data = 32'd0;
`endif

    // SPR read path
`ifdef OR1200_DU_READREGS
    reg [31:0] spr_dat_o_reg;
    always @* begin
        spr_dat_o_reg = 32'd0;
        if (spr_acc) begin
            case (spr_addr_10)
`ifdef OR1200_DU_DMR1_IMPLEMENTED
                11'd16: spr_dat_o_reg = {18'd0, dmr1};
`endif
`ifdef OR1200_DU_DMR2_IMPLEMENTED
                11'd17: spr_dat_o_reg = {18'd0, dmr2};
`endif
`ifdef OR1200_DU_DSR_IMPLEMENTED
                11'd18: spr_dat_o_reg = {18'd0, dsr};
`endif
`ifdef OR1200_DU_DRR_IMPLEMENTED
                11'd19: spr_dat_o_reg = {18'd0, drr};
`endif
`ifdef OR1200_DU_DVR0_IMPLEMENTED
                11'd20: spr_dat_o_reg = dvr0;
`endif
`ifdef OR1200_DU_DVR1_IMPLEMENTED
                11'd21: spr_dat_o_reg = dvr1;
`endif
`ifdef OR1200_DU_DVR2_IMPLEMENTED
                11'd22: spr_dat_o_reg = dvr2;
`endif
`ifdef OR1200_DU_DVR3_IMPLEMENTED
                11'd23: spr_dat_o_reg = dvr3;
`endif
`ifdef OR1200_DU_DVR4_IMPLEMENTED
                11'd24: spr_dat_o_reg = dvr4;
`endif
`ifdef OR1200_DU_DVR5_IMPLEMENTED
                11'd25: spr_dat_o_reg = dvr5;
`endif
`ifdef OR1200_DU_DVR6_IMPLEMENTED
                11'd26: spr_dat_o_reg = dvr6;
`endif
`ifdef OR1200_DU_DVR7_IMPLEMENTED
                11'd27: spr_dat_o_reg = dvr7;
`endif
`ifdef OR1200_DU_DCR0_IMPLEMENTED
                11'd28: spr_dat_o_reg = {24'd0, dcr0};
`endif
`ifdef OR1200_DU_DCR1_IMPLEMENTED
                11'd29: spr_dat_o_reg = {24'd0, dcr1};
`endif
`ifdef OR1200_DU_DCR2_IMPLEMENTED
                11'd30: spr_dat_o_reg = {24'd0, dcr2};
`endif
`ifdef OR1200_DU_DCR3_IMPLEMENTED
                11'd31: spr_dat_o_reg = {24'd0, dcr3};
`endif
`ifdef OR1200_DU_DCR4_IMPLEMENTED
                11'd32: spr_dat_o_reg = {24'd0, dcr4};
`endif
`ifdef OR1200_DU_DCR5_IMPLEMENTED
                11'd33: spr_dat_o_reg = {24'd0, dcr5};
`endif
`ifdef OR1200_DU_DCR6_IMPLEMENTED
                11'd34: spr_dat_o_reg = {24'd0, dcr6};
`endif
`ifdef OR1200_DU_DCR7_IMPLEMENTED
                11'd35: spr_dat_o_reg = {24'd0, dcr7};
`endif
`ifdef OR1200_DU_DWCR0_IMPLEMENTED
                11'd36: spr_dat_o_reg = dwcr0;
`endif
`ifdef OR1200_DU_DWCR1_IMPLEMENTED
                11'd37: spr_dat_o_reg = dwcr1;
`endif
                default: spr_dat_o_reg = tb_sel ? tb_rd_data : 32'd0;
            endcase
        end
    end
    assign spr_dat_o = spr_dat_o_reg;
`else
    assign spr_dat_o = 32'd0;
`endif

`else
    // DU not implemented: minimal bridge
    assign du_dsr = 14'd0;
    assign dbg_bp_o = 1'b0;
    assign du_hwbkpt = 1'b0;
    assign spr_dat_o = 32'd0;
`endif

endmodule
