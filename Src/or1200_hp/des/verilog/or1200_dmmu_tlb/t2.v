`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_dmmu_tlb (
    input         clk,
    input         rst,

    // Translation i/f
    input         tlb_en,
    input  [31:0] vaddr,
    output        hit,
    output [31:13] ppn,
    output        uwe,
    output        ure,
    output        swe,
    output        sre,
    output        ci,

`ifdef OR1200_BIST
    input                                mbist_si_i,
    output                               mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif

    // SPR access
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

    //--------------------------------------------------------------------------
    // Internal wires
    //--------------------------------------------------------------------------
    wire [`OR1200_DTLB_INDXW-1:0] tlb_index;
    wire [13:0] tlb_mr_ram_out;   // {vpn[13:1], v}  = 13+1 = 14b
    wire [23:0] tlb_tr_ram_out;   // {ppn[19:0], swe, sre, uwe, ure, ci} = 19+1+4+1=?
                                   // ppn[31:13]=19b, swe,sre,uwe,ure=4b, ci=1b → 24b

    wire        tlb_mr_en, tlb_mr_we;
    wire        tlb_tr_en, tlb_tr_we;

    wire [12:0] tlb_mr_din;   // {vpn[31:19](13b), v(1b)} → 14b stored
    wire [23:0] tlb_tr_din;   // {ppn[31:13](19b), swe,sre,uwe,ure(4b), ci(1b)} → 24b

    // Decoded fields from match RAM
    wire [12:0] vpn;
    wire        v;

    // Decoded fields from translate RAM
    // tlb_tr_ram_out[23:5]=ppn[31:13](19b), [4]=swe,[3]=sre,[2]=uwe,[1]=ure,[0]=ci

`ifdef OR1200_BIST
    wire mbist_mr_so, mbist_tr_so;
    assign mbist_so_o = mbist_tr_so;
`endif

    //--------------------------------------------------------------------------
    // TLB index selection: SPR has priority over tlb_en
    //--------------------------------------------------------------------------
    assign tlb_index = spr_cs ? spr_addr[`OR1200_DTLB_INDXW-1:0]
                               : vaddr[`OR1200_DTLB_INDXW+12:13];

    //--------------------------------------------------------------------------
    // Match RAM enable/write
    //--------------------------------------------------------------------------
    assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
    assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];

    // Match RAM write data: {vpn[31:19](13b), v(1b)}
    assign tlb_mr_din = {spr_dat_i[31:19], spr_dat_i[0]};

    //--------------------------------------------------------------------------
    // Translate RAM enable/write
    //--------------------------------------------------------------------------
    assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
    assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];

    // Translate RAM write data: {ppn[31:13](19b), swe,sre,uwe,ure(4b), ci(1b)}
    assign tlb_tr_din = {spr_dat_i[31:13],
                         spr_dat_i[9], spr_dat_i[8],
                         spr_dat_i[7], spr_dat_i[6],
                         spr_dat_i[1]};

    //--------------------------------------------------------------------------
    // Decode match RAM output
    //--------------------------------------------------------------------------
    assign vpn = tlb_mr_ram_out[13:1];
    assign v   = tlb_mr_ram_out[0];

    //--------------------------------------------------------------------------
    // Hit generation (not gated by tlb_en)
    //--------------------------------------------------------------------------
    assign hit = (vpn == vaddr[31:19]) & v;

    //--------------------------------------------------------------------------
    // Decode translate RAM output
    //--------------------------------------------------------------------------
    assign ppn = tlb_tr_ram_out[23:5];
    assign swe = tlb_tr_ram_out[4];
    assign sre = tlb_tr_ram_out[3];
    assign uwe = tlb_tr_ram_out[2];
    assign ure = tlb_tr_ram_out[1];
    assign ci  = tlb_tr_ram_out[0];

    //--------------------------------------------------------------------------
    // SPR read data
    //--------------------------------------------------------------------------
    assign spr_dat_o =
        (spr_cs & ~spr_write & ~spr_addr[7]) ?
            // Match register readback
            {vpn, {`OR1200_DTLB_INDXW{1'b0}},
             {(13-`OR1200_DTLB_INDXW){1'b0}},
             (tlb_index & {`OR1200_DTLB_INDXW{v}}),
             5'b0, v} :
        (spr_cs & ~spr_write & spr_addr[7]) ?
            // Translate register readback: {ppn,zeros,swe,sre,uwe,ure,zeros,ci,0}
            {ppn, 3'b0, swe, sre, uwe, ure, 3'b0, ci, 1'b0} :
        32'h0000_0000;

    //--------------------------------------------------------------------------
    // RAM instantiation
    //--------------------------------------------------------------------------
`ifdef OR1200_RAM_MODELS_VIRTEX

    dtlb_mr_ram dtlb_mr_ram (
        .clka  (clk), .ena  (tlb_mr_en), .wea  (tlb_mr_we),
        .addra (tlb_index), .dia  (tlb_mr_din),
        .clkb  (clk), .addrb(tlb_index), .dob  (tlb_mr_ram_out)
    );

    dtlb_tr_ram dtlb_tr_ram (
        .clka  (clk), .ena  (tlb_tr_en), .wea  (tlb_tr_we),
        .addra (tlb_index), .dia  (tlb_tr_din),
        .clkb  (clk), .addrb(tlb_index), .dob  (tlb_tr_ram_out)
    );

`else

    or1200_spram_64x14 or1200_dtlb_mr (
        .clk  (clk),
        .rst  (rst),
        .ce   (tlb_mr_en),
        .we   (tlb_mr_we),
        .oe   (1'b1),
        .addr (tlb_index),
        .di   (tlb_mr_din),
        .doq  (tlb_mr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_mr_so),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

    or1200_spram_64x24 or1200_dtlb_tr (
        .clk  (clk),
        .rst  (rst),
        .ce   (tlb_tr_en),
        .we   (tlb_tr_we),
        .oe   (1'b1),
        .addr (tlb_index),
        .di   (tlb_tr_din),
        .doq  (tlb_tr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (mbist_mr_so),
        .mbist_so_o   (mbist_tr_so),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`endif

endmodule