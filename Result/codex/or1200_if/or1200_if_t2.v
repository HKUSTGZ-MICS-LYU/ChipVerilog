`include "or1200_defines.v"

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

  reg saved;
  reg [31:0] insn_saved;
  reg [31:0] addr_saved;

  wire [31:0] nop_special = {`OR1200_OR32_NOP, 26'h041_0000};
  wire [31:0] nop_default = {`OR1200_OR32_NOP, 26'h061_0000};

  // Combinational instruction selection priority
  assign if_insn =
      (icpu_err_i | no_more_dslot | rfe) ? nop_special :
      (saved ? insn_saved :
       (icpu_ack_i ? icpu_dat_i : nop_default));

  assign if_pc = saved ? addr_saved : icpu_adr_i;

  assign if_stall = (~icpu_err_i) & (~icpu_ack_i) & (~saved);

  assign genpc_refetch = saved & icpu_ack_i;

  // Exception decode, suppressed by no_more_dslot
  assign except_itlbmiss = icpu_err_i & ~no_more_dslot & (icpu_tag_i == `OR1200_ITAG_TE);
  assign except_immufault = icpu_err_i & ~no_more_dslot & (icpu_tag_i == `OR1200_ITAG_PE);
  assign except_ibuserr = icpu_err_i & ~no_more_dslot & (icpu_tag_i == `OR1200_ITAG_BE);

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      saved <= 1'b0;
      insn_saved <= nop_special;
      addr_saved <= 32'd0;
    end else if (flushpipe) begin
      saved <= 1'b0;
      insn_saved <= nop_special;
      addr_saved <= 32'd0;
    end else begin
      if (icpu_ack_i && if_freeze && !saved) begin
        saved <= 1'b1;
        insn_saved <= icpu_dat_i;
        addr_saved <= icpu_adr_i;
      end else if (!if_freeze) begin
        saved <= 1'b0;
        insn_saved <= nop_special;
        addr_saved <= icpu_adr_i;
      end
    end
  end

endmodule

