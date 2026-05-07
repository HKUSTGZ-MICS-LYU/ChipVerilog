`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_ic_ram(
	// Clock and reset
	clk, rst, 

`ifdef OR1200_BIST
	// RAM BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	// Internal i/f
	addr, en, we, datain, dataout
);

parameter dw = `OR1200_OPERAND_WIDTH;
parameter aw = `OR1200_ICINDX;

//
// I/O
//
input 				clk;
input				rst;
input	[aw-1:0]		addr;
input				en;
input	[3:0]			we;
input	[dw-1:0]		datain;
output	[dw-1:0]		dataout;

`ifdef OR1200_BIST
//
// RAM BIST
//
input mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output mbist_so_o;
`endif

`ifdef OR1200_NO_IC

//
// Insn cache not implemented
//
assign dataout = {dw{1'b0}};
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX

//
//	Non-generic FPGA model instantiations
//


wire en_wire;
wire [0 : 0] we_wire;
wire [10 : 0] addr_wire;
wire [31 : 0] datain_wire;

assign en_wire = en;
assign we_wire = we[0];
assign addr_wire = addr;
assign datain_wire = datain;

ic_ram_sub ic_ram0 (
	.clka(clk),
	.ena(en_wire),
	.wea(we_wire), // Bus [0 : 0] 
	.addra(addr_wire), // Bus [10 : 0] 
	.dina(datain_wire), // Bus [31 : 0] 
	.clkb(clk),
	.addrb(addr_wire),
	.doutb(dataout)); // Bus [31 : 0] 

`else

//
// Instantiation of IC RAM block
//
`ifdef OR1200_IC_1W_512B
or1200_spram_128x32 ic_ram0(
`endif
`ifdef OR1200_IC_1W_4KB
or1200_spram_1024x32 ic_ram0(
`endif
`ifdef OR1200_IC_1W_8KB
or1200_spram_2048x32 ic_ram0(
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
	.we(we[0]),
	.oe(1'b1),
	.addr(addr),
	.di(datain),
	.doq(dataout)
);

`endif
`endif

endmodule

