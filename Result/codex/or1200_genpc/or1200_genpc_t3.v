// Generated from or1200_genpc/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_genpc(
    // Clock and reset
    input clk,
    input rst,

    // External i/f to IC
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,

    // Internal i/f
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

reg [31:0] icpu_adr_o_r;
reg icpu_cycstb_o_r;
reg [3:0] icpu_sel_o_r;
reg [3:0] icpu_tag_o_r;
reg taken_r;
assign icpu_adr_o = icpu_adr_o_r;
assign icpu_cycstb_o = icpu_cycstb_o_r;
assign icpu_sel_o = icpu_sel_o_r;
assign icpu_tag_o = icpu_tag_o_r;
assign taken = taken_r;

reg [31:2] pc_reg;
always @(posedge clk or posedge rst) begin
    if (rst)
        pc_reg <= 30'd0;
    else if (!genpc_freeze) begin
        if (except_start)
            pc_reg <= {except_prefix, 27'd0, except_type};
        else if (spr_pc_we)
            pc_reg <= spr_dat_i[31:2];
        else if (genpc_refetch)
            pc_reg <= icpu_adr_i[31:2];
        else if (branch_op != 0)
            pc_reg <= branch_addrofs;
        else
            pc_reg <= pc_reg + 30'd1;
    end
end

always @* begin
    icpu_adr_o_r = {pc_reg, 2'b00};
    icpu_cycstb_o_r = !genpc_stop_prefetch && !icpu_rty_i && !no_more_dslot;
    icpu_sel_o_r = 4'hf;
    icpu_tag_o_r = {3'd0, except_start};
    taken_r = except_start || spr_pc_we || genpc_refetch || (branch_op != 0);
end

endmodule
