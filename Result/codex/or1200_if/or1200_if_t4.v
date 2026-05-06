// Generated from or1200_if/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_if(
    // Clock and reset
    input clk,
    input rst,

    // External i/f to IC
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,

    // Internal i/f
    input if_freeze,
    output [31:0] if_insn,
    output [31:0] if_pc,
    input flushpipe,
    output if_stall,
    input no_more_dslot,
    output genpc_refetch,
    input rfe,
    output except_itlbmiss,
    output except_immufault,
    output except_ibuserr
);

reg [31:0] if_insn_r;
reg [31:0] if_pc_r;
reg if_stall_r;
reg genpc_refetch_r;
reg except_itlbmiss_r;
reg except_immufault_r;
reg except_ibuserr_r;
assign if_insn = if_insn_r;
assign if_pc = if_pc_r;
assign if_stall = if_stall_r;
assign genpc_refetch = genpc_refetch_r;
assign except_itlbmiss = except_itlbmiss_r;
assign except_immufault = except_immufault_r;
assign except_ibuserr = except_ibuserr_r;

reg [31:0] insn_saved;
reg [31:0] addr_saved;
reg saved;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        insn_saved <= 32'h1500_0000;
        addr_saved <= 32'd0;
        saved <= 1'b0;
    end else if (flushpipe) begin
        insn_saved <= 32'h1500_0000;
        addr_saved <= 32'd0;
        saved <= 1'b0;
    end else if (if_freeze && icpu_ack_i && !saved) begin
        insn_saved <= icpu_dat_i;
        addr_saved <= icpu_adr_i;
        saved <= 1'b1;
    end else if (!if_freeze) begin
        saved <= 1'b0;
    end
end

always @* begin
    if_insn_r = 32'h1500_0000;
    if_pc_r = saved ? addr_saved : icpu_adr_i;
    if_stall_r = !icpu_err_i && !icpu_ack_i && !saved;
    genpc_refetch_r = saved && icpu_ack_i;
    except_itlbmiss_r = icpu_err_i && (icpu_tag_i[0]) && !no_more_dslot;
    except_immufault_r = icpu_err_i && (icpu_tag_i[1]) && !no_more_dslot;
    except_ibuserr_r = icpu_err_i && !(|icpu_tag_i[1:0]) && !no_more_dslot;
    if (icpu_err_i || no_more_dslot || rfe)
        if_insn_r = 32'h1500_0000;
    else if (saved)
        if_insn_r = insn_saved;
    else if (icpu_ack_i)
        if_insn_r = icpu_dat_i;
end

endmodule
