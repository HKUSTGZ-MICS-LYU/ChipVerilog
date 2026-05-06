`include "or1200_defines.v"


module or1200_ic_tag(
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [8:0] addr,
    input en,
    input we,
    input [19:0] datain,
    output tag_v,
    output [18:0] tag
);
`ifdef OR1200_NO_IC
assign tag_v = 1'b0;
assign tag = 19'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`else
reg [19:0] mem [0:511];
reg [19:0] dout_r;
assign {tag,tag_v} = dout_r;
always @(posedge clk) begin
    if (en) begin
        if (we) mem[addr] <= datain;
        dout_r <= mem[addr];
    end
end
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`endif
endmodule
