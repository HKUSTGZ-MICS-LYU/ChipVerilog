// Generated from or1200_immu_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_immu_top(
    // Rst and clk
    input clk,
    input rst,

    // CPU i/f
    input ic_en,
    input immu_en,
    input supv,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    output [31:0] icpu_adr_o,
    output [3:0] icpu_tag_o,
    output icpu_rty_o,
    output icpu_err_o,

    // SPR access
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // QMEM i/f
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    output [31:0] qmemimmu_adr_o,
    output qmemimmu_cycstb_o,
    output qmemimmu_ci_o
);

reg [31:0] icpu_adr_o_r;
reg [3:0] icpu_tag_o_r;
reg icpu_rty_o_r;
reg icpu_err_o_r;
reg [31:0] spr_dat_o_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [31:0] qmemimmu_adr_o_r;
reg qmemimmu_cycstb_o_r;
reg qmemimmu_ci_o_r;
assign icpu_adr_o = icpu_adr_o_r;
assign icpu_tag_o = icpu_tag_o_r;
assign icpu_rty_o = icpu_rty_o_r;
assign icpu_err_o = icpu_err_o_r;
assign spr_dat_o = spr_dat_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign qmemimmu_adr_o = qmemimmu_adr_o_r;
assign qmemimmu_cycstb_o = qmemimmu_cycstb_o_r;
assign qmemimmu_ci_o = qmemimmu_ci_o_r;

always @* begin
    icpu_adr_o_r = icpu_adr_i;
    icpu_tag_o_r = qmemimmu_tag_i;
    icpu_rty_o_r = qmemimmu_rty_i;
    icpu_err_o_r = immu_en ? qmemimmu_err_i : 1'b0;
    spr_dat_o_r = {30'd0, supv, immu_en};
    qmemimmu_adr_o_r = icpu_adr_i;
    qmemimmu_cycstb_o_r = ic_en & icpu_cycstb_i;
    qmemimmu_ci_o_r = !immu_en;
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
