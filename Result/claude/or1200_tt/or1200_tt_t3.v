`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_tt (
    input         clk,
    input         rst,
    input         du_stall,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output        intr
);

`ifdef OR1200_TT_IMPLEMENTED

    //--------------------------------------------------------------------------
    // TTMR: Tick Timer Mode Register
    //--------------------------------------------------------------------------
`ifdef OR1200_TT_TTMR
    reg [31:0] ttmr;
`else
    wire [31:0] ttmr = {2'b11, 30'b0};
`endif

    //--------------------------------------------------------------------------
    // TTCR: Tick Timer Count Register
    //--------------------------------------------------------------------------
`ifdef OR1200_TT_TTCR
    reg [31:0] ttcr;
`else
    wire [31:0] ttcr = 32'b0;
`endif

    //--------------------------------------------------------------------------
    // SPR address select (write-side only)
    //--------------------------------------------------------------------------
    wire ttmr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
    wire ttcr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

    //--------------------------------------------------------------------------
    // Combinational control signals
    //--------------------------------------------------------------------------

    // match: TTMR threshold field == TTCR[27:0]
    wire match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);

    // restart: match AND mode == 2'b01 (auto-restart)
    wire restart = match & (ttmr[`OR1200_TT_TTMR_M] == 2'b01);

    // stop: match AND mode == 2'b10 (single-run stop)
    //       OR mode == 2'b00 (disabled/stopped)
    //       OR du_stall (debug halt)
    wire stop = (match & (ttmr[`OR1200_TT_TTMR_M] == 2'b10))
              | (ttmr[`OR1200_TT_TTMR_M] == 2'b00)
              | du_stall;

    //--------------------------------------------------------------------------
    // TTMR sequential update
    // Priority: rst > software write > hardware IP update > hold
    //--------------------------------------------------------------------------
`ifdef OR1200_TT_TTMR
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ttmr <= 32'b0;
        end else if (ttmr_sel & spr_write) begin
            // Software write: load entire TTMR
            ttmr <= spr_dat_i;
        end else if (ttmr[`OR1200_TT_TTMR_IE]) begin
            // Hardware: update IP bit only when IE == 1
            // match && IE → set IP; !match && IE → hold IP
            ttmr[`OR1200_TT_TTMR_IP] <= ttmr[`OR1200_TT_TTMR_IP]
                                        | (match & ttmr[`OR1200_TT_TTMR_IE]);
        end
        // else: hold
    end
`endif

    //--------------------------------------------------------------------------
    // TTCR sequential update
    // Priority: rst > restart clear > software write > increment (!stop) > hold
    //--------------------------------------------------------------------------
`ifdef OR1200_TT_TTCR
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ttcr <= 32'b0;
        end else if (restart) begin
            ttcr <= 32'b0;
        end else if (ttcr_sel & spr_write) begin
            ttcr <= spr_dat_i;
        end else if (!stop) begin
            ttcr <= ttcr + 32'h1;
        end
        // stop == 1: hold
    end
`endif

    //--------------------------------------------------------------------------
    // Interrupt output: directly connected to IP bit
    //--------------------------------------------------------------------------
    assign intr = ttmr[`OR1200_TT_TTMR_IP];

    //--------------------------------------------------------------------------
    // SPR read data (combinational; not gated by spr_cs)
    // TTMR offset → ttmr; all other offsets → ttcr
    //--------------------------------------------------------------------------
    reg [31:0] spr_dat_o_r;

    always @(spr_addr or ttmr or ttcr) begin
`ifdef OR1200_TT_READREGS
        if (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR)
            spr_dat_o_r = ttmr;
        else
            spr_dat_o_r = ttcr;
`else
        spr_dat_o_r = 32'b0;
`endif
    end

    assign spr_dat_o = spr_dat_o_r;

`else   // OR1200_TT_IMPLEMENTED not defined

    //--------------------------------------------------------------------------
    // Not implemented: no interrupts, no timer state
    //--------------------------------------------------------------------------
    assign intr = 1'b0;

`ifdef OR1200_TT_READREGS
    assign spr_dat_o = 32'b0;
`endif

`endif  // OR1200_TT_IMPLEMENTED

endmodule