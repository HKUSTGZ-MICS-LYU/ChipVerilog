module or1200_tt (
    input clk,
    input rst,
    input du_stall,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
    output reg intr
);

`ifndef OR1200_TT_IMPLEMENTED
`define OR1200_TT_IMPLEMENTED
`endif

`ifndef OR1200_TT_TTMR
`define OR1200_TT_TTMR
`endif

`ifndef OR1200_TT_TTCR
`define OR1200_TT_TTCR
`endif

`ifndef OR1200_TT_READREGS
`define OR1200_TT_READREGS
`endif

`ifndef OR1200_TTOFS_BITS
`define OR1200_TTOFS_BITS 7:0
`endif

`ifndef OR1200_TT_OFS_TTMR
`define OR1200_TT_OFS_TTMR 8'h00
`endif

`ifndef OR1200_TT_OFS_TTCR
`define OR1200_TT_OFS_TTCR 8'h01
`endif

`ifndef OR1200_TT_TTMR_IP
`define OR1200_TT_TTMR_IP 0
`endif

`ifndef OR1200_TT_TTMR_IE
`define OR1200_TT_TTMR_IE 1
`endif

`ifndef OR1200_TT_TTMR_M
`define OR1200_TT_TTMR_M 31:30
`endif

`ifndef OR1200_TT_TTMR_TP
`define OR1200_TT_TTMR_TP 27:0
`endif

`ifdef OR1200_TT_IMPLEMENTED

wire ttmr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
wire ttcr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

wire match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);
wire restart = match && (ttmr[`OR1200_TT_TTMR_M] == 2'b01);
wire stop = (match && (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) || (ttmr[`OR1200_TT_TTMR_M] == 2'b00) || du_stall;

`ifdef OR1200_TT_TTMR
reg [31:0] ttmr;

always @(posedge clk or posedge rst) begin
    if (rst)
        ttmr <= 32'b0;
    else if (ttmr_sel && spr_write)
        ttmr <= spr_dat_i;
    else if (ttmr[`OR1200_TT_TTMR_IE])
        ttmr[`OR1200_TT_TTMR_IP] <= ttmr[`OR1200_TT_TTMR_IP] | (match & ttmr[`OR1200_TT_TTMR_IE]);
end
`else
wire [31:0] ttmr = {2'b11, 30'b0};
`endif

`ifdef OR1200_TT_TTCR
reg [31:0] ttcr;

always @(posedge clk or posedge rst) begin
    if (rst)
        ttcr <= 32'b0;
    else if (restart)
        ttcr <= 32'b0;
    else if (ttcr_sel && spr_write)
        ttcr <= spr_dat_i;
    else if (!stop)
        ttcr <= ttcr + 1;
end
`else
wire [31:0] ttcr = 32'b0;
`endif

assign intr = ttmr[`OR1200_TT_TTMR_IP];

`ifdef OR1200_TT_READREGS
always @(*) begin
    if (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR)
        spr_dat_o = ttmr;
    else
        spr_dat_o = ttcr;
end
`else
// no assignment to spr_dat_o (maintains previous value)
`endif

`else // OR1200_TT_IMPLEMENTED not defined

assign intr = 1'b0;

`ifdef OR1200_TT_READREGS
assign spr_dat_o = 32'b0;
`else
// no assignment to spr_dat_o (maintains previous value)
`endif

`endif // OR1200_TT_IMPLEMENTED

endmodule
