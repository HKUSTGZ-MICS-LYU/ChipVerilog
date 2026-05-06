module or1200_top(
    input clk,
    input rst,
    input sig_int,
    input sig_tick,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i
);

    wire clk_cpu;
    wire ic_en;
    wire dc_en;
    wire immu_en;
    wire dmmu_en;
    wire supv;

    assign clk_cpu = clk;

    or1200_cpu cpu_inst(
        .clk(clk_cpu),
        .rst(rst),
        .ic_en(ic_en),
        .dc_en(dc_en),
        .immu_en(immu_en),
        .dmmu_en(dmmu_en),
        .supv(supv),
        .icpu_adr_o(icpu_adr_o),
        .icpu_cycstb_o(icpu_cycstb_o),
        .icpu_sel_o(icpu_sel_o),
        .icpu_tag_o(icpu_tag_o),
        .icpu_dat_i(icpu_dat_i),
        .icpu_ack_i(icpu_ack_i),
        .icpu_rty_i(icpu_rty_i),
        .icpu_err_i(icpu_err_i),
        .dcpu_adr_o(dcpu_adr_o),
        .dcpu_cycstb_o(dcpu_cycstb_o),
        .dcpu_we_o(dcpu_we_o),
        .dcpu_sel_o(dcpu_sel_o),
        .dcpu_tag_o(dcpu_tag_o),
        .dcpu_dat_o(dcpu_dat_o),
        .dcpu_dat_i(dcpu_dat_i),
        .dcpu_ack_i(dcpu_ack_i),
        .dcpu_rty_i(dcpu_rty_i),
        .dcpu_err_i(dcpu_err_i),
        .sig_int(sig_int),
        .sig_tick(sig_tick)
    );

endmodule
