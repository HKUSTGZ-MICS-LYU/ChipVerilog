module or1200_freeze(
    input         clk,
    input         rst,
    input  [1:0]  multicycle,
    input         flushpipe,
    input         extend_flush,
    input         lsu_stall,
    input         if_stall,
    input         lsu_unstall,
    input         du_stall,
    input         mac_stall,
    input         force_dslot_fetch,
    input         abort_ex,
    output        genpc_freeze,
    output        if_freeze,
    output        id_freeze,
    output        ex_freeze,
    output        wb_freeze,
    input         icpu_ack_i,
    input         icpu_err_i
);

reg        flushpipe_r;
reg [1:0]  multicycle_cnt;
wire       multicycle_freeze;

assign multicycle_freeze = |multicycle_cnt;

always @(posedge clk or posedge rst) begin
    if (rst)
        flushpipe_r <= 1'b0;
    else if (icpu_ack_i | icpu_err_i)
        flushpipe_r <= flushpipe;
    else if (!flushpipe)
        flushpipe_r <= 1'b0;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        multicycle_cnt <= 2'b00;
    else if (|multicycle_cnt)
        multicycle_cnt <= multicycle_cnt - 2'd1;
    else if ((|multicycle) & !ex_freeze)
        multicycle_cnt <= multicycle;
end

assign genpc_freeze = du_stall | flushpipe_r;

assign id_freeze = lsu_stall
                 | (~lsu_unstall & if_stall)
                 | multicycle_freeze
                 | force_dslot_fetch
                 | du_stall
                 | mac_stall;

assign if_freeze = id_freeze | extend_flush;

assign wb_freeze = lsu_stall
                 | (~lsu_unstall & if_stall)
                 | multicycle_freeze
                 | du_stall
                 | mac_stall
                 | abort_ex;

assign ex_freeze = wb_freeze;

endmodule
