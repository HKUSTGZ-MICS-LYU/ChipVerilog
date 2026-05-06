// or1200_cpu top-level integration module
module or1200_cpu(
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
    // Internal wires
    wire [31:0] sr;
    wire except_prefix;

    // genpc outputs
    wire [31:0] genpc_pc;
    wire genpc_cycstb;
    wire [3:0] genpc_sel;
    wire [3:0] genpc_tag;

    // if outputs
    wire [31:0] if_insn;
    wire [31:0] if_pc;
    wire if_stall;
    wire if_ibus_err;

    // ctrl outputs (decode stage)
    wire [31:0] ctrl_imm;
    wire [31:0] ctrl_br_offset;
    wire [31:0] ctrl_lsu_offset;
    wire [3:0] ctrl_alu_op;
    wire [2:0] ctrl_mac_op;
    wire [2:0] ctrl_lsu_op;
    wire [1:0] ctrl_rfwb_op;
    wire [4:0] ctrl_rf_addra;
    wire [4:0] ctrl_rf_addrb;
    wire [4:0] ctrl_rf_addrw;
    wire ctrl_rf_rda_en;
    wire ctrl_rf_rdb_en;
    wire ctrl_sel_imm;
    wire ctrl_branch_op;
    wire [2:0] ctrl_branch_sel;
    wire ctrl_syscall;
    wire ctrl_trap;
    wire ctrl_illegal;
    wire ctrl_rfe;
    wire ctrl_dslot;
    wire ctrl_macrc;
    wire ctrl_multicycle;
    wire [15:0] ctrl_spr_addr_imm;
    wire ctrl_spr_we_ctrl;
    wire [31:0] ctrl_spr_cs_ctrl;
    wire ctrl_flag_we;
    wire ctrl_carry_we;
    wire ctrl_except_illegal;

    // rf outputs
    wire [31:0] rf_dataa;
    wire [31:0] rf_datab;

    // operandmuxes outputs
    wire [31:0] opmux_a;
    wire [31:0] opmux_b;
    wire [31:0] opmux_alu_a;
    wire [31:0] opmux_alu_b;
    wire [31:0] opmux_lsu_addr;
    wire [31:0] opmux_lsu_data;

    // alu outputs
    wire [31:0] alu_result;
    wire alu_flag;
    wire alu_carry;
    wire alu_flag_we;
    wire alu_carry_we;

    // mac outputs
    wire [31:0] mac_result;
    wire mac_busy;
    wire mac_stall;

    // lsu outputs
    wire lsu_stall;
    wire lsu_align_err;
    wire lsu_dtlb_miss;
    wire lsu_dmmu_fault;
    wire lsu_dbus_err;
    wire [31:0] lsu_data_r;

    // wbmux outputs
    wire [31:0] wbmux_rf_dataw;
    wire [31:0] wbmux_fwd_data;
    wire wbmux_fwd_valid;

    // except outputs
    wire [2:0] except_type;
    wire except_start;
    wire except_started;
    wire except_flushpipe;
    wire except_ext_flush;
    wire [12:0] except_stop;
    wire except_epcr_we;
    wire [31:0] except_epcr;
    wire except_eear_we;
    wire [31:0] except_eear;
    wire except_esr_we;
    wire [31:0] except_esr;
    wire except_abort;

    // freeze outputs
    wire freeze_genpc;
    wire freeze_if;
    wire freeze_id;
    wire freeze_ex;
    wire freeze_wb;
    wire freeze_refetch;

    // spr outputs
    wire [31:0] sprs_sr;
    wire [31:0] sprs_spr_dat_cpu;
    wire [31:0] sprs_spr_addr;
    wire [31:0] sprs_spr_cs;
    wire sprs_spr_we;
    wire [31:0] sprs_du_dat_cpu;
    wire sprs_branch_op;
    wire [31:0] sprs_spr_dat_npc;

    // Additional internal connections for genpc
    wire [31:0] genpc_link_addr;
    wire genpc_branch_taken;
    wire genpc_flag;
    wire genpc_except_prefix;

    // Instantiate or1200_sprs
    or1200_sprs or1200_sprs_inst (
        .clk(clk),
        .rst(rst),
        .spr_addr_i(ctrl_spr_addr_imm),
        .spr_dat_i(wbmux_rf_dataw),
        .spr_we_i(ctrl_spr_we_ctrl),
        .spr_cs_i(ctrl_spr_cs_ctrl),
        .sr_o(sr),
        .spr_dat_cpu_o(sprs_spr_dat_cpu),
        .spr_addr_o(sprs_spr_addr),
        .spr_cs_o(sprs_spr_cs),
        .spr_we_o(sprs_spr_we),
        .du_addr_i(du_addr),
        .du_dat_i(du_dat_du),
        .du_read_i(du_read),
        .du_write_i(du_write),
        .du_dat_o(sprs_du_dat_cpu),
        .epcr_we_i(except_epcr_we),
        .epcr_i(except_epcr),
        .eear_we_i(except_eear_we),
        .eear_i(except_eear),
        .esr_we_i(except_esr_we),
        .esr_i(except_esr),
        .rf_addrw_i(ctrl_rf_addrw),
        .rf_we_i(ctrl_rfwb_op[0]),
        .rf_dataw_i(wbmux_rf_dataw),
        .spr_dat_pic_i(spr_dat_pic),
        .spr_dat_tt_i(spr_dat_tt),
        .spr_dat_pm_i(spr_dat_pm),
        .spr_dat_dmmu_i(spr_dat_dmmu),
        .spr_dat_immu_i(spr_dat_immu),
        .spr_dat_du_i(spr_dat_du),
        .mac_result_i(mac_result),
        .mac_busy_i(mac_busy),
        .branch_op_i(ctrl_branch_sel),
        .branch_taken_i(genpc_branch_taken),
        .flag_i(alu_flag),
        .spr_dat_npc_o(sprs_spr_dat_npc),
        .dw(wbmux_rf_dataw)
    );

    // Instantiate or1200_genpc
    or1200_genpc or1200_genpc_inst (
        .clk(clk),
        .rst(rst),
        .branch_op_i(ctrl_branch_sel),
        .branch_offset_i(ctrl_br_offset),
        .link_addr_i(genpc_link_addr),
        .flag_i(alu_flag),
        .branch_taken_o(genpc_branch_taken),
        .except_type_i(except_type),
        .except_start_i(except_start),
        .except_prefix_i(except_prefix),
        .epcr_i(except_epcr),
        .spr_pc_we_i(sprs_spr_we & sprs_spr_cs[0]), // Simplified SPR PC write
        .spr_pc_i(sprs_spr_dat_cpu),
        .freeze_i(freeze_genpc),
        .refetch_i(freeze_refetch),
        .pc_o(genpc_pc),
        .cycstb_o(genpc_cycstb),
        .sel_o(genpc_sel),
        .tag_o(genpc_tag)
    );

    // Instantiate or1200_if
    or1200_if or1200_if_inst (
        .clk(clk),
        .rst(rst),
        .icpu_dat_i(icpu_dat_i),
        .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i),
        .icpu_adr_i(icpu_adr_i),
        .icpu_tag_i(icpu_tag_i),
        .freeze_i(freeze_if),
        .flush_i(except_flushpipe),
        .refetch_i(freeze_refetch),
        .rfe_i(ctrl_rfe),
        .except_start_i(except_start),
        .insn_o(if_insn),
        .pc_o(if_pc),
        .stall_o(if_stall),
        .ibus_err_o(if_ibus_err)
    );

    // Instantiate or1200_ctrl
    or1200_ctrl or1200_ctrl_inst (
        .clk(clk),
        .rst(rst),
        .insn_i(if_insn),
        .freeze_id_i(freeze_id),
        .flush_i(except_flushpipe),
        .du_hwbkpt_i(du_hwbkpt),
        .imm_o(ctrl_imm),
        .br_offset_o(ctrl_br_offset),
        .lsu_offset_o(ctrl_lsu_offset),
        .alu_op_o(ctrl_alu_op),
        .mac_op_o(ctrl_mac_op),
        .lsu_op_o(ctrl_lsu_op),
        .rfwb_op_o(ctrl_rfwb_op),
        .rf_addra_o(ctrl_rf_addra),
        .rf_addrb_o(ctrl_rf_addrb),
        .rf_addrw_o(ctrl_rf_addrw),
        .rf_rda_en_o(ctrl_rf_rda_en),
        .rf_rdb_en_o(ctrl_rf_rdb_en),
        .sel_imm_o(ctrl_sel_imm),
        .branch_sel_o(ctrl_branch_sel),
        .syscall_o(ctrl_syscall),
        .trap_o(ctrl_trap),
        .illegal_o(ctrl_illegal),
        .rfe_o(ctrl_rfe),
        .dslot_o(ctrl_dslot),
        .macrc_o(ctrl_macrc),
        .multicycle_o(ctrl_multicycle),
        .spr_addr_imm_o(ctrl_spr_addr_imm),
        .spr_we_o(ctrl_spr_we_ctrl),
        .spr_cs_o(ctrl_spr_cs_ctrl),
        .flag_we_o(ctrl_flag_we),
        .carry_we_o(ctrl_carry_we),
        .branch_op_o(ctrl_branch_op)
    );

    // Instantiate or1200_rf
    or1200_rf or1200_rf_inst (
        .clk(clk),
        .rst(rst),
        .addra_i(ctrl_rf_addra),
        .addrb_i(ctrl_rf_addrb),
        .addrw_i(ctrl_rf_addrw),
        .rda_en_i(ctrl_rf_rda_en),
        .rdb_en_i(ctrl_rf_rdb_en),
        .we_i(ctrl_rfwb_op[0]),
        .dataw_i(wbmux_rf_dataw),
        .freeze_wb_i(freeze_wb),
        .dataa_o(rf_dataa),
        .datab_o(rf_datab)
    );

    // Instantiate or1200_operandmuxes
    or1200_operandmuxes or1200_operandmuxes_inst (
        .rf_dataa_i(rf_dataa),
        .rf_datab_i(rf_datab),
        .imm_i(ctrl_imm),
        .sel_imm_i(ctrl_sel_imm),
        .ex_fwd_data_i(wbmux_fwd_data),
        .ex_fwd_valid_i(wbmux_fwd_valid),
        .wb_fwd_data_i(wbmux_rf_dataw),
        .wb_fwd_valid_i(ctrl_rfwb_op[0]),
        .lsu_offset_i(ctrl_lsu_offset),
        .a_o(opmux_a),
        .b_o(opmux_b),
        .alu_a_o(opmux_alu_a),
        .alu_b_o(opmux_alu_b),
        .lsu_addr_o(opmux_lsu_addr),
        .lsu_data_o(opmux_lsu_data)
    );

    // Instantiate or1200_alu
    or1200_alu or1200_alu_inst (
        .a_i(opmux_alu_a),
        .b_i(opmux_alu_b),
        .alu_op_i(ctrl_alu_op),
        .flag_we_i(ctrl_flag_we),
        .carry_we_i(ctrl_carry_we),
        .result_o(alu_result),
        .flag_o(alu_flag),
        .carry_o(alu_carry),
        .flag_we_o(alu_flag_we),
        .carry_we_o(alu_carry_we)
    );

    // Instantiate or1200_mac
    or1200_mac or1200_mac_inst (
        .clk(clk),
        .rst(rst),
        .a_i(opmux_a),
        .b_i(opmux_b),
        .mac_op_i(ctrl_mac_op),
        .macrc_i(ctrl_macrc),
        .freeze_ex_i(freeze_ex),
        .result_o(mac_result),
        .busy_o(mac_busy),
        .stall_o(mac_stall)
    );

    // Instantiate or1200_lsu
    or1200_lsu or1200_lsu_inst (
        .clk(clk),
        .rst(rst),
        .addr_i(opmux_lsu_addr),
        .data_i(opmux_lsu_data),
        .lsu_op_i(ctrl_lsu_op),
        .freeze_ex_i(freeze_ex),
        .dcpu_dat_i(dcpu_dat_i),
        .dcpu_ack_i(dcpu_ack_i),
        .dcpu_err_i(dcpu_err_i),
        .dcpu_rty_i(dcpu_rty_i),
        .dcpu_tag_i(dcpu_tag_i),
        .dcpu_adr_o(dcpu_adr_o),
        .dcpu_cycstb_o(dcpu_cycstb_o),
        .dcpu_we_o(dcpu_we_o),
        .dcpu_sel_o(dcpu_sel_o),
        .dcpu_tag_o(dcpu_tag_o),
        .dcpu_dat_o(dcpu_dat_o),
        .data_r_o(lsu_data_r),
        .stall_o(lsu_stall),
        .align_err_o(lsu_align_err),
        .dtlb_miss_o(lsu_dtlb_miss),
        .dmmu_fault_o(lsu_dmmu_fault),
        .dbus_err_o(lsu_dbus_err)
    );

    // Instantiate or1200_wbmux
    or1200_wbmux or1200_wbmux_inst (
        .alu_result_i(alu_result),
        .lsu_data_i(lsu_data_r),
        .spr_data_i(sprs_spr_dat_cpu),
        .link_addr_i(genpc_link_addr),
        .rfwb_op_i(ctrl_rfwb_op),
        .rf_dataw_o(wbmux_rf_dataw),
        .fwd_data_o(wbmux_fwd_data),
        .fwd_valid_o(wbmux_fwd_valid)
    );

    // Instantiate or1200_except
    or1200_except or1200_except_inst (
        .clk(clk),
        .rst(rst),
        .ibus_err_i(if_ibus_err),
        .dbus_err_i(lsu_dbus_err),
        .illegal_i(ctrl_illegal),
        .align_err_i(lsu_align_err),
        .dtlb_miss_i(lsu_dtlb_miss),
        .itlb_miss_i(1'b0), // Placeholder from IF stage
        .dmmu_fault_i(lsu_dmmu_fault),
        .immu_fault_i(1'b0), // Placeholder from IF stage
        .sig_int_i(sig_int),
        .sig_tick_i(sig_tick),
        .syscall_i(ctrl_syscall),
        .trap_i(ctrl_trap),
        .freeze_id_i(freeze_id),
        .dslot_i(ctrl_dslot),
        .du_dsr_i(du_dsr),
        .du_hwbkpt_i(du_hwbkpt),
        .except_type_o(except_type),
        .except_start_o(except_start),
        .except_started_o(except_started),
        .flushpipe_o(except_flushpipe),
        .ext_flush_o(except_ext_flush),
        .except_stop_o(except_stop),
        .epcr_we_o(except_epcr_we),
        .epcr_o(except_epcr),
        .eear_we_o(except_eear_we),
        .eear_o(except_eear),
        .esr_we_o(except_esr_we),
        .esr_o(except_esr),
        .abort_o(except_abort)
    );

    // Instantiate or1200_freeze
    or1200_freeze or1200_freeze_inst (
        .multicycle_i(ctrl_multicycle),
        .flush_i(except_flushpipe),
        .ext_flush_i(except_ext_flush),
        .lsu_stall_i(lsu_stall),
        .if_stall_i(if_stall),
        .lsu_unstall_i(1'b0), // Placeholder
        .force_dslot_fetch_i(1'b0), // Placeholder
        .abort_i(except_abort),
        .du_stall_i(du_stall),
        .mac_stall_i(mac_stall),
        .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i),
        .freeze_genpc_o(freeze_genpc),
        .freeze_if_o(freeze_if),
        .freeze_id_o(freeze_id),
        .freeze_ex_o(freeze_ex),
        .freeze_wb_o(freeze_wb),
        .refetch_o(freeze_refetch)
    );

    // Combinational assignments for external outputs
    assign ic_en = sr[4];
    assign dc_en = sr[3];
    assign immu_en = sr[6];
    assign dmmu_en = sr[5];
    assign supv = sr[0];
    assign except_prefix = sr[14];

    assign du_except = except_stop;
    assign du_dat_cpu = sprs_du_dat_cpu;

    assign ex_insn = if_insn; // Execute stage instruction (simplified)
    assign ex_freeze = freeze_ex;
    assign id_pc = if_pc; // ID stage PC (simplified)
    assign branch_op = ctrl_branch_sel;
    assign spr_dat_npc = sprs_spr_dat_npc;
    assign rf_dataw = wbmux_rf_dataw;

    // Instruction interface outputs
    assign icpu_adr_o = genpc_pc;
    assign icpu_cycstb_o = genpc_cycstb;
    assign icpu_sel_o = genpc_sel;
    assign icpu_tag_o = genpc_tag;

    // SPR interface outputs
    assign spr_addr = sprs_spr_addr;
    assign spr_dat_cpu = sprs_spr_dat_cpu;
    assign spr_cs = sprs_spr_cs;
    assign spr_we = sprs_spr_we;

    // Link address connection (simplified)
    assign genpc_link_addr = if_pc + 32'd4;

endmodule
