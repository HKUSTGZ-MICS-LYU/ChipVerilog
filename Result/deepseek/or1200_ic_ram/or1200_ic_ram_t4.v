`ifdef OR1200_NO_IC
    assign dataout = 32'd0;
    `ifdef OR1200_BIST
        assign mbist_so_o = mbist_si_i;
    `endif
`elsif OR1200_RAM_MODELS_VIRTEX
    ic_ram_sub u_ic_ram_sub (
        .clka(clk),
        .clkb(clk),
        .ena(en),
        .wea(we[0]),
        .addra(addr),
        .dina(datain),
        .addrb(addr),
        .doutb(dataout)
        `ifdef OR1200_BIST
        ,
        .mbist_si(mbist_si_i),
        .mbist_so(mbist_so_o),
        .mbist_ctrl(mbist_ctrl_i)
        `endif
    );
`else
    `ifdef OR1200_IC_1W_512B
        or1200_spram_128x32 u_ram (
            .clk(clk),
            .rst(rst),
            .ce(en),
            .we(we[0]),
            .addr(addr),
            .di(datain),
            .doq(dataout),
            .oe(1'b1)
            `ifdef OR1200_BIST
            ,
            .mbist_si(mbist_si_i),
            .mbist_so(mbist_so_o),
            .mbist_ctrl(mbist_ctrl_i)
            `endif
        );
    `elsif OR1200_IC_1W_4KB
        or1200_spram_1024x32 u_ram (
            .clk(clk),
            .rst(rst),
            .ce(en),
            .we(we[0]),
            .addr(addr),
            .di(datain),
            .doq(dataout),
            .oe(1'b1)
            `ifdef OR1200_BIST
            ,
            .mbist_si(mbist_si_i),
            .mbist_so(mbist_so_o),
            .mbist_ctrl(mbist_ctrl_i)
            `endif
        );
    `elsif OR1200_IC_1W_8KB
        or1200_spram_2048x32 u_ram (
            .clk(clk),
            .rst(rst),
            .ce(en),
            .we(we[0]),
            .addr(addr),
            .di(datain),
            .doq(dataout),
            .oe(1'b1)
            `ifdef OR1200_BIST
            ,
            .mbist_si(mbist_si_i),
            .mbist_so(mbist_so_o),
            .mbist_ctrl(mbist_ctrl_i)
            `endif
        );
    `else
        or1200_spram_2048x32 u_ram (
            .clk(clk),
            .rst(rst),
            .ce(en),
            .we(we[0]),
            .addr(addr),
            .di(datain),
            .doq(dataout),
            .oe(1'b1)
            `ifdef OR1200_BIST
            ,
            .mbist_si(mbist_si_i),
            .mbist_so(mbist_so_o),
            .mbist_ctrl(mbist_ctrl_i)
            `endif
        );
    `endif
`endif

endmodule
