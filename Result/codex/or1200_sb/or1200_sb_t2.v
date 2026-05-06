module or1200_sb(
    input               clk,
    input               rst,
    input      [31:0]   dcsb_dat_i,
    input      [31:0]   dcsb_adr_i,
    input               dcsb_cyc_i,
    input               dcsb_stb_i,
    input               dcsb_we_i,
    input      [3:0]    dcsb_sel_i,
    input               dcsb_cab_i,
    output     [31:0]   dcsb_dat_o,
    output              dcsb_ack_o,
    output              dcsb_err_o,
    output     [31:0]   sbbiu_dat_o,
    output     [31:0]   sbbiu_adr_o,
    output              sbbiu_cyc_o,
    output              sbbiu_stb_o,
    output              sbbiu_we_o,
    output     [3:0]    sbbiu_sel_o,
    output              sbbiu_cab_o,
    input      [31:0]   sbbiu_dat_i,
    input               sbbiu_ack_i,
    input               sbbiu_err_i
);

`ifdef OR1200_SB_IMPLEMENTED
wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
wire        fifo_wr;
wire        fifo_rd;
wire        fifo_full;
wire        fifo_empty;
wire        sel_sb;
wire        dcsb_passthrough_req;
reg         outstanding_store;
reg         fifo_wr_ack;

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
assign fifo_rd = ~outstanding_store;
assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

always @(posedge clk or posedge rst) begin
    if (rst)
        fifo_wr_ack <= 1'b0;
    else
        fifo_wr_ack <= fifo_wr;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        outstanding_store <= 1'b0;
    else if (sbbiu_ack_i)
        outstanding_store <= 1'b0;
    else if (sel_sb | fifo_wr)
        outstanding_store <= 1'b1;
end

assign dcsb_passthrough_req = dcsb_cyc_i & dcsb_stb_i & ~dcsb_we_i;

assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32] : dcsb_dat_i;
assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0]  : dcsb_adr_i;
assign sbbiu_cyc_o = sel_sb ? 1'b1              : dcsb_passthrough_req;
assign sbbiu_stb_o = sel_sb ? 1'b1              : dcsb_passthrough_req;
assign sbbiu_we_o  = sel_sb ? 1'b1              : dcsb_we_i;
assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64] : dcsb_sel_i;
assign sbbiu_cab_o = sel_sb ? 1'b0              : dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
assign dcsb_err_o = sel_sb ? 1'b0        : sbbiu_err_i;

or1200_sb_fifo #(
    .dw(68),
    .depth(4),
    .aw(2)
) u_sb_fifo (
    .clk     (clk),
    .rst     (rst),
    .data_i  (fifo_dat_i),
    .wr_i    (fifo_wr),
    .rd_i    (fifo_rd),
    .data_o  (fifo_dat_o),
    .full_o  (fifo_full),
    .empty_o (fifo_empty)
);

`else

assign sbbiu_dat_o = dcsb_dat_i;
assign sbbiu_adr_o = dcsb_adr_i;
assign sbbiu_cyc_o = dcsb_cyc_i;
assign sbbiu_stb_o = dcsb_stb_i;
assign sbbiu_we_o  = dcsb_we_i;
assign sbbiu_sel_o = dcsb_sel_i;
assign sbbiu_cab_o = dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sbbiu_ack_i;
assign dcsb_err_o = sbbiu_err_i;

`endif

endmodule

module or1200_sb_fifo
#(
    parameter dw = 68,
    parameter depth = 4,
    parameter aw = 2
)
(
    input               clk,
    input               rst,
    input      [dw-1:0] data_i,
    input               wr_i,
    input               rd_i,
    output reg [dw-1:0] data_o,
    output              full_o,
    output              empty_o
);

reg [dw-1:0] mem [0:depth-1];
reg [aw-1:0] wr_ptr;
reg [aw-1:0] rd_ptr;
reg [aw:0]   count;

wire do_rd_mem;
wire do_rd_bypass;
wire do_wr_mem;

assign empty_o = (count == {aw+1{1'b0}});
assign full_o  = (count == depth[aw:0]);

assign do_rd_mem    = rd_i & ~empty_o;
assign do_rd_bypass = rd_i & empty_o & wr_i;
assign do_wr_mem    = wr_i & (~full_o | do_rd_mem) & ~do_rd_bypass;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr <= {aw{1'b0}};
        rd_ptr <= {aw{1'b0}};
        count  <= {aw+1{1'b0}};
        data_o <= {dw{1'b0}};
    end else begin
        if (do_rd_mem)
            data_o <= mem[rd_ptr];
        else if (do_rd_bypass)
            data_o <= data_i;

        if (do_wr_mem) begin
            mem[wr_ptr] <= data_i;
            wr_ptr <= wr_ptr + {{(aw-1){1'b0}}, 1'b1};
        end

        if (do_rd_mem)
            rd_ptr <= rd_ptr + {{(aw-1){1'b0}}, 1'b1};

        case ({do_wr_mem, do_rd_mem})
            2'b10: count <= count + {{aw{1'b0}}, 1'b1};
            2'b01: count <= count - {{aw{1'b0}}, 1'b1};
            default: count <= count;
        endcase
    end
end

endmodule
