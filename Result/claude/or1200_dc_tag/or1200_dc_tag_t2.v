module or1200_dc_tag(
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

`ifdef OR1200_NO_DC
    assign tag_v = 1'b0;
    assign tag = 19'b0;
    
    `ifdef OR1200_BIST
        assign mbist_so_o = mbist_si_i;
    `endif

`else

    wire [19:0] doutb;

    `ifdef OR1200_VIRTEX
        
        assign tag_v = doutb[0];
        assign tag = doutb[19:1];
        
        `ifdef OR1200_BIST
            
            or1200_dc_tag_bist u_bist(
                .clk(clk),
                .rst(rst),
                .mbist_si_i(mbist_si_i),
                .mbist_so_o(mbist_so_o),
                .mbist_ctrl_i(mbist_ctrl_i),
                .tag_ram_addr(addr),
                .tag_ram_en(en),
                .tag_ram_we(we),
                .tag_ram_din(datain),
                .tag_ram_dout(doutb)
            );
        `else
            
            or1200_dc_tag_virtex u_tag_ram(
                .clk(clk),
                .rst(rst),
                .addr(addr),
                .en(en),
                .we(we),
                .din(datain),
                .dout(doutb)
            );
        `endif

    `else
        
        assign tag_v = doutb[0];
        assign tag = doutb[19:1];

        `ifdef OR1200_BIST
            
            or1200_dc_tag_bist u_bist(
                .clk(clk),
                .rst(rst),
                .mbist_si_i(mbist_si_i),
                .mbist_so_o(mbist_so_o),
                .mbist_ctrl_i(mbist_ctrl_i),
                .tag_ram_addr(addr),
                .tag_ram_en(en),
                .tag_ram_we(we),
                .tag_ram_din(datain),
                .tag_ram_dout(doutb)
            );
        `else
            
            or1200_dc_tag_ram u_tag_ram(
                .clk(clk),
                .rst(rst),
                .addr(addr),
                .en(en),
                .we(we),
                .din(datain),
                .dout(doutb)
            );
        `endif

    `endif

`endif

endmodule

module or1200_dc_tag_ram(
    input clk,
    input rst,
    input [8:0] addr,
    input en,
    input we,
    input [19:0] din,
    output [19:0] dout
);

or1200_spram_512x20 u_ram(
    .clk(clk),
    .rst(rst),
    .ce(en),
    .we(we),
    .oe(1'b1),
    .addr(addr),
    .di(din),
    .doq(dout)
);

endmodule
