// Generated from: Description/or1200_sb_description.txt
module or1200_sb(
    input         clk,
    input         rst,

    // DC<->SB
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

    // SB<->BIU
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

`include "or1200_defines.v"

  assign dcsb_dat_o = sbbiu_dat_i;

`ifdef OR1200_SB_IMPLEMENTED
  // Simple small FIFO for {sel,dat,adr}
  localparam int DEPTH = 4;
  reg [67:0] mem [0:DEPTH-1];
  reg [$clog2(DEPTH)-1:0] wptr, rptr;
  reg [$clog2(DEPTH+1)-1:0] count;

  wire fifo_full  = (count == DEPTH);
  wire fifo_empty = (count == 0);

  reg fifo_wr_ack;
  reg outstanding_store;

  wire fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
  wire fifo_rd = ~outstanding_store;

  wire sel_sb = (~fifo_empty) | (fifo_empty & outstanding_store);

  wire [67:0] fifo_dat_o = mem[rptr];
  wire [3:0]  fifo_sel = fifo_dat_o[67:64];
  wire [31:0] fifo_dat = fifo_dat_o[63:32];
  wire [31:0] fifo_adr = fifo_dat_o[31:0];

  // FIFO write/ack pulse
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      wptr <= '0;
      rptr <= '0;
      count <= '0;
      fifo_wr_ack <= 1'b0;
    end else begin
      fifo_wr_ack <= 1'b0;
      if (fifo_wr) begin
        mem[wptr] <= {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
        wptr <= wptr + 1'b1;
        count <= count + 1'b1;
        fifo_wr_ack <= 1'b1;
      end
      if (sel_sb && fifo_rd && !fifo_empty) begin
        // Pop only when SB path active and no outstanding store
        rptr <= rptr + 1'b1;
        count <= count - 1'b1;
      end
    end
  end

  // outstanding_store tracking
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      outstanding_store <= 1'b0;
    end else begin
      if (sbbiu_ack_i) begin
        outstanding_store <= 1'b0;
      end else if (sel_sb || fifo_wr) begin
        outstanding_store <= 1'b1;
      end
    end
  end

  // DC-side responses
  assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
  assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;

  // BIU-side drive
  assign sbbiu_dat_o = sel_sb ? fifo_dat : dcsb_dat_i;
  assign sbbiu_adr_o = sel_sb ? fifo_adr : dcsb_adr_i;
  assign sbbiu_sel_o = sel_sb ? fifo_sel : dcsb_sel_i;
  assign sbbiu_we_o  = sel_sb ? 1'b1 : dcsb_we_i;
  assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;
  assign sbbiu_cyc_o = sel_sb ? 1'b1 : dcsb_cyc_i;
  assign sbbiu_stb_o = sel_sb ? 1'b1 : dcsb_stb_i;

`else
  // Pass-through
  assign dcsb_ack_o = sbbiu_ack_i;
  assign dcsb_err_o = sbbiu_err_i;
  assign sbbiu_dat_o = dcsb_dat_i;
  assign sbbiu_adr_o = dcsb_adr_i;
  assign sbbiu_cyc_o = dcsb_cyc_i;
  assign sbbiu_stb_o = dcsb_stb_i;
  assign sbbiu_we_o  = dcsb_we_i;
  assign sbbiu_sel_o = dcsb_sel_i;
  assign sbbiu_cab_o = dcsb_cab_i;
`endif

endmodule
