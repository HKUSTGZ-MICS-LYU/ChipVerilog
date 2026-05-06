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

reg [1:0] multicycle_cnt;
reg flushpipe_r;

wire multicycle_freeze;

// Multicycle freeze: active when multicycle_cnt is non-zero
assign multicycle_freeze = (multicycle_cnt != 2'b00);

// genpc_freeze: Prevents PC advancement based on debug stall or registered flush request
assign genpc_freeze = du_stall | flushpipe_r;

// id_freeze: Conditions that cause decode stage to freeze
// LSU waits, instruction fetch waits with LSU not yet unstalled, multicycle operation,
// delay slot forced fetch, debug shutdown, or MAC stall
assign id_freeze = lsu_stall | 
                   (if_stall & ~lsu_unstall) | 
                   multicycle_freeze | 
                   force_dslot_fetch | 
                   du_stall | 
                   mac_stall;

// if_freeze: Fetch stage freeze triggered by decode freeze or extended flush
assign if_freeze = id_freeze | extend_flush;

// wb_freeze: Writeback stage has same main conditions as id_freeze, plus abort_ex priority
assign wb_freeze = lsu_stall | 
                   (if_stall & ~lsu_unstall) | 
                   multicycle_freeze | 
                   force_dslot_fetch | 
                   du_stall | 
                   mac_stall | 
                   abort_ex;

// ex_freeze: Execute stage freeze directly follows writeback freeze
assign ex_freeze = wb_freeze;

// Sequential logic for multicycle_cnt
always @(posedge clk or negedge rst) begin
    if (~rst) begin
        multicycle_cnt <= 2'b00;
    end else begin
        if (multicycle_cnt != 2'b00) begin
            // Decrement multicycle counter when active
            multicycle_cnt <= multicycle_cnt - 1;
        end else if ((multicycle != 2'b00) & ~id_freeze) begin
            // Load new multicycle count when counter is zero, multicycle is requested, and id is not frozen
            multicycle_cnt <= multicycle;
        end
    end
end

// Sequential logic for flushpipe_r
always @(posedge clk or negedge rst) begin
    if (~rst) begin
        flushpipe_r <= 1'b0;
    end else begin
        if (icpu_ack_i | icpu_err_i) begin
            // Latch flushpipe on instruction fetch completion or error
            flushpipe_r <= flushpipe;
        end else begin
            // Clear flushpipe_r on subsequent clocks if no new request
            flushpipe_r <= 1'b0;
        end
    end
end

endmodule
