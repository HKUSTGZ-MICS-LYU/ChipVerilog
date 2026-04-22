`include "timescale.v"
`include "or1200_defines.v"

// Generated from ORIGINAL description.txt
// Key issue: detail 1.4 claimed dw/aw module parameters exist
// -> generates a parameterized wrapper (WRONG, RTL has fixed widths)

module or1200_dc_ram #(
    parameter dw = `OR1200_OPERAND_WIDTH,
    parameter aw = `OR1200_DCINDX
)(
    clk, rst,

`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

    addr, en, we, datain, dataout
);

input                   clk;
input                   rst;
input   [aw-1:0]        addr;
input                   en;
input   [dw/8-1:0]      we;
input   [dw-1:0]        datain;
output  [dw-1:0]        dataout;

`ifdef OR1200_BIST
input                   mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output                  mbist_so_o;
`endif

`ifdef OR1200_NO_DC
assign dataout = {dw{1'b0}};
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX
wire            en_wire;
wire [dw/8-1:0] we_wire;
wire [aw-1:0]   addr_wire;
wire [dw-1:0]   datain_wire;

assign en_wire     = en;
assign we_wire     = we;
assign addr_wire   = addr;
assign datain_wire = datain;

dc_ram_sub dc_ram(
    .clka(clk), .ena(en_wire), .wea(we_wire),
    .addra(addr_wire), .dina(datain_wire),
    .clkb(clk), .addrb(addr_wire), .doutb(dataout)
);

`else

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
    .clk(clk), .rst(rst),
    .ce(en), .we(we), .oe(1'b1),
    .addr(addr), .di(datain), .doq(dataout)
);

`endif
`endif

endmodule
