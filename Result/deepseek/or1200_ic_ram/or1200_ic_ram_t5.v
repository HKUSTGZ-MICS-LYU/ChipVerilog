`timescale 1ns/1ps

module or1200_ic_ram (
    input clk,
    input rst,
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
    wire [0:0] we_wire;
    wire [10:0] addr_wire;
    wire [31:0] datain_wire;
    wire [31:0] dataout_wire;

    assign en_wire = en;
    assign we_wire = we[0];
    assign addr_wire = addr;
    assign datain_wire = datain;

`ifdef OR1200_NO_IC
    assign dataout = 32'h0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`elsif OR1200_RAM_MODELS_VIRTEX
    ic_ram_sub ram_inst (
        .clk(clk),
        .ena(en_wire),
        .wea(we_wire),
        .addra(addr_wire),
        .addrb(addr_wire),
        .dina(datain_wire),
        .doutb(dataout)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`else
    // Generic RAM path
`ifdef OR1200_IC_1W_512B
    or1200_spram_128x32 ram_inst (
`elsif OR1200_IC_1W_4KB
    or1200_spram_1024x32 ram_inst (
`elsif OR1200_IC_1W_8KB
    or1200_spram_2048x32 ram_inst (
`else
    // Default: smallest
    or1200_spram_128x32 ram_inst (
`endif
        .clk(clk),
        .rst(rst),
        .ce(en_wire),
        .we(we_wire),
        .addr(addr_wire),
        .di(datain_wire),
        .doq(dataout),
        .oe(1'b1)
    `ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
    `endif
    );
`endif

endmodule
