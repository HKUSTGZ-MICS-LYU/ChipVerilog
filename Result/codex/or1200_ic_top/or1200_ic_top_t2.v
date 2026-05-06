// Generated from or1200_ic_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
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

reg [31:0] icbiu_dat_o_r;
reg [31:0] icbiu_adr_o_r;
reg icbiu_cyc_o_r;
reg icbiu_stb_o_r;
reg icbiu_we_o_r;
reg [3:0] icbiu_sel_o_r;
reg icbiu_cab_o_r;
reg [31:0] icqmem_dat_o_r;
reg icqmem_ack_o_r;
reg icqmem_rty_o_r;
reg icqmem_err_o_r;
reg [3:0] icqmem_tag_o_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
assign icbiu_dat_o = icbiu_dat_o_r;
assign icbiu_adr_o = icbiu_adr_o_r;
assign icbiu_cyc_o = icbiu_cyc_o_r;
assign icbiu_stb_o = icbiu_stb_o_r;
assign icbiu_we_o = icbiu_we_o_r;
assign icbiu_sel_o = icbiu_sel_o_r;
assign icbiu_cab_o = icbiu_cab_o_r;
assign icqmem_dat_o = icqmem_dat_o_r;
assign icqmem_ack_o = icqmem_ack_o_r;
assign icqmem_rty_o = icqmem_rty_o_r;
assign icqmem_err_o = icqmem_err_o_r;
assign icqmem_tag_o = icqmem_tag_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif

always @* begin
    icqmem_dat_o_r = icbiu_dat_i;
    icqmem_ack_o_r = icbiu_ack_i;
    icqmem_err_o_r = icbiu_err_i;
    icqmem_rty_o_r = !icqmem_ack_o_r;
    icqmem_tag_o_r = icbiu_err_i ? 4'hf : icqmem_tag_i;
    icbiu_adr_o_r = icqmem_adr_i;
    icbiu_cyc_o_r = icqmem_cycstb_i;
    icbiu_stb_o_r = icqmem_cycstb_i;
    icbiu_we_o_r = 1'b0;
    icbiu_sel_o_r = 4'hf;
    icbiu_cab_o_r = ic_en;
    icbiu_dat_o_r = 32'd0;
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
