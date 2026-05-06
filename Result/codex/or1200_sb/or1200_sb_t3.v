// Generated from or1200_sb/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_sb(
    // RISC clock, reset
    input clk,
    input rst,

    // Internal RISC bus (DC<->SB)
    input [31:0] dcsb_dat_i,
    input [31:0] dcsb_adr_i,
    input dcsb_cyc_i,
    input dcsb_stb_i,
    input dcsb_we_i,
    input [3:0] dcsb_sel_i,
    input dcsb_cab_i,
    output [31:0] dcsb_dat_o,
    output dcsb_ack_o,
    output dcsb_err_o,

    // BIU bus
    output [31:0] sbbiu_dat_o,
    output [31:0] sbbiu_adr_o,
    output sbbiu_cyc_o,
    output sbbiu_stb_o,
    output sbbiu_we_o,
    output [3:0] sbbiu_sel_o,
    output sbbiu_cab_o,
    input [31:0] sbbiu_dat_i,
    input sbbiu_ack_i,
    input sbbiu_err_i
);

reg [31:0] dcsb_dat_o_r;
reg dcsb_ack_o_r;
reg dcsb_err_o_r;
reg [31:0] sbbiu_dat_o_r;
reg [31:0] sbbiu_adr_o_r;
reg sbbiu_cyc_o_r;
reg sbbiu_stb_o_r;
reg sbbiu_we_o_r;
reg [3:0] sbbiu_sel_o_r;
reg sbbiu_cab_o_r;
assign dcsb_dat_o = dcsb_dat_o_r;
assign dcsb_ack_o = dcsb_ack_o_r;
assign dcsb_err_o = dcsb_err_o_r;
assign sbbiu_dat_o = sbbiu_dat_o_r;
assign sbbiu_adr_o = sbbiu_adr_o_r;
assign sbbiu_cyc_o = sbbiu_cyc_o_r;
assign sbbiu_stb_o = sbbiu_stb_o_r;
assign sbbiu_we_o = sbbiu_we_o_r;
assign sbbiu_sel_o = sbbiu_sel_o_r;
assign sbbiu_cab_o = sbbiu_cab_o_r;

always @* begin
    sbbiu_cyc_o_r = dcsb_cyc_i;
    sbbiu_stb_o_r = dcsb_stb_i;
    sbbiu_we_o_r = dcsb_we_i;
    sbbiu_sel_o_r = dcsb_sel_i;
    sbbiu_adr_o_r = dcsb_adr_i;
    sbbiu_dat_o_r = dcsb_dat_i;
    sbbiu_cab_o_r = dcsb_cab_i;
    dcsb_dat_o_r = sbbiu_dat_i;
    dcsb_ack_o_r = sbbiu_ack_i;
    dcsb_err_o_r = sbbiu_err_i;
end

endmodule
