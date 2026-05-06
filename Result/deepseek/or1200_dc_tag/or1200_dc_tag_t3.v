`timescale 1ns / 1ps

module or1200_dc_tag(
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

`ifdef OR1200_NO_DC

    assign tag = 19'd0;
    assign tag_v = 1'b0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else // OR1200_NO_DC not defined

`ifdef OR1200_RAM_MODELS_VIRTEX

    // Virtex-specific tag RAM
    wire [19:0] doutb;
    assign tag = doutb[19:1];
    assign tag_v = doutb[0];

    // Instantiate dc_tag_sub (FPGA-specific)
    dc_tag_sub u_dc_tag_sub (
        .clka  (clk),
        .ena   (en),
        .wea   (we),
        .addra (addr),
        .dina  (datain),
        .doutb (doutb)
    );

    // No BIST connections specified for this path; connect as needed if BIST is enabled
`ifdef OR1200_BIST
    // If BIST ports are required by the macro, they would be added here.
    // Assume macro handles BIST internally; mbist_so_o driven from macro.
    // Since spec does not detail, we leave unassigned (maybe need to assign).
    // To be safe, drive mbist_so_o low or from macro if port exists.
    // For now, assign mbist_so_o = 1'b0;
    assign mbist_so_o = 1'b0;
`endif

`else // OR1200_RAM_MODELS_VIRTEX not defined

    // Generic single-port RAM macro selection based on cache size
`ifdef OR1200_DC_1W_4KB
    // 256 x 21 RAM
    wire [20:0] doq;
    assign {tag, tag_v} = doq[19:0]; // doq is 21 bits; we take lower 20 bits as {tag, tag_v}
    // Actually spec says doq({tag, tag_v}) so doq width is 20? For 21-bit, we need to map.
    // Updated: doq[19:0] = {tag, tag_v} if doq is 20 bits, but RAM is 21-bit.
    // We'll map doq[19:0] to {tag, tag_v} and ignore doq[20].
    // But spec says .doq({tag, tag_v}) meaning doq is exactly 20 bits? Contradiction.
    // To align: simulate .doq as 20-bit output, but RAM is 21-bit.
    // Better: tie unused bits.
    // I'll assume the RAM macro has 21-bit output, but we only need lower 20.
    assign {tag, tag_v} = doq[19:0]; // ignore bit 20
    wire [20:0] di;
    assign di = {1'b0, datain}; // pad to 21 bits

    or1200_spram_256x21 u_ram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .addr(addr[7:0]),
        .di(di),
        .doq(doq)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

`elsif OR1200_DC_1W_8KB
    // 512 x 20 RAM
    wire [19:0] doq;
    assign {tag, tag_v} = doq;
    wire [19:0] di;
    assign di = datain;

    or1200_spram_512x20 u_ram (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we),
        .addr(addr[8:0]),
        .di(di),
        .doq(doq)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

`else
    // Default fallback (should not happen)
    assign tag = 19'd0;
    assign tag_v = 1'b0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`endif

`endif // OR1200_RAM_MODELS_VIRTEX

`endif // OR1200_NO_DC

endmodule
