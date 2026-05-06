`timescale 1ns / 1ps

module or1200_dc_tag (
    input               clk,
    input               rst,
`ifdef OR1200_BIST
    input               mbist_si_i,
    output              mbist_so_o,
    input  [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    input  [8:0]        addr,
    input               en,
    input               we,
    input  [19:0]       datain,
    output              tag_v,
    output [18:0]       tag
);

`ifdef OR1200_NO_DC
    assign tag   = 19'd0;
    assign tag_v = 1'b0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else // OR1200_NO_DC not defined

`ifdef OR1200_RAM_MODELS_VIRTEX
    wire [19:0] doutb;

    dc_tag_sub u_dc_tag_sub (
        .clk    (clk),
        .addr   (addr),
        .en     (en),
        .we     (we),
        .datain (datain),
        .doutb  (doutb)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_ctrl_i (mbist_ctrl_i),
        .mbist_so_o   (mbist_so_o)
`endif
    );

    assign tag   = doutb[19:1];
    assign tag_v = doutb[0];

`else // not OR1200_RAM_MODELS_VIRTEX

`ifdef OR1200_DC_1W_4KB
    wire [20:0] doq; // note: spram width 21 bits
    or1200_spram_256x21 u_tag_ram (
        .clk   (clk),
        .rst   (rst),
        .ce    (en),
        .we    (we),
        .addr  (addr),
        .di    ({1'b0, datain}),   // pad to 21 bits
        .doq   (doq)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_ctrl_i (mbist_ctrl_i),
        .mbist_so_o   (mbist_so_o)
`endif
    );
    assign tag   = doq[20:2];   // tag is 19 bits from bits 20 down to 2
    assign tag_v = doq[1];    // originally bit 0? but we padded so datain is at bits 19:0, but we put at bits 20:0 as {1'b0, datain}. So doq[0] would be the 0 from pad if not written? Actually we want datain[0] (valid) to be stored in bit 0 of the 21-bit word. But we padded with 1'b0 at the top. So doq[19:0] correspond to datain[19:0]. But doq[20] is the pad bit. So tag = doq[19:1] which is bits 19 down to 1 (19 bits), and tag_v = doq[0]. So adjust: tag = doq[19:1]; tag_v = doq[0].
    // However doq is 21 bits [20:0]. So doq[19:1] is 19 bits.
    assign tag   = doq[19:1];
    assign tag_v = doq[0];

`elsif OR1200_DC_1W_8KB
    wire [19:0] doq; // 20 bits
    or1200_spram_512x20 u_tag_ram (
        .clk   (clk),
        .rst   (rst),
        .ce    (en),
        .we    (we),
        .addr  (addr),
        .di    (datain),
        .doq   (doq)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_ctrl_i (mbist_ctrl_i),
        .mbist_so_o   (mbist_so_o)
`endif
    );
    assign tag   = doq[19:1];
    assign tag_v = doq[0];

`else
    // fallback: assume 4KB size (256x21)
    wire [20:0] doq;
    or1200_spram_256x21 u_tag_ram (
        .clk   (clk),
        .rst   (rst),
        .ce    (en),
        .we    (we),
        .addr  (addr),
        .di    ({1'b0, datain}),
        .doq   (doq)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_ctrl_i (mbist_ctrl_i),
        .mbist_so_o   (mbist_so_o)
`endif
    );
    assign tag   = doq[19:1];
    assign tag_v = doq[0];
`endif

`endif // OR1200_RAM_MODELS_VIRTEX

`endif // OR1200_NO_DC

endmodule
