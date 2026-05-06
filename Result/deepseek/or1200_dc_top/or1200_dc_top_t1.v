// or1200_dc_top module

module or1200_dc_top(
    // Rst, clk and clock control
    input clk,
    input rst,

    // External i/f
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

    // Internal i/f
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
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // SPRs
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

    // Internal signals
    wire [18:0] tag;
    wire tag_v;
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
    wire mbist_ram_so;
    wire mbist_tag_so;
    wire mbist_ram_si;
    wire mbist_tag_si;
    wire [31:12] dc_tag_datain;

`ifdef OR1200_BIST
    assign mbist_ram_si = mbist_si_i;
    assign mbist_tag_si = mbist_ram_so;
`endif

    // SPR-based invalidation
    assign dc_inv = spr_cs & spr_write;
    assign dctag_we = dcfsm_tag_we | dc_inv;
    assign dctag_addr = dc_inv ? spr_dat_i[12:4] : dc_addr[12:4];
    assign dctag_v = ~dc_inv;

    // Tag RAM instance
    or1200_dc_tag u_dc_tag (
        .clk(clk),
        .rst(rst),
        .addr(dctag_addr),
        .en(dctag_en),
        .we(dctag_we),
        .datain(dc_tag_datain),
        .tag_v(dctag_v),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_tag_si),
        .mbist_so_o(mbist_tag_so),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .tag(tag),
        .tag_v_o(tag_v)
    );

    // Data RAM instance
    or1200_dc_ram u_dc_ram (
        .clk(clk),
        .rst(rst),
        .addr(dc_addr[12:2]),
        .we(dcram_we),
        .datain(to_dcram),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_ram_si),
        .mbist_so_o(mbist_ram_so),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
        .dataout(from_dcram)
    );

    // FSM instance
    or1200_dc_fsm u_dc_fsm (
        .clk(clk),
        .rst(rst),
        .dc_en(dc_en),
        .dcqmem_adr_i(dcqmem_adr_i),
        .dcqmem_cycstb_i(dcqmem_cycstb_i),
        .dcqmem_ci_i(dcqmem_ci_i),
        .dcqmem_we_i(dcqmem_we_i),
        .dcqmem_sel_i(dcqmem_sel_i),
        .dcqmem_tag_i(dcqmem_tag_i),
        .dcqmem_dat_i(dcqmem_dat_i),
        .dcsb_dat_i(dcsb_dat_i),
        .dcsb_ack_i(dcsb_ack_i),
        .dcsb_err_i(dcsb_err_i),
        .tag(tag),
        .tag_v(tag_v),
        .tagcomp_miss(tagcomp_miss),
        .saved_addr(saved_addr),
        .dc_addr(dc_addr),
        .dcram_we(dcram_we),
        .dcfsm_tag_we(dcfsm_tag_we),
        .dcfsm_biu_read(dcfsm_biu_read),
        .dcfsm_biu_write(dcfsm_biu_write),
        .dcfsm_burst(dcfsm_burst),
        .dcfsm_first_hit_ack(dcfsm_first_hit_ack),
        .dcfsm_first_miss_ack(dcfsm_first_miss_ack),
        .dcfsm_first_miss_err(dcfsm_first_miss_err),
        .dc_tag_datain(dc_tag_datain)
    );

    // External bus address
    assign dcsb_adr_o = dc_addr;

    // External bus control signals (cache-enabled vs bypass)
    assign dcsb_cyc_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
    assign dcsb_stb_o = dc_en ? (dcfsm_biu_read | dcfsm_biu_write) : dcqmem_cycstb_i;
    assign dcsb_we_o = dc_en ? dcfsm_biu_write : dcqmem_we_i;
    assign dcsb_cab_o = dc_en ? dcfsm_burst : 1'b0;

    // External bus byte select
    assign dcsb_sel_o = (dc_en & !dcqmem_ci_i & dcfsm_biu_read) ? 4'b1111 : dcqmem_sel_i;

    // External bus write data
    assign dcsb_dat_o = dcqmem_dat_i;

    // Data to write into DCRAM
    assign to_dcram = (dc_en & dcfsm_biu_read) ? dcsb_dat_i : dcqmem_dat_i;

    // Tag compare logic
    always @(*) begin
        if (tag_v && (tag == saved_addr[31:13]))
            tagcomp_miss = 1'b0;
        else
            tagcomp_miss = 1'b1;
    end

    // LSU/QMEM response data
    assign dcqmem_dat_o = (~dc_en | dcfsm_first_miss_ack) ? dcsb_dat_i : from_dcram;

    // LSU/QMEM acknowledge
    assign dcqmem_ack_o = dc_en ? (dcfsm_first_hit_ack | dcfsm_first_miss_ack) : dcsb_ack_i;

    // LSU/QMEM error
    assign dcqmem_err_o = dc_en ? dcfsm_first_miss_err : dcsb_err_i;

    // LSU/QMEM retry (inverse of ack)
    assign dcqmem_rty_o = ~dcqmem_ack_o;

    // LSU/QMEM tag
    assign dcqmem_tag_o = dcqmem_err_o ? 4'b0001 : dcqmem_tag_i; // OR1200_DTAG_BE = 4'b0001

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_tag_so;
`endif

endmodule
