`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_du (
    input         clk,
    input         rst,
    input         dcpu_cycstb_i,
    input         dcpu_we_i,
    input  [31:0] dcpu_adr_i,
    input  [31:0] dcpu_dat_lsu,
    input  [31:0] dcpu_dat_dc,
    input  [0:0]  icpu_cycstb_i,
    input         ex_freeze,
    input  [2:0]  branch_op,
    input  [31:0] ex_insn,
    input  [31:0] id_pc,
    input  [31:0] spr_dat_npc,
    input  [31:0] rf_dataw,
    output [13:0] du_dsr,
    output        du_stall,
    output [31:0] du_addr,
    input  [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output        du_read,
    output        du_write,
    input  [12:0] du_except,
    output        du_hwbkpt,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    // External Debug Interface
    input         dbg_stall_i,
    input         dbg_ewt_i,
    output [3:0]  dbg_lss_o,
    output [1:0]  dbg_is_o,
    output [10:0] dbg_wp_o,
    output        dbg_bp_o,
    input         dbg_stb_i,
    input         dbg_we_i,
    input  [31:0] dbg_adr_i,
    input  [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output        dbg_ack_o
);

    //--------------------------------------------------------------------------
    // Direct debug interface forwarding (always present)
    //--------------------------------------------------------------------------
    assign du_stall  = dbg_stall_i;
    assign du_addr   = dbg_adr_i;
    assign du_dat_o  = dbg_dat_i;
    assign du_read   = dbg_stb_i & ~dbg_we_i;
    assign du_write  = dbg_stb_i &  dbg_we_i;
    assign dbg_dat_o = du_dat_i;

    // dbg_ack_o: one-cycle delayed dbg_stb_i
    reg dbg_ack_r;
    always @(posedge clk or posedge rst) begin
        if (rst) dbg_ack_r <= 1'b0;
        else     dbg_ack_r <= dbg_stb_i;
    end
    assign dbg_ack_o = dbg_ack_r;

    // dbg_wp_o always 0 per spec
    assign dbg_wp_o = 11'b0;

`ifdef OR1200_DU_IMPLEMENTED

    //--------------------------------------------------------------------------
    // Debug registers
    //--------------------------------------------------------------------------

    // DSR - Debug Stop Register [13:0]
`ifdef OR1200_DU_DSR
    reg [13:0] dsr;
    wire spr_sel_dsr = spr_cs && (spr_addr[10:0] == `OR1200_DU_DSR_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                       dsr <= 14'h0;
        else if (spr_sel_dsr & spr_write) dsr <= spr_dat_i[13:0];
    end
    assign du_dsr = dsr;
