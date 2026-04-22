`include "timescale.v"
`include "or1200_defines.v"

module or1200_dc_tag(
	clk, rst,

`ifdef OR1200_BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	addr, en, we, datain, tag_v, tag
);

input		clk;
input		rst;
input	[8:0]	addr;
input		en;
input		we;
input	[19:0]	datain;
output		tag_v;
output	[18:0]	tag;

`ifdef OR1200_BIST
input		mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output		mbist_so_o;
`endif

`ifdef OR1200_NO_DC

// Data cache not implemented: tag always 0, tag_v always 0
assign tag   = {`OR1200_DCTAG_W-1{1'b0}};
assign tag_v = 1'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX

// Virtex path: bit 0 = tag_v, bits [19:1] = tag
wire [19:0] doutb;
assign tag   = doutb[19:1];
assign tag_v = doutb[0];

dc_tag_sub dc_tag0(
	.clka(clk),
	.ena(en),
	.wea(we),
	.addra(addr),
	.dina(datain),
	.clkb(clk),
	.addrb(addr),
	.doutb(doutb)
);

`else

// Generic path: packed as {tag, tag_v} = doq[19:0]
// tag_v = data[0], tag = data[19:1]
`ifdef OR1200_DC_1W_4KB
or1200_spram_256x21 dc_tag0(
`endif
`ifdef OR1200_DC_1W_8KB
or1200_spram_512x20 dc_tag0(
`endif
`ifdef OR1200_BIST
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
