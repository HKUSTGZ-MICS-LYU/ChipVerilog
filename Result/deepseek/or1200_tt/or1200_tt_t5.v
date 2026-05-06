module or1200_tt (
    input clk,
    input rst,
    input du_stall,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output intr
);

    // Default local constants (can be overridden by `define)
    localparam TT_OFS_WIDTH = 8;
    localparam [TT_OFS_WIDTH-1:0] OR1200_TT_OFS_TTMR = 'h00;
    localparam [TT_OFS_WIDTH-1:0] OR1200_TT_OFS_TTCR = 'h01;

    localparam TTMR_IE_BIT = 31;
    localparam TTMR_IP_BIT = 30;
    localparam TTMR_M_MSB  = 29;
    localparam TTMR_M_LSB  = 28;
    localparam TTMR_TP_MSB = 27;
    localparam TTMR_TP_LSB = 0;

    // Conditional register/wire declarations
    `ifdef OR1200_TT_IMPLEMENTED

        `ifdef OR1200_TT_TTMR
            reg [31:0] ttmr;
        `else
            wire [31:0] ttmr = {2'b11, 30'b0};
        `endif

        `ifdef OR1200_TT_TTCR
            reg [31:0] ttcr;
        `else
            wire [31:0] ttcr = 32'b0;
        `endif

        // SPR address decoding
        wire ttmr_sel = spr_cs && (spr_addr[TT_OFS_WIDTH-1:0] == OR1200_TT_OFS_TTMR);
        wire ttcr_sel = spr_cs && (spr_addr[TT_OFS_WIDTH-1:0] == OR1200_TT_OFS_TTCR);

        // Match, restart, stop
        wire match = (ttmr[TTMR_TP_MSB:TTMR_TP_LSB] == ttcr[TTMR_TP_MSB:TTMR_TP_LSB]);
        wire restart = match && (ttmr[TTMR_M_MSB:TTMR_M_LSB] == 2'b01);
        wire stop = (match && (ttmr[TTMR_M_MSB:TTMR_M_LSB] == 2'b10)) ||
                    (ttmr[TTMR_M_MSB:TTMR_M_LSB] == 2'b00) ||
                    du_stall;

        // Sequential TTMR update
        `ifdef OR1200_TT_TTMR
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    ttmr <= 32'b0;
                end else if (ttmr_sel && spr_write) begin
                    ttmr <= spr_dat_i;
                end else if (ttmr[TTMR_IE_BIT]) begin
                    ttmr[TTMR_IP_BIT] <= ttmr[TTMR_IP_BIT] | (match & ttmr[TTMR_IE_BIT]);
                end
            end
        `endif

        // Sequential TTCR update
        `ifdef OR1200_TT_TTCR
            always @(posedge clk or posedge rst) begin
                if (rst) begin
                    ttcr <= 32'b0;
                end else if (restart) begin
                    ttcr <= 32'b0;
                end else if (ttcr_sel && spr_write) begin
                    ttcr <= spr_dat_i;
                end else if (!stop) begin
                    ttcr <= ttcr + 1;
                end
            end
        `endif

        // SPR read data
        `ifdef OR1200_TT_READREGS
            assign spr_dat_o = (spr_addr[TT_OFS_WIDTH-1:0] == OR1200_TT_OFS_TTMR) ? ttmr : ttcr;
        `else
            // no assignment (per spec)
        `endif

        // Interrupt output
        assign intr = ttmr[TTMR_IP_BIT];

    `else
        // OR1200_TT_IMPLEMENTED not defined
        assign intr = 1'b0;

        `ifdef OR1200_TT_READREGS
            assign spr_dat_o = 32'b0;
        `else
            // no assignment (per spec)
        `endif
    `endif

endmodule
