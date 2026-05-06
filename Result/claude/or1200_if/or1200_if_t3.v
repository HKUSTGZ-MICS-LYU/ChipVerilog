`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_if (
    input         clk,
    input         rst,

    // External i/f to IC
    input  [31:0] icpu_dat_i,
    input         icpu_ack_i,
    input         icpu_err_i,
    input  [31:0] icpu_adr_i,
    input  [3:0]  icpu_tag_i,

    // Internal i/f
    input         if_freeze,
    output [31:0] if_insn,
    output [31:0] if_pc,
    input         flushpipe,
    output        if_stall,
    input         no_more_dslot,
    output        genpc_refetch,
    input         rfe,
    output        except_itlbmiss,
    output        except_immufault,
    output        except_ibuserr
);

    //--------------------------------------------------------------------------
    // Internal state registers
    //--------------------------------------------------------------------------
    reg [31:0] insn_saved;
    reg [31:0] addr_saved;
    reg        saved;

    //--------------------------------------------------------------------------
    // Combinational outputs
    //--------------------------------------------------------------------------

    // if_insn: priority: error/control NOP > saved > ack > default NOP
    assign if_insn =
        (icpu_err_i | no_more_dslot | rfe) ?
            {`OR1200_OR32_NOP, 26'h041_0000} :
        saved ?
            insn_saved :
        icpu_ack_i ?
            icpu_dat_i :
            {`OR1200_OR32_NOP, 26'h061_0000};

    // if_pc: saved address or current interface address
    assign if_pc = saved ? addr_saved : icpu_adr_i;

    // if_stall: no error, no ack, no saved instruction
    assign if_stall = ~icpu_err_i & ~icpu_ack_i & ~saved;

    // genpc_refetch: saved instruction exists and new ack arrives
    assign genpc_refetch = saved & icpu_ack_i;

    //--------------------------------------------------------------------------
    // Instruction-fetch exception decode
    //--------------------------------------------------------------------------
    assign except_itlbmiss = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_TE) & ~no_more_dslot;
    assign except_immufault = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_PE) & ~no_more_dslot;
    assign except_ibuserr  = icpu_err_i & (icpu_tag_i == `OR1200_ITAG_BE) & ~no_more_dslot;

    //--------------------------------------------------------------------------
    // Sequential: saved state registers
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            saved      <= 1'b0;
            insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};
            addr_saved <= 32'h0000_0000;
        end else if (flushpipe) begin
            saved      <= 1'b0;
            insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};
            addr_saved <= 32'h0000_0000;
        end else begin
            // Update saved
            if (icpu_ack_i & if_freeze & ~saved)
                saved <= 1'b1;
            else if (~if_freeze)
                saved <= 1'b0;

            // Update insn_saved
            if (icpu_ack_i & if_freeze & ~saved)
                insn_saved <= icpu_dat_i;
            else if (~if_freeze)
                insn_saved <= {`OR1200_OR32_NOP, 26'h041_0000};

            // Update addr_saved
            if (icpu_ack_i & if_freeze & ~saved)
                addr_saved <= icpu_adr_i;
            else if (~if_freeze)
                addr_saved <= icpu_adr_i;
        end
    end

endmodule