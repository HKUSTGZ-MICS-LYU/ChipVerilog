`include "or1200_defines.v"

module or1200_reg2mem(
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] regdata,
    output [31:0] memdata
);

reg [7:0] memdata_hh;
reg [7:0] memdata_hl;
reg [7:0] memdata_lh;
reg [7:0] memdata_ll;

always @* begin
    if ((lsu_op == `OR1200_LSUOP_SB) && (addr == 2'b00))
        memdata_hh = regdata[7:0];
    else if ((lsu_op == `OR1200_LSUOP_SH) && (addr == 2'b00))
        memdata_hh = regdata[15:8];
    else
        memdata_hh = regdata[31:24];
end

always @* begin
    if ((lsu_op == `OR1200_LSUOP_SW) && (addr == 2'b00))
        memdata_hl = regdata[23:16];
    else
        memdata_hl = regdata[7:0];
end

always @* begin
    if ((lsu_op == `OR1200_LSUOP_SB) && (addr == 2'b10))
        memdata_lh = regdata[7:0];
    else
        memdata_lh = regdata[15:8];
end

always @* begin
    memdata_ll = regdata[7:0];
end

assign memdata = {memdata_hh, memdata_hl, memdata_lh, memdata_ll};

endmodule
