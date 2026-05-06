module or1200_if(
    input clk,
    input rst,

    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,

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

reg [31:0] insn_saved;
reg [31:0] addr_saved;
reg saved;

wire nop_error;
wire nop_default;

assign nop_error = 32'h15000000;
assign nop_default = 32'h15000000;

wire should_output_error_nop;
wire should_use_saved;
wire should_use_current;
wire should_output_default_nop;

assign should_output_error_nop = icpu_err_i | no_more_dslot | rfe;
assign should_use_saved = saved & ~should_output_error_nop;
assign should_use_current = icpu_ack_i & ~should_output_error_nop & ~saved;
assign should_output_default_nop = ~should_output_error_nop & ~saved & ~icpu_ack_i;

assign if_insn = should_output_error_nop ? nop_error :
                 should_use_saved ? insn_saved :
                 should_use_current ? icpu_dat_i :
                 nop_default;

assign if_pc = saved ? addr_saved : icpu_adr_i;

assign if_stall = ~icpu_err_i & ~icpu_ack_i & ~saved;

assign genpc_refetch = saved & icpu_ack_i;

assign except_itlbmiss = icpu_err_i & ~no_more_dslot & (icpu_tag_i == 4'h1);
assign except_immufault = icpu_err_i & ~no_more_dslot & (icpu_tag_i == 4'h2);
assign except_ibuserr = icpu_err_i & ~no_more_dslot & (icpu_tag_i == 4'h3);

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        saved <= 1'b0;
        insn_saved <= 32'h15000000;
        addr_saved <= 32'h0;
    end else if (flushpipe) begin
        saved <= 1'b0;
        insn_saved <= 32'h15000000;
        addr_saved <= 32'h0;
    end else begin
        if (icpu_ack_i & if_freeze & ~saved) begin
            saved <= 1'b1;
            insn_saved <= icpu_dat_i;
            addr_saved <= icpu_adr_i;
        end
        if (~if_freeze) begin
            saved <= 1'b0;
        end
    end
end

endmodule
