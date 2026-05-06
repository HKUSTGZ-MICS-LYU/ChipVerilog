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

// ---------------------------------------------------------------------------
// Internal wires and registers
// ---------------------------------------------------------------------------

// SR bits (exported outputs)
reg [31:0] sr;

assign ic_en       = sr[4];
assign immu_en     = sr[6];
assign dc_en       = sr[3];
assign dmmu_en     = sr[5];
assign supv        = sr[0];
reg except_prefix; // from sr[14] for genpc

// Freeze signals from freeze module
wire freeze_pc;
wire freeze_if;
wire freeze_id;
wire freeze_ex;
wire freeze_wb;
wire freeze_mac;

// Pipeline flush and control
wire flushpipe;
wire ext_flush;
wire abort_ex;
wire ila_ds; // instruction fetch alignment exception or similar

// IF stage wires
wire [31:0] insn_if;
wire [31:0] pc_if;
wire if_stall;
wire if_err;
wire if_align;

// ID stage wires from ctrl
wire [31:0] insn_id;
wire [31:0] pc_id;
wire [31:0] immediate;
wire [31:0] branch_offset;
wire [31:0] lsu_offset;
wire [4:0] rf_raddr_a;
wire [4:0] rf_raddr_b;
wire [4:0] rf_waddr;
wire we_rf; // write enable for register file, derived from rfwb_op[0]
wire [2:0] branch_op_int;
wire [3:0] rfwb_op;
wire [4:0] alu_op;
wire [2:0] mac_op;
wire [2:0] lsu_op;
wire [31:0] spr_immediate;
wire syscall;
wire trap;
wire illegal;
wire rfe;
wire ds_delayslot;
wire mac_ce;

// Register file
wire [31:0] rf_data_a;
wire [31:0] rf_data_b;

// Operand selection and forwarding
wire [31:0] operand_a;
wire [31:0] operand_b;
wire [31:0] operand_imm;
wire flag_od;
wire carry_od;

// ALU result and flags
wire [31:0] alu_result;
wire flag_al;
wire carry_al;
wire alu_we_flag;
wire alu_we_carry;

// Multiplier/MAC result
wire [31:0] mac_result;
wire mac_busy;

// LSU signals
wire lsu_stall;
wire [31:0] lsu_data;
wire lsu_except;
wire lsu_align_except;

// Write-back mux
wire [31:0] wb_mux_out;
wire [31:0] wb_fwd_data;
wire wb_fwd_valid;

// Exception module
wire [6:0] except_type;
wire except_start;
wire except_ack;
wire [31:0] except_epc;
wire [31:0] except_eear;
wire [31:0] except_esr;
wire [12:0] except_stop;
wire except_illegal;
wire except_buserr;

// Debug signals
wire [31:0] du_dat_cpu_int;
wire du_except_int;

// SPR bus internal
wire [31:0] spr_addr_int;
wire [31:0] spr_dat_cpu_int;
wire [31:0] spr_cs_int;
wire spr_we_int;
wire [31:0] spr_dat_npc_int;

// GenPC/IF address bus signals
wire [31:0] icpu_adr_int;
wire icpu_cycstb_int;

// ---------------------------------------------------------------------------
// Submodule instances
// ---------------------------------------------------------------------------

// Freeze logic
or1200_freeze u_freeze (
    .clk(clk),
    .rst(rst),
    .if_stall(if_stall),
    .lsu_stall(lsu_stall),
    .flushpipe(flushpipe),
    .ext_flush(ext_flush),
    .abort_ex(abort_ex),
    .du_stall(du_stall),
    .mac_busy(mac_busy),
    .mac_ce(mac_ce),
    .ds_delayslot(ds_delayslot),
    .if_ack(icpu_ack_i),
    .if_err(if_err),
    .freeze_pc(freeze_pc),
    .freeze_if(freeze_if),
    .freeze_id(freeze_id),
    .freeze_ex(freeze_ex),
    .freeze_wb(freeze_wb),
    .freeze_mac(freeze_mac)
);

