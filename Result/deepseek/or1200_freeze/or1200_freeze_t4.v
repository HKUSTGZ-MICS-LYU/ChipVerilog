module or1200_freeze(
    input clk,
    input rst,
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
    input icpu_ack_i,
    input icpu_err_i,
    output genpc_freeze,
    output if_freeze,
    output id_freeze,
    output ex_freeze,
    output wb_freeze
);

    reg [1:0] multicycle_cnt;
    reg flushpipe_r;
    wire multicycle_freeze;

    // multicycle_freeze is asserted when counter is non-zero
    assign multicycle_freeze = |multicycle_cnt;

    // Sequential logic for flushpipe_r and multicycle_cnt
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flushpipe_r <= 1'b0;
            multicycle_cnt <= 2'b00;
        end else begin
            // flushpipe_r update
            if (icpu_ack_i || icpu_err_i) begin
                flushpipe_r <= flushpipe;
            end else if (~flushpipe) begin
                flushpipe_r <= 1'b0;
            end
            // else retain

            // multicycle_cnt update
            if (|multicycle_cnt) begin
                multicycle_cnt <= multicycle_cnt - 1'b1;
            end else if (|multicycle && ~ex_freeze) begin
                multicycle_cnt <= multicycle;
            end
        end
    end

    // Combinational freeze outputs
    assign genpc_freeze = du_stall || flushpipe_r;

    assign id_freeze = lsu_stall || (~lsu_unstall & if_stall) || multicycle_freeze ||
                       force_dslot_fetch || du_stall || mac_stall;

    assign if_freeze = id_freeze || extend_flush;

    assign wb_freeze = lsu_stall || (~lsu_unstall & if_stall) || multicycle_freeze ||
                       du_stall || mac_stall || abort_ex;

    assign ex_freeze = wb_freeze;

endmodule
