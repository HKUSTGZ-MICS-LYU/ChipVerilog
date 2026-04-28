`include "timescale.v"
`include "or1200_defines.v"

module or1200_freeze(
    clk, rst,
    multicycle, flushpipe, extend_flush,
    lsu_stall, if_stall, lsu_unstall,
    du_stall, mac_stall, force_dslot_fetch, abort_ex,
    genpc_freeze, if_freeze, id_freeze, ex_freeze, wb_freeze,
    icpu_ack_i, icpu_err_i
);

input        clk, rst;
input [1:0]  multicycle;
input        flushpipe;
input        extend_flush;
input        lsu_stall;
input        if_stall;
input        lsu_unstall;
input        du_stall;
input        mac_stall;
input        force_dslot_fetch;
input        abort_ex;
output       genpc_freeze;
output       if_freeze;
output       id_freeze;
output       ex_freeze;
output       wb_freeze;
input        icpu_ack_i;
input        icpu_err_i;

reg [1:0] multicycle_cnt;
reg       flushpipe_r;

wire multicycle_freeze = |multicycle_cnt;

// genpc_freeze
assign genpc_freeze = du_stall | flushpipe_r;

// id_freeze
assign id_freeze = lsu_stall |
                   (~lsu_unstall & if_stall) |
                   multicycle_freeze |
                   force_dslot_fetch |
                   du_stall |
                   mac_stall;

// if_freeze
assign if_freeze = id_freeze | extend_flush;

// wb_freeze
assign wb_freeze = lsu_stall |
                   (~lsu_unstall & if_stall) |
                   multicycle_freeze |
                   du_stall |
                   mac_stall |
                   abort_ex;

// ex_freeze follows wb_freeze
assign ex_freeze = wb_freeze;

// Sequential state
always @(posedge clk or posedge rst) begin
    if (rst) begin
        flushpipe_r    <= 1'b0;
        multicycle_cnt <= 2'b00;
    end else begin
        // flushpipe_r
        if (icpu_ack_i | icpu_err_i)
            flushpipe_r <= flushpipe;
        else if (!flushpipe)
            flushpipe_r <= 1'b0;

        // multicycle_cnt
        if (|multicycle_cnt)
            multicycle_cnt <= multicycle_cnt - 2'd1;
        else if (|multicycle & !ex_freeze)
            multicycle_cnt <= multicycle;
    end
end

endmodule