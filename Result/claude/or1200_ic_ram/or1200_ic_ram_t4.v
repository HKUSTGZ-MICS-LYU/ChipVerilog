// Generated from: Description/or1200_ic_ram_description.txt
module or1200_ic_ram(
    input         clk,
    input         rst,
`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input  [10:0] addr,
    input         en,
    input  [3:0]  we,
    input  [31:0] datain,
    output [31:0] dataout
);

`include "or1200_defines.v"

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i;
  wire _unused_bist = |mbist_ctrl_i;
`endif

`ifdef OR1200_NO_IC
  assign dataout = 32'd0;
`else
  // Wrapper uses only we[0] (word write enable)
  reg [31:0] ram [0:2047];
  reg [31:0] dout;
  assign dataout = dout;

  always @(posedge clk) begin
    if (en) begin
      dout <= ram[addr];
      if (we[0]) begin
        ram[addr] <= datain;
      end
    end
  end

  wire _unused_rst = rst;
`endif
endmodule

