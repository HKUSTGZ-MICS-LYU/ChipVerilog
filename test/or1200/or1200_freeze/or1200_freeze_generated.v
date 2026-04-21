`include "timescale.v"
`include "or1200_defines.v"

`define OR1200_NO_FREEZE            3'd0
`define OR1200_FREEZE_BYDC          3'd1
`define OR1200_FREEZE_BYMULTICYCLE  3'd2
`define OR1200_WAIT_LSU_TO_FINISH   3'd3
`define OR1200_WAIT_IC              3'd4

module or1200_freeze(
	clk, rst,
	multicycle, flushpipe, extend_flush, lsu_stall, if_stall,
	lsu_unstall, du_stall, mac_stall,
	force_dslot_fetch, abort_ex,
	genpc_freeze, if_freeze, id_freeze, ex_freeze, wb_freeze,
	icpu_ack_i, icpu_err_i
);

input		clk;
input		rst;
input	[1:0]	multicycle;
input		flushpipe;
input		extend_flush;
input		lsu_stall;
input		if_stall;
input		lsu_unstall;
input		force_dslot_fetch;
input		abort_ex;
input		du_stall;
input		mac_stall;
output		genpc_freeze;
output		if_freeze;
output		id_freeze;
output		ex_freeze;
output		wb_freeze;
input		icpu_ack_i;
input		icpu_err_i;

wire		multicycle_freeze;
reg	[1:0]	multicycle_cnt;
reg		flushpipe_r;

// Rule 1: later-stage freeze must not be asserted unless earlier required freezes are also asserted
// Rule 2: ex_freeze/wb_freeze may be deasserted while id_freeze/if_freeze are asserted (NOP insertion)

// genpc_freeze: du_stall or registered flushpipe
assign genpc_freeze = du_stall | flushpipe_r;

// if_freeze: at least as strong as id_freeze; also held during extended flush
assign if_freeze = id_freeze | extend_flush;

// id_freeze: LSU wait, IF stall (without unstall), multicycle, force dslot, du_stall, mac_stall
assign id_freeze = (lsu_stall | (~lsu_unstall & if_stall) | multicycle_freeze | force_dslot_fetch) | du_stall | mac_stall;

// ex_freeze = wb_freeze (execution stage follows writeback stage exactly)
assign ex_freeze = wb_freeze;

// wb_freeze: same as id_freeze core conditions plus abort_ex
assign wb_freeze = (lsu_stall | (~lsu_unstall & if_stall) | multicycle_freeze) | du_stall | mac_stall | abort_ex;

// flushpipe_r: aligned to icpu ack/err; cleared when no active flush
always @(posedge clk or posedge rst)
	if (rst)
		flushpipe_r <= #1 1'b0;
	else if (icpu_ack_i | icpu_err_i)
		flushpipe_r <= #1 flushpipe;
	else if (!flushpipe)
		flushpipe_r <= #1 1'b0;

// multicycle_freeze: active while countdown is nonzero
assign multicycle_freeze = |multicycle_cnt;

// multicycle counter: decrement each cycle; load when new multicycle op starts
always @(posedge clk or posedge rst)
	if (rst)
		multicycle_cnt <= #1 2'b00;
	else if (|multicycle_cnt)
		multicycle_cnt <= #1 multicycle_cnt - 2'd1;
	else if (|multicycle & !ex_freeze)
		multicycle_cnt <= #1 multicycle;

endmodule
