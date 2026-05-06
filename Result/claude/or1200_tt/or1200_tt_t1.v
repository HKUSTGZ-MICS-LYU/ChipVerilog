// Generated from: Description/or1200_tt_description.txt
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

`include "or1200_defines.v"

`ifdef OR1200_TT_IMPLEMENTED

  wire ttmr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR);
  wire ttcr_sel = spr_cs && (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTCR);

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

  wire match = (ttmr[`OR1200_TT_TTMR_TP] == ttcr[27:0]);
  wire restart = match && (ttmr[`OR1200_TT_TTMR_M] == 2'b01);
  wire stop = (match && (ttmr[`OR1200_TT_TTMR_M] == 2'b10)) ||
              (ttmr[`OR1200_TT_TTMR_M] == 2'b00) ||
              du_stall;

`ifdef OR1200_TT_TTMR
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      ttmr <= 32'b0;
    end else if (ttmr_sel && spr_write) begin
      ttmr <= spr_dat_i;
    end else if (ttmr[`OR1200_TT_TTMR_IE]) begin
      // Only IP is updated by hardware; it is sticky until SW overwrite.
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
      ttcr <= ttcr + 32'd1;
    end
  end
`endif

  // SPR read mux (not gated by spr_cs)
  reg [31:0] spr_dat_r;
  assign spr_dat_o = spr_dat_r;
  always @* begin
`ifdef OR1200_TT_READREGS
    if (spr_addr[`OR1200_TTOFS_BITS] == `OR1200_TT_OFS_TTMR) spr_dat_r = ttmr;
    else spr_dat_r = ttcr;
`else
    spr_dat_r = 32'd0;
`endif
  end

  assign intr = ttmr[`OR1200_TT_TTMR_IP];

`else
  assign intr = 1'b0;
`ifdef OR1200_TT_READREGS
  assign spr_dat_o = 32'd0;
`endif
`endif

endmodule
