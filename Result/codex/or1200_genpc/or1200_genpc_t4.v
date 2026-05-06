`include "or1200_defines.v"


module or1200_genpc(
    input clk,
    input rst,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,
    input [2:0] branch_op,
    input [3:0] except_type,
    input except_prefix,
    input [31:2] branch_addrofs,
    input [31:0] lr_restor,
    input flag,
    output taken,
    input except_start,
    input [31:2] binsn_addr,
    input [31:0] epcr,
    input [31:0] spr_dat_i,
    input spr_pc_we,
    input genpc_refetch,
    input genpc_freeze,
    input genpc_stop_prefetch,
    input no_more_dslot
);
reg [31:2] pcreg;
reg genpc_refetch_r;
wire [31:0] except_vec = {except_prefix ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P, except_type, 8'h00};
reg [31:0] pc_next;
always @(*) begin
    if (spr_pc_we) pc_next = spr_dat_i;
    else if (except_start) pc_next = except_vec;
    else case (branch_op)
        `OR1200_BRANCHOP_J:   pc_next = {branch_addrofs,2'b00};
        `OR1200_BRANCHOP_JR:  pc_next = lr_restor;
        `OR1200_BRANCHOP_BAL: pc_next = {binsn_addr + branch_addrofs, 2'b00};
        `OR1200_BRANCHOP_BF:  pc_next = flag ? {branch_addrofs,2'b00} : {pcreg + 30'd1,2'b00};
        `OR1200_BRANCHOP_BNF: pc_next = !flag ? {branch_addrofs,2'b00} : {pcreg + 30'd1,2'b00};
        `OR1200_BRANCHOP_RFE: pc_next = epcr;
        default: pc_next = {pcreg + 30'd1,2'b00};
    endcase
end
assign taken = spr_pc_we || except_start || (branch_op==`OR1200_BRANCHOP_J) || (branch_op==`OR1200_BRANCHOP_JR) || (branch_op==`OR1200_BRANCHOP_BAL) || ((branch_op==`OR1200_BRANCHOP_BF)&&flag) || ((branch_op==`OR1200_BRANCHOP_BNF)&&!flag) || (branch_op==`OR1200_BRANCHOP_RFE);
assign icpu_adr_o = ((no_more_dslot || except_start || spr_pc_we) && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc_next;
assign icpu_cycstb_o = !genpc_freeze & !genpc_stop_prefetch;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = `OR1200_ITAG_NI;
always @(posedge clk or posedge rst) begin
    if (rst) begin pcreg <= 30'h0000003f; genpc_refetch_r <= 1'b0; end
    else begin
        genpc_refetch_r <= genpc_refetch;
        if (spr_pc_we) pcreg <= spr_dat_i[31:2];
        else if (no_more_dslot || except_start || (!genpc_freeze && !icpu_rty_i && !genpc_refetch)) pcreg <= pc_next[31:2];
    end
end
endmodule