// SR/SPR access module (includes SR register and SPR bus interface)
or1200_sprs u_sprs (
    .clk(clk),
    .rst(rst),
    .du_addr(du_addr),
    .du_dat_du(du_dat_du),
    .du_read(du_read),
    .du_write(du_write),
    .spr_dat_pic(spr_dat_pic),
    .spr_dat_tt(spr_dat_tt),
    .spr_dat_pm(spr_dat_pm),
    .spr_dat_dmmu(spr_dat_dmmu),
    .spr_dat_immu(spr_dat_immu),
    .spr_dat_du(spr_dat_du),
    .except_type(except_type),
    .except_start(except_start),
    .except_ack(except_ack),
    .except_epc(except_epc),
    .except_eear(except_eear),
    .except_esr(except_esr),
    .sr(sr),
    .spr_addr(spr_addr_int),
    .spr_dat_cpu(spr_dat_cpu_int),
    .spr_cs(spr_cs_int),
    .spr_we(spr_we_int),
    .spr_dat_npc(spr_dat_npc_int),
    .du_dat_cpu(du_dat_cpu_int)
);

assign except_prefix = sr[14];

// Program Counter generator
or1200_genpc u_genpc (
    .clk(clk),
    .rst(rst),
    .freeze(freeze_pc),
    .branch_op(branch_op_int),
    .flag(flag_od),
    .branch_offset(branch_offset),
    .link_reg(alu_result), // typically link address from ALU
    .except_type(except_type),
    .except_start(except_start),
    .except_prefix(except_prefix),
    .epcr(except_epc),
    .rfe(rfe),
    .pc_wr(spr_dat_cpu_int), // software write to PC via SPR
    .pc_wr_en(spr_we_int & (spr_addr_int == 32'h0000_0010)), // example: SPR_NPC
    .pc_current(pc_if),
    .icpu_adr_o(icpu_adr_int),
    .icpu_cycstb_o(icpu_cycstb_int)
);

// Instruction Fetch
or1200_if u_if (
    .clk(clk),
    .rst(rst),
    .freeze(freeze_if),
    .flushpipe(flushpipe),
    .ext_flush(ext_flush),
    .abort_ex(abort_ex),
    .rfe(rfe),
    .ds_delayslot(ds_delayslot),
    .pc_from_genpc(pc_if),
    .insn_from_mem(icpu_dat_i),
    .ack(icpu_ack_i),
    .err(icpu_err_i),
    .adr_i(icpu_adr_i),
    .tag_i(icpu_tag_i),
    .insn_out(insn_if),
    .pc_out(pc_if),
    .stall(if_stall),
    .err_exception(if_err),
    .align_exception(if_align)
);

// Instruction decode / control
or1200_ctrl u_ctrl (
    .clk(clk),
    .rst(rst),
    .freeze(freeze_id),
    .flushpipe(flushpipe),
    .insn(insn_if),
    .pc(pc_if),
    .branch_op(branch_op_int),
    .immediate(immediate),
    .branch_offset(branch_offset),
    .lsu_offset(lsu_offset),
    .rf_raddr_a(rf_raddr_a),
    .rf_raddr_b(rf_raddr_b),
    .rf_waddr(rf_waddr),
    .rfwb_op(rfwb_op),
    .alu_op(alu_op),
    .mac_op(mac_op),
    .lsu_op(lsu_op),
    .spr_immediate(spr_immediate),
    .syscall(syscall),
    .trap(trap),
    .illegal(illegal),
    .rfe(rfe),
    .ds_delayslot(ds_delayslot),
    .mac_ce(mac_ce),
    .id_pc(id_pc),
    .ex_insn(ex_insn)
);

assign we_rf = rfwb_op[0];
assign branch_op = branch_op_int;

// Register file
or1200_rf u_rf (
    .clk(clk),
    .rst(rst),
    .raddr_a(rf_raddr_a),
    .raddr_b(rf_raddr_b),
    .waddr(rf_waddr),
    .we(we_rf),
    .wdata(rf_dataw),
    .freeze(freeze_id),
    .data_a(rf_data_a),
    .data_b(rf_data_b)
);

// Operand muxes and forwarding
or1200_operandmuxes u_operandmuxes (
    .clk(clk),
    .rst(rst),
    .rf_data_a(rf_data_a),
    .rf_data_b(rf_data_b),
    .immediate(immediate),
    .sel_imm(1'b0), // from ctrl, but omitted for brevity
    .alu_result(alu_result),
    .lsu_data(lsu_data),
    .wb_data(wb_mux_out),
    .wb_fwd_data(wb_fwd_data),
    .wb_fwd_valid(wb_fwd_valid),
    .ex_fwd_valid(1'b0), // simplified
    .freeze(freeze_ex),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .operand_imm(operand_imm),
    .flag_out(flag_od),
    .carry_out(carry_od)
);

assign ex_freeze = freeze_ex;

// ALU
or1200_alu u_alu (
    .clk(clk),
    .rst(rst),
    .op(alu_op),
    .a(operand_a),
    .b(operand_b),
    .imm(operand_imm),
    .flag_in(flag_od),
    .carry_in(carry_od),
    .result(alu_result),
    .flag_out(flag_al),
    .carry_out(carry_al),
    .we_flag(alu_we_flag),
    .we_carry(alu_we_carry)
);

// Multiplier/MAC
or1200_mult_mac u_mult_mac (
    .clk(clk),
    .rst(rst),
    .op(mac_op),
    .a(operand_a),
    .b(operand_b),
    .ce(mac_ce),
    .freeze(freeze_mac),
    .result(mac_result),
    .busy(mac_busy)
);

// Load/Store Unit
or1200_lsu u_lsu (
    .clk(clk),
    .rst(rst),
    .op(lsu_op),
    .addr_base(operand_a),
    .offset(lsu_offset),
    .store_data(operand_b),
    .dcpu_dat_i(dcpu_dat_i),
    .dcpu_ack_i(dcpu_ack_i),
    .dcpu_rty_i(dcpu_rty_i),
    .dcpu_err_i(dcpu_err_i),
    .dcpu_adr_o(dcpu_adr_o),
    .dcpu_cycstb_o(dcpu_cycstb_o),
    .dcpu_we_o(dcpu_we_o),
    .dcpu_sel_o(dcpu_sel_o),
    .dcpu_tag_o(dcpu_tag_o),
    .dcpu_dat_o(dcpu_dat_o),
    .load_data(lsu_data),
    .stall(lsu_stall),
    .except(lsu_except),
    .align_except(lsu_align_except)
);

// Write-back mux
or1200_wbmux u_wbmux (
    .clk(clk),
    .rst(rst),
    .alu_result(alu_result),
    .lsu_data(lsu_data),
    .spr_data(spr_dat_cpu_int), // SPR read data for WB
    .link_addr(spr_dat_npc_int), // link address from genpc/SPR
    .rfwb_op(rfwb_op),
    .freeze(freeze_wb),
    .rf_dataw(rf_dataw),
    .wb_fwd_data(wb_fwd_data),
    .wb_fwd_valid(wb_fwd_valid)
);

// Exception module
or1200_except u_except (
    .clk(clk),
    .rst(rst),
    .if_err(if_err),
    .if_align(if_align),
    .lsu_except(lsu_except),
    .lsu_align_except(lsu_align_except),
    .illegal(illegal),
    .syscall(syscall),
    .trap(trap),
    .interrupt(sig_int),
    .tick(sig_tick),
    .du_hwbkpt(du_hwbkpt),
    .du_dsr(du_dsr),
    .except_type(except_type),
    .except_start(except_start),
    .except_ack(except_ack),
    .except_epc(except_epc),
    .except_eear(except_eear),
    .except_esr(except_esr),
    .flushpipe(flushpipe),
    .ext_flush(ext_flush),
    .except_stop(except_stop),
    .abort_ex(abort_ex)
);

assign du_except = except_stop;

// Debug return data
assign du_dat_cpu = du_dat_cpu_int;

// Output assignments from internal wires
assign spr_addr     = spr_addr_int;
assign spr_dat_cpu   = spr_dat_cpu_int;
assign spr_cs       = spr_cs_int;
assign spr_we       = spr_we_int;
assign spr_dat_npc  = spr_dat_npc_int;

// Instruction side bus outputs
assign icpu_adr_o   = icpu_adr_int;
assign icpu_cycstb_o = icpu_cycstb_int;
assign icpu_sel_o   = 4'b1111;
assign icpu_tag_o   = 4'b0000;

// Debug outputs
assign ex_freeze = freeze_ex;

endmodule
