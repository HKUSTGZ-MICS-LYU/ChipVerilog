module or1200_dc_top (
    input clk,
    input rst,
    output [31:0] dcsb_dat_o,
    output [31:0] dcsb_adr_o,
    output dcsb_cyc_o,
    output dcsb_stb_o,
    output dcsb_we_o,
    output [3:0] dcsb_sel_o,
    output dcsb_cab_o,
    input [31:0] dcsb_dat_i,
    input dcsb_ack_i,
    input dcsb_err_i,
    input dc_en,
    input [31:0] dcqmem_adr_i,
    input dcqmem_cycstb_i,
    input dcqmem_ci_i,
    input dcqmem_we_i,
    input [3:0] dcqmem_sel_i,
    input [3:0] dcqmem_tag_i,
    input [31:0] dcqmem_dat_i,
    output [31:0] dcqmem_dat_o,
    output dcqmem_ack_o,
    output dcqmem_rty_o,
    output dcqmem_err_o,
    output [3:0] dcqmem_tag_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

localparam [3:0] OR1200_DTAG_BE = 4'b1111;

wire [31:0] dc_addr;
wire [31:0] saved_addr;
wire dcfsm_biu_read;
wire dcfsm_biu_write;
wire dcfsm_burst;
wire dcfsm_tag_we;
wire [3:0] dcram_we;
wire dcfsm_first_hit_ack;
wire dcfsm_first_miss_ack;
wire dcfsm_first_miss_err;
wire tag_v;
wire [18:0] tag;
wire [31:0] from_dcram;
wire [31:0] to_dcram;
wire dctag_we;
wire [8:0] dctag_addr;
wire dctag_en;
wire dctag_v;
wire dc_inv;
wire tagcomp_miss;
wire mbist_ram_so;
wire mbist_tag_so;
wire mbist_ram_si;
wire mbist_tag_si;

assign dcsb_dat_o = dcqmem_dat_i;
assign dcsb_adr_o = dc_addr;
assign dctag_en = 1'b1;
assign dc_inv = spr_cs & spr_write;
assign dctag_v = ~dc_inv;
assign dctag_we = dcfsm_tag_we | dc_inv;
assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];

// Tag data input: tag from saved_addr[31:13] and valid bit
wire [19:0] tag_din;
assign tag_din = dc_inv ? 20'b0 : {saved_addr[31:13], dctag_v};

// Data to DCRAM selection
assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;

// tag comparison
assign tagcomp_miss = ~(tag_v & (tag == saved_addr[31:13]));

// Interface muxing
assign dcsb_cyc_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_stb_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_we_o = dc_en ? dcfsm_biu_write : dcqmem_we_i;
assign dcsb_cab_o = dc_en ? dcfsm_burst : 1'b0;
assign dcsb_sel_o = (dc_en & ~dcqmem_ci_i & dcfsm_biu_read) ? 4'b1111 : dcqmem_sel_i;

assign dcqmem_ack_o = dc_en ? (dcfsm_first_hit_ack | dcfsm_first_miss_ack) : dcsb_ack_i;
assign dcqmem_err_o = dc_en ? dcfsm_first_miss_err : dcsb_err_i;
assign dcqmem_rty_o = ~dcqmem_ack_o;
assign dcqmem_dat_o = (dc_en & ~dcfsm_first_miss_ack) ? from_dcram : dcsb_dat_i;
assign dcqmem_tag_o = dcqmem_err_o ? OR1200_DTAG_BE : dcqmem_tag_i;

// BIST connectivity
`ifdef OR1200_BIST
assign mbist_ram_si = mbist_si_i;
assign mbist_tag_si = mbist_ram_so;
assign mbist_so_o = mbist_tag_so;
`endif

// Submodule instantiations
or1200_dc_fsm u_dc_fsm (
    .clk(clk),
    .rst(rst),
    .tagcomp_miss(tagcomp_miss),
    .dcqmem_adr_i(dcqmem_adr_i),
    .dcqmem_cycstb_i(dcqmem_cycstb_i),
    .dcqmem_we_i(dcqmem_we_i),
    .dcqmem_ci_i(dcqmem_ci_i),
    .dcsb_ack_i(dcsb_ack_i),
    .dcsb_err_i(dcsb_err_i),
    .dc_en(dc_en),
    .dc_addr(dc_addr),
    .saved_addr(saved_addr),
    .dcfsm_biu_read(dcfsm_biu_read),
    .dcfsm_biu_write(dcfsm_biu_write),
    .dcfsm_burst(dcfsm_burst),
    .dcfsm_tag_we(dcfsm_tag_we),
    .dcram_we(dcram_we),
    .dcfsm_first_hit_ack(dcfsm_first_hit_ack),
    .dcfsm_first_miss_ack(dcfsm_first_miss_ack),
    .dcfsm_first_miss_err(dcfsm_first_miss_err)
);

or1200_dc_ram u_dc_ram (
    .clk(clk),
    .rst(rst),
    .addr(dc_addr[12:4]),
    .we(dcram_we),
    .din(to_dcram),
    .dout(from_dcram)
`ifdef OR1200_BIST
    ,
    .mbist_si(mbist_ram_si),
    .mbist_so(mbist_ram_so),
    .mbist_ctrl(mbist_ctrl_i)
`endif
);

or1200_dc_tag u_dc_tag (
    .clk(clk),
    .rst(rst),
    .addr(dctag_addr),
    .we(dctag_we),
    .en(dctag_en),
    .din(tag_din),
    .tag(tag),
    .valid(tag_v)
`ifdef OR1200_BIST
    ,
    .mbist_si(mbist_tag_si),
    .mbist_so(mbist_tag_so),
    .mbist_ctrl(mbist_ctrl_i)
`endif
);

endmodule
