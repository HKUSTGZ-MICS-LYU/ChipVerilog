module or1200_dc_top(
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

wire tag_v;
wire [18:0] tag;
wire [31:0] to_dcram;
wire [31:0] from_dcram;
wire [31:0] saved_addr;
wire [3:0] dcram_we;
wire dctag_we;
wire [31:0] dc_addr;
wire dcfsm_biu_read;
wire dcfsm_biu_write;
reg tagcomp_miss;
wire [12:4] dctag_addr;
wire dctag_en;
wire dctag_v;
wire dc_inv;
wire dcfsm_first_hit_ack;
wire dcfsm_first_miss_ack;
wire dcfsm_first_miss_err;
wire dcfsm_burst;
wire dcfsm_tag_we;

`ifdef OR1200_BIST
wire mbist_ram_so;
wire mbist_tag_so;
wire mbist_ram_si = mbist_si_i;
wire mbist_tag_si = mbist_ram_so;
`endif

wire [31:12] dc_tag_datain;

wire dcfsm_first_ack;
wire dcfsm_first_err;

assign dcfsm_first_ack = dcfsm_first_hit_ack | dcfsm_first_miss_ack;
assign dcfsm_first_err = dcfsm_first_miss_err;

assign dc_inv = spr_cs & spr_write;

assign dctag_en = dc_en | dc_inv;

always @(tag or saved_addr or tag_v) begin
    if ((tag != saved_addr[31:13]) || !tag_v) begin
        tagcomp_miss = 1'b1;
    end else begin
        tagcomp_miss = 1'b0;
    end
end

assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];

assign dc_tag_datain = {dc_addr[31:13], dctag_v};

assign dctag_v = dc_inv ? 1'b0 : 1'b1;

assign dctag_we = dcfsm_tag_we | dc_inv;

assign dcqmem_dat_o = dc_en ? (dcfsm_first_hit_ack ? from_dcram : dcsb_dat_i) : dcsb_dat_i;

assign dcqmem_ack_o = dc_en ? dcfsm_first_ack : (dcqmem_cycstb_i & dcsb_ack_i);

assign dcqmem_err_o = dc_en ? dcfsm_first_err : (dcqmem_cycstb_i & dcsb_err_i);

assign dcqmem_rty_o = dc_en ? ~dcfsm_first_ack : ~(dcsb_ack_i | dcsb_err_i);

assign dcqmem_tag_o = dcsb_err_i ? {4{1'b1}} : dcqmem_tag_i;

assign dcsb_cyc_o = dc_en ? dcfsm_biu_read | dcfsm_biu_write : dcqmem_cycstb_i;

assign dcsb_stb_o = dc_en ? dcfsm_biu_read | dcfsm_biu_write : dcqmem_cycstb_i;

assign dcsb_we_o = dc_en ? dcfsm_biu_write : dcqmem_we_i;

assign dcsb_sel_o = dc_en ? (dcfsm_biu_write ? dcqmem_sel_i : 4'hF) : dcqmem_sel_i;

assign dcsb_cab_o = dcfsm_burst;

assign dcsb_dat_o = dcqmem_dat_i;

assign dcsb_adr_o = dc_addr;

assign dc_addr = dcfsm_biu_read | dcfsm_biu_write ? saved_addr : dcqmem_adr_i;

assign to_dcram = dcsb_dat_i;

or1200_dc_fsm dcfsm(
    .clk(clk),
    .rst(rst),
    .dc_en(dc_en),
    .dcqmem_cycstb_i(dcqmem_cycstb_i),
    .dcqmem_ci_i(dcqmem_ci_i),
    .dcqmem_we_i(dcqmem_we_i),
    .dcqmem_sel_i(dcqmem_sel_i),
    .tagcomp_miss(tagcomp_miss),
    .biudata_valid(dcsb_ack_i),
    .biudata_error(dcsb_err_i),
    .start_addr(dcqmem_adr_i),
    .saved_addr(saved_addr),
    .first_hit_ack(dcfsm_first_hit_ack),
    .first_miss_ack(dcfsm_first_miss_ack),
    .first_miss_err(dcfsm_first_miss_err),
    .biu_read(dcfsm_biu_read),
    .biu_write(dcfsm_biu_write),
    .burst(dcfsm_burst),
    .tag_we(dcfsm_tag_we),
    .dcram_we(dcram_we)
);

or1200_dc_ram dcram(
    .clk(clk),
    .rst(rst),
    .addr(dc_addr[11:2]),
    .datain(to_dcram),
    .dataout(from_dcram),
    .we(dcram_we & {4{dc_en}}),
    .en(dc_en)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_ram_si),
    .mbist_so_o(mbist_ram_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

or1200_dc_tag dctag(
    .clk(clk),
    .rst(rst),
    .addr(dctag_addr),
    .en(dctag_en),
    .we(dctag_we & dctag_en),
    .datain(dc_tag_datain),
    .tag_v(tag_v),
    .tag(tag)
`ifdef OR1200_BIST
    ,.mbist_si_i(mbist_tag_si),
    .mbist_so_o(mbist_tag_so),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

`ifdef OR1200_BIST
assign mbist_so_o = mbist_tag_so;
`endif

endmodule
