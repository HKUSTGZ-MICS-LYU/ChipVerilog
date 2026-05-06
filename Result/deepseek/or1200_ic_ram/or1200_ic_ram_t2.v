// No instruction cache
  assign dataout = 32'h0;
  `ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
  `endif
`elsif OR1200_RAM_MODELS_VIRTEX
  // Virtex RAM model
  ic_ram_sub ic_ram_sub_inst (
    .clk(clk),
    .ena(en),
    .wea(we[0]),
    .addra(addr),
    .dina(datain),
    .addrb(addr),
    .doutb(dataout)
  );
`else
  // Generic RAM model
  `ifdef OR1200_IC_1W_512B
    or1200_spram_128x32 ic_ram_inst (
      .clk(clk),
      .rst(rst),
      .ce(en),
      .we(we[0]),
      .oe(1'b1),
      .addr(addr),
      .di(datain),
      .doq(dataout)
    );
  `elsif OR1200_IC_1W_4KB
    or1200_spram_1024x32 ic_ram_inst (
      .clk(clk),
      .rst(rst),
      .ce(en),
      .we(we[0]),
      .oe(1'b1),
      .addr(addr),
      .di(datain),
      .doq(dataout)
    );
  `elsif OR1200_IC_1W_8KB
    or1200_spram_2048x32 ic_ram_inst (
      .clk(clk),
      .rst(rst),
      .ce(en),
      .we(we[0]),
      .oe(1'b1),
      .addr(addr),
      .di(datain),
      .doq(dataout)
    );
  `endif
  `ifdef OR1200_BIST
    // BIST connections for generic RAM
    `ifdef OR1200_IC_1W_512B
      assign mbist_so_o = ic_ram_inst.mbist_so_o;
    `elsif OR1200_IC_1W_4KB
      assign mbist_so_o = ic_ram_inst.mbist_so_o;
    `elsif OR1200_IC_1W_8KB
      assign mbist_so_o = ic_ram_inst.mbist_so_o;
    `endif
  `endif
`endif
