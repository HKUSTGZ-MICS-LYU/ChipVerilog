// Generated from or1200_du/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_du(
    // RISC Internal Interface
    input clk,
    input rst,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    input [31:0] dcpu_adr_i,
    input [31:0] dcpu_dat_lsu,
    input [31:0] dcpu_dat_dc,
    input icpu_cycstb_i,
    input ex_freeze,
    input [2:0] branch_op,
    input [31:0] ex_insn,
    input [31:0] id_pc,
    input [31:0] spr_dat_npc,
    input [31:0] rf_dataw,
    output [13:0] du_dsr,
    output du_stall,
    output [31:0] du_addr,
    input [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output du_read,
    output du_write,
    input [12:0] du_except,
    output du_hwbkpt,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    // External Debug Interface
    input dbg_stall_i,
    input dbg_ewt_i,
    output [3:0] dbg_lss_o,
    output [1:0] dbg_is_o,
    output [10:0] dbg_wp_o,
    output dbg_bp_o,
    input dbg_stb_i,
    input dbg_we_i,
    input [31:0] dbg_adr_i,
    input [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output dbg_ack_o
);

reg [13:0] du_dsr_r;
reg du_stall_r;
reg [31:0] du_addr_r;
reg [31:0] du_dat_o_r;
reg du_read_r;
reg du_write_r;
reg du_hwbkpt_r;
reg [31:0] spr_dat_o_r;
reg [3:0] dbg_lss_o_r;
reg [1:0] dbg_is_o_r;
reg [10:0] dbg_wp_o_r;
reg dbg_bp_o_r;
reg [31:0] dbg_dat_o_r;
reg dbg_ack_o_r;
assign du_dsr = du_dsr_r;
assign du_stall = du_stall_r;
assign du_addr = du_addr_r;
assign du_dat_o = du_dat_o_r;
assign du_read = du_read_r;
assign du_write = du_write_r;
assign du_hwbkpt = du_hwbkpt_r;
assign spr_dat_o = spr_dat_o_r;
assign dbg_lss_o = dbg_lss_o_r;
assign dbg_is_o = dbg_is_o_r;
assign dbg_wp_o = dbg_wp_o_r;
assign dbg_bp_o = dbg_bp_o_r;
assign dbg_dat_o = dbg_dat_o_r;
assign dbg_ack_o = dbg_ack_o_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        du_dsr_r <= 0;
        du_stall_r <= 0;
        du_addr_r <= 0;
        du_dat_o_r <= 0;
        du_read_r <= 0;
        du_write_r <= 0;
        du_hwbkpt_r <= 0;
        spr_dat_o_r <= 0;
        dbg_lss_o_r <= 0;
        dbg_is_o_r <= 0;
        dbg_wp_o_r <= 0;
        dbg_bp_o_r <= 0;
        dbg_dat_o_r <= 0;
        dbg_ack_o_r <= 0;
    end else begin
        du_dat_o_r <= du_dat_i;
        spr_dat_o_r <= spr_dat_i;
        dbg_dat_o_r <= dbg_dat_i;
    end
end

endmodule
