// Generated from or1200_iwb_biu/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_iwb_biu(
    // RISC clock, reset and clock control
    input clk,
    input rst,
    input [1:0] clmode,

    // WISHBONE interface
    input wb_clk_i,
    input wb_rst_i,
    input wb_ack_i,
    input wb_err_i,
    input wb_rty_i,
    input [31:0] wb_dat_i,
    output wb_cyc_o,
    output [31:0] wb_adr_o,
    output wb_stb_o,
    output wb_we_o,
    output [3:0] wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0] wb_cti_o,
    output [1:0] wb_bte_o,
`endif

    // Internal RISC bus
    input [31:0] biu_dat_i,
    input [31:0] biu_adr_i,
    input biu_cyc_i,
    input biu_stb_i,
    input biu_we_i,
    input [3:0] biu_sel_i,
    input biu_cab_i,
    output [31:0] biu_dat_o,
    output biu_ack_o,
    output biu_err_o
);

reg wb_cyc_o_r;
reg [31:0] wb_adr_o_r;
reg wb_stb_o_r;
reg wb_we_o_r;
reg [3:0] wb_sel_o_r;
reg [31:0] wb_dat_o_r;
`ifdef OR1200_WB_CAB
reg wb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
reg [2:0] wb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
reg [1:0] wb_bte_o_r;
`endif
reg [31:0] biu_dat_o_r;
reg biu_ack_o_r;
reg biu_err_o_r;
assign wb_cyc_o = wb_cyc_o_r;
assign wb_adr_o = wb_adr_o_r;
assign wb_stb_o = wb_stb_o_r;
assign wb_we_o = wb_we_o_r;
assign wb_sel_o = wb_sel_o_r;
assign wb_dat_o = wb_dat_o_r;
`ifdef OR1200_WB_CAB
assign wb_cab_o = wb_cab_o_r;
`endif
`ifdef OR1200_WB_B3
assign wb_cti_o = wb_cti_o_r;
`endif
`ifdef OR1200_WB_B3
assign wb_bte_o = wb_bte_o_r;
`endif
assign biu_dat_o = biu_dat_o_r;
assign biu_ack_o = biu_ack_o_r;
assign biu_err_o = biu_err_o_r;

always @* begin
    wb_adr_o_r = biu_adr_i;
    wb_cyc_o_r = biu_cyc_i;
    wb_stb_o_r = biu_stb_i;
    wb_we_o_r = 1'b0;
    wb_sel_o_r = biu_sel_i;
    wb_dat_o_r = 32'd0;
    biu_dat_o_r = wb_dat_i;
    biu_ack_o_r = wb_ack_i;
    biu_err_o_r = wb_err_i;
`ifdef OR1200_WB_CAB
    wb_cab_o_r = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
    wb_cti_o_r = 3'b000;
    wb_bte_o_r = 2'b00;
`endif
end

endmodule
