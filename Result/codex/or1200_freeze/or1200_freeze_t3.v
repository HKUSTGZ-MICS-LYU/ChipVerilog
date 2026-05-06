// Generated from or1200_freeze/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_freeze(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
    input [1:0] multicycle,
    input flushpipe,
    input extend_flush,
    input lsu_stall,
    input if_stall,
    input lsu_unstall,
    input du_stall,
    input mac_stall,
    input force_dslot_fetch,
    input abort_ex,
    output genpc_freeze,
    output if_freeze,
    output id_freeze,
    output ex_freeze,
    output wb_freeze,
    input icpu_ack_i,
    input icpu_err_i
);

reg genpc_freeze_r;
reg if_freeze_r;
reg id_freeze_r;
reg ex_freeze_r;
reg wb_freeze_r;
assign genpc_freeze = genpc_freeze_r;
assign if_freeze = if_freeze_r;
assign id_freeze = id_freeze_r;
assign ex_freeze = ex_freeze_r;
assign wb_freeze = wb_freeze_r;

reg [1:0] multicycle_cnt;
reg flushpipe_r_reg;
wire multicycle_freeze = |multicycle_cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        multicycle_cnt <= 2'd0;
        flushpipe_r_reg <= 1'b0;
    end else begin
        if (icpu_ack_i || icpu_err_i)
            flushpipe_r_reg <= flushpipe;
        else if (!flushpipe)
            flushpipe_r_reg <= 1'b0;
        if (multicycle_cnt != 0)
            multicycle_cnt <= multicycle_cnt - 1'b1;
        else if ((multicycle != 0) && !wb_freeze_r)
            multicycle_cnt <= multicycle;
    end
end

always @* begin
    genpc_freeze_r = du_stall | flushpipe_r_reg;
    id_freeze_r = lsu_stall | ((if_stall) & !lsu_unstall) | multicycle_freeze | force_dslot_fetch | du_stall | mac_stall;
    if_freeze_r = id_freeze_r | extend_flush;
    wb_freeze_r = id_freeze_r | abort_ex;
    ex_freeze_r = wb_freeze_r;
end

endmodule
