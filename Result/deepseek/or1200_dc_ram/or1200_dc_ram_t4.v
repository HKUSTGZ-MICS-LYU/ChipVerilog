module or1200_dc_ram(
    // Reset and clock
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);

`ifdef OR1200_NO_DC

    assign dataout = 32'd0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`elsif OR1200_RAM_MODELS_VIRTEX

    wire [10:0] addr_wire;
    wire [3:0] we_wire;
    wire [31:0] datain_wire;
    wire en_wire;

    assign addr_wire = addr;
    assign we_wire = we;
    assign datain_wire = datain;
    assign en_wire = en;

    wire [31:0] dataout_virtex;

    dc_ram_sub u_dc_ram_sub(
        .clk(clk),
        .a_addr(addr_wire),
        .a_en(en_wire),
        .a_we(we_wire),
        .a_din(datain_wire),
        .b_addr(addr_wire),
        .b_dout(dataout_virtex)
    );

    assign dataout = dataout_virtex;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else
    // Generic RAM path
    // Instantiate appropriate RAM macro based on cache size configuration

`ifdef OR1200_DC_1W_4KB
    or1200_spram_1024x32_bw u_dc_ram(
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(dataout)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
`elsif OR1200_DC_1W_8KB
    or1200_spram_2048x32_bw u_dc_ram(
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(dataout)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
`else
    // No valid configuration defined; tie outputs to zero
    assign dataout = 32'd0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`endif   // OR1200_DC_1W_*KB

`endif   // OR1200_NO_DC / VIRTEX / default

endmodule
