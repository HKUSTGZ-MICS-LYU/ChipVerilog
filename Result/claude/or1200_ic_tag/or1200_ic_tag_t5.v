// Generated from: Description/or1200_ic_tag_description.txt
module or1200_ic_tag(
    input         clk,
    input         rst,
`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input  [8:0]  addr,
    input         en,
    input         we,
    input  [19:0] datain,
    output        tag_v,
    output [18:0] tag
);

`include "or1200_defines.v"

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i;
  wire _unused_bist = |mbist_ctrl_i;
`endif

`ifdef OR1200_NO_IC
  assign tag = 19'd0;
  assign tag_v = 1'b0;
  wire _unused = clk ^ rst ^ en ^ we ^ |addr ^ |datain;
`else
  reg [19:0] ram [0:511];
  reg [19:0] dout;

  always @(posedge clk) begin
    if (en) begin
      dout <= ram[addr];
      if (we) ram[addr] <= datain;
    end
  end

  assign tag   = dout[19:1];
  assign tag_v = dout[0];
  wire _unused_rst = rst;
`endif
endmodule

