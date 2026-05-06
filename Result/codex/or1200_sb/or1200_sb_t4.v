`include "or1200_defines.v"

module or1200_sb(
    input         clk,
    input         rst,
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
localparam DEPTH = `OR1200_SB_ENTRIES;
reg [31:0] fifo_dat [0:DEPTH-1];
reg [31:0] fifo_adr [0:DEPTH-1];
reg [3:0]  fifo_sel [0:DEPTH-1];
reg [`OR1200_SB_LOG-1:0] wr_ptr, rd_ptr;
reg [`OR1200_SB_LOG:0] count;
reg outstanding_store;
reg fifo_wr_ack;
wire fifo_empty = (count == 0);
wire fifo_full  = (count == DEPTH);
wire fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
wire fifo_rd = ~outstanding_store & ~fifo_empty;
wire sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= 0; rd_ptr <= 0; count <= 0; fifo_wr_ack <= 0; outstanding_store <= 0;
    end else begin
        fifo_wr_ack <= 1'b0;
        if (fifo_wr) begin
            fifo_dat[wr_ptr] <= dcsb_dat_i;
            fifo_adr[wr_ptr] <= dcsb_adr_i;
            fifo_sel[wr_ptr] <= dcsb_sel_i;
            wr_ptr <= wr_ptr + 1'b1;
            count <= count + 1'b1;
            fifo_wr_ack <= 1'b1;
        end
        if (fifo_rd) begin
            outstanding_store <= 1'b1;
        end
        if (sbbiu_ack_i && outstanding_store) begin
            outstanding_store <= 1'b0;
            if (!fifo_empty) begin
                rd_ptr <= rd_ptr + 1'b1;
                count <= count - 1'b1;
            end
        end else if (sel_sb || fifo_wr) begin
            outstanding_store <= 1'b1;
        end
    end
end

assign sbbiu_dat_o = sel_sb ? fifo_dat[rd_ptr] : dcsb_dat_i;
assign sbbiu_adr_o = sel_sb ? fifo_adr[rd_ptr] : dcsb_adr_i;
assign sbbiu_sel_o = sel_sb ? fifo_sel[rd_ptr] : dcsb_sel_i;
assign sbbiu_we_o  = sel_sb ? 1'b1 : dcsb_we_i;
assign sbbiu_cyc_o = sel_sb ? 1'b1 : dcsb_cyc_i;
assign sbbiu_stb_o = sel_sb ? 1'b1 : dcsb_stb_i;
assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;
assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;
`else
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
`endif

endmodule
