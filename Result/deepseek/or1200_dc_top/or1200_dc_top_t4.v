`include "or1200_defines.v"

module or1200_dc_top(
    clk,
    rst,

    // External i/f
    dcsb_dat_o,
    dcsb_adr_o,
    dcsb_cyc_o,
    dcsb_stb_o,
    dcsb_we_o,
    dcsb_sel_o,
    dcsb_cab_o,
    dcsb_dat_i,
    dcsb_ack_i,
    dcsb_err_i,

    // Internal i/f
    dc_en,
    dcqmem_adr_i,
    dcqmem_cycstb_i,
    dcqmem_ci_i,
    dcqmem_we_i,
    dcqmem_sel_i,
    dcqmem_tag_i,
    dcqmem_dat_i,
    dcqmem_dat_o,
    dcqmem_ack_o,
    dcqmem_rty_o,
    dcqmem_err_o,
    dcqmem_tag_o,

`ifdef OR1200_BIST
    mbist_si_i,
    mbist_so_o,
    mbist_ctrl_i,
`endif

    // SPRs
    spr_cs,
    spr_write,
    spr_dat_i
);

input clk;
input rst;

output [31:0] dcsb_dat_o;
output [31:0] dcsb_adr_o;
output dcsb_cyc_o;
output dcsb_stb_o;
output dcsb_we_o;
output [3:0] dcsb_sel_o;
output dcsb_cab_o;
input [31:0] dcsb_dat_i;
input dcsb_ack_i;
input dcsb_err_i;

input dc_en;
input [31:0] dcqmem_adr_i;
input dcqmem_cycstb_i;
input dcqmem_ci_i;
input dcqmem_we_i;
input [3:0] dcqmem_sel_i;
input [3:0] dcqmem_tag_i;
input [31:0] dcqmem_dat_i;
output [31:0] dcqmem_dat_o;
output dcqmem_ack_o;
output dcqmem_rty_o;
output dcqmem_err_o;
output [3:0] dcqmem_tag_o;

`ifdef OR1200_BIST
input mbist_si_i;
output mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
`endif

input spr_cs;
input spr_write;
input [31:0] spr_dat_i;

// Local parameters
localparam DTAG_BE = 4'b1111;

// Declare internal signals
wire [31:0] dc_addr;
wire dcfsm_biu_read;
wire dcfsm_biu_write;
wire dcfsm_first_hit_ack;
wire dcfsm_first_miss_ack;
wire dcfsm_first_miss_err;
wire dcfsm_burst;
wire dcfsm_tag_we;
wire [3:0] dcram_we;
wire [31:0] saved_addr;
wire tag_v;
wire [18:0] tag;

wire [31:0] to_dcram;
wire [31:0] from_dcram;
wire dctag_we;
wire dctag_v;
wire dc_inv;
wire [8:0] dctag_addr;
wire dctag_en;
wire tagcomp_miss;

`ifdef OR1200_BIST
wire mbist_ram_si;
wire mbist_ram_so;
wire mbist_tag_si;
wire mbist_tag_so;
`endif

// Invalidation logic
assign dc_inv = spr_cs & spr_write;
assign dctag_v = ~dc_inv;
assign dctag_we = dcfsm_tag_we | dc_inv;

// Tag address selection
assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];
assign dctag_en = 1'b1; // Always enabled

// External address
assign dcsb_adr_o = dc_addr;

// External write data always from LSU/QMEM
assign dcsb_dat_o = dcqmem_dat_i;

// External bus control for bypass mode or cache mode
wire bypass = ~dc_en;

assign dcsb_cyc_o = bypass ? dcqmem_cycstb_i : (dcfsm_biu_read | dcfsm_biu_write);
assign dcsb_stb_o = bypass ? dcqmem_cycstb_i : (dcfsm_biu_read | dcfsm_biu_write);
assign dcsb_we_o = bypass ? dcqmem_we_i : dcfsm_biu_write;
assign dcsb_cab_o = bypass ? 1'b0 : dcfsm_burst;

// Byte selects
wire biu_read_non_ci;
assign biu_read_non_ci = dc_en & ~dcqmem_ci_i & dcfsm_biu_read;
assign dcsb_sel_o = biu_read_non_ci ? 4'b1111 : dcqmem_sel_i;

// Data to dcram
assign to_dcram = dcfsm_biu_read ? dcsb_dat_i : dcqmem_dat_i;

// Data return to LSU/QMEM
wire first_miss_ack_de;
assign first_miss_ack_de = dc_en & dcfsm_first_miss_ack;
assign dcqmem_dat_o = (bypass | first_miss_ack_de) ? dcsb_dat_i : from_dcram;

// LSU/QMEM response control
assign dcqmem_ack_o = bypass ? dcsb_ack_i : (dcfsm_first_hit_ack | dcfsm_first_miss_ack);
assign dcqmem_err_o = bypass ? dcsb_err_i : dcfsm_first_miss_err;
assign dcqmem_rty_o = ~dcqmem_ack_o;

// Tag output
assign dcqmem_tag_o = dcqmem_err_o ? DTAG_BE : dcqmem_tag_i;

// Tag compare
always @(*) begin
    if (dc_en)
        tagcomp_miss = (tag != saved_addr[31:13]) | ~tag_v;
    else
        tagcomp_miss = 1'b0; // Not used in bypass
end

`ifdef OR1200_BIST
assign mbist_ram_si = mbist_si_i;
assign mbist_tag_si = mbist_ram_so;
assign mbist_so_o = mbist_tag_so;
`endif

// Instantiate submodules
or1200_dc_fsm u_dc_fsm (
    .clk(clk),
    .rst(rst),
    .dc_en(dc_en),
    .tagcomp_miss(tagcomp_miss),
    .dcqmem_adr_i(dcqmem_adr_i),
    .dcqmem_cycstb_i(dcqmem_cycstb_i),
    .dcqmem_ci_i(dcqmem_ci_i),
    .dcqmem_we_i(dcqmem_we_i),
    .dcsb_ack_i(dcsb_ack_i),
    .dcsb_err_i(dcsb_err_i),
    .saved_addr(saved_addr),
    .dc_addr(dc_addr),
    .dcfsm_biu_read(dcfsm_biu_read),
    .dcfsm_biu_write(dcfsm_biu_write),
    .dcfsm_first_hit_ack(dcfsm_first_hit_ack),
    .dcfsm_first_miss_ack(dcfsm_first_miss_ack),
    .dcfsm_first_miss_err(dcfsm_first_miss_err),
    .dcfsm_burst(dcfsm_burst),
    .dcfsm_tag_we(dcfsm_tag_we),
    .dcram_we(dcram_we)
);

or1200_dc_ram u_dc_ram (
    .clk(clk),
    .rst(rst),
    .addr(dc_addr[12:0]), // Assuming 13-bit index? Adjust as per actual
    .dat_i(to_dcram),
    .we(dcram_we),
    .dat_o(from_dcram)
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
    .tag_in(dc_tag_datain), // We need to define this? According to spec, tag_in? might be from saved_addr[31:13] when writing.
    .tag_out(tag),
    .valid_in(dctag_v),
    .valid_out(tag_v)
`ifdef OR1200_BIST
    ,
    .mbist_si(mbist_tag_si),
    .mbist_so(mbist_tag_so),
    .mbist_ctrl(mbist_ctrl_i)
`endif
);

// Tag data input: during normal tag write, use saved_addr[31:13]; during invalidate, we don't care? 
// Since we set tag_in to something; for invalidation, we can set to 0 or saved_addr.
// The spec doesn't specify tag_in for invalidation; typically it's don't-care.
// We'll use saved_addr[31:13] for writes, 0 for invalidate? Actually tag_in is used when dctag_we is asserted.
// To be safe, assign tag_in as saved_addr[31:13] during normal operations, and during invalidation it's not used.
// But we need to drive it. We can use saved_addr[31:13] always; the valid bit will be cleared.
assign dc_tag_datain = saved_addr[31:13]; // 19 bits

endmodule
