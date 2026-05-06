`include "or1200_defines.v"


module or1200_except(
    input clk,
    input rst,
    input sig_ibuserr,
    input sig_dbuserr,
    input sig_illegal,
    input sig_align,
    input sig_range,
    input sig_dtlbmiss,
    input sig_dmmufault,
    input sig_int,
    input sig_syscall,
    input sig_trap,
    input sig_itlbmiss,
    input sig_immufault,
    input sig_tick,
    input branch_taken,
    input genpc_freeze,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input if_stall,
    input [31:0] if_pc,
    output reg [31:0] id_pc,
    output [31:2] lr_sav,
    output flushpipe,
    output reg extend_flush,
    output reg [3:0] except_type,
    output except_start,
    output except_started,
    output [12:0] except_stop,
    input ex_void,
    output [31:0] spr_dat_ppc,
    output [31:0] spr_dat_npc,
    input [31:0] datain,
    input [13:0] du_dsr,
    input epcr_we,
    input eear_we,
    input esr_we,
    input pc_we,
    output reg [31:0] epcr,
    output reg [31:0] eear,
    output reg [15:0] esr,
    input sr_we,
    input [15:0] to_sr,
    input [15:0] sr,
    input [31:0] lsu_addr,
    output abort_ex,
    input icpu_ack_i,
    input icpu_err_i,
    input dcpu_ack_i,
    input dcpu_err_i
);
reg [31:0] ex_pc, wb_pc;
reg [2:0] id_exceptflags, ex_exceptflags;
reg ex_dslot, delayed1_ex_dslot, delayed2_ex_dslot;
reg [2:0] state;
reg [2:0] delayed_iee, delayed_tee;
localparam FLU_IDLE=3'd0, FLU1=3'd1, FLU2=3'd2, FLU3=3'd3, FLU4=3'd4, FLU5=3'd5;
wire int_pending = sig_int & sr[`OR1200_SR_IEE] & delayed_iee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
wire tick_pending = sig_tick & sr[`OR1200_SR_TEE] & delayed_tee[2] & ~ex_freeze & ~branch_taken & ~ex_dslot & ~sr_we;
wire [12:0] raw_except = {sig_trap & ~ex_freeze, sig_syscall & ~ex_freeze, sig_range, sig_dbuserr, sig_dmmufault, sig_dtlbmiss, sig_align, sig_illegal, sig_ibuserr|ex_exceptflags[2], sig_itlbmiss|ex_exceptflags[1], sig_immufault|ex_exceptflags[0], int_pending, tick_pending};
assign except_stop = raw_except & du_dsr[12:0];
wire any_except = |raw_except;
wire except_flushpipe = any_except && (state==FLU_IDLE);
assign flushpipe = except_flushpipe | pc_we | extend_flush;
assign except_start = (except_type != `OR1200_EXCEPT_NONE) & extend_flush;
assign except_started = except_start & extend_flush;
assign spr_dat_ppc = wb_pc;
assign spr_dat_npc = ex_void ? id_pc : ex_pc;
assign lr_sav = ex_pc[31:2];
assign abort_ex = sig_dbuserr | sig_dmmufault | sig_dtlbmiss | sig_align | sig_illegal;
function [3:0] choose_except;
input [12:0] v;
begin
    if (v[0]) choose_except = `OR1200_EXCEPT_TICK;
    else if (v[1]) choose_except = `OR1200_EXCEPT_INT;
    else if (v[2]) choose_except = `OR1200_EXCEPT_IPF;
    else if (v[3]) choose_except = `OR1200_EXCEPT_ITLBMISS;
    else if (v[4]) choose_except = `OR1200_EXCEPT_BUSERR;
    else if (v[5]) choose_except = `OR1200_EXCEPT_ILLEGAL;
    else if (v[6]) choose_except = `OR1200_EXCEPT_ALIGN;
    else if (v[7]) choose_except = `OR1200_EXCEPT_DTLBMISS;
    else if (v[8]) choose_except = `OR1200_EXCEPT_DPF;
    else if (v[9]) choose_except = `OR1200_EXCEPT_BUSERR;
    else if (v[10]) choose_except = `OR1200_EXCEPT_RANGE;
    else if (v[11]) choose_except = `OR1200_EXCEPT_TRAP;
    else if (v[12]) choose_except = `OR1200_EXCEPT_SYSCALL;
    else choose_except = `OR1200_EXCEPT_NONE;
end endfunction
always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_pc <= 0; ex_pc <= 0; wb_pc <= 0; id_exceptflags <= 0; ex_exceptflags <= 0; ex_dslot <= 0; delayed1_ex_dslot <= 0; delayed2_ex_dslot <= 0;
        state <= FLU_IDLE; extend_flush <= 0; except_type <= `OR1200_EXCEPT_NONE; epcr <= 0; eear <= 0; esr <= 16'h8000; delayed_iee <= 0; delayed_tee <= 0;
    end else begin
        delayed_iee <= {delayed_iee[1:0], sr[`OR1200_SR_IEE]};
        delayed_tee <= {delayed_tee[1:0], sr[`OR1200_SR_TEE]};
        if (!id_freeze) begin id_pc <= if_pc; id_exceptflags <= {sig_ibuserr,sig_itlbmiss,sig_immufault}; end
        if (flushpipe) begin id_exceptflags <= 0; ex_exceptflags <= 0; end
        if (!ex_freeze) begin ex_pc <= id_pc; ex_exceptflags <= id_exceptflags; ex_dslot <= branch_taken; end
        if (!wb_freeze) begin wb_pc <= ex_pc; delayed1_ex_dslot <= ex_dslot; delayed2_ex_dslot <= delayed1_ex_dslot; end
        if (epcr_we) epcr <= datain;
        if (eear_we) eear <= datain;
        if (esr_we) esr <= {1'b1, datain[14:0]};
        case (state)
            FLU_IDLE: begin
                extend_flush <= 1'b0;
                if (except_flushpipe) begin
                    except_type <= choose_except(raw_except);
                    esr <= sr_we ? to_sr : sr;
                    epcr <= delayed2_ex_dslot ? wb_pc : ex_pc;
                    if (sig_itlbmiss || sig_immufault || sig_ibuserr) eear <= if_pc;
                    else if (sig_dtlbmiss || sig_dmmufault || sig_dbuserr || sig_align) eear <= lsu_addr;
                    state <= FLU1;
                    extend_flush <= 1'b1;
                end else begin
                    except_type <= `OR1200_EXCEPT_NONE;
                end
            end
            FLU1: begin extend_flush <= 1'b1; state <= FLU2; end
            FLU2: begin extend_flush <= 1'b1; state <= FLU3; end
            FLU3: begin extend_flush <= 1'b1; state <= FLU4; end
            FLU4: begin extend_flush <= 1'b1; state <= FLU5; end
            FLU5: begin
                extend_flush <= 1'b1;
                if (!if_stall && !id_freeze) begin state <= FLU_IDLE; extend_flush <= 1'b0; except_type <= `OR1200_EXCEPT_NONE; end
            end
        endcase
    end
end
endmodule
