module or1200_tt(
    input         clk,
    input         rst,
    input         du_stall,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output        intr
);

`ifdef OR1200_TT_IMPLEMENTED

`ifdef OR1200_TT_TTMR
reg [31:0] ttmr;
`else
wire [31:0] ttmr;
`endif

`ifdef OR1200_TT_TTCR
reg [31:0] ttcr;
`else
wire [31:0] ttcr;
`endif

wire ttmr_sel;
wire ttcr_sel;
wire match;
wire restart;
wire stop;

assign ttmr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
assign ttcr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

`ifdef OR1200_TT_TTMR
always @(posedge clk or posedge rst) begin
    if (rst)
        ttmr <= 32'b0;
    else if (ttmr_sel & spr_write)
        ttmr <= spr_dat_i;
    else if (ttmr[`OR1200_TT_TTMR_IE])
        ttmr[`OR1200_TT_TTMR_IP] <= ttmr[`OR1200_TT_TTMR_IP] | (match & ttmr[`OR1200_TT_TTMR_IE]);
end
`else
assign ttmr = {2'b11, 30'b0};
`endif

`ifdef OR1200_TT_TTCR
always @(posedge clk or posedge rst) begin
    if (rst)
        ttcr <= 32'b0;
    else if (restart)
        ttcr <= 32'b0;
    else if (ttcr_sel & spr_write)
        ttcr <= spr_dat_i;
    else if (!stop)
        ttcr <= ttcr + 32'd1;
end
`else
assign ttcr = 32'b0;
`endif

`ifdef OR1200_TT_READREGS
reg [31:0] spr_dat_o;
always @(spr_addr or ttmr or ttcr) begin
    case (spr_addr[`OR1200_TTOFS_BITS])
        `OR1200_TT_OFS_TTMR: spr_dat_o = ttmr;
        default:             spr_dat_o = ttcr;
    endcase
end
`endif

assign match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);
assign restart = match & (ttmr[`OR1200_TT_TTMR_M] == 2'b01);
assign stop = (match & (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) |
              (ttmr[`OR1200_TT_TTMR_M] == 2'b00) |
              du_stall;

assign intr = ttmr[`OR1200_TT_TTMR_IP];

`else

assign intr = 1'b0;
`ifdef OR1200_TT_READREGS
assign spr_dat_o = 32'b0;
`endif

`endif

endmodule
