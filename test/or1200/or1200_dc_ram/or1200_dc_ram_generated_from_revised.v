`include "timescale.v"
`include "or1200_defines.v"

module or1200_dc_ram(
	clk, rst,

`ifdef OR1200_BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	addr, en, we, datain, dataout
);

input			clk;
input			rst;
input	[10:0]		addr;
input			en;
input	[3:0]		we;
input	[31:0]		datain;
output	[31:0]		dataout;

`ifdef OR1200_BIST
input			mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output			mbist_so_o;
`endif

`ifdef OR1200_NO_DC

assign dataout = {`OR1200_OPERAND_WIDTH{1'b0}};
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX

// Virtex path: block RAM with separate write (port A) and read (port B) ports
wire		en_wire;
wire [3:0]	we_wire;
wire [10:0]	addr_wire;
wire [31:0]	datain_wire;

assign en_wire     = en;
assign we_wire     = we;
assign addr_wire   = addr;
assign datain_wire = datain;

dc_ram_sub dc_ram(
	.clka(clk),
	.ena(en_wire),
	.wea(we_wire),
	.addra(addr_wire),
	.dina(datain_wire),
	.clkb(clk),
	.addrb(addr_wire),
	.doutb(dataout)
);

`else

// Generic path: single-port RAM macro
// Data width: 32 bits (fixed)
// Address width: 11 bits, determined by configured cache size
`ifdef OR1200_DC_1W_4KB
or1200_spram_1024x32_bw dc_ram(
`endif
`ifdef OR1200_DC_1W_8KB
or1200_spram_2048x32_bw dc_ram(
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
	.doq(dataout)
);

`endif
`endif

endmodule
