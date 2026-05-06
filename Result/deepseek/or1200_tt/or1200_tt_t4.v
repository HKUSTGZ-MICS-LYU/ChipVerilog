`define OR1200_TTOFS_BITS 4:0
`endif

`ifndef OR1200_TT_OFS_TTMR
`define OR1200_TT_OFS_TTMR 5'h00
`endif

`ifndef OR1200_TT_OFS_TTCR
`define OR1200_TT_OFS_TTCR 5'h01
`endif

`ifndef OR1200_TT_TTMR_IE
`define OR1200_TT_TTMR_IE 31
`endif

`ifndef OR1200_TT_TTMR_IP
`define OR1200_TT_TTMR_IP 30
`endif

`ifndef OR1200_TT_TTMR_TP
`define OR1200_TT_TTMR_TP 27:0
`endif

`ifndef OR1200_TT_TTMR_M
`define OR1200_TT_TTMR_M 29:28
`endif

module or1200_tt (
    input clk,
    input rst,
    input du_stall,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
    output wire intr
);

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

    wire ttmr_sel;
    wire ttcr_sel;
    wire match;
    wire restart;
    wire stop;

    assign ttmr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
    assign ttcr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

    assign match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);

    assign restart = match && (ttmr[`OR1200_TT_TTMR_M] == 2'b01);

    assign stop = (match && (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) ||
                  (ttmr[`OR1200_TT_TTMR_M] == 2'b00) ||
                  du_stall;

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

`ifdef OR1200_TT_READREGS
    always @(*) begin
        if (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR) begin
            spr_dat_o = ttmr;
        end else begin
            spr_dat_o = ttcr;
        end
    end
`else
    always @(*) begin
        spr_dat_o = 32'b0;
    end
`endif

    assign intr = ttmr[`OR1200_TT_TTMR_IP];

`else
    // OR1200_TT_IMPLEMENTED not defined

`ifdef OR1200_TT_READREGS
    assign spr_dat_o = 32'b0;
`endif

    assign intr = 1'b0;

`endif

endmodule
