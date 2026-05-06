`include "or1200_defines.v"

module or1200_ic_tag(
    // Clock and reset
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input [8:0] addr,
    input en,
    input we,
    input [19:0] datain,
    output tag_v,
    output [18:0] tag
);

`ifdef OR1200_NO_IC

    // No instruction cache: permanently invalid
    assign tag = {19{1'b0}};
    assign tag_v = 1'b0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`elsif OR1200_RAM_MODELS_VIRTEX

    // Virtex-specific RAM implementation
    wire [19:0] doutb;

    ic_tag_sub u_ic_tag_sub (
        .clk   (clk),
        .en    (en),
        .we    (we),
        .addr  (addr),
        .din   (datain),
        .doutb (doutb)
    );

    assign tag   = doutb[19:1];
    assign tag_v = doutb[0];

`ifdef OR1200_BIST
    assign mbist_so_o = 1'b0;
`endif

`else

    // Generic RAM implementation
    // Select RAM macro based on cache size configuration

`ifdef OR1200_IC_1W_512B

    or1200_spram_32x24 #(
        .aw(5),
        .dw(24)
    ) u_spram (
        .clk  (clk),
        .rst  (rst),
        .ce   (en),
        .we   (we),
        .oe   (1'b1),
        .addr (addr[4:0]),
        .di   ({4'b0, datain}),   // Pad to 24 bits (upper bits unused)
        .doq  ({doq_hi, tag, tag_v}), // doq is 24 bits
`ifdef OR1200_BIST
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

    // doq_hi bits are unused (bits 23:20)
    wire [3:0] doq_hi;

`elsif OR1200_IC_1W_4KB

    or1200_spram_256x21 #(
        .aw(8),
        .dw(21)
    ) u_spram (
        .clk  (clk),
        .rst  (rst),
        .ce   (en),
        .we   (we),
        .oe   (1'b1),
        .addr (addr[7:0]),
        .di   ({1'b0, datain}),   // Pad to 21 bits (bit 20 unused)
        .doq  ({doq_bit, tag, tag_v}), // doq is 21 bits
`ifdef OR1200_BIST
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

    wire doq_bit;  // unused bit [20]

`elsif OR1200_IC_1W_8KB

    or1200_spram_512x20 #(
        .aw(9),
        .dw(20)
    ) u_spram (
        .clk  (clk),
        .rst  (rst),
        .ce   (en),
        .we   (we),
        .oe   (1'b1),
        .addr (addr[8:0]),
        .di   (datain),
        .doq  ({tag, tag_v}),
`ifdef OR1200_BIST
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`else

    // No valid cache size configuration: default to invalid outputs
    assign tag   = {19{1'b0}};
    assign tag_v = 1'b0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`endif // OR1200_IC_1W_*

`endif // OR1200_NO_IC / VIRTEX / generic

endmodule
