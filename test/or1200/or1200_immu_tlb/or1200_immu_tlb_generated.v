`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

//
// Instruction-side TLB
//

module or1200_immu_tlb(
        // Clock and reset
        clk, rst,

        // Translation interface
        tlb_en, vaddr, hit, ppn, uxe, sxe, ci,

`ifdef OR1200_BIST
        // RAM BIST
        mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

        // SPR interface
        spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o
);

//
// I/O
//

// Clock and reset
input                           clk;
input                           rst;

// Translation interface
input                           tlb_en;
input   [31:0]                  vaddr;
output                          hit;
output  [31:13]                 ppn;
output                          uxe;
output                          sxe;
output                          ci;

`ifdef OR1200_BIST
// RAM BIST
input                           mbist_si_i;
input   [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
output                          mbist_so_o;
`endif

// SPR interface
input                           spr_cs;
input                           spr_write;
input   [31:0]                  spr_addr;
input   [31:0]                  spr_dat_i;
output  [31:0]                  spr_dat_o;

//
// Internal wires
//
wire    [31:19]                 vpn;
wire                            v;
wire    [5:0]                   tlb_index;

wire                            tlb_mr_en;
wire                            tlb_mr_we;
wire    [13:0]                  tlb_mr_ram_in;
wire    [13:0]                  tlb_mr_ram_out;

wire                            tlb_tr_en;
wire                            tlb_tr_we;
wire    [21:0]                  tlb_tr_ram_in;
wire    [21:0]                  tlb_tr_ram_out;

`ifdef OR1200_BIST
wire                            itlb_mr_ram_si;
wire                            itlb_mr_ram_so;
wire                            itlb_tr_ram_si;
wire                            itlb_tr_ram_so;
`endif

//
// Entry format
//
// Match register (MR):      { vpn[31:19], v }
// Translate register (TR):  { ppn[31:13], uxe, sxe, ci }
//

//
// Enable / write-enable generation
//
assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];

assign tlb_tr_en = tlb_en | (spr_cs &  spr_addr[7]);
assign tlb_tr_we = spr_cs & spr_write &  spr_addr[7];

//
// TLB index
// - normal lookup: vaddr[18:13]
// - SPR access   : spr_addr[5:0]
//
assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

//
// MR RAM packing / unpacking
//
assign vpn           = tlb_mr_ram_out[13:1];
assign v             = tlb_mr_ram_out[0];
assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

//
// TR RAM packing / unpacking
//
assign ppn           = tlb_tr_ram_out[21:3];
assign uxe           = tlb_tr_ram_out[2];
assign sxe           = tlb_tr_ram_out[1];
assign ci            = tlb_tr_ram_out[0];
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

//
// Hit generation
//
assign hit = (vpn == vaddr[31:19]) & v;

//
// SPR readback
//
assign spr_dat_o =
        (!spr_write & !spr_addr[7]) ?
                {vpn,
                 tlb_index & {`OR1200_ITLB_INDXW{v}},
                 {`OR1200_ITLB_TAGW-7{1'b0}},
                 1'b0,
                 5'b00000,
                 v} :
        (!spr_write &  spr_addr[7]) ?
                {ppn,
                 {`OR1200_IMMU_PS-8{1'b0}},
                 uxe,
                 sxe,
                 4'b0000,
                 ci,
                 1'b0} :
        32'h0000_0000;

`ifdef OR1200_BIST
assign itlb_mr_ram_si = mbist_si_i;
assign itlb_tr_ram_si = itlb_mr_ram_so;
assign mbist_so_o     = itlb_tr_ram_so;
`endif

`ifdef OR1200_RAM_MODELS_VIRTEX

//
// Non-generic FPGA model instantiations
//
wire                            tlb_tr_en_wire;
wire    [0:0]                   tlb_tr_we_wire;
wire    [5:0]                   tlb_index_wire;
wire    [21:0]                  tlb_tr_ram_in_wire;

wire                            tlb_mr_en_wire;
wire    [0:0]                   tlb_mr_we_wire;
wire    [13:0]                  tlb_mr_ram_in_wire;

assign tlb_tr_en_wire     = tlb_tr_en;
assign tlb_tr_we_wire     = tlb_tr_we;
assign tlb_index_wire     = tlb_index;
assign tlb_tr_ram_in_wire = tlb_tr_ram_in;

assign tlb_mr_en_wire     = tlb_mr_en;
assign tlb_mr_we_wire     = tlb_mr_we;
assign tlb_mr_ram_in_wire = tlb_mr_ram_in;

itlb_tr_sub itlb_tr_ram (
        .clka   (clk),
        .ena    (tlb_tr_en_wire),
        .wea    (tlb_tr_we_wire),
        .addra  (tlb_index_wire),
        .dina   (tlb_tr_ram_in_wire),
        .clkb   (clk),
        .addrb  (tlb_index_wire),
        .doutb  (tlb_tr_ram_out)
);

itlb_mr_sub itlb_mr_ram (
        .clka   (clk),
        .ena    (tlb_mr_en_wire),
        .wea    (tlb_mr_we_wire),
        .addra  (tlb_index_wire),
        .dina   (tlb_mr_ram_in_wire),
        .clkb   (clk),
        .addrb  (tlb_index_wire),
        .doutb  (tlb_mr_ram_out)
);

`else

//
// Translate RAM
//
or1200_spram_64x22 itlb_tr_ram (
        .clk            (clk),
        .rst            (rst),
`ifdef OR1200_BIST
        .mbist_si_i     (itlb_tr_ram_si),
        .mbist_so_o     (itlb_tr_ram_so),
        .mbist_ctrl_i   (mbist_ctrl_i),
`endif
        .ce             (tlb_tr_en),
        .we             (tlb_tr_we),
        .oe             (1'b1),
        .addr           (tlb_index),
        .di             (tlb_tr_ram_in),
        .doq            (tlb_tr_ram_out)
);

//
// Match RAM
//
or1200_spram_64x14 itlb_mr_ram (
        .clk            (clk),
        .rst            (rst),
`ifdef OR1200_BIST
        .mbist_si_i     (itlb_mr_ram_si),
        .mbist_so_o     (itlb_mr_ram_so),
        .mbist_ctrl_i   (mbist_ctrl_i),
`endif
        .ce             (tlb_mr_en),
        .we             (tlb_mr_we),
        .oe             (1'b1),
        .addr           (tlb_index),
        .di             (tlb_mr_ram_in),
        .doq            (tlb_mr_ram_out)
);

`endif

endmodule
