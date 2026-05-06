`include "or1200_defines.v"

module or1200_tt(
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

`ifdef OR1200_TT_IMPLEMENTED

    // Tick Timer Mode Register
`ifdef OR1200_TT_TTMR
    reg [31:0] ttmr;
`else
    wire [31:0] ttmr;
    assign ttmr = {2'b11, 30'b0};
`endif

    // Tick Timer Count Register
`ifdef OR1200_TT_TTCR
    reg [31:0] ttcr;
`else
    wire [31:0] ttcr;
    assign ttcr = 32'b0;
`endif

    // SPR address decode
    wire ttmr_sel;
    wire ttcr_sel;

    assign ttmr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
    assign ttcr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

    // Match, restart, and stop logic
    wire match;
    wire restart;
    wire stop;

    assign match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);
    assign restart = match && (ttmr[`OR1200_TT_TTMR_M] == 2'b01);
    assign stop = (match && (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) ||
                  (ttmr[`OR1200_TT_TTMR_M] == 2'b00) ||
                  du_stall;

    // Sequential update of TTMR
`ifdef OR1200_TT_TTMR
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ttmr <= 32'b0;
        end else if (ttmr_sel && spr_write) begin
            ttmr <= spr_dat_i;
        end else if (ttmr[`OR1200_TT_TTMR_IE]) begin
            ttmr[`OR1200_TT_TTMR_IP] <= ttmr[`OR1200_TT_TTMR_IP] | (match & ttmr[`OR1200_TT_TTMR_IE]);
        end
    end
`endif

    // Sequential update of TTCR
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
    always @(*) begin
        if (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR)
            spr_dat_o = ttmr;
        else
            spr_dat_o = ttcr;
    end
`else
    // If readregs not defined, spr_dat_o is not assigned here,
    // but the outer `else branch handles it.
`endif

    // Interrupt output
    assign intr = ttmr[`OR1200_TT_TTMR_IP];

`else  // !OR1200_TT_IMPLEMENTED

    assign intr = 1'b0;

`ifdef OR1200_TT_READREGS
    assign spr_dat_o = 32'b0;
`endif

`endif

endmodule
