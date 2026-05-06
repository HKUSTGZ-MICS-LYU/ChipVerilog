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
localparam QUEUE_DEPTH = 4;

wire [67:0] fifo_dat_i;
wire [67:0] fifo_dat_o;
wire fifo_wr;
wire fifo_rd;
wire fifo_full;
wire fifo_empty;
wire sel_sb;
reg outstanding_store;
reg fifo_wr_ack;

reg [67:0] issue_data;
reg issue_valid;
reg [67:0] queue_mem [0:QUEUE_DEPTH-1];
reg [1:0] queue_wr_ptr;
reg [1:0] queue_rd_ptr;
reg [2:0] queue_count;

wire buffered_write_req;
wire direct_pass_through;
wire ack_store;
wire enqueue_store;

assign fifo_dat_i = {dcsb_sel_i, dcsb_dat_i, dcsb_adr_i};
assign fifo_dat_o = issue_data;
assign fifo_empty = ~issue_valid;
assign fifo_full = issue_valid & (queue_count == QUEUE_DEPTH[2:0]);
assign buffered_write_req = dcsb_cyc_i & dcsb_stb_i & dcsb_we_i;
assign fifo_wr = buffered_write_req & ~fifo_full & ~fifo_wr_ack;
assign fifo_rd = ~outstanding_store;
assign sel_sb = ~fifo_empty | (fifo_empty & outstanding_store);
assign direct_pass_through = ~sel_sb & ~buffered_write_req;
assign ack_store = sbbiu_ack_i & outstanding_store;
assign enqueue_store = fifo_wr & issue_valid & ~(ack_store & (queue_count == 3'd0));

assign sbbiu_dat_o = sel_sb ? fifo_dat_o[63:32] : dcsb_dat_i;
assign sbbiu_adr_o = sel_sb ? fifo_dat_o[31:0] : dcsb_adr_i;
assign sbbiu_cyc_o = sel_sb ? issue_valid : (direct_pass_through ? dcsb_cyc_i : 1'b0);
assign sbbiu_stb_o = sel_sb ? issue_valid : (direct_pass_through ? dcsb_stb_i : 1'b0);
assign sbbiu_we_o = sel_sb ? 1'b1 : dcsb_we_i;
assign sbbiu_sel_o = sel_sb ? fifo_dat_o[67:64] : dcsb_sel_i;
assign sbbiu_cab_o = sel_sb ? 1'b0 : dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sel_sb ? fifo_wr_ack : sbbiu_ack_i;
assign dcsb_err_o = sel_sb ? 1'b0 : sbbiu_err_i;

always @(posedge clk) begin
    if (rst) begin
        outstanding_store <= 1'b0;
        fifo_wr_ack <= 1'b0;
        issue_data <= 68'd0;
        issue_valid <= 1'b0;
        queue_wr_ptr <= 2'd0;
        queue_rd_ptr <= 2'd0;
        queue_count <= 3'd0;
    end else begin
        fifo_wr_ack <= fifo_wr;

        if (ack_store) begin
            if (queue_count != 3'd0) begin
                issue_data <= queue_mem[queue_rd_ptr];
                issue_valid <= 1'b1;
                queue_rd_ptr <= queue_rd_ptr + 2'd1;
            end else if (!fifo_wr) begin
                issue_valid <= 1'b0;
            end
        end

        if (fifo_wr) begin
            if (!issue_valid || (ack_store & (queue_count == 3'd0))) begin
                issue_data <= fifo_dat_i;
                issue_valid <= 1'b1;
            end else begin
                queue_mem[queue_wr_ptr] <= fifo_dat_i;
                queue_wr_ptr <= queue_wr_ptr + 2'd1;
            end
        end

        case ({ack_store & (queue_count != 3'd0), enqueue_store})
            2'b10: queue_count <= queue_count - 3'd1;
            2'b01: queue_count <= queue_count + 3'd1;
            default: queue_count <= queue_count;
        endcase

        if (sbbiu_ack_i) begin
            outstanding_store <= 1'b0;
        end else if (sel_sb | fifo_wr) begin
            outstanding_store <= 1'b1;
        end
    end
end

`else
assign sbbiu_dat_o = dcsb_dat_i;
assign sbbiu_adr_o = dcsb_adr_i;
assign sbbiu_cyc_o = dcsb_cyc_i;
assign sbbiu_stb_o = dcsb_stb_i;
assign sbbiu_we_o = dcsb_we_i;
assign sbbiu_sel_o = dcsb_sel_i;
assign sbbiu_cab_o = dcsb_cab_i;

assign dcsb_dat_o = sbbiu_dat_i;
assign dcsb_ack_o = sbbiu_ack_i;
assign dcsb_err_o = sbbiu_err_i;
`endif

endmodule
