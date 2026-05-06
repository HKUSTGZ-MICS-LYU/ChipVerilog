`include "or1200_defines.v"

module or1200_dc_ram(
    clk,
    rst,
`ifdef OR1200_BIST
    mbist_si_i,
    mbist_so_o,
    mbist_ctrl_i,
`endif
    addr,
    en,
    we,
    datain,
    dataout
);

input          clk;
input          rst;
`ifdef OR1200_BIST
input          mbist_si_i;
output         mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif
input  [10:0]  addr;
input          en;
input  [3:0]   we;
input  [31:0]  datain;
output [31:0]  dataout;

`ifdef OR1200_NO_DC

assign dataout = 32'h0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`elsif OR1200_RAM_MODELS_VIRTEX

wire [10:0] addr_wire;
wire [3:0]  we_wire;
wire [31:0] datain_wire;
wire        en_wire;

assign addr_wire   = addr;
assign we_wire     = we;
assign datain_wire = datain;
assign en_wire     = en;

dc_ram_sub dc_ram_sub_inst(
    .clk(clk),
    .addra(addr_wire),
    .addrb(addr_wire),
    .wea(we_wire),
    .ena(en_wire),
    .dina(datain_wire),
    .doutb(dataout)
);

`else // Generic RAM path

`ifdef OR1200_DC_1W_4KB

`ifdef OR1200_BIST
or1200_spram_1024x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[9:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1),
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
);
`else
or1200_spram_1024x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[9:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1)
);
`endif

`elsif OR1200_DC_1W_8KB

`ifdef OR1200_BIST
or1200_spram_2048x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[10:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1),
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
);
`else
or1200_spram_2048x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[10:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1)
);
`endif

`else
// If no specific size is defined, default to 4KB with BIST if defined
`ifdef OR1200_BIST
or1200_spram_1024x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[9:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1),
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
);
`else
or1200_spram_1024x32_bw u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .addr(addr[9:0]),
    .di(datain),
    .doq(dataout),
    .oe(1'b1)
);
`endif

`endif // OR1200_DC_1W_4KB / OR1200_DC_1W_8KB

`endif // OR1200_NO_DC / OR1200_RAM_MODELS_VIRTEX / Generic

endmodule
