`ifdef OR1200_NO_DC
  assign dataout = 32'd0;
  `ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
  `endif
`elsif OR1200_RAM_MODELS_VIRTEX
  wire        en_wire;
  wire [3:0]  we_wire;
  wire [10:0] addr_wire;
  wire [31:0] datain_wire;

  assign en_wire    = en;
  assign we_wire    = we;
  assign addr_wire  = addr;
  assign datain_wire = datain;

  dc_ram_sub dc_ram_sub_i (
    .clk(clk),
    .en_a(en_wire),
    .we_a(we_wire),
    .addr_a(addr_wire),
    .di_a(datain_wire),
    .addr_b(addr_wire),
    .do_b(dataout)
  );
`else
  `ifdef OR1200_DC_1W_4KB
    or1200_spram_1024x32_bw #(
      .addr_width(10)
    ) spram_i (
      .clk(clk),
      .rst(rst),
      .ce(en),
      .we(we),
      .oe(1'b1),
      .addr(addr[9:0]),
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
    or1200_spram_2048x32_bw #(
      .addr_width(11)
    ) spram_i (
      .clk(clk),
      .rst(rst),
      .ce(en),
      .we(we),
      .oe(1'b1),
      .addr(addr[10:0]),
      .di(datain),
      .doq(dataout)
      `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
      `endif
    );
  `endif
`endif
