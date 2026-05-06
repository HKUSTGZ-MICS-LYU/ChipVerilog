// Generated for or1200_immu_top from local description.txt and detail.txt only.
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
assign icpu_adr_o = 0;
assign icpu_tag_o = 0;
assign icpu_rty_o = 0;
assign icpu_err_o = 0;
assign spr_dat_o = 0;
assign qmemimmu_adr_o = 0;
assign qmemimmu_cycstb_o = 0;
assign qmemimmu_ci_o = 0;
endmodule
