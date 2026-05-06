module or1200_cpu(
    input clk,
    input rst,

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

    input sig_int,
    input sig_tick,

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
    wire [31:0] if_insn;
    wire [31:0] if_pc;
    wire if_stall;

    wire [31:0] id_insn;
    wire [31:0] id_pc_int;
    wire id_freeze;

    wire [31:0] ex_insn_int;
    wire [31:0] ex_pc;
    wire ex_freeze_int;
    wire [31:0] ex_branch_addrofs;
    wire [31:0] ex_lsu_addrofs;
    wire [31:0] ex_simm;
    wire [31:0] ex_operand_a;
    wire [31:0] ex_operand_b;
    wire [31:0] ex_rf_dataw;
    wire ex_flushpipe;

    wire [31:0] wb_insn;
    wire [31:0] wb_pc;
    wire wb_freeze;

    wire [31:0] ctrl_rf_addra;
    wire [31:0] ctrl_rf_addrb;
    wire [31:0] ctrl_rf_addrw;
    wire ctrl_rf_we;
    wire [31:0] ctrl_rf_dataw;
    wire ctrl_rf_rda_en;
    wire ctrl_rf_rdb_en;
    wire ctrl_rf_rdw_en;

    wire [31:0] rf_dataa;
    wire [31:0] rf_datab;

    wire [31:0] alu_result;
    wire alu_flag;
    wire alu_flag_we;
    wire alu_carry;
    wire alu_carry_we;

    wire [31:0] mac_result;
    wire mac_stall;
    wire mac_flag;
    wire mac_flag_we;

    wire [31:0] lsu_result;
    wire lsu_stall;
    wire lsu_align_err;
    wire lsu_dtlb_miss;
    wire lsu_dmmu_fault;
    wire lsu_bus_err;

    wire [31:0] spr_dat_cpu_int;
    wire [31:0] spr_addr_int;
    wire [31:0] spr_cs_int;
    wire spr_we_int;

    wire [31:0] wbmux_rf_dataw;
    wire [31:0] wbmux_fwd_data;
    wire wbmux_fwd_we;

    wire [31:0] except_type;
    wire except_start;
    wire except_started;
    wire except_flushpipe;
    wire except_ext_flush;
    wire [12:0] except_stop;
    wire [31:0] except_epcr;
    wire except_epcr_we;
    wire [31:0] except_eear;
    wire except_eear_we;
    wire [31:0] except_esr;
    wire except_esr_we;

    wire [31:0] genpc_npc;
    wire genpc_icpu_cycstb;
    wire genpc_icpu_sel;
    wire [3:0] genpc_icpu_tag;

    wire if_ibus_err;
    wire if_itlb_miss;
    wire if_immu_fault;

    wire ctrl_branch_op;
    wire [2:0] ctrl_branch_op_vec;
    wire ctrl_branch_insn;
    wire ctrl_alu_op;
    wire [3:0] ctrl_alu_op_vec;
    wire ctrl_mac_op;
    wire [1:0] ctrl_mac_op_vec;
    wire ctrl_lsu_op;
    wire [3:0] ctrl_lsu_op_vec;
    wire ctrl_rfwb_op;
    wire [2:0] ctrl_rfwb_op_vec;
    wire ctrl_spr_cs;
    wire ctrl_spr_we;
    wire ctrl_syscall;
    wire ctrl_trap;
    wire ctrl_illegal;
    wire ctrl_rfe;
    wire ctrl_dslot;
    wire ctrl_macrc_op;
    wire ctrl_mac_stall;
    wire ctrl_multicycle;
    wire ctrl_except_prefix;

    wire [31:0] sr;
    wire [31:0] epcr;
    wire [31:0] eear;
    wire [31:0] esr;

    wire freeze_if;
    wire freeze_id;
    wire freeze_ex;
    wire freeze_wb;
    wire freeze_genpc;

    // Instantiate submodules
    or1200_ctrl or1200_ctrl_inst (
        .clk(clk),
        .rst(rst),
        .id_insn(id_insn),
        .id_pc(id_pc_int),
        .ex_insn(ex_insn_int),
        .ex_pc(ex_pc),
        .wb_insn(wb_insn),
        .wb_pc(wb_pc),
        .id_freeze(freeze_id),
        .ex_freeze(freeze_ex),
        .wb_freeze(freeze_wb),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .except_start(except_start),
        .except_started(except_started),
        .branch_flag(alu_flag),
        .branch_carry(alu_carry),
        .mac_flag(mac_flag),
        .du_hwbkpt(du_hwbkpt),
        .rf_addra(ctrl_rf_addra),
        .rf_addrb(ctrl_rf_addrb),
        .rf_addrw(ctrl_rf_addrw),
        .rf_we(ctrl_rf_we),
        .rf_rda_en(ctrl_rf_rda_en),
        .rf_rdb_en(ctrl_rf_rdb_en),
        .simm(ex_simm),
        .branch_addrofs(ex_branch_addrofs),
        .lsu_addrofs(ex_lsu_addrofs),
        .branch_op(ctrl_branch_op_vec),
        .alu_op(ctrl_alu_op_vec),
        .mac_op(ctrl_mac_op_vec),
        .lsu_op(ctrl_lsu_op_vec),
        .rfwb_op(ctrl_rfwb_op_vec),
        .spr_cs(ctrl_spr_cs),
        .spr_we(ctrl_spr_we),
        .syscall(ctrl_syscall),
        .trap(ctrl_trap),
        .illegal(ctrl_illegal),
        .rfe(ctrl_rfe),
        .dslot(ctrl_dslot),
        .macrc_op(ctrl_macrc_op),
        .multicycle(ctrl_multicycle),
        .except_prefix(ctrl_except_prefix)
    );

    or1200_rf or1200_rf_inst (
        .clk(clk),
        .rst(rst),
        .addra(ctrl_rf_addra),
        .addrb(ctrl_rf_addrb),
        .addrw(ctrl_rf_addrw),
        .we(ctrl_rf_we),
        .dataw(wbmux_rf_dataw),
        .rda_en(ctrl_rf_rda_en),
        .rdb_en(ctrl_rf_rdb_en),
        .freeze(freeze_ex),
        .spr_cs(spr_cs_int[0]),
        .spr_we(spr_we_int),
        .spr_addr(spr_addr_int),
        .spr_dat_cpu(spr_dat_cpu_int),
        .spr_dat_rf(spr_dat_rf),
        .dataa(rf_dataa),
        .datab(rf_datab)
    );

    wire spr_dat_rf;

    or1200_operandmuxes or1200_operandmuxes_inst (
        .rf_dataa(rf_dataa),
        .rf_datab(rf_datab),
        .simm(ex_simm),
        .ex_fwd_data(wbmux_fwd_data),
        .ex_fwd_we(wbmux_fwd_we),
        .wb_fwd_data(wbmux_rf_dataw),
        .wb_fwd_we(ctrl_rf_we),
        .operand_a(ex_operand_a),
        .operand_b(ex_operand_b)
    );

    or1200_alu or1200_alu_inst (
        .clk(clk),
        .rst(rst),
        .a(ex_operand_a),
        .b(ex_operand_b),
        .alu_op(ctrl_alu_op_vec),
        .flag_we(alu_flag_we),
        .carry_we(alu_carry_we),
        .result(alu_result),
        .flag(alu_flag),
        .carry(alu_carry)
    );

    or1200_mult_mac or1200_mult_mac_inst (
        .clk(clk),
        .rst(rst),
        .a(ex_operand_a),
        .b(ex_operand_b),
        .mac_op(ctrl_mac_op_vec),
        .macrc_op(ctrl_macrc_op),
        .freeze(freeze_ex),
        .spr_cs(spr_cs_int[1]),
        .spr_we(spr_we_int),
        .spr_addr(spr_addr_int),
        .spr_dat_cpu(spr_dat_cpu_int),
        .spr_dat_mac(spr_dat_mac),
        .result(mac_result),
        .stall(mac_stall),
        .flag(mac_flag),
        .flag_we(mac_flag_we)
    );

    wire spr_dat_mac;

    or1200_lsu or1200_lsu_inst (
        .clk(clk),
        .rst(rst),
        .ex_insn(ex_insn_int),
        .ex_pc(ex_pc),
        .ex_freeze(freeze_ex),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .lsu_op(ctrl_lsu_op_vec),
        .addr_base(ex_operand_a),
        .addr_ofs(ex_lsu_addrofs),
        .store_data(ex_operand_b),
        .dcpu_dat_i(dcpu_dat_i),
        .dcpu_ack_i(dcpu_ack_i),
        .dcpu_rty_i(dcpu_rty_i),
        .dcpu_err_i(dcpu_err_i),
        .dcpu_tag_i(dcpu_tag_i),
        .dcpu_adr_o(dcpu_adr_o),
        .dcpu_cycstb_o(dcpu_cycstb_o),
        .dcpu_we_o(dcpu_we_o),
        .dcpu_sel_o(dcpu_sel_o),
        .dcpu_tag_o(dcpu_tag_o),
        .dcpu_dat_o(dcpu_dat_o),
        .result(lsu_result),
        .stall(lsu_stall),
        .align_err(lsu_align_err),
        .dtlb_miss(lsu_dtlb_miss),
        .dmmu_fault(lsu_dmmu_fault),
        .bus_err(lsu_bus_err)
    );

    or1200_wbmux or1200_wbmux_inst (
        .alu_result(alu_result),
        .lsu_result(lsu_result),
        .spr_result(spr_dat_cpu_int),
        .link_addr(ex_pc),
        .rfwb_op(ctrl_rfwb_op_vec),
        .rf_dataw(wbmux_rf_dataw),
        .fwd_data(wbmux_fwd_data),
        .fwd_we(wbmux_fwd_we)
    );

    or1200_genpc or1200_genpc_inst (
        .clk(clk),
        .rst(rst),
        .icpu_dat_i(icpu_dat_i),
        .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i),
        .icpu_adr_i(icpu_adr_i),
        .icpu_tag_i(icpu_tag_i),
        .icpu_adr_o(icpu_adr_o),
        .icpu_cycstb_o(icpu_cycstb_o),
        .icpu_sel_o(icpu_sel_o),
        .icpu_tag_o(icpu_tag_o),
        .branch_op(ctrl_branch_op_vec),
        .branch_addrofs(ex_branch_addrofs),
        .branch_flag(alu_flag),
        .except_type(except_type),
        .except_start(except_start),
        .except_prefix(ctrl_except_prefix),
        .link_addr(ex_pc),
        .epcr(epcr),
        .spr_cs(spr_cs_int[2]),
        .spr_we(spr_we_int),
        .spr_addr(spr_addr_int),
        .spr_dat_cpu(spr_dat_cpu_int),
        .spr_dat_npc(spr_dat_npc),
        .freeze(freeze_genpc),
        .refetch(except_ext_flush),
        .npc(genpc_npc)
    );

    or1200_if or1200_if_inst (
        .clk(clk),
        .rst(rst),
        .icpu_dat_i(icpu_dat_i),
        .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i),
        .icpu_adr_i(icpu_adr_i),
        .icpu_tag_i(icpu_tag_i),
        .freeze(freeze_if),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .refetch(except_ext_flush),
        .rfe(ctrl_rfe),
        .except_start(except_start),
        .if_insn(if_insn),
        .if_pc(if_pc),
        .if_stall(if_stall),
        .ibus_err(if_ibus_err),
        .itlb_miss(if_itlb_miss),
        .immu_fault(if_immu_fault)
    );

    or1200_except or1200_except_inst (
        .clk(clk),
        .rst(rst),
        .id_insn(id_insn),
        .ex_insn(ex_insn_int),
        .ex_pc(ex_pc),
        .wb_insn(wb_insn),
        .wb_pc(wb_pc),
        .id_freeze(freeze_id),
        .ex_freeze(freeze_ex),
        .wb_freeze(freeze_wb),
        .if_ibus_err(if_ibus_err),
        .if_itlb_miss(if_itlb_miss),
        .if_immu_fault(if_immu_fault),
        .lsu_bus_err(lsu_bus_err),
        .lsu_align_err(lsu_align_err),
        .lsu_dtlb_miss(lsu_dtlb_miss),
        .lsu_dmmu_fault(lsu_dmmu_fault),
        .illegal(ctrl_illegal),
        .syscall(ctrl_syscall),
        .trap(ctrl_trap),
        .sig_int(sig_int),
        .sig_tick(sig_tick),
        .du_dsr(du_dsr),
        .except_type(except_type),
        .except_start(except_start),
        .except_started(except_started),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .except_stop(except_stop),
        .epcr(epcr),
        .epcr_we(except_epcr_we),
        .eear(eear),
        .eear_we(except_eear_we),
        .esr(esr),
        .esr_we(except_esr_we)
    );

    or1200_freeze or1200_freeze_inst (
        .clk(clk),
        .rst(rst),
        .if_stall(if_stall),
        .lsu_stall(lsu_stall),
        .mac_stall(mac_stall),
        .multicycle(ctrl_multicycle),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .except_start(except_start),
        .except_started(except_started),
        .du_stall(du_stall),
        .icpu_ack_i(icpu_ack_i),
        .icpu_err_i(icpu_err_i),
        .freeze_if(freeze_if),
        .freeze_id(freeze_id),
        .freeze_ex(freeze_ex),
        .freeze_wb(freeze_wb),
        .freeze_genpc(freeze_genpc)
    );

    or1200_sprs or1200_sprs_inst (
        .clk(clk),
        .rst(rst),
        .id_insn(id_insn),
        .ex_insn(ex_insn_int),
        .wb_insn(wb_insn),
        .id_pc(id_pc_int),
        .ex_pc(ex_pc),
        .wb_pc(wb_pc),
        .id_freeze(freeze_id),
        .ex_freeze(freeze_ex),
        .wb_freeze(freeze_wb),
        .flushpipe(except_flushpipe),
        .ext_flush(except_ext_flush),
        .except_type(except_type),
        .except_start(except_start),
        .except_started(except_started),
        .epcr(epcr),
        .epcr_we(except_epcr_we),
        .eear(eear),
        .eear_we(except_eear_we),
        .esr(esr),
        .esr_we(except_esr_we),
        .spr_dat_pic(spr_dat_pic),
        .spr_dat_tt(spr_dat_tt),
        .spr_dat_pm(spr_dat_pm),
        .spr_dat_dmmu(spr_dat_dmmu),
        .spr_dat_immu(spr_dat_immu),
        .spr_dat_du(spr_dat_du),
        .spr_dat_rf(spr_dat_rf),
        .spr_dat_mac(spr_dat_mac),
        .du_stall(du_stall),
        .du_addr(du_addr),
        .du_dat_du(du_dat_du),
        .du_read(du_read),
        .du_write(du_write),
        .du_hwbkpt(du_hwbkpt),
        .du_dat_cpu(du_dat_cpu),
        .spr_addr(spr_addr),
        .spr_dat_cpu(spr_dat_cpu),
        .spr_cs(spr_cs),
        .spr_we(spr_we),
        .spr_cs_int(spr_cs_int),
        .spr_we_int(spr_we_int),
        .spr_addr_int(spr_addr_int),
        .spr_dat_cpu_int(spr_dat_cpu_int),
        .sr(sr)
    );

    // Pipeline registers
    or1200_pipe_reg #(.WIDTH(32)) id_insn_reg (.clk(clk), .rst(rst), .freeze(freeze_id), .flush(except_flushpipe), .d(if_insn), .q(id_insn));
    or1200_pipe_reg #(.WIDTH(32)) id_pc_reg (.clk(clk), .rst(rst), .freeze(freeze_id), .flush(except_flushpipe), .d(if_pc), .q(id_pc_int));
    or1200_pipe_reg #(.WIDTH(32)) ex_insn_reg (.clk(clk), .rst(rst), .freeze(freeze_ex), .flush(except_flushpipe), .d(id_insn), .q(ex_insn_int));
    or1200_pipe_reg #(.WIDTH(32)) ex_pc_reg (.clk(clk), .rst(rst), .freeze(freeze_ex), .flush(except_flushpipe), .d(id_pc_int), .q(ex_pc));
    or1200_pipe_reg #(.WIDTH(32)) wb_insn_reg (.clk(clk), .rst(rst), .freeze(freeze_wb), .flush(except_flushpipe), .d(ex_insn_int), .q(wb_insn));
    or1200_pipe_reg #(.WIDTH(32)) wb_pc_reg (.clk(clk), .rst(rst), .freeze(freeze_wb), .flush(except_flushpipe), .d(ex_pc), .q(wb_pc));

    // Assign outputs
    assign ic_en = sr[4];
    assign dc_en = sr[3];
    assign immu_en = sr[6];
    assign dmmu_en = sr[5];
    assign supv = sr[0];
    assign ex_insn = ex_insn_int;
    assign ex_freeze = freeze_ex;
    assign id_pc = id_pc_int;
    assign branch_op = ctrl_branch_op_vec;
    assign rf_dataw = wbmux_rf_dataw;
    assign du_except = except_stop;

