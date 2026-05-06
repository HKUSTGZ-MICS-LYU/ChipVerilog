module or1200_if(
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
    output if_stall,
    input no_more_dslot,
    output genpc_refetch,
    input rfe,
    output except_itlbmiss,
    output except_immufault,
    output except_ibuserr
);

    // Local parameters
    localparam OR1200_ITAG_TE = 4'd1;
    localparam OR1200_ITAG_PE = 4'd2;
    localparam OR1200_ITAG_BE = 4'd4;
    localparam [31:0] SPECIAL_NOP = 32'h04100000;
    localparam [31:0] DEFAULT_NOP = 32'h06100000;

    // Internal registers
    reg saved;
    reg [31:0] insn_saved;
    reg [31:0] addr_saved;

    // Sequential logic for saved, insn_saved, addr_saved
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            saved <= 1'b0;
            insn_saved <= SPECIAL_NOP;
            addr_saved <= 32'b0;
        end else begin
            if (flushpipe) begin
                saved <= 1'b0;
                insn_saved <= SPECIAL_NOP;
                addr_saved <= 32'b0;
            end else begin
                if (icpu_ack_i && if_freeze && !saved) begin
                    saved <= 1'b1;
                    insn_saved <= icpu_dat_i;
                    addr_saved <= icpu_adr_i;
                end else if (!if_freeze) begin
                    saved <= 1'b0;
                    insn_saved <= SPECIAL_NOP;
                    addr_saved <= icpu_adr_i;
                end else begin
                    saved <= saved;
                    insn_saved <= insn_saved;
                    addr_saved <= addr_saved;
                end
            end
        end
    end

    // Combinational outputs
    always @(*) begin
        // if_insn priority
        if (icpu_err_i || no_more_dslot || rfe) begin
            if_insn = SPECIAL_NOP;
        end else if (saved) begin
            if_insn = insn_saved;
        end else if (icpu_ack_i) begin
            if_insn = icpu_dat_i;
        end else begin
            if_insn = DEFAULT_NOP;
        end
    end

    always @(*) begin
        // if_pc mux
        if (saved) begin
            if_pc = addr_saved;
        end else begin
            if_pc = icpu_adr_i;
        end
    end

    assign if_stall = (!icpu_err_i & !icpu_ack_i & !saved);
    assign genpc_refetch = (saved & icpu_ack_i);

    // Exception signals, gated by no_more_dslot
    assign except_itlbmiss = (icpu_err_i & (icpu_tag_i == OR1200_ITAG_TE) & !no_more_dslot);
    assign except_immufault = (icpu_err_i & (icpu_tag_i == OR1200_ITAG_PE) & !no_more_dslot);
    assign except_ibuserr = (icpu_err_i & (icpu_tag_i == OR1200_ITAG_BE) & !no_more_dslot);

endmodule
