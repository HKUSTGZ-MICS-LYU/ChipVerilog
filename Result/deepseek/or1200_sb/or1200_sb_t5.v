module or1200_sb (
    clk,
    rst,
    dcsb_dat_i,
    dcsb_adr_i,
    dcsb_cyc_i,
    dcsb_stb_i,
    dcsb_we_i,
    dcsb_sel_i,
    dcsb_cab_i,
    dcsb_dat_o,
    dcsb_ack_o,
    dcsb_err_o,
    sbbiu_dat_o,
    sbbiu_adr_o,
    sbbiu_cyc_o,
    sbbiu_stb_o,
    sbbiu_we_o,
    sbbiu_sel_o,
    sbbiu_cab_o,
    sbbiu_dat_i,
    sbbiu_ack_i,
    sbbiu_err_i
);

input clk;
input rst;
input [31:0] dcsb_dat_i;
input [31:0] dcsb_adr_i;
input dcsb_cyc_i;
input dcsb_stb_i;
input dcsb_we_i;
input [3:0] dcsb_sel_i;
input dcsb_cab_i;
output reg [31:0] dcsb_dat_o;
output reg dcsb_ack_o;
output reg dcsb_err_o;
output [31:0] sbbiu_dat_o;
output [31:0] sbbiu_adr_o;
output sbbiu_cyc_o;
output sbbiu_stb_o;
output sbbiu_we_o;
output [3:0] sbbiu_sel_o;
output sbbiu_cab_o;
input [31:0] sbbiu_dat_i;
input sbbiu_ack_i;
input sbbiu_err_i;

`ifdef OR1200_SB_IMPLEMENTED

wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
reg outstanding_store;
reg fifo_wr_ack;
wire sel_sb;
wire [3:0] sel_f;
wire [31:0] dat_f;
wire [31:0] adr_f;

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

or1200_sb_fifo u_fifo (
    .clk(clk),
    .rst(rst),
    .wr(fifo_wr),
    .rd(fifo_rd),
    .dat_i(fifo_dat_i),
    .dat_o(fifo_dat_o),
    .full(fifo_full),
    .empty(fifo_empty)
);

assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;

always @(posedge clk) begin
    if (rst)
        fifo_wr_ack <= 1'b0;
    else if (fifo_wr)
        fifo_wr_ack <= 1'b1;
    else
        fifo_wr_ack <= 1'b0;
end

assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

assign fifo_rd = ~outstanding_store;

always @(posedge clk) begin
    if (rst)
        outstanding_store <= 1'b0;
    else if (sbbiu_ack_i)
        outstanding_store <= 1'b0;
    else if (sel_sb | fifo_wr)
        outstanding_store <= 1'b1;
end

assign {sel_f, dat_f, adr_f} = fifo_dat_o;

assign sbbiu_we_o = sel_sb ? 1'b1 : dcsb_we_i;
assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;
assign sbbiu_sel_o = sel_sb ? sel_f : dcsb_sel_i;
assign sbbiu_dat_o = sel_sb ? dat_f : dcsb_dat_i;
assign sbbiu_adr_o = sel_sb ? adr_f : dcsb_adr_i;
assign sbbiu_cyc_o = sel_sb;
assign sbbiu_stb_o = sel_sb;

always @(*) begin
    if (sel_sb) begin
        dcsb_ack_o = fifo_wr_ack;
        dcsb_err_o = 1'b0;
    end else begin
        dcsb_ack_o = sbbiu_ack_i;
        dcsb_err_o = sbbiu_err_i;
    end
    dcsb_dat_o = sbbiu_dat_i;
end

`else

assign sbbiu_we_o = dcsb_we_i;
assign sbbiu_cab_o = dcsb_cab_i;
assign sbbiu_sel_o = dcsb_sel_i;
assign sbbiu_dat_o = dcsb_dat_i;
assign sbbiu_adr_o = dcsb_adr_i;
assign sbbiu_cyc_o = dcsb_cyc_i;
assign sbbiu_stb_o = dcsb_stb_i;

assign dcsb_ack_o = sbbiu_ack_i;
assign dcsb_err_o = sbbiu_err_i;
assign dcsb_dat_o = sbbiu_dat_i;

`endif

endmodule
