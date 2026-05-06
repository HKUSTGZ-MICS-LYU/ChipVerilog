module or1200_if (
    input          clk,
    input          rst,
    input  [31:0]  icpu_dat_i,
    input          icpu_ack_i,
    input          icpu_err_i,
    input  [31:0]  icpu_adr_i,
    input  [3:0]   icpu_tag_i,
    input          if_freeze,
    output [31:0]  if_insn,
    output [31:0]  if_pc,
    input          flushpipe,
    output         if_stall,
    input          no_more_dslot,
    output         genpc_refetch,
    input          rfe,
    output         except_itlbmiss,
    output         except_immufault,
    output         except_ibuserr
);

    // OR1200 NOP instruction constants
    localparam [31:0] OR1200_OR32_NOP = 6'b000000;
    localparam [31:0] SPECIAL_NOP = {OR1200_OR32_NOP, 26'h041_0000};
    localparam [31:0] DEFAULT_NOP = {OR1200_OR32_NOP, 26'h061_0000};

    // Instruction tag constants
    localparam [3:0] OR1200_ITAG_TE = 4'b0001;
    localparam [3:0] OR1200_ITAG_PE = 4'b0010;
    localparam [3:0] OR1200_ITAG_BE = 4'b0100;

    // Internal state registers
    reg        saved;
    reg [31:0] insn_saved;
    reg [31:0] addr_saved;

    // Combinational outputs
    wire        error_or_control_nop;

    assign error_or_control_nop = icpu_err_i || no_more_dslot || rfe;

    // if_insn selection
    assign if_insn = error_or_control_nop ? SPECIAL_NOP :
                     saved                     ? insn_saved :
                     icpu_ack_i                ? icpu_dat_i :
                                                 DEFAULT_NOP;

    // if_pc selection
    assign if_pc = saved ? addr_saved : icpu_adr_i;

    // if_stall
    assign if_stall = !icpu_err_i && !icpu_ack_i && !saved;

    // genpc_refetch
    assign genpc_refetch = saved && icpu_ack_i;

    // Exception signals (suppressed by no_more_dslot)
    assign except_itlbmiss  = icpu_err_i && (icpu_tag_i == OR1200_ITAG_TE) && !no_more_dslot;
    assign except_immufault = icpu_err_i && (icpu_tag_i == OR1200_ITAG_PE) && !no_more_dslot;
    assign except_ibuserr   = icpu_err_i && (icpu_tag_i == OR1200_ITAG_BE) && !no_more_dslot;

    // Sequential logic for saved, insn_saved, addr_saved
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            saved      <= 1'b0;
            insn_saved <= SPECIAL_NOP;
            addr_saved <= 32'h00000000;
        end else if (flushpipe) begin
            saved      <= 1'b0;
            insn_saved <= SPECIAL_NOP;
            addr_saved <= 32'h00000000;
        end else begin
            // Update saved
            if (icpu_ack_i && if_freeze && !saved)
                saved <= 1'b1;
            else if (!if_freeze)
                saved <= 1'b0;
            else
                saved <= saved;

            // Update insn_saved
            if (icpu_ack_i && if_freeze && !saved)
                insn_saved <= icpu_dat_i;
            else if (!if_freeze)
                insn_saved <= SPECIAL_NOP;
            else
                insn_saved <= insn_saved;

            // Update addr_saved
            if (icpu_ack_i && if_freeze && !saved)
                addr_saved <= icpu_adr_i;
            else if (!if_freeze)
                addr_saved <= icpu_adr_i;
            else
                addr_saved <= addr_saved;
        end
    end

endmodule
