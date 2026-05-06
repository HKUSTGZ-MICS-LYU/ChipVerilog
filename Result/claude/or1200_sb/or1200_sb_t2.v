module or1200_sb(
    input clk,
    input rst,

    input [31:0] dcsb_dat_i,
    input [31:0] dcsb_adr_i,
    input dcsb_cyc_i,
    input dcsb_stb_i,
    input dcsb_we_i,
    input [3:0] dcsb_sel_i,
    input dcsb_cab_i,
    output [31:0] dcsb_dat_o,
    output dcsb_ack_o,
    output dcsb_err_o,

    output [31:0] sbbiu_dat_o,
    output [31:0] sbbiu_adr_o,
    output sbbiu_cyc_o,
    output sbbiu_stb_o,
    output sbbiu_we_o,
    output [3:0] sbbiu_sel_o,
    output sbbiu_cab_o,
    input [31:0] sbbiu_dat_i,
    input sbbiu_ack_i,
    input sbbiu_err_i
);

parameter BUFFER_ENABLED = 1;

reg [67:0] fifo_mem[0:3];
reg [1:0] fifo_wptr;
reg [1:0] fifo_rptr;
reg [2:0] fifo_count;

wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
wire sel_sb;
reg outstanding_store;
reg fifo_wr_ack;

assign fifo_empty = (fifo_count == 3'b0);
assign fifo_full = (fifo_count == 3'b100);

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
assign fifo_dat_o = fifo_mem[fifo_rptr];

wire is_write = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i;
wire write_request = is_write & ~fifo_full;

assign fifo_wr = BUFFER_ENABLED & write_request & ~fifo_wr_ack;

assign fifo_rd = BUFFER_ENABLED & ~outstanding_store & ~fifo_empty;

assign sel_sb = BUFFER_ENABLED & (~fifo_empty | (fifo_empty & outstanding_store));

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fifo_wptr <= 2'b00;
        fifo_rptr <= 2'b00;
        fifo_count <= 3'b000;
    end else begin
        if (fifo_wr && !fifo_rd) begin
            fifo_mem[fifo_wptr] <= fifo_dat_i;
            fifo_wptr <= fifo_wptr + 1'b1;
            fifo_count <= fifo_count + 1'b1;
        end else if (fifo_rd && !fifo_wr) begin
            fifo_rptr <= fifo_rptr + 1'b1;
            fifo_count <= fifo_count - 1'b1;
        end else if (fifo_wr && fifo_rd) begin
            fifo_mem[fifo_wptr] <= fifo_dat_i;
            fifo_wptr <= fifo_wptr + 1'b1;
            fifo_rptr <= fifo_rptr + 1'b1;
        end
    end
end

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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        fifo_wr_ack <= 1'b0;
    end else begin
        fifo_wr_ack <= fifo_wr;
    end
end

wire [31:0] fifo_adr = fifo_dat_o[31:0];
wire [31:0] fifo_dat = fifo_dat_o[63:32];
wire [3:0] fifo_sel = fifo_dat_o[67:64];

wire [31:0] sb_adr = sel_sb ? fifo_adr : dcsb_adr_i;
wire [31:0] sb_dat = sel_sb ? fifo_dat : dcsb_dat_i;
wire [3:0] sb_sel = sel_sb ? fifo_sel : dcsb_sel_i;

assign sbbiu_adr_o = BUFFER_ENABLED ? sb_adr : dcsb_adr_i;
assign sbbiu_dat_o = BUFFER_ENABLED ? sb_dat : dcsb_dat_i;
assign sbbiu_sel_o = BUFFER_ENABLED ? sb_sel : dcsb_sel_i;
assign sbbiu_cyc_o = BUFFER_ENABLED ? (sel_sb ? 1'b1 : dcsb_cyc_i) : dcsb_cyc_i;
assign sbbiu_stb_o = BUFFER_ENABLED ? (sel_sb ? 1'b1 : dcsb_stb_i) : dcsb_stb_i;
assign sbbiu_we_o = BUFFER_ENABLED ? (sel_sb ? 1'b1 : dcsb_we_i) : dcsb_we_i;
assign sbbiu_cab_o = BUFFER_ENABLED ? (sel_sb ? 1'b0 : dcsb_cab_i) : dcsb_cab_i;

assign dcsb_dat_o = BUFFER_ENABLED ? (sel_sb ? 32'b0 : sbbiu_dat_i) : sbbiu_dat_i;
assign dcsb_ack_o = BUFFER_ENABLED ? (sel_sb ? fifo_wr_ack : sbbiu_ack_i) : sbbiu_ack_i;
assign dcsb_err_o = BUFFER_ENABLED ? (sel_sb ? 1'b0 : sbbiu_err_i) : sbbiu_err_i;

endmodule
