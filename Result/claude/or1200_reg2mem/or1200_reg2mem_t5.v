// Generated from: Description/or1200_reg2mem_description.txt
module or1200_reg2mem(
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] regdata,
    output [31:0] memdata
);

`include "or1200_defines.v"

  reg [7:0] memdata_hh;
  reg [7:0] memdata_hl;
  reg [7:0] memdata_lh;
  reg [7:0] memdata_ll;

  assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

  always @* begin
    memdata_hh = regdata[31:24];
    casex ({lsu_op, addr})
      {`OR1200_LSUOP_SB, 2'b00}: memdata_hh = regdata[7:0];
      {`OR1200_LSUOP_SH, 2'b00}: memdata_hh = regdata[15:8];
      default: memdata_hh = regdata[31:24];
    endcase
  end

  always @* begin
    memdata_hl = regdata[7:0];
    casex ({lsu_op, addr})
      {`OR1200_LSUOP_SW, 2'b00}: memdata_hl = regdata[23:16];
      default: memdata_hl = regdata[7:0];
    endcase
  end

  always @* begin
    memdata_lh = regdata[15:8];
    casex ({lsu_op, addr})
      {`OR1200_LSUOP_SB, 2'b10}: memdata_lh = regdata[7:0];
      default: memdata_lh = regdata[15:8];
    endcase
  end

  always @* begin
    memdata_ll = regdata[7:0];
  end
endmodule
