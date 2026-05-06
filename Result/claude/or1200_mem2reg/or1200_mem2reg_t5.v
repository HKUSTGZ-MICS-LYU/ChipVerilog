// Generated from: Description/or1200_mem2reg_description.txt
module or1200_mem2reg(
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] memdata,
    output [31:0] regdata
);

`include "or1200_defines.v"

  reg [31:0] regdata_r;
  assign regdata = regdata_r;

  wire [7:0] bsel =
      (addr == 2'b00) ? memdata[31:24] :
      (addr == 2'b01) ? memdata[23:16] :
      (addr == 2'b10) ? memdata[15:8]  :
                        memdata[7:0];

  wire [15:0] hsel =
      (addr == 2'b00) ? memdata[31:16] :
                        memdata[15:0]; // addr==2'b10 expected for aligned halfword

  always @* begin
    regdata_r = memdata;
    case (lsu_op)
      `OR1200_LSUOP_LBZ: regdata_r = {24'd0, bsel};
      `OR1200_LSUOP_LBS: regdata_r = {{24{bsel[7]}}, bsel};
      `OR1200_LSUOP_LHZ: regdata_r = {16'd0, hsel};
      `OR1200_LSUOP_LHS: regdata_r = {{16{hsel[15]}}, hsel};
      `OR1200_LSUOP_LWZ,
      `OR1200_LSUOP_LWS: regdata_r = memdata;
      default: regdata_r = memdata;
    endcase
  end
endmodule
