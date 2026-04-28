`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_immu_tlb (
    input         clk,
    input         rst,

    // Translation i/f
    input         tlb_en,
    input  [31:0] vaddr,
    output        hit,
    output [31:13] ppn,
    output        uxe,
    output        sxe,
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
    wire [12:0] vpn;   // tlb_mr_ram_out[13:1]
    wire        v;     // tlb_mr_ram_out[0]

    wire [5:0]  tlb_index;
    wire        tlb_mr_en, tlb_mr_we;
    wire [13:0] tlb_mr_ram_in;
    wire [13:0] tlb_mr_ram_out;

    wire        tlb_tr_en, tlb_tr_we;
    wire [21:0] tlb_tr_ram_in;
    wire [21:0] tlb_tr_ram_out;

`ifdef OR1200_BIST
    wire itlb_mr_ram_si = mbist_si_i;
    wire itlb_mr_ram_so;
    wire itlb_tr_ram_si = itlb_mr_ram_so;
    wire itlb_tr_ram_so;
    assign mbist_so_o = itlb_tr_ram_so;
`endif

    //--------------------------------------------------------------------------
    // TLB index: SPR has priority
    //--------------------------------------------------------------------------
    assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

    //--------------------------------------------------------------------------
    // MR RAM control
    //--------------------------------------------------------------------------
    assign tlb_mr_en  = tlb_en | (spr_cs & ~spr_addr[7]);
    assign tlb_mr_we  = spr_cs & spr_write & ~spr_addr[7];
    // Write data: {vpn[31:19](13b), v(1b)}
    assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

    //--------------------------------------------------------------------------
    // TR RAM control
    //--------------------------------------------------------------------------
    assign tlb_tr_en  = tlb_en | (spr_cs & spr_addr[7]);
    assign tlb_tr_we  = spr_cs & spr_write & spr_addr[7];
    // Write data: {ppn[31:13](19b), uxe(1b), sxe(1b), ci(1b)} = 22b
    assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

    //--------------------------------------------------------------------------
    // Decode MR RAM output
    //--------------------------------------------------------------------------
    assign vpn = tlb_mr_ram_out[13:1];
    assign v   = tlb_mr_ram_out[0];

    //--------------------------------------------------------------------------
    // Decode TR RAM output
    //--------------------------------------------------------------------------
    assign ppn = tlb_tr_ram_out[21:3];
    assign uxe = tlb_tr_ram_out[2];
    assign sxe = tlb_tr_ram_out[1];
    assign ci  = tlb_tr_ram_out[0];

    //--------------------------------------------------------------------------
    // Hit (not gated by tlb_en)
    //--------------------------------------------------------------------------
    assign hit = (vpn == vaddr[31:19]) & v;

    //--------------------------------------------------------------------------
    // SPR read data (not gated by spr_cs)
    //--------------------------------------------------------------------------
    assign spr_dat_o =
        (~spr_write & ~spr_addr[7]) ?
            // MR readback: {vpn[31:19], index&v, zeros, v}
            {vpn, (tlb_index & {6{v}}), 12'h0, v} :
        (~spr_write & spr_addr[7]) ?
            // TR readback: {ppn[31:13], zeros, uxe, sxe, zeros, ci, 0}
            {ppn, 3'b0, uxe, sxe, 3'b0, ci, 1'b0} :
        32'h0000_0000;

    //--------------------------------------------------------------------------
    // RAM instantiation
    //--------------------------------------------------------------------------
`ifdef OR1200_RAM_MODELS_VIRTEX

    // Virtex intermediate wires
    wire        tlb_tr_en_wire     = tlb_tr_en;
    wire [0:0]  tlb_tr_we_wire     = tlb_tr_we;
    wire [5:0]  tlb_index_wire     = tlb_index;
    wire [21:0] tlb_tr_ram_in_wire = tlb_tr_ram_in;
    wire        tlb_mr_en_wire     = tlb_mr_en;
    wire [0:0]  tlb_mr_we_wire     = tlb_mr_we;
    wire [13:0] tlb_mr_ram_in_wire = tlb_mr_ram_in;

    itlb_tr_sub itlb_tr_sub (
        .clka  (clk),
        .ena   (tlb_tr_en_wire),
        .wea   (tlb_tr_we_wire),
        .addra (tlb_index_wire),
        .dia   (tlb_tr_ram_in_wire),
        .clkb  (clk),
        .addrb (tlb_index_wire),
        .dob   (tlb_tr_ram_out)
    );

    itlb_mr_sub itlb_mr_sub (
        .clka  (clk),
        .ena   (tlb_mr_en_wire),
        .wea   (tlb_mr_we_wire),
        .addra (tlb_index_wire),
        .dia   (tlb_mr_ram_in_wire),
        .clkb  (clk),
        .addrb (tlb_index_wire),
        .dob   (tlb_mr_ram_out)
    );

`else

    or1200_spram_64x22 or1200_itlb_tr (
        .clk  (clk),
        .rst  (rst),
        .ce   (tlb_tr_en),
        .we   (tlb_tr_we),
        .oe   (1'b1),
        .addr (tlb_index),
        .di   (tlb_tr_ram_in),
        .doq  (tlb_tr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (itlb_tr_ram_si),
        .mbist_so_o   (itlb_tr_ram_so),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

    or1200_spram_64x14 or1200_itlb_mr (
        .clk  (clk),
        .rst  (rst),
        .ce   (tlb_mr_en),
        .we   (tlb_mr_we),
        .oe   (1'b1),
        .addr (tlb_index),
        .di   (tlb_mr_ram_in),
        .doq  (tlb_mr_ram_out)
`ifdef OR1200_BIST
        ,
        .mbist_si_i   (itlb_mr_ram_si),
        .mbist_so_o   (itlb_mr_ram_so),
        .mbist_ctrl_i (mbist_ctrl_i)
`endif
    );

`endif

endmodule