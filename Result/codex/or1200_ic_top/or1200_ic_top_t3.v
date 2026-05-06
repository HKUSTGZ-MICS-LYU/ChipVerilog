// Generated for or1200_ic_top from local description.txt and detail.txt only.
module or1200_ic_top(
    // Rst, clk and clock control
    input clk,
    input rst,

    // External i/f
    output [31:0] icbiu_dat_o,
    output [31:0] icbiu_adr_o,
    output icbiu_cyc_o,
    output icbiu_stb_o,
    output icbiu_we_o,
    output [3:0] icbiu_sel_o,
    output icbiu_cab_o,
    input [31:0] icbiu_dat_i,
    input icbiu_ack_i,
    input icbiu_err_i,

    // Internal i/f
    input ic_en,
    input [31:0] icqmem_adr_i,
    input icqmem_cycstb_i,
    input icqmem_ci_i,
    input [3:0] icqmem_sel_i,
    input [3:0] icqmem_tag_i,
    output [31:0] icqmem_dat_o,
    output icqmem_ack_o,
    output icqmem_rty_o,
    output icqmem_err_o,
    output [3:0] icqmem_tag_o,

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
assign icbiu_dat_o = 0;
assign icbiu_adr_o = 0;
assign icbiu_cyc_o = 0;
assign icbiu_stb_o = 0;
assign icbiu_we_o = 0;
assign icbiu_sel_o = 0;
assign icbiu_cab_o = 0;
assign icqmem_dat_o = 0;
assign icqmem_ack_o = 0;
assign icqmem_rty_o = 0;
assign icqmem_err_o = 0;
assign icqmem_tag_o = 0;
endmodule
