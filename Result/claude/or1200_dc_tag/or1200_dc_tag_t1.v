module or1200_dc_tag(
    input               clk,
    input               rst,
`ifdef OR1200_BIST
    input               mbist_si_i,
    output              mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    input       [8:0]   addr,
    input               en,
    input               we,
    input       [19:0]  datain,
    output              tag_v,
    output      [18:0]  tag
);

`ifdef OR1200_NO_DC

assign tag   = 19'b0;
assign tag_v = 1'b0;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_RAM_MODELS_VIRTEX

wire [19:0] doutb;

dc_tag_sub dc_tag_sub(
    .clka(clk),
    .ena(en),
    .wea(we),
    .addra(addr),
    .dina(datain),
    .clkb(clk),
    .enb(en),
    .addrb(addr),
    .doutb(doutb)
);

assign tag   = doutb[19:1];
assign tag_v = doutb[0];
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

`ifdef OR1200_DC_1W_4KB
or1200_spram_256x21 dc_tag0(
`elsif OR1200_DC_1W_8KB
or1200_spram_512x20 dc_tag0(
`else
or1200_spram_512x20 dc_tag0(
`endif
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
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

`endif

`endif

endmodule
