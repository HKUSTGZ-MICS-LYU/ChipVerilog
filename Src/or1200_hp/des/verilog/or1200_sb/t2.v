`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_sb (
    input         clk,
    input         rst,

    // DC <-> SB interface
    input  [31:0] dcsb_dat_i,
    input  [31:0] dcsb_adr_i,
    input         dcsb_cyc_i,
    input         dcsb_stb_i,
    input         dcsb_we_i,
    input  [3:0]  dcsb_sel_i,
    input         dcsb_cab_i,
    output [31:0] dcsb_dat_o,
    output        dcsb_ack_o,
    output        dcsb_err_o,

    // SB <-> BIU interface
    output [31:0] sbbiu_dat_o,
    output [31:0] sbbiu_adr_o,
    output        sbbiu_cyc_o,
    output        sbbiu_stb_o,
    output        sbbiu_we_o,
    output [3:0]  sbbiu_sel_o,
    output        sbbiu_cab_o,
    input  [31:0] sbbiu_dat_i,
    input         sbbiu_ack_i,
    input         sbbiu_err_i
);

`ifdef OR1200_SB_IMPLEMENTED

    //--------------------------------------------------------------------------
    // FIFO data layout: {sel[3:0], dat[31:0], adr[31:0]} = 68 bits
    //--------------------------------------------------------------------------
    wire [67:0] fifo_dat_i;
    wire [67:0] fifo_dat_o;
    wire        fifo_wr;
    wire        fifo_rd;
    wire        fifo_full;
    wire        fifo_empty;

    assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

    //--------------------------------------------------------------------------
    // Outstanding store: tracks an SB write issued to BIU awaiting ack
    //--------------------------------------------------------------------------
    reg outstanding_store;
    reg fifo_wr_ack;

    //--------------------------------------------------------------------------
    // Path selection:
    //   sel_sb = ~fifo_empty | (fifo_empty & outstanding_store)
    // Store Buffer path active when FIFO has data OR a BIU transaction is in flight
    //--------------------------------------------------------------------------
    wire sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

    //--------------------------------------------------------------------------
    // FIFO write condition:
    //   valid DC write request AND FIFO not full AND no held ack from last cycle
    //--------------------------------------------------------------------------
    assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;

    //--------------------------------------------------------------------------
    // FIFO read enable:
    //   allowed when no outstanding BIU store is in flight
    // Note: fifo_rd does not explicitly check fifo_empty; or1200_sb_fifo handles that
    //--------------------------------------------------------------------------
    assign fifo_rd = ~outstanding_store;

    //--------------------------------------------------------------------------
    // fifo_wr_ack: local write acknowledgment
    // Asserted one cycle after successful fifo_wr; clears when id_freeze releases
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            fifo_wr_ack <= 1'b0;
        else
            fifo_wr_ack <= fifo_wr;
    end

    //--------------------------------------------------------------------------
    // outstanding_store:
    //   Set when: SB path selected OR new write accepted into FIFO
    //   Cleared when: BIU returns ack
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            outstanding_store <= 1'b0;
        else if (sbbiu_ack_i)
            outstanding_store <= 1'b0;
        else if (sel_sb | fifo_wr)
            outstanding_store <= 1'b1;
    end

    //--------------------------------------------------------------------------
    // BIU-side outputs
    // Store Buffer path: driven from FIFO output, we=1, cab=0
    // Pass-through path: driven from DC-side request
    //--------------------------------------------------------------------------
    assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0]   : dcsb_adr_i;
    assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32]   : dcsb_dat_i;
    assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64]   : dcsb_sel_i;
    assign sbbiu_we_o  = sel_sb ? 1'b1                : dcsb_we_i;
    assign sbbiu_cab_o = sel_sb ? 1'b0                : dcsb_cab_i;
    assign sbbiu_cyc_o = sel_sb ? 1'b1                : dcsb_cyc_i;
    assign sbbiu_stb_o = sel_sb ? 1'b1                : dcsb_stb_i;

    //--------------------------------------------------------------------------
    // DC-side return signals
    // ACK: when SB path → local fifo_wr_ack; pass-through → BIU ack
    // ERR: when SB path → forced 0 (errors hidden from DC); pass-through → BIU err
    // DAT: always from BIU (reads return BIU data)
    //--------------------------------------------------------------------------
    assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
    assign dcsb_err_o = sel_sb ? 1'b0        : sbbiu_err_i;
    assign dcsb_dat_o = sbbiu_dat_i;

    //--------------------------------------------------------------------------
    // or1200_sb_fifo instantiation
    //--------------------------------------------------------------------------
    or1200_sb_fifo or1200_sb_fifo (
        .clk      (clk),
        .rst      (rst),
        .dat_i    (fifo_dat_i),
        .wr_i     (fifo_wr),
        .rd_i     (fifo_rd),
        .dat_o    (fifo_dat_o),
        .full_o   (fifo_full),
        .empty_o  (fifo_empty)
    );

`else   // OR1200_SB_IMPLEMENTED not defined: pure pass-through

    //--------------------------------------------------------------------------
    // Direct pass-through: DC <-> BIU with no buffering
    //--------------------------------------------------------------------------
    assign sbbiu_dat_o = dcsb_dat_i;
    assign sbbiu_adr_o = dcsb_adr_i;
    assign sbbiu_cyc_o = dcsb_cyc_i;
    assign sbbiu_stb_o = dcsb_stb_i;
    assign sbbiu_we_o  = dcsb_we_i;
    assign sbbiu_sel_o = dcsb_sel_i;
    assign sbbiu_cab_o = dcsb_cab_i;

    assign dcsb_dat_o  = sbbiu_dat_i;
    assign dcsb_ack_o  = sbbiu_ack_i;
    assign dcsb_err_o  = sbbiu_err_i;

`endif  // OR1200_SB_IMPLEMENTED

endmodule