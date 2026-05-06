module or1200_sb(
    input              clk,
    input              rst,
    input      [31:0]  dcsb_dat_i,
    input      [31:0]  dcsb_adr_i,
    input              dcsb_cyc_i,
    input              dcsb_stb_i,
    input              dcsb_we_i,
    input      [3:0]   dcsb_sel_i,
    input              dcsb_cab_i,
    output     [31:0]  dcsb_dat_o,
    output             dcsb_ack_o,
    output             dcsb_err_o,
    output     [31:0]  sbbiu_dat_o,
    output     [31:0]  sbbiu_adr_o,
    output             sbbiu_cyc_o,
    output             sbbiu_stb_o,
    output             sbbiu_we_o,
    output     [3:0]   sbbiu_sel_o,
    output             sbbiu_cab_o,
    input      [31:0]  sbbiu_dat_i,
    input              sbbiu_ack_i,
    input              sbbiu_err_i
);

`ifdef OR1200_SB_IMPLEMENTED
wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
wire        fifo_wr;
wire        fifo_rd;
wire        fifo_full;
wire        fifo_empty;
wire        sel_sb;
reg         outstanding_store;
reg         fifo_wr_ack;

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
assign fifo_wr    = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
assign fifo_rd    = ~outstanding_store;
assign sel_sb     = ~fifo_empty | (fifo_empty & outstanding_store);

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

or1200_sb_fifo u_or1200_sb_fifo (
    .clk   (clk),
    .rst   (rst),
    .dat_i (fifo_dat_i),
    .dat_o (fifo_dat_o),
    .wr    (fifo_wr),
    .rd    (fifo_rd),
    .full  (fifo_full),
    .empty (fifo_empty)
);

assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0]   : dcsb_adr_i;
assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32]  : dcsb_dat_i;
assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64]  : dcsb_sel_i;
assign sbbiu_cyc_o = sel_sb ? 1'b1               : dcsb_cyc_i;
assign sbbiu_stb_o = sel_sb ? 1'b1               : dcsb_stb_i;
assign sbbiu_we_o  = sel_sb ? 1'b1               : dcsb_we_i;
assign sbbiu_cab_o = sel_sb ? 1'b0               : dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;

`else

assign sbbiu_adr_o = dcsb_adr_i;
assign sbbiu_dat_o = dcsb_dat_i;
assign sbbiu_sel_o = dcsb_sel_i;
assign sbbiu_cyc_o = dcsb_cyc_i;
assign sbbiu_stb_o = dcsb_stb_i;
assign sbbiu_we_o  = dcsb_we_i;
assign sbbiu_cab_o = dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sbbiu_ack_i;
assign dcsb_err_o = sbbiu_err_i;

`endif

endmodule

`ifdef OR1200_SB_IMPLEMENTED
module or1200_sb_fifo (
    input             clk,
    input             rst,
    input      [67:0] dat_i,
    output     [67:0] dat_o,
    input             wr,
    input             rd,
    output            full,
    output            empty
);

reg [67:0] mem [0:3];
reg [67:0] last_dat;
reg [1:0]  wr_ptr;
reg [1:0]  rd_ptr;
reg [2:0]  count;

wire do_wr;
wire do_rd;

assign full  = (count == 3'd4);
assign empty = (count == 3'd0);
assign do_wr = wr & ~full;
assign do_rd = rd & ~empty;
assign dat_o = empty ? last_dat : mem[rd_ptr];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wr_ptr   <= 2'b00;
        rd_ptr   <= 2'b00;
        count    <= 3'b000;
        last_dat <= 68'b0;
    end else begin
        case ({do_wr, do_rd})
            2'b10: begin
                mem[wr_ptr] <= dat_i;
                wr_ptr      <= wr_ptr + 2'b01;
                count       <= count + 3'b001;
            end
            2'b01: begin
                last_dat <= mem[rd_ptr];
                rd_ptr   <= rd_ptr + 2'b01;
                count    <= count - 3'b001;
            end
            2'b11: begin
                mem[wr_ptr] <= dat_i;
                last_dat    <= mem[rd_ptr];
                wr_ptr      <= wr_ptr + 2'b01;
                rd_ptr      <= rd_ptr + 2'b01;
            end
            default: begin
            end
        endcase
    end
end

endmodule
`endif
