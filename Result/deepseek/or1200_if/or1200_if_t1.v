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

    localparam OR1200_OR32_NOP = 6'b011000;
    localparam OR1200_ITAG_TE = 4'b0001;
    localparam OR1200_ITAG_PE = 4'b0010;
    localparam OR1200_ITAG_BE = 4'b0100;

    reg saved;
    reg [31:0] insn_saved;
    reg [31:0] addr_saved;

    wire [31:0] special_nop = {OR1200_OR32_NOP, 26'h041_0000};
    wire [31:0] default_nop = {OR1200_OR32_NOP, 26'h061_0000};

    assign if_insn = (icpu_err_i || no_more_dslot || rfe) ? special_nop :
                     (saved) ? insn_saved :
                     (icpu_ack_i) ? icpu_dat_i :
                     default_nop;

    assign if_pc = (saved) ? addr_saved : icpu_adr_i;

    assign if_stall = !icpu_err_i && !icpu_ack_i && !saved;

    assign genpc_refetch = saved && icpu_ack_i;

    assign except_itlbmiss = icpu_err_i && (icpu_tag_i == OR1200_ITAG_TE) && !no_more_dslot;
    assign except_immufault = icpu_err_i && (icpu_tag_i == OR1200_ITAG_PE) && !no_more_dslot;
    assign except_ibuserr   = icpu_err_i && (icpu_tag_i == OR1200_ITAG_BE) && !no_more_dslot;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            saved       <= 1'b0;
            insn_saved  <= special_nop;
            addr_saved  <= 32'h00000000;
        end else if (flushpipe) begin
            saved       <= 1'b0;
            insn_saved  <= special_nop;
            addr_saved  <= 32'h00000000;
        end else begin
            if (icpu_ack_i && if_freeze && !saved) begin
                saved      <= 1'b1;
                insn_saved <= icpu_dat_i;
                addr_saved <= icpu_adr_i;
            end else if (!if_freeze) begin
                saved      <= 1'b0;
                insn_saved <= special_nop;
                addr_saved <= icpu_adr_i;
            end
        end
    end

endmodule
