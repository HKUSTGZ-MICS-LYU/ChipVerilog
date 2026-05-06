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

`ifdef OR1200_SB_IMPLEMENTED
    wire [67:0] fifo_dat_i;
    wire [67:0] fifo_dat_o;
    wire fifo_wr;
    wire fifo_rd;
    wire fifo_full;
    wire fifo_empty;
    wire sel_sb;
    reg outstanding_store;
    reg fifo_wr_ack;

    // FIFO data input: {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i}
    assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};

    // FIFO write condition
    assign fifo_wr = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i & ~fifo_full & ~fifo_wr_ack;

    // FIFO read condition: allow fetch when no outstanding store
    assign fifo_rd = ~outstanding_store;

    // Store buffer selection: FIFO not empty or outstanding store pending
    assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);

    // outstanding_store register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            outstanding_store <= 1'b0;
        end else begin
            if (sbbiu_ack_i) begin
                outstanding_store <= 1'b0;
            end else if (sel_sb | fifo_wr) begin
                outstanding_store <= 1'b1;
            end
        end
    end

    // fifo_wr_ack register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fifo_wr_ack <= 1'b0;
        end else begin
            // Assert ack one cycle after successful FIFO write
            if (fifo_wr) begin
                fifo_wr_ack <= 1'b1;
            end else begin
                fifo_wr_ack <= 1'b0;
            end
        end
    end

    // Instantiate the Store Buffer FIFO
    or1200_sb_fifo sb_fifo (
        .clk(clk),
        .rst(rst),
        .fifo_wr(fifo_wr),
        .fifo_rd(fifo_rd),
        .fifo_dat_i(fifo_dat_i),
        .fifo_dat_o(fifo_dat_o),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty)
    );

    // BIU output muxing based on sel_sb
    assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0] : dcsb_adr_i;
    assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32] : dcsb_dat_i;
    assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64] : dcsb_sel_i;
    assign sbbiu_we_o  = sel_sb ? 1'b1 : dcsb_we_i;
    assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;
    assign sbbiu_cyc_o = sel_sb ? ~fifo_empty : dcsb_cyc_i;
    assign sbbiu_stb_o = sel_sb ? ~fifo_empty : dcsb_stb_i;

    // DC-side outputs
    assign dcsb_dat_o = sbbiu_dat_i;
    assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
    assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;

`else
    // Direct pass-through when Store Buffer not implemented
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
