`timescale 1ns / 1ps

module or1200_if (
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  icpu_dat_i,
    input  wire         icpu_ack_i,
    input  wire         icpu_err_i,
    input  wire [31:0]  icpu_adr_i,
    input  wire [3:0]   icpu_tag_i,
    input  wire         if_freeze,
    output reg  [31:0]  if_insn,
    output reg  [31:0]  if_pc,
    input  wire         flushpipe,
    output wire         if_stall,
    input  wire         no_more_dslot,
    output wire         genpc_refetch,
    input  wire         rfe,
    output wire         except_itlbmiss,
    output wire         except_immufault,
    output wire         except_ibuserr
);

    // Local parameters
    localparam [5:0] OR1200_OR32_NOP = 6'b000000;
    localparam [31:0] IF_SPECIAL_NOP = {OR1200_OR32_NOP, 26'h041_0000};
    localparam [31:0] IF_DEFAULT_NOP = {OR1200_OR32_NOP, 26'h061_0000};
    localparam [3:0] OR1200_ITAG_TE = 4'd1;  // TLB miss
    localparam [3:0] OR1200_ITAG_PE = 4'd2;  // page fault
    localparam [3:0] OR1200_ITAG_BE = 4'd4;  // bus error

    // Internal registers
    reg         saved;
    reg  [31:0] insn_saved;
    reg  [31:0] addr_saved;

    // Combinational outputs
    always @(*) begin
        // if_insn priority
        if (icpu_err_i || no_more_dslot || rfe)
            if_insn = IF_SPECIAL_NOP;
        else if (saved)
            if_insn = insn_saved;
        else if (icpu_ack_i)
            if_insn = icpu_dat_i;
        else
            if_insn = IF_DEFAULT_NOP;

        // if_pc
        if (saved)
            if_pc = addr_saved;
        else
            if_pc = icpu_adr_i;
    end

    // if_stall (combinational)
    assign if_stall = !icpu_err_i & !icpu_ack_i & !saved;

    // genpc_refetch (combinational)
    assign genpc_refetch = saved & icpu_ack_i;

    // Exception decoding (combinational)
    wire err_active = icpu_err_i & !no_more_dslot;
    assign except_itlbmiss = err_active & (icpu_tag_i == OR1200_ITAG_TE);
    assign except_immufault = err_active & (icpu_tag_i == OR1200_ITAG_PE);
    assign except_ibuserr = err_active & (icpu_tag_i == OR1200_ITAG_BE);

    // Sequential logic for saved, insn_saved, addr_saved
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            saved <= 1'b0;
            insn_saved <= IF_SPECIAL_NOP;
            addr_saved <= 32'h0;
        end else if (flushpipe) begin
            saved <= 1'b0;
            insn_saved <= IF_SPECIAL_NOP;
            addr_saved <= 32'h0;
        end else begin
            // saved update
            if (icpu_ack_i & if_freeze & ~saved)
                saved <= 1'b1;
            else if (~if_freeze)
                saved <= 1'b0;
            // else hold

            // insn_saved update
            if (icpu_ack_i & if_freeze & ~saved)
                insn_saved <= icpu_dat_i;
            else if (~if_freeze)
                insn_saved <= IF_SPECIAL_NOP;
            // else hold

            // addr_saved update
            if (icpu_ack_i & if_freeze & ~saved)
                addr_saved <= icpu_adr_i;
            else if (~if_freeze)
                addr_saved <= icpu_adr_i;  // tracks current address when not frozen
            // else hold
        end
    end

endmodule
