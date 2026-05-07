`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_ic_tag(
	// Clock and reset
	clk, rst,

`ifdef OR1200_BIST
	// RAM BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	// Internal i/f
	addr, en, we, datain, tag_v, tag
);

parameter dw = `OR1200_ICTAG_W;
parameter aw = `OR1200_ICTAG;

//
// I/O
//

//
// Clock and reset
//
input				clk;
input				rst;

`ifdef OR1200_BIST
//
// RAM BIST
//
input mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output mbist_so_o;
`endif

//
// Internal i/f
//
input	[aw-1:0]		addr;
input				en;
input				we;
input	[dw-1:0]		datain;
output				tag_v;
output	[dw-2:0]		tag;

`ifdef OR1200_NO_IC

//
// Insn cache not implemented
//
assign tag = {dw-1{1'b0}};
assign tag_v = 1'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX

//
//	Non-generic FPGA model instantiations
//

wire [19:0] doutb;
assign tag = doutb[19:1];
assign tag_v = doutb[0];

ic_tag_sub ic_tag0 (
	.clka(clk),
	.ena(en),
	.wea(we), // Bus [0 : 0] 
	.addra(addr), // Bus [7 : 0] 
	.dina(datain), // Bus [19 : 0]
	.clkb(clk),
	.addrb(addr), 
	.doutb(doutb)); // Bus [19 : 0] 

`else

//
// Instantiation of TAG RAM block
//
`ifdef OR1200_IC_1W_512B
or1200_spram_32x24 ic_tag0(
`endif
`ifdef OR1200_IC_1W_4KB
or1200_spram_256x21 ic_tag0(
`endif
`ifdef OR1200_IC_1W_8KB
or1200_spram_512x20 ic_tag0(
`endif
`ifdef OR1200_BIST
	// RAM BIST
	.mbist_si_i(mbist_si_i),
	.mbist_so_o(mbist_so_o),
	.mbist_ctrl_i(mbist_ctrl_i),
`endif
	.clk(clk),
	.rst(rst),
	.ce(en),
	.we(we),
	.oe(1'b1),
	.addr(addr),
	.di(datain),
	.doq({tag, tag_v})
);
`endif

`endif

endmodule
