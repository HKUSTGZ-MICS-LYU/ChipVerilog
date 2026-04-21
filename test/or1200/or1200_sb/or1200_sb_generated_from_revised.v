`include "timescale.v"
`include "or1200_defines.v"

module or1200_sb(
	clk, rst,
	dcsb_dat_i, dcsb_adr_i, dcsb_cyc_i, dcsb_stb_i, dcsb_we_i, dcsb_sel_i, dcsb_cab_i,
	dcsb_dat_o, dcsb_ack_o, dcsb_err_o,
	sbbiu_dat_o, sbbiu_adr_o, sbbiu_cyc_o, sbbiu_stb_o, sbbiu_we_o, sbbiu_sel_o, sbbiu_cab_o,
	sbbiu_dat_i, sbbiu_ack_i, sbbiu_err_i
);

input		clk;
input		rst;
input	[31:0]	dcsb_dat_i;
input	[31:0]	dcsb_adr_i;
input		dcsb_cyc_i;
input		dcsb_stb_i;
input		dcsb_we_i;
input		dcsb_cab_i;
input	[3:0]	dcsb_sel_i;
output	[31:0]	dcsb_dat_o;
output		dcsb_ack_o;
output		dcsb_err_o;
output	[31:0]	sbbiu_dat_o;
output	[31:0]	sbbiu_adr_o;
output		sbbiu_cyc_o;
output		sbbiu_stb_o;
output		sbbiu_we_o;
output		sbbiu_cab_o;
output	[3:0]	sbbiu_sel_o;
input	[31:0]	sbbiu_dat_i;
input		sbbiu_ack_i;
input		sbbiu_err_i;

`ifdef OR1200_SB_IMPLEMENTED

wire	[67:0]	fifo_dat_i;
wire	[67:0]	fifo_dat_o;
wire		fifo_wr;
wire		fifo_rd;
wire		fifo_full;
wire		fifo_empty;
wire		sel_sb;
reg		outstanding_store;
reg		fifo_wr_ack;

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
assign {sbbiu_sel_o, sbbiu_dat_o, sbbiu_adr_o} = sel_sb ? fifo_dat_o : {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

// REVISED: fifo_wr includes ~fifo_wr_ack to prevent double-write
assign fifo_wr    = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
// REVISED: fifo_rd = ~outstanding_store (one store at a time)
assign fifo_rd    = ~outstanding_store;
assign dcsb_dat_o = sbbiu_dat_i;
// REVISED: dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i
assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;
assign sbbiu_cyc_o = sel_sb ? outstanding_store : dcsb_cyc_i;
assign sbbiu_stb_o = sel_sb ? outstanding_store : dcsb_stb_i;
assign sbbiu_we_o  = sel_sb ? 1'b1 : dcsb_we_i;
assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;
// REVISED: sel_sb = ~fifo_empty | (fifo_empty & outstanding_store)
assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

or1200_sb_fifo or1200_sb_fifo(
	.clk_i(clk), .rst_i(rst),
	.dat_i(fifo_dat_i), .wr_i(fifo_wr), .rd_i(fifo_rd),
	.dat_o(fifo_dat_o), .full_o(fifo_full), .empty_o(fifo_empty)
);

// REVISED: outstanding_store set on sel_sb | fifo_wr, cleared on sbbiu_ack_i
always @(posedge clk or posedge rst)
	if (rst)
		outstanding_store <= #1 1'b0;
	else if (sbbiu_ack_i)
		outstanding_store <= #1 1'b0;
	else if (sel_sb | fifo_wr)
		outstanding_store <= #1 1'b1;

always @(posedge clk or posedge rst)
	if (rst)
		fifo_wr_ack <= #1 1'b0;
	else if (fifo_wr)
		fifo_wr_ack <= #1 1'b1;
	else
		fifo_wr_ack <= #1 1'b0;

`else

assign sbbiu_dat_o = dcsb_dat_i;
assign sbbiu_adr_o = dcsb_adr_i;
assign sbbiu_cyc_o = dcsb_cyc_i;
assign sbbiu_stb_o = dcsb_stb_i;
assign sbbiu_we_o  = dcsb_we_i;
assign sbbiu_cab_o = dcsb_cab_i;
assign sbbiu_sel_o = dcsb_sel_i;
assign dcsb_dat_o  = sbbiu_dat_i;
assign dcsb_ack_o  = sbbiu_ack_i;
assign dcsb_err_o  = sbbiu_err_i;

`endif

endmodule
