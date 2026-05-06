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
    input spr_cs,
    input spr_write,
    input [31:0] spr_dat_i
);

    wire [31:0] dc_addr;
    wire [31:0] saved_addr;
    wire [3:0] dcram_we;
    wire tag_we;
    wire biu_read;
    wire biu_write;
    wire first_hit_ack;
    wire first_miss_ack;
    wire first_miss_err;
    wire burst;
    wire [31:0] from_dcram;
    wire [31:0] to_dcram;
    wire [18:0] tag;
    wire tag_v;
    wire tagcomp_miss;
    
    assign dcsb_dat_o = dcqmem_dat_i;
    assign dcsb_adr_o = dc_addr;
    assign dcsb_cyc_o = dc_en ? (biu_read | biu_write) : dcqmem_cycstb_i;
    assign dcsb_stb_o = dc_en ? (biu_read | biu_write) : dcqmem_cycstb_i;
    assign dcsb_we_o = dc_en ? biu_write : dcqmem_we_i;
    assign dcsb_sel_o = 4'b1111;
    assign dcsb_cab_o = burst;
    
    assign dcqmem_dat_o = dc_en ? from_dcram : dcsb_dat_i;
    assign dcqmem_ack_o = dc_en ? (first_hit_ack | first_miss_ack) : dcsb_ack_i;
    assign dcqmem_rty_o = dc_en ? !dcqmem_ack_o : dcsb_err_i;
    assign dcqmem_err_o = dc_en ? first_miss_err : dcsb_err_i;
    assign dcqmem_tag_o = dcqmem_tag_i;
    
    assign to_dcram = biu_write ? dcqmem_dat_i : dcsb_dat_i;
    
    assign tagcomp_miss = (tag != dc_addr[28:10]) | !tag_v | dcqmem_ci_i;

    or1200_dc_ram ram_inst(
        .clk(clk), .rst(rst),
        .addr(dc_addr[12:2]),
        .en(dc_en),
        .we(dcram_we),
        .datain(to_dcram),
        .dataout(from_dcram)
    );

    or1200_dc_tag tag_inst(
        .clk(clk), .rst(rst),
        .addr(dc_addr[10:2]),
        .en(dc_en | tag_we),
        .we(tag_we),
        .datain({1'b1, dc_addr[28:10]}),
        .tag_v(tag_v),
        .tag(tag)
    );

    or1200_dc_fsm fsm_inst(
        .clk(clk), .rst(rst),
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
        .dcram_we(dcram_we),
        .biu_read(biu_read),
        .biu_write(biu_write),
        .first_hit_ack(first_hit_ack),
        .first_miss_ack(first_miss_ack),
        .first_miss_err(first_miss_err),
        .burst(burst),
        .tag_we(tag_we),
        .dc_addr(dc_addr)
    );

endmodule
