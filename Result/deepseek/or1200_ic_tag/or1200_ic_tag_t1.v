`timescale 1ns / 1ps

module or1200_ic_tag (
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
    // No instruction cache implemented
    assign tag   = 19'd0;
    assign tag_v = 1'b0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else
`ifdef OR1200_RAM_MODELS_VIRTEX
    // Virtex-specific RAM implementation
    wire [19:0] doutb;

    ic_tag_sub ic_tag_sub_inst (
        .clk    (clk),
        .en     (en),
        .we     (we),
        .addr   (addr),
        .di     (datain),
        .dout   (doutb)
    );

    assign tag   = doutb[19:1];
    assign tag_v = doutb[0];

`else
    // Generic RAM implementation
    wire [19:0] ram_dout;
    assign tag   = ram_dout[19:1];
    assign tag_v = ram_dout[0];

    // Select RAM macro based on cache size configuration
`ifdef OR1200_IC_1W_512B
    or1200_spram_32x24 ic_tag_ram (
        .clk (clk),
        .rst (rst),
        .ce  (en),
        .we  (we),
        .oe  (1'b1),
        .addr(addr),
        .di  (datain),
        .doq (ram_dout)
    );
`elsif OR1200_IC_1W_4KB
    or1200_spram_256x21 ic_tag_ram (
        .clk (clk),
        .rst (rst),
        .ce  (en),
        .we  (we),
        .oe  (1'b1),
        .addr(addr),
        .di  (datain),
        .doq (ram_dout)
    );
`elsif OR1200_IC_1W_8KB
    or1200_spram_512x20 ic_tag_ram (
        .clk (clk),
        .rst (rst),
        .ce  (en),
        .we  (we),
        .oe  (1'b1),
        .addr(addr),
        .di  (datain),
        .doq (ram_dout)
    );
`else
    // Default to the smallest RAM or a generic placeholder if no cache size defined
    or1200_spram_32x24 ic_tag_ram (
        .clk (clk),
        .rst (rst),
        .ce  (en),
        .we  (we),
        .oe  (1'b1),
        .addr(addr),
        .di  (datain),
        .doq (ram_dout)
    );
`endif

`endif // OR1200_RAM_MODELS_VIRTEX
`endif // OR1200_NO_IC

endmodule
