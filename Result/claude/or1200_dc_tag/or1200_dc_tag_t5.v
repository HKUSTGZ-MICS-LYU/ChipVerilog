//////////////////////////////////////////////////////////////////////
////                                                              ////
////  OR1200 Data Cache — Tag RAM Wrapper                         ////
////                                                              ////
////  Stores tag[18:0] and valid bit tag_v per cache index.       ////
////  Selects between no-DC stub, Virtex RAM model, or generic    ////
////  single-port SPRAM based on compile-time macros.             ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "or1200_defines.v"

module or1200_dc_tag (
    // Clock and reset
    input        clk,
    input        rst,

`ifdef OR1200_BIST
    // RAM BIST
    input                                mbist_si_i,
    output                               mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input  [8:0]  addr,
    input         en,
    input         we,
    input  [19:0] datain,
    output        tag_v,
    output [18:0] tag
);

// ====================================================================
// Path 1 — Data cache disabled (OR1200_NO_DC)
// ====================================================================
`ifdef OR1200_NO_DC

    assign tag   = 19'h0;
    assign tag_v = 1'b0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

// ====================================================================
// Path 2 — Virtex-specific RAM model
// ====================================================================
`elsif OR1200_RAM_MODELS_VIRTEX

    wire [19:0] doutb;

    // tag occupies bits [19:1], valid bit is bit [0]
    assign tag   = doutb[19:1];
    assign tag_v = doutb[0];

    dc_tag_sub dc_tag_sub (
        // Write / Port A
        .clka   (clk),
        .ena    (en),
        .wea    (we),
        .addra  (addr),
        .dia    (datain),
        // Read / Port B
        .clkb   (clk),
        .enb    (en),
        .addrb  (addr),
        .dob    (doutb)
    );
    // MBIST signals not connected in the Virtex RAM model path.

// ====================================================================
// Path 3 — Generic single-port SPRAM
// ====================================================================
`else

`ifdef OR1200_DC_1W_8KB
    // 512 x 20 — 8 KB data cache (9-bit index, 20-bit tag+valid)
    or1200_spram_512x20 or1200_spram_512x20 (
        .clk    (clk),
        .rst    (rst),
        .ce     (en),
        .we     (we),
        .oe     (1'b1),
        .addr   (addr),
        .di     (datain),
        .doq    ({tag, tag_v})
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`else
    // Default: OR1200_DC_1W_4KB — 256 x 21 — 4 KB data cache
    or1200_spram_256x21 or1200_spram_256x21 (
        .clk    (clk),
        .rst    (rst),
        .ce     (en),
        .we     (we),
        .oe     (1'b1),
        .addr   (addr),
        .di     (datain),
        .doq    ({tag, tag_v})
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`endif  // OR1200_DC_1W_8KB

`endif  // OR1200_NO_DC / OR1200_RAM_MODELS_VIRTEX / generic

endmodule
