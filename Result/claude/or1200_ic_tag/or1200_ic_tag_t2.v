module or1200_ic_tag(
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
    assign tag_v = 1'b0;
    assign tag = 19'b0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`else
    wire [19:0] doutb;

    or1200_spram_512x20 ic_tag_ram(
        .clk(clk),
        .rst(rst),
        .ce(en),
        .oe(1'b1),
        .addr(addr),
        .we(we),
        .di(datain),
        .doq(doutb)
    );

    assign tag_v = doutb[0];
    assign tag = doutb[19:1];

`ifdef OR1200_BIST
    assign mbist_so_o = 1'b0;
`endif
`endif

endmodule
