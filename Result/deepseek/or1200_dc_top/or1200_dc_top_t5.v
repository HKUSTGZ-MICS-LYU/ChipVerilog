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

// ----------------------------------------------------------------------
// Internal signals
// ----------------------------------------------------------------------
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
wire [8:0] dctag_addr;  // bits [12:4] -> 9 bits
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
wire mbist_ram_si;
wire mbist_tag_si;
`endif

// ----------------------------------------------------------------------
// Derived signals
// ----------------------------------------------------------------------
assign dc_inv = spr_cs & spr_write;
assign dctag_we = dcfsm_tag_we | dc_inv;
assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];
assign dctag_v = ~dc_inv;
assign dcsb_dat_o = dcqmem_dat_i;
assign dcsb_adr_o = dc_addr;

// ----------------------------------------------------------------------
// Tag compare (combinational)
// ----------------------------------------------------------------------
always @(*) begin
    if (tag !== saved_addr[31:13] || !tag_v)
        tagcomp_miss = 1'b1;
    else
        tagcomp_miss = 1'b0;
end

// ----------------------------------------------------------------------
// Cache bypass / enabled muxes
// ----------------------------------------------------------------------
wire cache_en = dc_en;

// dcsb_cyc_o, dcsb_stb_o
assign dcsb_cyc_o = cache_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
assign dcsb_stb_o = cache_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;

// dcsb_we_o
assign dcsb_we_o = cache_en ? dcfsm_biu_write : dcqmem_we_i;

// dcsb_cab_o
assign dcsb_cab_o = cache_en ? dcfsm_burst : 1'b0;

// dcsb_sel_o
wire biu_read_ncinh = cache_en & ~dcqmem_ci_i & dcfsm_biu_read;
assign dcsb_sel_o = biu_read_ncinh ? 4'b1111 : dcqmem_sel_i;

// dcqmem_ack_o, dcqmem_err_o
wire ack_bypass = ~cache_en & dcsb_ack_i;
wire ack_cache = cache_en & (dcfsm_first_hit_ack | dcfsm_first_miss_ack);
assign dcqmem_ack_o = ack_bypass | ack_cache;

wire err_bypass = ~cache_en & dcsb_err_i;
wire err_cache = cache_en & dcfsm_first_miss_err;
assign dcqmem_err_o = err_bypass | err_cache;

assign dcqmem_rty_o = ~dcqmem_ack_o;

// dcqmem_tag_o
wire bus_err = cache_en & dcfsm_first_miss_err;
assign dcqmem_tag_o = bus_err ? (4'b1110) : dcqmem_tag_i;  // OR1200_DTAG_BE = 4'b1110

// dcqmem_dat_o
wire sel_dcsb_dat = (~cache_en) | (cache_en & dcfsm_first_miss_ack);
assign dcqmem_dat_o = sel_dcsb_dat ? dcsb_dat_i : from_dcram;

// to_dcram: during BIU read use external data, otherwise store data
assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;

// ----------------------------------------------------------------------
// Save address register
// ----------------------------------------------------------------------
// The saved address is latched when a new transaction starts in cache mode.
// Use FSM's load indication; else if invalid we hold.
reg [31:0] saved_addr_reg;
wire load_addr = cache_en & dcqmem_cycstb_i & (~dcqmem_ack_o); // simple latch on request while not yet acknowledged
always @(posedge clk or posedge rst) begin
    if (rst)
        saved_addr_reg <= 32'b0;
    else if (load_addr)
        saved_addr_reg <= dcqmem_adr_i;
end
assign saved_addr = saved_addr_reg;

// ----------------------------------------------------------------------
// Tag RAM data-in
// ----------------------------------------------------------------------
wire [18:0] dctag_datain = dc_addr[31:13]; // tag bits from the FSM current address

// ----------------------------------------------------------------------
// Instantiations
// ----------------------------------------------------------------------

// Data cache FSM
or1200_dc_fsm u_fsm (
    .clk(clk),
    .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_i),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    // inputs from top
    .dcqmem_cycstb_i(dcqmem_cycstb_i),
    .dcqmem_ci_i(dcqmem_ci_i),
    .dcqmem_we_i(dcqmem_we_i),
    .tagcomp_miss(tagcomp_miss),
    .dcsb_ack_i(dcsb_ack_i),
    .dcsb_err_i(dcsb_err_i),
    // outputs
    .dc_addr(dc_addr),
    .dcfsm_biu_read(dcfsm_biu_read),
    .dcfsm_biu_write(dcfsm_biu_write),
    .dcfsm_burst(dcfsm_burst),
    .dcfsm_tag_we(dcfsm_tag_we),
    .dcfsm_first_hit_ack(dcfsm_first_hit_ack),
    .dcfsm_first_miss_ack(dcfsm_first_miss_ack),
    .dcfsm_first_miss_err(dcfsm_first_miss_err),
    .dcram_we(dcram_we)
);

// Data cache RAM
or1200_dc_ram u_ram (
    .clk(clk),
    .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_ram_si),
    .mbist_ctrl_i(mbist_ctrl_i),
    .mbist_so_o(mbist_ram_so),
`endif
    .addr(dc_addr[12:4]),   // index bits
    .we(dcram_we),          // byte write enables from FSM
    .din(to_dcram),
    .dout(from_dcram)
);

// Data cache tag
or1200_dc_tag u_tag (
    .clk(clk),
    .rst(rst),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_tag_si),
    .mbist_ctrl_i(mbist_ctrl_i),
    .mbist_so_o(mbist_tag_so),
`endif
    .en(dctag_en),
    .we(dctag_we),
    .addr(dctag_addr),       // 9-bit index
    .tag_din(dctag_datain),  // 19-bit tag to write
    .valid_din(dctag_v),     // valid bit input
    .tag_dout(tag),
    .valid_dout(tag_v)
);

`ifdef OR1200_BIST
assign mbist_ram_si = mbist_si_i;
assign mbist_tag_si = mbist_ram_so;
assign mbist_so_o = mbist_tag_so;
assign dctag_en = 1'b1; // enable always during operation
`else
assign dctag_en = 1'b1;
`endif

endmodule