endmodule

module or1200_pipe_reg #(parameter WIDTH = 32) (
    input clk,
    input rst,
    input freeze,
    input flush,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q <= {WIDTH{1'b0}};
        end else if (flush) begin
            q <= {WIDTH{1'b0}};
        end else if (!freeze) begin
            q <= d;
        end
    end
endmodule

// Placeholder submodule declarations (these would be full implementations in actual OR1200 code)
// The following are simplified stubs to satisfy connectivity; real implementations would be instantiated here.

module or1200_ctrl (
    input clk, rst,
    input [31:0] id_insn, id_pc, ex_insn, ex_pc, wb_insn, wb_pc,
    input id_freeze, ex_freeze, wb_freeze,
    input flushpipe, ext_flush, except_start, except_started,
    input branch_flag, branch_carry, mac_flag, du_hwbkpt,
    output [31:0] rf_addra, rf_addrb, rf_addrw,
    output rf_we, rf_rda_en, rf_rdb_en,
    output [31:0] simm, branch_addrofs, lsu_addrofs,
    output [2:0] branch_op,
    output [3:0] alu_op,
    output [1:0] mac_op,
    output [3:0] lsu_op,
    output [2:0] rfwb_op,
    output spr_cs, spr_we,
    output syscall, trap, illegal, rfe, dslot, macrc_op,
    output multicycle, except_prefix
);
    // Simplified stub
    assign rf_addra = 32'd0;
    assign rf_addrb = 32'd0;
    assign rf_addrw = 32'd0;
    assign rf_we = 1'b0;
    assign rf_rda_en = 1'b0;
    assign rf_rdb_en = 1'b0;
    assign simm = 32'd0;
    assign branch_addrofs = 32'd0;
    assign lsu_addrofs = 32'd0;
    assign branch_op = 3'd0;
    assign alu_op = 4'd0;
    assign mac_op = 2'd0;
    assign lsu_op = 4'd0;
    assign rfwb_op = 3'd0;
    assign spr_cs = 1'b0;
    assign spr_we = 1'b0;
    assign syscall = 1'b0;
    assign trap = 1'b0;
    assign illegal = 1'b0;
    assign rfe = 1'b0;
    assign dslot = 1'b0;
    assign macrc_op = 1'b0;
    assign multicycle = 1'b0;
    assign except_prefix = 1'b0;
endmodule

module or1200_rf (
    input clk, rst,
    input [31:0] addra, addrb, addrw,
    input we,
    input [31:0] dataw,
    input rda_en, rdb_en,
    input freeze,
    input spr_cs, spr_we,
    input [31:0] spr_addr, spr_dat_cpu,
    output [31:0] spr_dat_rf,
    output [31:0] dataa, datab
);
    assign dataa = 32'd0;
    assign datab = 32'd0;
    assign spr_dat_rf = 32'd0;
endmodule

module or1200_operandmuxes (
    input [31:0] rf_dataa, rf_datab, simm,
    input [31:0] ex_fwd_data, wb_fwd_data,
    input ex_fwd_we, wb_fwd_we,
    output [31:0] operand_a, operand_b
);
    assign operand_a = rf_dataa;
    assign operand_b = rf_datab;
endmodule

module or1200_alu (
    input clk, rst,
    input [31:0] a, b,
    input [3:0] alu_op,
    input flag_we, carry_we,
    output [31:0] result,
    output flag, carry
);
    assign result = 32'd0;
    assign flag = 1'b0;
    assign carry = 1'b0;
endmodule

module or1200_mult_mac (
    input clk, rst,
    input [31:0] a, b,
    input [1:0] mac_op,
    input macrc_op,
    input freeze,
    input spr_cs, spr_we,
    input [31:0] spr_addr, spr_dat_cpu,
    output [31:0] spr_dat_mac,
    output [31:0] result,
    output stall, flag, flag_we
);
    assign result = 32'd0;
    assign stall = 1'b0;
    assign flag = 1'b0;
    assign flag_we = 1'b0;
    assign spr_dat_mac = 32'd0;
endmodule

module or1200_lsu (
    input clk, rst,
    input [31:0] ex_insn, ex_pc,
    input ex_freeze,
    input flushpipe, ext_flush,
    input [3:0] lsu_op,
    input [31:0] addr_base, addr_ofs, store_data,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i, dcpu_rty_i, dcpu_err_i,
    input [3:0] dcpu_tag_i,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o, dcpu_we_o,
    output [3:0] dcpu_sel_o, dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    output [31:0] result,
    output stall, align_err, dtlb_miss, dmmu_fault, bus_err
);
    assign dcpu_adr_o = 32'd0;
    assign dcpu_cycstb_o = 1'b0;
    assign dcpu_we_o = 1'b0;
    assign dcpu_sel_o = 4'd0;
    assign dcpu_tag_o = 4'd0;
    assign dcpu_dat_o = 32'd0;
    assign result = 32'd0;
    assign stall = 1'b0;
    assign align_err = 1'b0;
    assign dtlb_miss = 1'b0;
    assign dmmu_fault = 1'b0;
    assign bus_err = 1'b0;
endmodule

module or1200_wbmux (
    input [31:0] alu_result, lsu_result, spr_result, link_addr,
    input [2:0] rfwb_op,
    output [31:0] rf_dataw, fwd_data,
    output fwd_we
);
    assign rf_dataw = alu_result;
    assign fwd_data = alu_result;
    assign fwd_we = 1'b0;
endmodule

module or1200_genpc (
    input clk, rst,
    input [31:0] icpu_dat_i,
    input icpu_ack_i, icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o, icpu_tag_o,
    input [2:0] branch_op,
    input [31:0] branch_addrofs,
    input branch_flag,
    input [31:0] except_type,
    input except_start,
    input except_prefix,
    input [31:0] link_addr,
    input [31:0] epcr,
    input spr_cs, spr_we,
    input [31:0] spr_addr, spr_dat_cpu,
    output [31:0] spr_dat_npc,
    input freeze, refetch,
    output [31:0] npc
);
    assign icpu_adr_o = 32'd0;
    assign icpu_cycstb_o = 1'b0;
    assign icpu_sel_o = 4'd0;
    assign icpu_tag_o = 4'd0;
    assign spr_dat_npc = 32'd0;
    assign npc = 32'd0;
endmodule

module or1200_if (
    input clk, rst,
    input [31:0] icpu_dat_i,
    input icpu_ack_i, icpu_err_i,
    input [31:0] icpu_adr_i,
    input [3:0] icpu_tag_i,
    input freeze, flushpipe, ext_flush, refetch, rfe, except_start,
    output [31:0] if_insn, if_pc,
    output if_stall, ibus_err, itlb_miss, immu_fault
);
    assign if_insn = 32'd0;
    assign if_pc = 32'd0;
    assign if_stall = 1'b0;
    assign ibus_err = 1'b0;
    assign itlb_miss = 1'b0;
    assign immu_fault = 1'b0;
endmodule

module or1200_except (
    input clk, rst,
    input [31:0] id_insn, ex_insn, ex_pc, wb_insn, wb_pc,
    input id_freeze, ex_freeze, wb_freeze,
    input if_ibus_err, if_itlb_miss, if_immu_fault,
    input lsu_bus_err, lsu_align_err, lsu_dtlb_miss, lsu_dmmu_fault,
    input illegal, syscall, trap,
    input sig_int, sig_tick,
    input [13:0] du_dsr,
    output [31:0] except_type,
    output except_start, except_started,
    output flushpipe, ext_flush,
    output [12:0] except_stop,
    output [31:0] epcr, eear, esr,
    output epcr_we, eear_we, esr_we
);
    assign except_type = 32'd0;
    assign except_start = 1'b0;
    assign except_started = 1'b0;
    assign flushpipe = 1'b0;
    assign ext_flush = 1'b0;
    assign except_stop = 13'd0;
    assign epcr = 32'd0;
    assign eear = 32'd0;
    assign esr = 32'd0;
    assign epcr_we = 1'b0;
    assign eear_we = 1'b0;
    assign esr_we = 1'b0;
endmodule

module or1200_freeze (
    input clk, rst,
    input if_stall, lsu_stall, mac_stall, multicycle,
    input flushpipe, ext_flush, except_start, except_started,
    input du_stall, icpu_ack_i, icpu_err_i,
    output freeze_if, freeze_id, freeze_ex, freeze_wb, freeze_genpc
);
    assign freeze_if = 1'b0;
    assign freeze_id = 1'b0;
    assign freeze_ex = 1'b0;
    assign freeze_wb = 1'b0;
    assign freeze_genpc = 1'b0;
endmodule

module or1200_sprs (
    input clk, rst,
    input [31:0] id_insn, ex_insn, wb_insn, id_pc, ex_pc, wb_pc,
    input id_freeze, ex_freeze, wb_freeze,
    input flushpipe, ext_flush,
    input [31:0] except_type,
    input except_start, except_started,
    input [31:0] epcr, eear, esr,
    input epcr_we, eear_we, esr_we,
    input [31:0] spr_dat_pic, spr_dat_tt, spr_dat_pm, spr_dat_dmmu, spr_dat_immu, spr_dat_du,
    input [31:0] spr_dat_rf, spr_dat_mac,
    input du_stall,
    input [31:0] du_addr, du_dat_du,
    input du_read, du_write, du_hwbkpt,
    output [31:0] du_dat_cpu,
    output [31:0] spr_addr, spr_dat_cpu,
    output [31:0] spr_cs,
    output spr_we,
    output [31:0] spr_cs_int, spr_we_int, spr_addr_int, spr_dat_cpu_int,
    output [31:0] sr
);
    assign du_dat_cpu = 32'd0;
    assign spr_addr = 32'd0;
    assign spr_dat_cpu = 32'd0;
    assign spr_cs = 32'd0;
    assign spr_we = 1'b0;
    assign spr_cs_int = 32'd0;
    assign spr_we_int = 1'b0;
    assign spr_addr_int = 32'd0;
    assign spr_dat_cpu_int = 32'd0;
    assign sr = 32'd0;
endmodule
