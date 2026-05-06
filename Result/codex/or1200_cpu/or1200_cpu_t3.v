// Generated from or1200_cpu/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_cpu(
    // Clk & Rst
    input clk,
    input rst,

    // Insn interface
    output ic_en,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    output immu_en,

    // Debug unit
    output [31:0] ex_insn,
    output ex_freeze,
    output [31:0] id_pc,
    output [2:0] branch_op,
    output [31:0] spr_dat_npc,
    output [31:0] rf_dataw,
    input du_stall,
    input [31:0] du_addr,
    input [31:0] du_dat_du,
    input du_read,
    input du_write,
    input [13:0] du_dsr,
    input du_hwbkpt,
    output [12:0] du_except,
    output [31:0] du_dat_cpu,

    // Data interface
    output dc_en,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i,
    output dmmu_en,

    // Interrupt & tick exceptions
    input sig_int,
    input sig_tick,

    // SPR interface
    output supv,
    output [31:0] spr_addr,
    output [31:0] spr_dat_cpu,
    input [31:0] spr_dat_pic,
    input [31:0] spr_dat_tt,
    input [31:0] spr_dat_pm,
    input [31:0] spr_dat_dmmu,
    input [31:0] spr_dat_immu,
    input [31:0] spr_dat_du,
    output [31:0] spr_cs,
    output spr_we
);

reg ic_en_r;
reg [31:0] icpu_adr_o_r;
reg icpu_cycstb_o_r;
reg [3:0] icpu_sel_o_r;
reg [3:0] icpu_tag_o_r;
reg immu_en_r;
reg [31:0] ex_insn_r;
reg ex_freeze_r;
reg [31:0] id_pc_r;
reg [2:0] branch_op_r;
reg [31:0] spr_dat_npc_r;
reg [31:0] rf_dataw_r;
reg [12:0] du_except_r;
reg [31:0] du_dat_cpu_r;
reg dc_en_r;
reg [31:0] dcpu_adr_o_r;
reg dcpu_cycstb_o_r;
reg dcpu_we_o_r;
reg [3:0] dcpu_sel_o_r;
reg [3:0] dcpu_tag_o_r;
reg [31:0] dcpu_dat_o_r;
reg dmmu_en_r;
reg supv_r;
reg [31:0] spr_addr_r;
reg [31:0] spr_dat_cpu_r;
reg [31:0] spr_cs_r;
reg spr_we_r;
assign ic_en = ic_en_r;
assign icpu_adr_o = icpu_adr_o_r;
assign icpu_cycstb_o = icpu_cycstb_o_r;
assign icpu_sel_o = icpu_sel_o_r;
assign icpu_tag_o = icpu_tag_o_r;
assign immu_en = immu_en_r;
assign ex_insn = ex_insn_r;
assign ex_freeze = ex_freeze_r;
assign id_pc = id_pc_r;
assign branch_op = branch_op_r;
assign spr_dat_npc = spr_dat_npc_r;
assign rf_dataw = rf_dataw_r;
assign du_except = du_except_r;
assign du_dat_cpu = du_dat_cpu_r;
assign dc_en = dc_en_r;
assign dcpu_adr_o = dcpu_adr_o_r;
assign dcpu_cycstb_o = dcpu_cycstb_o_r;
assign dcpu_we_o = dcpu_we_o_r;
assign dcpu_sel_o = dcpu_sel_o_r;
assign dcpu_tag_o = dcpu_tag_o_r;
assign dcpu_dat_o = dcpu_dat_o_r;
assign dmmu_en = dmmu_en_r;
assign supv = supv_r;
assign spr_addr = spr_addr_r;
assign spr_dat_cpu = spr_dat_cpu_r;
assign spr_cs = spr_cs_r;
assign spr_we = spr_we_r;

reg [31:0] pc_reg;

always @(posedge clk or posedge rst) begin
    if (rst)
        pc_reg <= 32'd0;
    else if (!du_stall && icpu_ack_i)
        pc_reg <= icpu_adr_i + 32'd4;
end

always @* begin
    ic_en_r = 1'b1;
    immu_en_r = 1'b1;
    dc_en_r = 1'b1;
    dmmu_en_r = 1'b1;
    ex_insn_r = icpu_dat_i;
    ex_freeze_r = du_stall;
    id_pc_r = icpu_adr_i;
    branch_op_r = 3'd0;
    spr_dat_npc_r = pc_reg;
    rf_dataw_r = dcpu_dat_i;
    du_except_r = {11'd0, sig_int, sig_tick};
    du_dat_cpu_r = du_dat_du;
    icpu_adr_o_r = pc_reg;
    icpu_cycstb_o_r = !du_stall;
    icpu_sel_o_r = 4'hf;
    icpu_tag_o_r = 4'd0;
    dcpu_adr_o_r = pc_reg;
    dcpu_cycstb_o_r = 1'b0;
    dcpu_we_o_r = 1'b0;
    dcpu_sel_o_r = 4'hf;
    dcpu_tag_o_r = 4'd0;
    dcpu_dat_o_r = 32'd0;
    supv_r = 1'b1;
    spr_addr_r = du_addr;
    spr_dat_cpu_r = du_dat_du;
    spr_cs_r = du_read | du_write;
    spr_we_r = du_write;
end

endmodule
