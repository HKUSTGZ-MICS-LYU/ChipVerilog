module or1200_ic_tag(
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    input [8:0] addr,
    input en,
    input we,
    input [19:0] datain,
    output tag_v,
    output [18:0] tag
);
`ifdef OR1200_NO_IC
    // No instruction cache: outputs are zero, MBIST passthrough
    assign tag_v = 1'b0;
    assign tag = {19{1'b0}};
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`elsif OR1200_RAM_MODELS_VIRTEX
    wire [19:0] doutb;
    ic_tag_sub u_ic_tag_sub (
        .clk(clk),
        .en(en),
        .we(we),
        .addr(addr),
        .datain(datain),
        .doutb(doutb)
    );
    assign tag = doutb[19:1];
    assign tag_v = doutb[0];
`else
    // Generic RAM path
`ifdef OR1200_IC_1W_512B
    or1200_spram_32x24 u_ram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq({tag, tag_v})
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
`elsif OR1200_IC_1W_4KB
    or1200_spram_256x21 u_ram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq({tag, tag_v})
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
`elsif OR1200_IC_1W_8KB
    or1200_spram_512x20 u_ram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq({tag, tag_v})
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
`else
    // Default: placeholder (should not happen in valid config)
    assign tag = {19{1'bx}};
    assign tag_v = 1'bx;
`endif
`endif

endmodule
