// Generated from or1200_qmem_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_qmem_top(
    // Rst, clk and clock control
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // QMEM and CPU/IMMU
    input [31:0] qmemimmu_adr_i,
    input qmemimmu_cycstb_i,
    input qmemimmu_ci_i,
    input [3:0] qmemicpu_sel_i,
    input [3:0] qmemicpu_tag_i,
    output [31:0] qmemicpu_dat_o,
    output qmemicpu_ack_o,
    output qmemimmu_rty_o,
    output qmemimmu_err_o,
    output [3:0] qmemimmu_tag_o,

    // QMEM and IC
    output [31:0] icqmem_adr_o,
    output icqmem_cycstb_o,
    output icqmem_ci_o,
    output [3:0] icqmem_sel_o,
    output [3:0] icqmem_tag_o,
    input [31:0] icqmem_dat_i,
    input icqmem_ack_i,
    input icqmem_rty_i,
    input icqmem_err_i,
    input [3:0] icqmem_tag_i,

    // QMEM and CPU/DMMU
    input [31:0] qmemdmmu_adr_i,
    input qmemdmmu_cycstb_i,
    input qmemdmmu_ci_i,
    input qmemdcpu_we_i,
    input [3:0] qmemdcpu_sel_i,
    input [3:0] qmemdcpu_tag_i,
    input [31:0] qmemdcpu_dat_i,
    output [31:0] qmemdcpu_dat_o,
    output qmemdcpu_ack_o,
    output qmemdcpu_rty_o,
    output qmemdmmu_err_o,
    output [3:0] qmemdmmu_tag_o,

    // QMEM and DC
    output [31:0] dcqmem_adr_o,
    output dcqmem_cycstb_o,
    output dcqmem_ci_o,
    output dcqmem_we_o,
    output [3:0] dcqmem_sel_o,
    output [3:0] dcqmem_tag_o,
    output [31:0] dcqmem_dat_o,
    input [31:0] dcqmem_dat_i,
    input dcqmem_ack_i,
    input dcqmem_rty_i,
    input dcqmem_err_i,
    input [3:0] dcqmem_tag_i
);

`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [31:0] qmemicpu_dat_o_r;
reg qmemicpu_ack_o_r;
reg qmemimmu_rty_o_r;
reg qmemimmu_err_o_r;
reg [3:0] qmemimmu_tag_o_r;
reg [31:0] icqmem_adr_o_r;
reg icqmem_cycstb_o_r;
reg icqmem_ci_o_r;
reg [3:0] icqmem_sel_o_r;
reg [3:0] icqmem_tag_o_r;
reg [31:0] qmemdcpu_dat_o_r;
reg qmemdcpu_ack_o_r;
reg qmemdcpu_rty_o_r;
reg qmemdmmu_err_o_r;
reg [3:0] qmemdmmu_tag_o_r;
reg [31:0] dcqmem_adr_o_r;
reg dcqmem_cycstb_o_r;
reg dcqmem_ci_o_r;
reg dcqmem_we_o_r;
reg [3:0] dcqmem_sel_o_r;
reg [3:0] dcqmem_tag_o_r;
reg [31:0] dcqmem_dat_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign qmemicpu_dat_o = qmemicpu_dat_o_r;
assign qmemicpu_ack_o = qmemicpu_ack_o_r;
assign qmemimmu_rty_o = qmemimmu_rty_o_r;
assign qmemimmu_err_o = qmemimmu_err_o_r;
assign qmemimmu_tag_o = qmemimmu_tag_o_r;
assign icqmem_adr_o = icqmem_adr_o_r;
assign icqmem_cycstb_o = icqmem_cycstb_o_r;
assign icqmem_ci_o = icqmem_ci_o_r;
assign icqmem_sel_o = icqmem_sel_o_r;
assign icqmem_tag_o = icqmem_tag_o_r;
assign qmemdcpu_dat_o = qmemdcpu_dat_o_r;
assign qmemdcpu_ack_o = qmemdcpu_ack_o_r;
assign qmemdcpu_rty_o = qmemdcpu_rty_o_r;
assign qmemdmmu_err_o = qmemdmmu_err_o_r;
assign qmemdmmu_tag_o = qmemdmmu_tag_o_r;
assign dcqmem_adr_o = dcqmem_adr_o_r;
assign dcqmem_cycstb_o = dcqmem_cycstb_o_r;
assign dcqmem_ci_o = dcqmem_ci_o_r;
assign dcqmem_we_o = dcqmem_we_o_r;
assign dcqmem_sel_o = dcqmem_sel_o_r;
assign dcqmem_tag_o = dcqmem_tag_o_r;
assign dcqmem_dat_o = dcqmem_dat_o_r;

always @* begin
    qmemicpu_dat_o_r = icqmem_dat_i;
    qmemicpu_ack_o_r = icqmem_ack_i;
    qmemimmu_rty_o_r = icqmem_rty_i;
    qmemimmu_err_o_r = icqmem_err_i;
    qmemimmu_tag_o_r = icqmem_tag_i;
    icqmem_adr_o_r = qmemimmu_adr_i;
    icqmem_cycstb_o_r = qmemimmu_cycstb_i;
    icqmem_ci_o_r = qmemimmu_ci_i;
    icqmem_sel_o_r = qmemicpu_sel_i;
    icqmem_tag_o_r = qmemicpu_tag_i;
    qmemdcpu_dat_o_r = dcqmem_dat_i;
    qmemdcpu_ack_o_r = dcqmem_ack_i;
    qmemdcpu_rty_o_r = dcqmem_rty_i;
    qmemdmmu_err_o_r = dcqmem_err_i;
    qmemdmmu_tag_o_r = dcqmem_tag_i;
    dcqmem_adr_o_r = qmemdmmu_adr_i;
    dcqmem_cycstb_o_r = qmemdmmu_cycstb_i;
    dcqmem_ci_o_r = qmemdmmu_ci_i;
    dcqmem_we_o_r = qmemdcpu_we_i;
    dcqmem_sel_o_r = qmemdcpu_sel_i;
    dcqmem_tag_o_r = qmemdcpu_tag_i;
    dcqmem_dat_o_r = qmemdcpu_dat_i;
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
