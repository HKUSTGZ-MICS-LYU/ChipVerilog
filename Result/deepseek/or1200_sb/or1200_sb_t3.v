module or1200_sb (
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

// Internal signals
wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
wire sel_sb;
reg outstanding_store;
reg fifo_wr_ack;

// Combinational assignments
assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

`ifdef OR1200_SB_IMPLEMENTED
    // FIFO control
    assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;
    assign fifo_rd = ~outstanding_store;

    // Path selection
    assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

    // Outstanding store register
    always @(posedge clk or posedge rst) begin
        if (rst)
            outstanding_store <= 1'b0;
        else if (sbbiu_ack_i)
            outstanding_store <= 1'b0;
        else if (sel_sb | fifo_wr)
            outstanding_store <= 1'b1;
        else
            outstanding_store <= outstanding_store;
    end

    // FIFO write acknowledge
    always @(posedge clk or posedge rst) begin
        if (rst)
            fifo_wr_ack <= 1'b0;
        else
            fifo_wr_ack <= fifo_wr;
    end

    // DC side outputs
    assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
    assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;
    assign dcsb_dat_o = sbbiu_dat_i;

    // BIU side outputs
    assign sbbiu_cyc_o = sel_sb ? 1'b1 : dcsb_cyc_i;
    assign sbbiu_stb_o = sel_sb ? (~outstanding_store) : dcsb_stb_i;
    assign sbbiu_we_o = sel_sb ? 1'b1 : dcsb_we_i;
    assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0] : dcsb_adr_i;
    assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32] : dcsb_dat_i;
    assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64] : dcsb_sel_i;
    assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;

    // Store buffer FIFO instantiation
    or1200_sb_fifo #(
        .DATA_WIDTH(68),
        .ADDR_WIDTH(3)
    ) sb_fifo_inst (
        .clk(clk),
        .rst(rst),
        .dat_i(fifo_dat_i),
        .dat_o(fifo_dat_o),
        .wr(fifo_wr),
        .rd(fifo_rd),
        .full(fifo_full),
        .empty(fifo_empty)
    );

`else
    // OR1200_SB_IMPLEMENTED not defined - direct pass through
    assign dcsb_dat_o = sbbiu_dat_i;
    assign dcsb_ack_o = sbbiu_ack_i;
    assign dcsb_err_o = sbbiu_err_i;
    assign sbbiu_dat_o = dcsb_dat_i;
    assign sbbiu_adr_o = dcsb_adr_i;
    assign sbbiu_cyc_o = dcsb_cyc_i;
    assign sbbiu_stb_o = dcsb_stb_i;
    assign sbbiu_we_o = dcsb_we_i;
    assign sbbiu_sel_o = dcsb_sel_i;
    assign sbbiu_cab_o = dcsb_cab_i;

    // Tie unused signals to avoid latches
    assign fifo_wr = 1'b0;
    assign fifo_rd = 1'b0;
    assign fifo_dat_i = 68'b0;
    assign sel_sb = 1'b0;
    // FIFO not instantiated, so full and empty are not used
    // outstanding_store and fifo_wr_ack not used
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            outstanding_store <= 1'b0;
            fifo_wr_ack <= 1'b0;
        end else begin
            outstanding_store <= 1'b0;
            fifo_wr_ack <= 1'b0;
        end
    end
`endif

endmodule
