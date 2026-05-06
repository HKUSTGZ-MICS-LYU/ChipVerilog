// Generated from or1200_except/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_except(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
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
    output [31:0] id_pc,
    output [31:2] lr_sav,
    output flushpipe,
    output extend_flush,
    output [3:0] except_type,
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
    output [31:0] epcr,
    output [31:0] eear,
    output [15:0] esr,
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

reg [31:0] id_pc_r;
reg [31:2] lr_sav_r;
reg flushpipe_r;
reg extend_flush_r;
reg [3:0] except_type_r;
reg except_start_r;
reg except_started_r;
reg [12:0] except_stop_r;
reg [31:0] spr_dat_ppc_r;
reg [31:0] spr_dat_npc_r;
reg [31:0] epcr_r;
reg [31:0] eear_r;
reg [15:0] esr_r;
reg abort_ex_r;
assign id_pc = id_pc_r;
assign lr_sav = lr_sav_r;
assign flushpipe = flushpipe_r;
assign extend_flush = extend_flush_r;
assign except_type = except_type_r;
assign except_start = except_start_r;
assign except_started = except_started_r;
assign except_stop = except_stop_r;
assign spr_dat_ppc = spr_dat_ppc_r;
assign spr_dat_npc = spr_dat_npc_r;
assign epcr = epcr_r;
assign eear = eear_r;
assign esr = esr_r;
assign abort_ex = abort_ex_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_pc_r <= 0;
        lr_sav_r <= 0;
        flushpipe_r <= 0;
        extend_flush_r <= 0;
        except_type_r <= 0;
        except_start_r <= 0;
        except_started_r <= 0;
        except_stop_r <= 0;
        spr_dat_ppc_r <= 0;
        spr_dat_npc_r <= 0;
        epcr_r <= 0;
        eear_r <= 0;
        esr_r <= 0;
        abort_ex_r <= 0;
    end else begin

    end
end

endmodule
