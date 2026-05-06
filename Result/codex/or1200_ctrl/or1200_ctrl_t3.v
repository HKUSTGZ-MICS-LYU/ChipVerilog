// Generated from or1200_ctrl/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_ctrl(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input flushpipe,
    input [31:0] if_insn,
    output [31:0] ex_insn,
    output [2:0] branch_op,
    input branch_taken,
    output [4:0] rf_addra,
    output [4:0] rf_addrb,
    output rf_rda,
    output rf_rdb,
    output [3:0] alu_op,
    output [1:0] mac_op,
    output [1:0] shrot_op,
    output [3:0] comp_op,
    output [4:0] rf_addrw,
    output [2:0] rfwb_op,
    output [31:0] wb_insn,
    output [31:0] simm,
    output [31:2] branch_addrofs,
    output [31:0] lsu_addrofs,
    output [1:0] sel_a,
    output [1:0] sel_b,
    output [3:0] lsu_op,
    output [4:0] cust5_op,
    output [5:0] cust5_limm,
    output [1:0] multicycle,
    output [15:0] spr_addrimm,
    input wbforw_valid,
    input du_hwbkpt,
    output sig_syscall,
    output sig_trap,
    output force_dslot_fetch,
    output no_more_dslot,
    output ex_void,
    output id_macrc_op,
    output ex_macrc_op,
    output rfe,
    output except_illegal
);

reg [31:0] ex_insn_r;
reg [2:0] branch_op_r;
reg [4:0] rf_addra_r;
reg [4:0] rf_addrb_r;
reg rf_rda_r;
reg rf_rdb_r;
reg [3:0] alu_op_r;
reg [1:0] mac_op_r;
reg [1:0] shrot_op_r;
reg [3:0] comp_op_r;
reg [4:0] rf_addrw_r;
reg [2:0] rfwb_op_r;
reg [31:0] wb_insn_r;
reg [31:0] simm_r;
reg [31:2] branch_addrofs_r;
reg [31:0] lsu_addrofs_r;
reg [1:0] sel_a_r;
reg [1:0] sel_b_r;
reg [3:0] lsu_op_r;
reg [4:0] cust5_op_r;
reg [5:0] cust5_limm_r;
reg [1:0] multicycle_r;
reg [15:0] spr_addrimm_r;
reg sig_syscall_r;
reg sig_trap_r;
reg force_dslot_fetch_r;
reg no_more_dslot_r;
reg ex_void_r;
reg id_macrc_op_r;
reg ex_macrc_op_r;
reg rfe_r;
reg except_illegal_r;
assign ex_insn = ex_insn_r;
assign branch_op = branch_op_r;
assign rf_addra = rf_addra_r;
assign rf_addrb = rf_addrb_r;
assign rf_rda = rf_rda_r;
assign rf_rdb = rf_rdb_r;
assign alu_op = alu_op_r;
assign mac_op = mac_op_r;
assign shrot_op = shrot_op_r;
assign comp_op = comp_op_r;
assign rf_addrw = rf_addrw_r;
assign rfwb_op = rfwb_op_r;
assign wb_insn = wb_insn_r;
assign simm = simm_r;
assign branch_addrofs = branch_addrofs_r;
assign lsu_addrofs = lsu_addrofs_r;
assign sel_a = sel_a_r;
assign sel_b = sel_b_r;
assign lsu_op = lsu_op_r;
assign cust5_op = cust5_op_r;
assign cust5_limm = cust5_limm_r;
assign multicycle = multicycle_r;
assign spr_addrimm = spr_addrimm_r;
assign sig_syscall = sig_syscall_r;
assign sig_trap = sig_trap_r;
assign force_dslot_fetch = force_dslot_fetch_r;
assign no_more_dslot = no_more_dslot_r;
assign ex_void = ex_void_r;
assign id_macrc_op = id_macrc_op_r;
assign ex_macrc_op = ex_macrc_op_r;
assign rfe = rfe_r;
assign except_illegal = except_illegal_r;

always @* begin
    except_illegal_r = 1'b0;
    ex_insn_r = if_insn;
    wb_insn_r = if_insn;
    branch_op_r = if_insn[31:29];
    rf_addra_r = if_insn[20:16];
    rf_addrb_r = if_insn[15:11];
    rf_addrw_r = if_insn[25:21];
    rf_rda_r = 1'b1;
    rf_rdb_r = 1'b1;
    alu_op_r = if_insn[3:0];
    mac_op_r = if_insn[1:0];
    shrot_op_r = if_insn[7:6];
    comp_op_r = if_insn[3:0];
    rfwb_op_r = {1'b1, if_insn[1:0]};
    sel_a_r = 2'b00;
    sel_b_r = if_insn[16] ? 2'b11 : 2'b00;
    simm_r = {{16{if_insn[15]}}, if_insn[15:0]};
    branch_addrofs_r = if_insn[31:2];
    lsu_addrofs_r = {{16{if_insn[15]}}, if_insn[15:0]};
    lsu_op_r = if_insn[27:24];
    cust5_op_r = if_insn[25:21];
    cust5_limm_r = if_insn[5:0];
    multicycle_r = if_insn[1:0];
    spr_addrimm_r = if_insn[15:0];
    sig_syscall_r = (if_insn[31:24] == 8'h20);
    sig_trap_r = (if_insn[31:24] == 8'h21);
    force_dslot_fetch_r = branch_taken & !id_freeze;
    no_more_dslot_r = flushpipe;
    ex_void_r = (if_insn == 32'h1500_0000);
    id_macrc_op_r = (if_insn[10:6] == 5'h1f);
    ex_macrc_op_r = id_macrc_op_r & !ex_freeze;
    rfe_r = (if_insn[31:24] == 8'h24);
    except_illegal_r = du_hwbkpt & wbforw_valid;
end

endmodule
