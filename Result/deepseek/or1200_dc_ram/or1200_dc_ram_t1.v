module or1200_dc_ram (
    input clk, rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    assign dataout = 32'd0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
endmodule
`else
`ifdef OR1200_RAM_MODELS_VIRTEX
module or1200_dc_ram (
    input clk, rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
    wire en_wire;
    wire [3:0] we_wire;
    wire [10:0] addr_wire;
    wire [31:0] datain_wire;

    assign en_wire = en;
    assign we_wire = we;
    assign addr_wire = addr;
    assign datain_wire = datain;

    dc_ram_sub dc_ram_sub (
        .clk(clk),
        .en_a(en_wire),
        .we_a(we_wire),
        .addr_a(addr_wire),
        .di_a(datain_wire),
        .addr_b(addr_wire),
        .do_b(dataout)
    );
endmodule
`else
module or1200_dc_ram (
    input clk, rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);
`ifdef OR1200_DC_1W_4KB
    or1200_spram_1024x32_bw ram (
        .clk(clk),
        .rst(rst),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(dataout)
    );
`elsif OR1200_DC_1W_8KB
    or1200_spram_2048x32_bw ram (
        .clk(clk),
        .rst(rst),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .ce(en),
        .we(we),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(dataout)
    );
`else
    // No valid cache size selected, but not NO_DC either.
    // Provide a safe fallback: zero output, no storage.
    assign dataout = 32'd0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`endif
endmodule
`endif
`endif
