`include "timescale.v"
`include "or1200_defines.v"

module or1200_tt(
    clk, rst,
    du_stall,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
    intr
);

input         clk, rst;
input         du_stall;
input         spr_cs, spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;
output        intr;

`ifdef OR1200_TT_IMPLEMENTED

// TTMR and TTCR storage
`ifdef OR1200_TT_TTMR
reg  [31:0] ttmr;
`else
wire [31:0] ttmr = {2'b11, 30'b0};
`endif

`ifdef OR1200_TT_TTCR
reg  [31:0] ttcr;
`else
wire [31:0] ttcr = 32'b0;
`endif

// SPR address select
wire ttmr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
wire ttcr_sel = spr_cs & (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

// Combinational control signals
wire match   = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);
wire restart = match & (ttmr[`OR1200_TT_TTMR_M] == 2'b01);
wire stop    = (match & (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) |
               (ttmr[`OR1200_TT_TTMR_M] == 2'b00) |
               du_stall;

// intr: directly driven by IP bit
assign intr = ttmr[`OR1200_TT_TTMR_IP];

// TTMR sequential update
`ifdef OR1200_TT_TTMR
always @(posedge clk or posedge rst) begin
    if (rst)
        ttmr <= 32'b0;
    else if (ttmr_sel & spr_write)
        ttmr <= spr_dat_i;
    else if (ttmr[`OR1200_TT_TTMR_IE])
        ttmr[`OR1200_TT_TTMR_IP] <= ttmr[`OR1200_TT_TTMR_IP] |
                                     (match & ttmr[`OR1200_TT_TTMR_IE]);
end
`endif

// TTCR sequential update
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
`endif

// SPR read data (combinational, not gated by spr_cs)
reg [31:0] spr_dat_o;
always @(spr_addr or ttmr or ttcr) begin
`ifdef OR1200_TT_READREGS
    case (spr_addr[`OR1200_TTOFS_BITS])
        `OR1200_TT_OFS_TTMR: spr_dat_o = ttmr;
        default:             spr_dat_o = ttcr;
    endcase
`else
    spr_dat_o = 32'b0;
`endif
end

`else // !OR1200_TT_IMPLEMENTED

assign intr = 1'b0;
`ifdef OR1200_TT_READREGS
assign spr_dat_o = 32'b0;
`else
reg [31:0] spr_dat_o;
always @(*) spr_dat_o = 32'b0;
`endif

`endif // OR1200_TT_IMPLEMENTED

endmodule