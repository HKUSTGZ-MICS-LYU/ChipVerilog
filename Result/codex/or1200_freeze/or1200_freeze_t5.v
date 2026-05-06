module or1200_freeze(
    clk,
    rst,
    multicycle,
    flushpipe,
    extend_flush,
    lsu_stall,
    if_stall,
    lsu_unstall,
    du_stall,
    mac_stall,
    force_dslot_fetch,
    abort_ex,
    genpc_freeze,
    if_freeze,
    id_freeze,
    ex_freeze,
    wb_freeze,
    icpu_ack_i,
    icpu_err_i
);

input clk;
input rst;
input [1:0] multicycle;
input flushpipe;
input extend_flush;
input lsu_stall;
input if_stall;
input lsu_unstall;
input du_stall;
input mac_stall;
input force_dslot_fetch;
input abort_ex;
input icpu_ack_i;
input icpu_err_i;
output genpc_freeze;
output if_freeze;
output id_freeze;
output ex_freeze;
output wb_freeze;

reg flushpipe_r;
reg [1:0] multicycle_cnt;
wire multicycle_freeze;

assign multicycle_freeze = |multicycle_cnt;

assign genpc_freeze = du_stall | flushpipe_r;
assign id_freeze = lsu_stall | (~lsu_unstall & if_stall) | multicycle_freeze |
                   force_dslot_fetch | du_stall | mac_stall;
assign if_freeze = id_freeze | extend_flush;
assign wb_freeze = lsu_stall | (~lsu_unstall & if_stall) | multicycle_freeze |
                   du_stall | mac_stall | abort_ex;
assign ex_freeze = wb_freeze;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        flushpipe_r <= 1'b0;
        multicycle_cnt <= 2'b00;
    end
    else begin
        if (icpu_ack_i | icpu_err_i)
            flushpipe_r <= flushpipe;
        else if (!flushpipe)
            flushpipe_r <= 1'b0;

        if (|multicycle_cnt)
            multicycle_cnt <= multicycle_cnt - 2'b01;
        else if ((|multicycle) & !ex_freeze)
            multicycle_cnt <= multicycle;
    end
end

endmodule
