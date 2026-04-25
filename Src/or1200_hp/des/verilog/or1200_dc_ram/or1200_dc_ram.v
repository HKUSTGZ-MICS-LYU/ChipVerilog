`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_dc_ram(
	// Reset and clock
	clk, rst,

`ifdef OR1200_BIST
	// RAM BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	// Internal i/f
	addr, en, we, datain, dataout
);

parameter dw = `OR1200_OPERAND_WIDTH;
parameter aw = `OR1200_DCINDX;

//
// I/O
//
input				clk;
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
input				mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;       // bist chain shift control
output				mbist_so_o;
`endif

`ifdef OR1200_NO_DC

//
// Data cache not implemented
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
wire [3 : 0] we_wire;
wire [10 : 0] addr_wire;
wire [31 : 0] datain_wire;

assign en_wire = en;
assign we_wire = we;
assign addr_wire = addr;
assign datain_wire = datain;

dc_ram_sub dc_ram (
	.clka(clk),
	.ena(en_wire),
	.wea(we_wire), // Bus [0 : 0] 
	.addra(addr_wire), // Bus [9 : 0] 
	.dina(datain_wire), // Bus [31 : 0] 
	.clkb(clk),
	.addrb(addr_wire),
	.doutb(dataout)); // Bus [31 : 0] 

`else


//
// Instantiation of RAM block
//
`ifdef OR1200_DC_1W_4KB
or1200_spram_1024x32_bw dc_ram(
`endif
`ifdef OR1200_DC_1W_8KB
or1200_spram_2048x32_bw dc_ram(
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
	.doq(dataout)
);
`endif
`endif
endmodule
