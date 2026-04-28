`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_freeze (
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

    //--------------------------------------------------------------------------
    // Internal state
    //--------------------------------------------------------------------------
    reg        flushpipe_r;
    reg [1:0]  multicycle_cnt;

    wire multicycle_freeze = |multicycle_cnt;

    //--------------------------------------------------------------------------
    // Sequential: flushpipe_r and multicycle_cnt
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            flushpipe_r    <= 1'b0;
            multicycle_cnt <= 2'h0;
        end else begin
            // flushpipe_r: sample flushpipe on icpu ack/err, else clear if no flush
            if (icpu_ack_i | icpu_err_i)
                flushpipe_r <= flushpipe;
            else if (!flushpipe)
                flushpipe_r <= 1'b0;

            // multicycle_cnt: decrement if nonzero, load if zero and not ex_freeze
            if (multicycle_cnt != 2'h0)
                multicycle_cnt <= multicycle_cnt - 2'h1;
            else if ((multicycle != 2'h0) && !ex_freeze)
                multicycle_cnt <= multicycle;
        end
    end

    //--------------------------------------------------------------------------
    // Combinational freeze outputs
    //--------------------------------------------------------------------------

    // genpc_freeze: du_stall or registered flush
    assign genpc_freeze = du_stall | flushpipe_r;

    // wb_freeze / ex_freeze: LSU stall, if_stall (not unstalled), multicycle,
    //                        du_stall, mac_stall, abort_ex
    assign wb_freeze = lsu_stall | (~lsu_unstall & if_stall) |
                       multicycle_freeze | du_stall | mac_stall | abort_ex;

    // ex_freeze directly follows wb_freeze
    assign ex_freeze = wb_freeze;

    // id_freeze: same as wb_freeze conditions minus abort_ex, plus force_dslot_fetch
    assign id_freeze = lsu_stall | (~lsu_unstall & if_stall) |
                       multicycle_freeze | force_dslot_fetch |
                       du_stall | mac_stall;

    // if_freeze: id_freeze or extend_flush
    assign if_freeze = id_freeze | extend_flush;

endmodule