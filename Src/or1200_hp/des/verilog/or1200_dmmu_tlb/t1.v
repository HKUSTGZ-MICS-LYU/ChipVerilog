`include "timescale.v"
`include "or1200_defines.v"

module or1200_dmmu_tlb(
    clk, rst,
    tlb_en, vaddr, hit, ppn, uwe, ure, swe, sre, ci,
`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o
);

input         clk, rst;
input         tlb_en;
input  [31:0] vaddr;
output        hit;
output [31:13] ppn;
output        uwe, ure, swe, sre, ci;
`ifdef OR1200_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif
input         spr_cs;
input         spr_write;
input  [31:0] spr_addr;
input  [31:0] spr_dat_i;
output [31:0] spr_dat_o;

// Internal wires
wire [31:19] vpn;
wire         v;
wire [5:0]   tlb_index;
wire         tlb_mr_en;
wire         tlb_mr_we;
wire [13:0]  tlb_mr_ram_in;
wire [13:0]  tlb_mr_ram_out;
wire         tlb_tr_en;
wire         tlb_tr_we;
wire [23:0]  tlb_tr_ram_in;
wire [23:0]  tlb_tr_ram_out;

`ifdef OR1200_BIST
wire dtlb_mr_ram_si, dtlb_mr_ram_so;
wire dtlb_tr_ram_si, dtlb_tr_ram_so;
assign dtlb_mr_ram_si = mbist_si_i;
assign dtlb_tr_ram_si = dtlb_mr_ram_so;
assign mbist_so_o     = dtlb_tr_ram_so;
`endif

// Enable/write-enable generation
assign tlb_mr_en = tlb_en | (spr_cs & !spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & !spr_addr[7];
assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];

// Index: SPR has priority
assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

// Match RAM input: {vpn[31:19], v}
assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

// Match RAM output decode
assign vpn = tlb_mr_ram_out[13:1];
assign v   = tlb_mr_ram_out[0];

// Translate RAM input: {ppn[31:13], swe, sre, uwe, ure, ci}
assign tlb_tr_ram_in = {spr_dat_i[31:13],
                        spr_dat_i[9],
                        spr_dat_i[8],
                        spr_dat_i[7],
                        spr_dat_i[6],
                        spr_dat_i[1]};

// Translate RAM output decode
assign ppn = tlb_tr_ram_out[23:5];
assign swe = tlb_tr_ram_out[4];
assign sre = tlb_tr_ram_out[3];
assign uwe = tlb_tr_ram_out[2];
assign ure = tlb_tr_ram_out[1];
assign ci  = tlb_tr_ram_out[0];

// Hit logic (not gated by tlb_en)
assign hit = (vpn == vaddr[31:19]) & v;

// SPR readback
assign spr_dat_o =
    (!spr_write & !spr_addr[7]) ?
        {vpn, tlb_index & {`OR1200_DTLB_INDXW{v}},
         {`OR1200_DTLB_TAGW-7{1'b0}}, 1'b0, 5'b00000, v} :
    (!spr_write &  spr_addr[7]) ?
        {ppn, {`OR1200_DMMU_PS-8{1'b0}},
         swe, sre, uwe, ure, {4{1'b0}}, ci, 1'b0} :
        32'h00000000;

`ifdef OR1200_RAM_MODELS_VIRTEX

wire        tlb_tr_en_w  = tlb_tr_en;
wire [0:0]  tlb_tr_we_w  = tlb_tr_we;
wire [5:0]  tlb_index_w  = tlb_index;
wire [23:0] tlb_tr_ram_in_w = tlb_tr_ram_in;
wire        tlb_mr_en_w  = tlb_mr_en;
wire [0:0]  tlb_mr_we_w  = tlb_mr_we;
wire [13:0] tlb_mr_ram_in_w = tlb_mr_ram_in;

dtlb_tr_sub dtlb_tr_ram(
    .clka(clk), .ena(tlb_tr_en_w), .wea(tlb_tr_we_w),
    .addra(tlb_index_w), .dina(tlb_tr_ram_in_w),
    .clkb(clk), .addrb(tlb_index_w), .doutb(tlb_tr_ram_out)
);

dtlb_mr_sub dtlb_mr_ram(
    .clka(clk), .ena(tlb_mr_en_w), .wea(tlb_mr_we_w),
    .addra(tlb_index_w), .dina(tlb_mr_ram_in_w),
    .clkb(clk), .addrb(tlb_index_w), .doutb(tlb_mr_ram_out)
);

`else

or1200_spram_64x24 dtlb_tr_ram(
    .clk(clk), .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(dtlb_tr_ram_si), .mbist_so_o(dtlb_tr_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .ce(tlb_tr_en), .we(tlb_tr_we), .oe(1'b1),
    .addr(tlb_index), .di(tlb_tr_ram_in), .doq(tlb_tr_ram_out)
);

or1200_spram_64x14 dtlb_mr_ram(
    .clk(clk), .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(dtlb_mr_ram_si), .mbist_so_o(dtlb_mr_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .ce(tlb_mr_en), .we(tlb_mr_we), .oe(1'b1),
    .addr(tlb_index), .di(tlb_mr_ram_in), .doq(tlb_mr_ram_out)
);

`endif

endmodule