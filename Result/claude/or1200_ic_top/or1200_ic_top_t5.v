module or1200_ic_top(
    input clk,
    input rst,
    input [31:0] icsb_dat_i,
    input icsb_ack_i,
    input icsb_err_i,
    input ic_en,
    input [31:0] icqmem_adr_i,
    input icqmem_cycstb_i,
    input [3:0] icqmem_tag_i,
    output [31:0] icqmem_dat_o,
    output icqmem_ack_o,
    output icqmem_rty_o,
    output icqmem_err_o,
    output [3:0] icqmem_tag_o,
    output [31:0] icsb_adr_o,
    output icsb_cyc_o,
    output icsb_stb_o,
    output [3:0] icsb_sel_o,
    output icsb_cab_o
);

    wire [31:0] ic_addr;
    wire [31:0] saved_addr;
    wire [3:0] icram_we;
    wire tag_we;
    wire biu_read;
    wire first_hit_ack;
    wire first_miss_ack;
    wire first_miss_err;
    wire burst;
    wire [31:0] from_icram;
    wire [18:0] tag;
    wire tag_v;
    wire tagcomp_miss;
    
    assign icsb_adr_o = ic_addr;
    assign icsb_cyc_o = ic_en ? biu_read : icqmem_cycstb_i;
    assign icsb_stb_o = ic_en ? biu_read : icqmem_cycstb_i;
    assign icsb_sel_o = 4'b1111;
    assign icsb_cab_o = burst;
    
    assign icqmem_dat_o = ic_en ? from_icram : icsb_dat_i;
    assign icqmem_ack_o = ic_en ? (first_hit_ack | first_miss_ack) : icsb_ack_i;
    assign icqmem_rty_o = ic_en ? !icqmem_ack_o : icsb_err_i;
    assign icqmem_err_o = ic_en ? first_miss_err : icsb_err_i;
    assign icqmem_tag_o = icqmem_tag_i;
    
    assign tagcomp_miss = (tag != ic_addr[28:10]) | !tag_v;

    or1200_ic_ram ram_inst(
        .clk(clk), .rst(rst),
        .addr(ic_addr[12:2]),
        .en(ic_en),
        .we(icram_we),
        .datain(icsb_dat_i),
        .dataout(from_icram)
    );

    or1200_ic_tag tag_inst(
        .clk(clk), .rst(rst),
        .addr(ic_addr[10:2]),
        .en(ic_en | tag_we),
        .we(tag_we),
        .datain({1'b1, ic_addr[28:10]}),
        .tag_v(tag_v),
        .tag(tag)
    );

    or1200_ic_fsm fsm_inst(
        .clk(clk), .rst(rst),
        .ic_en(ic_en),
        .icqmem_cycstb_i(icqmem_cycstb_i),
        .biudata_valid(icsb_ack_i),
        .biudata_error(icsb_err_i),
        .start_addr(icqmem_adr_i),
        .tagcomp_miss(tagcomp_miss),
        .saved_addr(saved_addr),
        .biu_read(biu_read),
        .first_hit_ack(first_hit_ack),
        .first_miss_ack(first_miss_ack),
        .first_miss_err(first_miss_err),
        .burst(burst),
        .tag_we(tag_we),
        .icram_we(icram_we),
        .ic_addr(ic_addr)
    );

endmodule
