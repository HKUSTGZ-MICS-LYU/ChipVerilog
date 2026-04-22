`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_ic_ram(
    // Clock and reset
    clk,
    rst,
`ifdef OR1200_BIST
    // RAM BIST
    mbist_si_i,
    mbist_so_o,
    mbist_ctrl_i,
`endif
    // Internal i/f
    addr,
    en,
    we,
    datain,
    dataout
);

input         clk;
input         rst;
input  [10:0] addr;
input         en;
input  [3:0]  we;
input  [31:0] datain;
output [31:0] dataout;

`ifdef OR1200_BIST
input mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output mbist_so_o;
`endif

`ifdef OR1200_NO_IC

assign dataout = {`OR1200_OPERAND_WIDTH{1'b0}};
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

reg [31:0] mem [0:2047];
reg [31:0] dataout_r;
integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dataout_r <= 32'b0;
    end
    else if (en) begin
        if (we[0])
            mem[addr] <= datain;
        dataout_r <= mem[addr];
    end
end

assign dataout = dataout_r;

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`endif

endmodule