`else
    assign du_dsr = 14'h0;
    wire [13:0] dsr = 14'h0;
`endif

    // Decode except_stop from du_except
    wire [13:0] except_stop = {{1'b0}, du_except};

    // DRR - Debug Reason Register
`ifdef OR1200_DU_DRR
    reg [13:0] drr;
    wire spr_sel_drr = spr_cs && (spr_addr[10:0] == `OR1200_DU_DRR_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                        drr <= 14'h0;
        else if (spr_sel_drr & spr_write) drr <= spr_dat_i[13:0];
        else                            drr <= drr | except_stop;
    end
`else
    wire [13:0] drr = 14'h0;
`endif

    // DMR1 - Debug Mode Register 1
`ifdef OR1200_DU_DMR1
    reg [24:0] dmr1;
    wire spr_sel_dmr1 = spr_cs && (spr_addr[10:0] == `OR1200_DU_DMR1_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                         dmr1 <= 25'h0;
        else if (spr_sel_dmr1 & spr_write) dmr1 <= spr_dat_i[24:0];
    end
`else
    wire [24:0] dmr1 = 25'h0;
`endif

    // DMR2 - Debug Mode Register 2
`ifdef OR1200_DU_DMR2
    reg [23:0] dmr2;
    wire spr_sel_dmr2 = spr_cs && (spr_addr[10:0] == `OR1200_DU_DMR2_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                         dmr2 <= 24'h0;
        else if (spr_sel_dmr2 & spr_write) dmr2 <= spr_dat_i[23:0];
    end
`else
    wire [23:0] dmr2 = 24'h0;
`endif

    // DVR0-DVR7 and DCR0-DCR7
`ifdef OR1200_DU_HWBKPTS
    reg [31:0] dvr [0:7];
    reg [7:0]  dcr [0:7];
    integer dvi;
    genvar gi;

    generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : dvr_dcr_regs
        wire spr_sel_dvr = spr_cs && (spr_addr[10:4] == 7'h08) &&
                           (spr_addr[3:1] == gi[2:0]) && !spr_addr[0];
        wire spr_sel_dcr = spr_cs && (spr_addr[10:4] == 7'h08) &&
                           (spr_addr[3:1] == gi[2:0]) &&  spr_addr[0];
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                dvr[gi] <= 32'h0;
                dcr[gi] <= 8'h0;
            end else begin
                if (spr_sel_dvr & spr_write) dvr[gi] <= spr_dat_i[31:0];
                if (spr_sel_dcr & spr_write) dcr[gi] <= spr_dat_i[7:0];
            end
        end
    end
    endgenerate
`endif

    // DWCR0, DWCR1
`ifdef OR1200_DU_DWCR0
    reg [31:0] dwcr0;
    wire spr_sel_dwcr0 = spr_cs && (spr_addr[10:0] == `OR1200_DU_DWCR0_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                          dwcr0 <= 32'h0;
        else if (spr_sel_dwcr0 & spr_write) dwcr0 <= spr_dat_i;
    end
`else
    wire [31:0] dwcr0 = 32'h0;
`endif

`ifdef OR1200_DU_DWCR1
    reg [31:0] dwcr1;
    wire spr_sel_dwcr1 = spr_cs && (spr_addr[10:0] == `OR1200_DU_DWCR1_ADR);
    always @(posedge clk or posedge rst) begin
        if (rst)                          dwcr1 <= 32'h0;
        else if (spr_sel_dwcr1 & spr_write) dwcr1 <= spr_dat_i;
    end
`else
    wire [31:0] dwcr1 = 32'h0;
`endif

    //--------------------------------------------------------------------------
    // Hardware watchpoints
    //--------------------------------------------------------------------------
`ifdef OR1200_DU_HWBKPTS

    wire [31:0] comp_target [0:7];
    wire [7:0]  comp_en;
    wire [7:0]  match;
    reg  [10:0] wp;

    generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : wp_compare
        // Select compare target based on dcr[gi][7:5]
        assign comp_target[gi] =
            (dcr[gi][7:5] == 3'd1) ? id_pc :
            (dcr[gi][7:5] == 3'd2) ? (dcpu_we_i ? 32'h0 : dcpu_adr_i) :
            (dcr[gi][7:5] == 3'd3) ? (dcpu_we_i ? dcpu_adr_i : 32'h0) :
            (dcr[gi][7:5] == 3'd4) ? (dcpu_we_i ? 32'h0 : dcpu_dat_dc) :
            (dcr[gi][7:5] == 3'd5) ? (dcpu_we_i ? dcpu_dat_lsu : 32'h0) :
            (dcr[gi][7:5] == 3'd6) ? dcpu_adr_i :
            (dcr[gi][7:5] == 3'd7) ? (dcpu_we_i ? dcpu_dat_lsu : dcpu_dat_dc) :
            32'h0;

        // Compare enable
        assign comp_en[gi] =
            (dcr[gi][7:5] == 3'd0) ? 1'b0 :
            (dcr[gi][7:5] == 3'd1) ? 1'b1 :
            dcpu_cycstb_i;

        // Signed-modified operands
        wire [31:0] ca = {comp_target[gi][31] ^ dcr[gi][0], comp_target[gi][30:0]};
        wire [31:0] cb = {dvr[gi][31]         ^ dcr[gi][0], dvr[gi][30:0]};

        // Comparison
        assign match[gi] = comp_en[gi] & (
            (dcr[gi][4:2] == 3'd1) ? (ca == cb) :
            (dcr[gi][4:2] == 3'd2) ? (ca <  cb) :
            (dcr[gi][4:2] == 3'd3) ? (ca <= cb) :
            (dcr[gi][4:2] == 3'd4) ? (ca >  cb) :
            (dcr[gi][4:2] == 3'd5) ? (ca >= cb) :
            (dcr[gi][4:2] == 3'd6) ? (ca != cb) :
            1'b0
        );
    end
    endgenerate

    // Combine matches into wp[7:0] via DMR1 chaining
    always @(*) begin
        wp[0] = (dmr1[1:0]   == 2'd0) ? 1'b0 : match[0];
        wp[1] = (dmr1[3:2]   == 2'd0) ? 1'b0 :
                (dmr1[3:2]   == 2'd1) ? match[1] :
                (dmr1[3:2]   == 2'd2) ? (match[1] & wp[0]) :
                                        (match[1] | wp[0]);
        wp[2] = (dmr1[5:4]   == 2'd0) ? 1'b0 :
                (dmr1[5:4]   == 2'd1) ? match[2] :
                (dmr1[5:4]   == 2'd2) ? (match[2] & wp[1]) :
                                        (match[2] | wp[1]);
        wp[3] = (dmr1[7:6]   == 2'd0) ? 1'b0 :
                (dmr1[7:6]   == 2'd1) ? match[3] :
                (dmr1[7:6]   == 2'd2) ? (match[3] & wp[2]) :
                                        (match[3] | wp[2]);
        wp[4] = (dmr1[9:8]   == 2'd0) ? 1'b0 :
                (dmr1[9:8]   == 2'd1) ? match[4] :
                (dmr1[9:8]   == 2'd2) ? (match[4] & wp[3]) :
                                        (match[4] | wp[3]);
        wp[5] = (dmr1[11:10] == 2'd0) ? 1'b0 :
                (dmr1[11:10] == 2'd1) ? match[5] :
                (dmr1[11:10] == 2'd2) ? (match[5] & wp[4]) :
                                        (match[5] | wp[4]);
        wp[6] = (dmr1[13:12] == 2'd0) ? 1'b0 :
                (dmr1[13:12] == 2'd1) ? match[6] :
                (dmr1[13:12] == 2'd2) ? (match[6] & wp[5]) :
                                        (match[6] | wp[5]);
        wp[7] = (dmr1[15:14] == 2'd0) ? 1'b0 :
                (dmr1[15:14] == 2'd1) ? match[7] :
                (dmr1[15:14] == 2'd2) ? (match[7] & wp[6]) :
                                        (match[7] | wp[6]);
        // wp[8]: DWCR0 match
        wp[8]  = (dwcr0[31:16] == dwcr0[15:0]);
        // wp[9]: DWCR1 match
        wp[9]  = (dwcr1[31:16] == dwcr1[15:0]);
        // wp[10]: external watchpoint trigger
        wp[10] = dbg_ewt_i;
    end

    // du_hwbkpt: enabled watchpoints via DMR2
    assign du_hwbkpt = |(wp[10:0] & {dmr2[10:0]});

`else
    reg [10:0] wp;
    always @(*) wp = 11'b0;
    assign du_hwbkpt = 1'b0;
`endif

    //--------------------------------------------------------------------------
    // Breakpoint output (registered)
    //--------------------------------------------------------------------------
    reg dbg_bp_r;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dbg_bp_r <= 1'b0;
        end else if (!ex_freeze) begin
            dbg_bp_r <= |except_stop
`ifdef OR1200_DU_DMR1_ST
                       | (dmr1[22] & !ex_insn[16])
`endif
`ifdef OR1200_DU_DMR1_BT
                       | (dmr1[23] & (branch_op != `OR1200_BRANCHOP_NOP) & !ex_insn[16])
`endif
                       ;
        end else begin
            dbg_bp_r <= |except_stop;
        end
    end
    assign dbg_bp_o = dbg_bp_r;

    //--------------------------------------------------------------------------
    // Status outputs
    //--------------------------------------------------------------------------
`ifdef OR1200_DU_STATUS_UNIMPLEMENTED
    assign dbg_lss_o = 4'h0;
    // Simple toggle for dbg_is_o
    reg dbg_is_r;
    always @(posedge clk or posedge rst) begin
        if (rst) dbg_is_r <= 1'b0;
        else     dbg_is_r <= icpu_cycstb_i[0] ^ dbg_is_r;
    end
    assign dbg_is_o = {1'b0, dbg_is_r};
`else
    assign dbg_lss_o = {dcpu_cycstb_i & dcpu_we_i, dcpu_cycstb_i & ~dcpu_we_i, 2'b00};
    assign dbg_is_o  = {1'b0, icpu_cycstb_i[0]};
`endif

    //--------------------------------------------------------------------------
    // SPR read data
    //--------------------------------------------------------------------------
`ifdef OR1200_DU_READREGS
    reg [31:0] spr_dat_o_r;
    always @(*) begin
        case (spr_addr[10:0])
`ifdef OR1200_DU_DSR
            `OR1200_DU_DSR_ADR:  spr_dat_o_r = {18'h0, dsr};
`endif
`ifdef OR1200_DU_DRR
            `OR1200_DU_DRR_ADR:  spr_dat_o_r = {18'h0, drr};
`endif
`ifdef OR1200_DU_DMR1
            `OR1200_DU_DMR1_ADR: spr_dat_o_r = {7'h0, dmr1};
`endif
`ifdef OR1200_DU_DMR2
            `OR1200_DU_DMR2_ADR: spr_dat_o_r = {8'h0, dmr2};
`endif
`ifdef OR1200_DU_DWCR0
            `OR1200_DU_DWCR0_ADR: spr_dat_o_r = dwcr0;
`endif
`ifdef OR1200_DU_DWCR1
            `OR1200_DU_DWCR1_ADR: spr_dat_o_r = dwcr1;
`endif
`ifdef OR1200_DU_HWBKPTS
            // DVR0-7: addr [10:4]=8'h08, [3:1]=idx, [0]=0
            11'h100, 11'h102, 11'h104, 11'h106,
            11'h108, 11'h10a, 11'h10c, 11'h10e:
                spr_dat_o_r = dvr[spr_addr[3:1]];
            // DCR0-7: addr [0]=1
            11'h101, 11'h103, 11'h105, 11'h107,
            11'h109, 11'h10b, 11'h10d, 11'h10f:
                spr_dat_o_r = {24'h0, dcr[spr_addr[3:1]]};
`endif
            default: spr_dat_o_r = 32'h0;
        endcase
    end
    assign spr_dat_o = spr_dat_o_r;
`else
    assign spr_dat_o = 32'h0;
`endif

`else   // OR1200_DU_IMPLEMENTED not defined

    //--------------------------------------------------------------------------
    // Minimal: only forwarding, no debug registers
    //--------------------------------------------------------------------------
    assign du_dsr    = 14'h0;
    assign du_hwbkpt = 1'b0;
    assign dbg_bp_o  = 1'b0;
    assign dbg_lss_o = 4'h0;
    assign dbg_is_o  = 2'h0;
`ifdef OR1200_DU_READREGS
    assign spr_dat_o = 32'h0;
`else
    assign spr_dat_o = 32'h0;
`endif

`endif  // OR1200_DU_IMPLEMENTED

endmodule