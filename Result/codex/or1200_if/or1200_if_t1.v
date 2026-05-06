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

localparam [5:0] OR1200_OR32_NOP = 6'b000101;
localparam [3:0] OR1200_ITAG_TE = 4'h1;
localparam [3:0] OR1200_ITAG_PE = 4'h2;
localparam [3:0] OR1200_ITAG_BE = 4'h4;
localparam [31:0] NOP_SPECIAL = {OR1200_OR32_NOP, 26'h041_0000};
localparam [31:0] NOP_DEFAULT = {OR1200_OR32_NOP, 26'h061_0000};

reg [31:0] insn_saved;
reg [31:0] addr_saved;
reg saved;

assign if_insn = (icpu_err_i | no_more_dslot | rfe) ? NOP_SPECIAL :
                 saved ? insn_saved :
                 icpu_ack_i ? icpu_dat_i :
                 NOP_DEFAULT;

assign if_pc = saved ? addr_saved : icpu_adr_i;
assign if_stall = !icpu_err_i & !icpu_ack_i & !saved;
assign genpc_refetch = saved & icpu_ack_i;

assign except_itlbmiss = icpu_err_i & !no_more_dslot & (icpu_tag_i == OR1200_ITAG_TE);
assign except_immufault = icpu_err_i & !no_more_dslot & (icpu_tag_i == OR1200_ITAG_PE);
assign except_ibuserr = icpu_err_i & !no_more_dslot & (icpu_tag_i == OR1200_ITAG_BE);

always @(posedge clk or posedge rst) begin
    if (rst)
        saved <= 1'b0;
    else if (flushpipe)
        saved <= 1'b0;
    else if (icpu_ack_i & if_freeze & !saved)
        saved <= 1'b1;
    else if (!if_freeze)
        saved <= 1'b0;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        insn_saved <= NOP_SPECIAL;
    else if (flushpipe)
        insn_saved <= NOP_SPECIAL;
    else if (icpu_ack_i & if_freeze & !saved)
        insn_saved <= icpu_dat_i;
    else if (!if_freeze)
        insn_saved <= NOP_SPECIAL;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        addr_saved <= 32'h0000_0000;
    else if (flushpipe)
        addr_saved <= 32'h0000_0000;
    else if (icpu_ack_i & if_freeze & !saved)
        addr_saved <= icpu_adr_i;
    else if (!if_freeze)
        addr_saved <= icpu_adr_i;
end

endmodule
