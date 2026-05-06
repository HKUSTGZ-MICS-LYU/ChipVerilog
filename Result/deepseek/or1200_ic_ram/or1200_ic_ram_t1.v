module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    assign dataout = 32'h0;
    assign mbist_so_o = mbist_si_i;
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    assign dataout = 32'h0;
endmodule
`endif
`elsif OR1200_RAM_MODELS_VIRTEX
`ifdef OR1200_BIST
module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    ic_ram_sub ic_ram_sub0 (
        .clk(clk),
        .ena(en),
        .wea(we[0]),
        .addra(addr),
        .dina(datain),
        .addrb(addr),
        .doutb(dataout)
    );
    assign mbist_so_o = mbist_si_i;
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    ic_ram_sub ic_ram_sub0 (
        .clk(clk),
        .ena(en),
        .wea(we[0]),
        .addra(addr),
        .dina(datain),
        .addrb(addr),
        .doutb(dataout)
    );
endmodule
`endif
`else
`ifdef OR1200_IC_1W_512B
`ifdef OR1200_BIST
module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_128x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[6:0]),
        .di(datain),
        .doq(dataout),
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    );
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_128x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[6:0]),
        .di(datain),
        .doq(dataout)
    );
endmodule
`endif
`elsif OR1200_IC_1W_4KB
`ifdef OR1200_BIST
module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_1024x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[9:0]),
        .di(datain),
        .doq(dataout),
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    );
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_1024x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[9:0]),
        .di(datain),
        .doq(dataout)
    );
endmodule
`endif
`elsif OR1200_IC_1W_8KB
`ifdef OR1200_BIST
module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_2048x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[10:0]),
        .di(datain),
        .doq(dataout),
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    );
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_2048x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[10:0]),
        .di(datain),
        .doq(dataout)
    );
endmodule
`endif
`else
// No cache size defined, default to 2048x32
`ifdef OR1200_BIST
module or1200_ic_ram(
    input clk, rst,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_2048x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[10:0]),
        .di(datain),
        .doq(dataout),
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    );
endmodule
`else
module or1200_ic_ram(
    input clk, rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    or1200_spram_2048x32 spram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we[0]),
        .oe(1'b1),
        .addr(addr[10:0]),
        .di(datain),
        .doq(dataout)
    );
endmodule
`endif
`endif
`endif
