// Generated for or1200_dmmu_top from local description.txt and detail.txt only.
module or1200_dmmu_top(
    // Rst and clk
    input clk,
    input rst,

    // CPU i/f
    input dc_en,
    input dmmu_en,
    input supv,
    input [31:0] dcpu_adr_i,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    output [3:0] dcpu_tag_o,
    output dcpu_err_o,

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

    // DC i/f
    input qmemdmmu_err_i,
    input [3:0] qmemdmmu_tag_i,
    output [31:0] qmemdmmu_adr_o,
    output qmemdmmu_cycstb_o,
    output qmemdmmu_ci_o
);
assign dcpu_tag_o = 0;
assign dcpu_err_o = 0;
assign spr_dat_o = 0;
assign qmemdmmu_adr_o = 0;
assign qmemdmmu_cycstb_o = 0;
assign qmemdmmu_ci_o = 0;
endmodule
