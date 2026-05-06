// Generated from or1200_dmmu_top/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
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

reg [3:0] dcpu_tag_o_r;
reg dcpu_err_o_r;
reg [31:0] spr_dat_o_r;
`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [31:0] qmemdmmu_adr_o_r;
reg qmemdmmu_cycstb_o_r;
reg qmemdmmu_ci_o_r;
assign dcpu_tag_o = dcpu_tag_o_r;
assign dcpu_err_o = dcpu_err_o_r;
assign spr_dat_o = spr_dat_o_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign qmemdmmu_adr_o = qmemdmmu_adr_o_r;
assign qmemdmmu_cycstb_o = qmemdmmu_cycstb_o_r;
assign qmemdmmu_ci_o = qmemdmmu_ci_o_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dcpu_tag_o_r <= 0;
        dcpu_err_o_r <= 0;
        spr_dat_o_r <= 0;
`ifdef OR1200_BIST
        mbist_so_o_r <= 0;
`endif
        qmemdmmu_adr_o_r <= 0;
        qmemdmmu_cycstb_o_r <= 0;
        qmemdmmu_ci_o_r <= 0;
    end else begin
        spr_dat_o_r <= spr_dat_i;
    end
end

endmodule
