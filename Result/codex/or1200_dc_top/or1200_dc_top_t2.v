// Generated from or1200_dc_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
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

reg [31:0] dcsb_dat_o_r;
reg [31:0] dcsb_adr_o_r;
reg dcsb_cyc_o_r;
reg dcsb_stb_o_r;
reg dcsb_we_o_r;
reg [3:0] dcsb_sel_o_r;
reg dcsb_cab_o_r;
reg [31:0] dcqmem_dat_o_r;
reg dcqmem_ack_o_r;
reg dcqmem_rty_o_r;
reg dcqmem_err_o_r;
reg [3:0] dcqmem_tag_o_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
assign dcsb_dat_o = dcsb_dat_o_r;
assign dcsb_adr_o = dcsb_adr_o_r;
assign dcsb_cyc_o = dcsb_cyc_o_r;
assign dcsb_stb_o = dcsb_stb_o_r;
assign dcsb_we_o = dcsb_we_o_r;
assign dcsb_sel_o = dcsb_sel_o_r;
assign dcsb_cab_o = dcsb_cab_o_r;
assign dcqmem_dat_o = dcqmem_dat_o_r;
assign dcqmem_ack_o = dcqmem_ack_o_r;
assign dcqmem_rty_o = dcqmem_rty_o_r;
assign dcqmem_err_o = dcqmem_err_o_r;
assign dcqmem_tag_o = dcqmem_tag_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif

always @* begin
    dcqmem_dat_o_r = dcsb_dat_i;
    dcqmem_ack_o_r = dcsb_ack_i;
    dcqmem_err_o_r = dcsb_err_i;
    dcqmem_rty_o_r = !dcqmem_ack_o_r;
    dcqmem_tag_o_r = dcsb_err_i ? 4'hf : dcqmem_tag_i;
    dcsb_adr_o_r = dcqmem_adr_i;
    dcsb_cyc_o_r = dcqmem_cycstb_i;
    dcsb_stb_o_r = dcqmem_cycstb_i;
    dcsb_we_o_r = dcqmem_we_i;
    dcsb_sel_o_r = dcqmem_sel_i;
    dcsb_dat_o_r = dcqmem_dat_i;
    dcsb_cab_o_r = dc_en & !dcqmem_we_i;
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
