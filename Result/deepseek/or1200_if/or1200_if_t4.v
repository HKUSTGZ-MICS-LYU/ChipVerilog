module or1200_if (
    input clk,
    input rst,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    input if_freeze,
    output reg [31:0] if_insn,
    output reg [31:0] if_pc,
    input flushpipe,
    output reg if_stall,
    input no_more_dslot,
    output reg genpc_refetch,
    input rfe,
    output reg except_itlbmiss,
    output reg except_immufault,
    output reg except_ibuserr
);

localparam [5:0] OR1200_OR32_NOP = 6'h15;
localparam [31:0] SPECIAL_NOP = {OR1200_OR32_NOP, 26'h041_0000};
localparam [31:0] DEFAULT_NOP = {OR1200_OR32_NOP, 26'h061_0000};

localparam [3:0] OR1200_ITAG_TE = 4'd0;
localparam [3:0] OR1200_ITAG_PE = 4'd1;
localparam [3:0] OR1200_ITAG_BE = 4'd2;

reg saved;
reg [31:0] insn_saved;
reg [31:0] addr_saved;

// Combinational outputs
always @(*) begin
    if (icpu_err_i || no_more_dslot || rfe)
        if_insn = SPECIAL_NOP;
    else if (saved)
        if_insn = insn_saved;
    else if (icpu_ack_i)
        if_insn = icpu_dat_i;
    else
        if_insn = DEFAULT_NOP;
end

always @(*) begin
    if (saved)
        if_pc = addr_saved;
    else
        if_pc = icpu_adr_i;
end

always @(*) begin
    if_stall = ~icpu_err_i & ~icpu_ack_i & ~saved;
end

always @(*) begin
    genpc_refetch = saved & icpu_ack_i;
end

always @(*) begin
    except_itlbmiss = icpu_err_i & (icpu_tag_i == OR1200_ITAG_TE) & ~no_more_dslot;
    except_immufault = icpu_err_i & (icpu_tag_i == OR1200_ITAG_PE) & ~no_more_dslot;
    except_ibuserr = icpu_err_i & (icpu_tag_i == OR1200_ITAG_BE) & ~no_more_dslot;
end

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        saved <= 1'b0;
        insn_saved <= SPECIAL_NOP;
        addr_saved <= 32'h00000000;
    end else if (flushpipe) begin
        saved <= 1'b0;
        insn_saved <= SPECIAL_NOP;
        addr_saved <= 32'h00000000;
    end else begin
        // saved register
        if (icpu_ack_i & if_freeze & ~saved)
            saved <= 1'b1;
        else if (~if_freeze)
            saved <= 1'b0;
        else
            saved <= saved;
        // insn_saved register
        if (icpu_ack_i & if_freeze & ~saved)
            insn_saved <= icpu_dat_i;
        else if (~if_freeze)
            insn_saved <= SPECIAL_NOP;
        else
            insn_saved <= insn_saved;
        // addr_saved register
        if (icpu_ack_i & if_freeze & ~saved)
            addr_saved <= icpu_adr_i;
        else if (~if_freeze)
            addr_saved <= icpu_adr_i;
        else
            addr_saved <= addr_saved;
    end
end

endmodule
