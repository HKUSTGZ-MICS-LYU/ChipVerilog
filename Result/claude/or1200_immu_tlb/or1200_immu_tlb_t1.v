module or1200_immu_tlb(
    input clk,
    input rst,
    input tlb_en,
    input [31:0] vaddr,
    output hit,
    output [31:13] ppn,
    output uxe,
    output sxe,
    output ci,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

wire [31:19] vpn;
wire v;
wire [5:0] tlb_index;
wire tlb_mr_en;
wire tlb_mr_we;
wire [13:0] tlb_mr_ram_in;
wire [13:0] tlb_mr_ram_out;
wire tlb_tr_en;
wire tlb_tr_we;
wire [21:0] tlb_tr_ram_in;
wire [21:0] tlb_tr_ram_out;

wire itlb_mr_ram_si;
wire itlb_mr_ram_so;
wire itlb_tr_ram_si;
wire itlb_tr_ram_so;

wire tlb_tr_en_wire;
wire tlb_tr_we_wire;
wire [5:0] tlb_index_wire;
wire [21:0] tlb_tr_ram_in_wire;
wire tlb_mr_en_wire;
wire tlb_mr_we_wire;
wire [13:0] tlb_mr_ram_in_wire;

assign tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

assign tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
assign tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
assign tlb_mr_ram_in = {spr_dat_i[31:19], spr_dat_i[0]};

assign tlb_tr_en = tlb_en | (spr_cs & spr_addr[7]);
assign tlb_tr_we = spr_cs & spr_write & spr_addr[7];
assign tlb_tr_ram_in = {spr_dat_i[31:13], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};

assign vpn = tlb_mr_ram_out[13:1];
assign v = tlb_mr_ram_out[0];

assign ppn = tlb_tr_ram_out[21:3];
assign uxe = tlb_tr_ram_out[2];
assign sxe = tlb_tr_ram_out[1];
assign ci = tlb_tr_ram_out[0];

assign hit = (vpn == vaddr[31:19]) & v;

assign spr_dat_o = spr_write ? 32'h0000_0000 :
                   (spr_addr[7] ?
                    {ppn, 5'b00000, uxe, sxe, 4'b0000, ci, 1'b0} :
                    {vpn, (tlb_index & {6{v}}), 12'b0000_0000_0000, v});

`ifdef OR1200_BIST
assign itlb_mr_ram_si = mbist_si_i;
assign itlb_tr_ram_si = itlb_mr_ram_so;
assign mbist_so_o = itlb_tr_ram_so;
`else
assign itlb_mr_ram_si = 1'b0;
assign itlb_tr_ram_si = 1'b0;
`endif

`ifdef OR1200_RAM_MODELS_VIRTEX
assign tlb_tr_en_wire = tlb_tr_en;
assign tlb_tr_we_wire = {tlb_tr_we};
assign tlb_index_wire = tlb_index;
assign tlb_tr_ram_in_wire = tlb_tr_ram_in;
assign tlb_mr_en_wire = tlb_mr_en;
assign tlb_mr_we_wire = {tlb_mr_we};
assign tlb_mr_ram_in_wire = tlb_mr_ram_in;

itlb_tr_sub itlb_tr_ram(
    .clk(clk),
    .en(tlb_tr_en_wire),
    .we(tlb_tr_we_wire),
    .addr(tlb_index_wire),
    .di(tlb_tr_ram_in_wire),
    .do(tlb_tr_ram_out)
);

itlb_mr_sub itlb_mr_ram(
    .clk(clk),
    .en(tlb_mr_en_wire),
    .we(tlb_mr_we_wire),
    .addr(tlb_index_wire),
    .di(tlb_mr_ram_in_wire),
    .do(tlb_mr_ram_out)
);
`else
or1200_spram_64x22 itlb_tr_ram(
    .clk(clk),
    .rst(rst),
    .ce(tlb_tr_en),
    .we(tlb_tr_we),
    .oe(1'b1),
    .addr(tlb_index),
    .di(tlb_tr_ram_in),
    .doq(tlb_tr_ram_out)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(itlb_tr_ram_si),
    .mbist_so_o(itlb_tr_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_spram_64x14 itlb_mr_ram(
    .clk(clk),
    .rst(rst),
    .ce(tlb_mr_en),
    .we(tlb_mr_we),
    .oe(1'b1),
    .addr(tlb_index),
    .di(tlb_mr_ram_in),
    .doq(tlb_mr_ram_out)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(itlb_mr_ram_si),
    .mbist_so_o(itlb_mr_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);
`ifdef OR1200_BIST
`else
assign itlb_mr_ram_so = 1'b0;
assign itlb_tr_ram_so = 1'b0;
`endif
`endif

endmodule
