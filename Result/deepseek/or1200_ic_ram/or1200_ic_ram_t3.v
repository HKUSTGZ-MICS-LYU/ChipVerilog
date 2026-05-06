module or1200_ic_ram(
    input clk,
    input rst,
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output reg [31:0] dataout,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

`ifdef OR1200_NO_IC

    // No instruction cache: dataout always zero
    always @* dataout = 32'd0;

`ifdef OR1200_BIST
    // BIST bypass
    assign mbist_so_o = mbist_si_i;
`endif

`elsif OR1200_RAM_MODELS_VIRTEX

    // Virtex-specific RAM
    ic_ram_sub inst (
        .clk(clk),
        .ena(en),
        .wea(we[0]),
        .addra(addr),
        .addrb(addr),
        .dina(datain),
        .doutb(dataout)
    );

`else // Generic RAM path

    wire we_wire = we[0];
    wire [31:0] doq;

    // Select RAM depth based on cache size
`ifdef OR1200_IC_1W_512B
    or1200_spram_128x32 #(
`ifdef OR1200_BIST
        .BIST(1)
`else
        .BIST(0)
`endif
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we_wire),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(doq)
`ifdef OR1200_BIST
        ,.mbist_si(mbist_si_i),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );
`elsif OR1200_IC_1W_4KB
    or1200_spram_1024x32 #(
`ifdef OR1200_BIST
        .BIST(1)
`else
        .BIST(0)
`endif
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we_wire),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(doq)
`ifdef OR1200_BIST
        ,.mbist_si(mbist_si_i),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );
`elsif OR1200_IC_1W_8KB
    or1200_spram_2048x32 #(
`ifdef OR1200_BIST
        .BIST(1)
`else
        .BIST(0)
`endif
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we_wire),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(doq)
`ifdef OR1200_BIST
        ,.mbist_si(mbist_si_i),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );
`else
    // Default: no cache size defined, use smallest to avoid error
    or1200_spram_128x32 #(
`ifdef OR1200_BIST
        .BIST(1)
`else
        .BIST(0)
`endif
    ) ram_inst (
        .clk(clk),
        .rst(rst),
        .ce(en),
        .we(we_wire),
        .oe(1'b1),
        .addr(addr),
        .di(datain),
        .doq(doq)
`ifdef OR1200_BIST
        ,.mbist_si(mbist_si_i),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
`endif
    );
`endif

    always @* dataout = doq;

`endif
endmodule
