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

localparam [5:0] OP_J        = 6'h00;
localparam [5:0] OP_JAL      = 6'h01;
localparam [5:0] OP_BNF      = 6'h03;
localparam [5:0] OP_BF       = 6'h04;
localparam [5:0] OP_NOP      = 6'h05;
localparam [5:0] OP_MOVHI    = 6'h06;
localparam [5:0] OP_SYS      = 6'h08;
localparam [5:0] OP_RFE      = 6'h09;
localparam [5:0] OP_JR       = 6'h11;
localparam [5:0] OP_JALR     = 6'h12;
localparam [5:0] OP_LWZ      = 6'h21;
localparam [5:0] OP_LBZ      = 6'h23;
localparam [5:0] OP_LBS      = 6'h24;
localparam [5:0] OP_LHZ      = 6'h25;
localparam [5:0] OP_LHS      = 6'h26;
localparam [5:0] OP_ADDI     = 6'h27;
localparam [5:0] OP_ANDI     = 6'h29;
localparam [5:0] OP_ORI      = 6'h2a;
localparam [5:0] OP_XORI     = 6'h2b;
localparam [5:0] OP_MULI     = 6'h2c;
localparam [5:0] OP_MFSPR    = 6'h2d;
localparam [5:0] OP_SHIFTI   = 6'h2e;
localparam [5:0] OP_SFXXI    = 6'h2f;
localparam [5:0] OP_MTSPR    = 6'h30;
localparam [5:0] OP_SW       = 6'h35;
localparam [5:0] OP_SB       = 6'h36;
localparam [5:0] OP_SH       = 6'h37;
localparam [5:0] OP_ALU      = 6'h38;
localparam [5:0] OP_SFXX     = 6'h39;

localparam [31:0] EXCEPT_BASE_LO = 32'h0000_0000;
localparam [31:0] EXCEPT_BASE_HI = 32'hF000_0000;
localparam [31:0] VEC_BUSERR     = 32'h0000_0200;
localparam [31:0] VEC_ALIGN      = 32'h0000_0600;
localparam [31:0] VEC_ILLEGAL    = 32'h0000_0700;
localparam [31:0] VEC_TICK       = 32'h0000_0500;
localparam [31:0] VEC_INT        = 32'h0000_0800;
localparam [31:0] VEC_SYSCALL    = 32'h0000_0c00;
localparam [31:0] VEC_DEBUG      = 32'h0000_0d00;
localparam [31:0] VEC_TRAP       = 32'h0000_0e00;

localparam [31:0] SPR_GRP_RF     = 32'd0;
localparam [31:0] SPR_GRP_SYS    = 32'd1;
localparam [31:0] SPR_GRP_PIC    = 32'd2;
localparam [31:0] SPR_GRP_TT     = 32'd3;
localparam [31:0] SPR_GRP_PM     = 32'd4;
localparam [31:0] SPR_GRP_DMMU   = 32'd5;
localparam [31:0] SPR_GRP_IMMU   = 32'd6;
localparam [31:0] SPR_GRP_DU     = 32'd7;

localparam [4:0] SYS_SR_IDX      = 5'd0;
localparam [4:0] SYS_NPC_IDX     = 5'd1;
localparam [4:0] SYS_EPCR_IDX    = 5'd2;
localparam [4:0] SYS_EEAR_IDX    = 5'd3;
localparam [4:0] SYS_ESR_IDX     = 5'd4;

reg [31:0] rf[0:31];
reg [31:0] sr_r;
reg [31:0] npc_r;
reg [31:0] epcr_r;
reg [31:0] eear_r;
reg [31:0] esr_r;
reg [31:0] pc_r;
reg [31:0] id_pc_r;
reg [31:0] id_insn_r;
reg        id_valid_r;
reg [31:0] ex_pc_r;
reg [31:0] ex_insn_r;
reg        ex_valid_r;
reg [31:0] ex_op_a_r;
reg [31:0] ex_op_b_r;
reg [31:0] ex_imm_r;
reg [31:0] ex_spr_addr_r;
reg [4:0]  ex_rd_r;
reg [31:0] ex_link_r;
reg        flag_r;
reg [31:0] du_dat_cpu_r;
reg [31:0] spr_read_data_r;
reg [31:0] spr_cs_r;
reg [2:0]  branch_op_r;
reg [31:0] exception_vector_r;
reg [31:0] exception_eear_r;
reg [31:0] exception_epcr_r;
reg        exception_start_r;
reg        branch_taken_id_r;
reg [31:0] branch_target_id_r;
reg        wb_gpr_we_r;
reg [31:0] wb_data_r;
reg [31:0] alu_result_r;
reg        sf_result_r;
reg [31:0] id_rf_a_r;
reg [31:0] id_rf_b_r;
integer i;

wire except_prefix = sr_r[14];
wire [5:0] id_opcode = id_insn_r[31:26];
wire [4:0] id_rd = id_insn_r[25:21];
wire [4:0] id_ra = id_insn_r[20:16];
wire [4:0] id_rb = id_insn_r[15:11];
wire [15:0] id_imm16 = id_insn_r[15:0];
wire [31:0] id_imm_sext = {{16{id_imm16[15]}}, id_imm16};
wire [31:0] id_imm_zext = {16'h0000, id_imm16};
wire [31:0] id_branch_offs = {{4{id_insn_r[25]}}, id_insn_r[25:0], 2'b00};
wire [31:0] id_jump_target = id_pc_r + id_branch_offs;
wire [31:0] id_link_addr = id_pc_r + 32'd8;
wire [31:0] id_spr_addr = {11'd0, id_insn_r[25:21], id_insn_r[10:0]};
wire [5:0] ex_opcode = ex_insn_r[31:26];
wire [31:0] ex_add_result = ex_op_a_r + ex_imm_r;
wire ex_is_load = (ex_opcode == OP_LWZ) || (ex_opcode == OP_LBZ) || (ex_opcode == OP_LBS) ||
                  (ex_opcode == OP_LHZ) || (ex_opcode == OP_LHS);
wire ex_is_store = (ex_opcode == OP_SW) || (ex_opcode == OP_SB) || (ex_opcode == OP_SH);
wire ex_is_memory = ex_is_load || ex_is_store;
wire [31:0] lsu_addr = ex_add_result;
wire ex_align_err = ((ex_opcode == OP_LWZ) || (ex_opcode == OP_SW)) ? |lsu_addr[1:0] :
                    ((ex_opcode == OP_LHZ) || (ex_opcode == OP_LHS) || (ex_opcode == OP_SH)) ? lsu_addr[0] : 1'b0;
wire lsu_wait = ex_valid_r && ex_is_memory && !ex_align_err && !dcpu_ack_i && !dcpu_err_i && !dcpu_rty_i;
wire ex_stage_hold = du_stall || lsu_wait;
wire debug_access = du_read || du_write;
wire [31:0] spr_addr_active = debug_access ? du_addr : ex_spr_addr_r;
wire ex_mfspr = (ex_opcode == OP_MFSPR);
wire ex_mtspr = (ex_opcode == OP_MTSPR);
wire [31:0] except_base = except_prefix ? EXCEPT_BASE_HI : EXCEPT_BASE_LO;
wire [12:0] except_stop_w;
wire id_syscall = id_valid_r && (id_opcode == OP_SYS) && !id_insn_r[16];
wire id_trap = id_valid_r && (id_opcode == OP_SYS) && id_insn_r[16];
wire id_rfe = id_valid_r && (id_opcode == OP_RFE);
wire wb_for_load = ex_valid_r && ex_is_load && dcpu_ack_i && !dcpu_err_i && !ex_align_err;
wire wb_allowed = !du_stall && !exception_start_r;
wire [31:0] wb_data_next = wb_data_r;

assign ic_en = sr_r[4];
assign immu_en = sr_r[6];
assign dc_en = sr_r[3];
assign dmmu_en = sr_r[5];
assign supv = sr_r[0];
assign icpu_adr_o = pc_r;
assign icpu_cycstb_o = ~rst & ~du_stall;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = 4'b0001;
assign ex_insn = ex_insn_r;
assign ex_freeze = ex_stage_hold;
assign id_pc = id_pc_r;
assign branch_op = branch_op_r;
assign spr_dat_npc = npc_r;
assign rf_dataw = wb_data_next;
assign du_except = except_stop_w;
assign du_dat_cpu = du_dat_cpu_r;
assign dcpu_adr_o = lsu_addr;
assign dcpu_cycstb_o = ex_valid_r && ex_is_memory && !du_stall && !ex_align_err;
assign dcpu_we_o = ex_is_store;
assign dcpu_sel_o = ((ex_opcode == OP_SB) || (ex_opcode == OP_LBZ) || (ex_opcode == OP_LBS)) ? (4'b0001 << lsu_addr[1:0]) :
                    ((ex_opcode == OP_SH) || (ex_opcode == OP_LHZ) || (ex_opcode == OP_LHS)) ? (lsu_addr[1] ? 4'b1100 : 4'b0011) :
                    4'b1111;
assign dcpu_tag_o = ex_is_store ? 4'b0011 : 4'b0010;
assign dcpu_dat_o = ex_op_b_r;
assign spr_addr = spr_addr_active;
assign spr_dat_cpu = debug_access ? du_dat_du : ex_op_b_r;
assign spr_cs = spr_cs_r;
assign spr_we = (debug_access && du_write) || (ex_valid_r && ex_mtspr && !du_stall);

assign except_stop_w[0]  = icpu_err_i;
assign except_stop_w[1]  = dcpu_err_i;
assign except_stop_w[2]  = id_valid_r && !(id_opcode == OP_J || id_opcode == OP_JAL || id_opcode == OP_BNF || id_opcode == OP_BF ||
                                          id_opcode == OP_NOP || id_opcode == OP_MOVHI || id_opcode == OP_SYS || id_opcode == OP_RFE ||
                                          id_opcode == OP_JR || id_opcode == OP_JALR || id_opcode == OP_LWZ || id_opcode == OP_LBZ ||
                                          id_opcode == OP_LBS || id_opcode == OP_LHZ || id_opcode == OP_LHS || id_opcode == OP_ADDI ||
                                          id_opcode == OP_ANDI || id_opcode == OP_ORI || id_opcode == OP_XORI || id_opcode == OP_MULI ||
                                          id_opcode == OP_MFSPR || id_opcode == OP_SHIFTI || id_opcode == OP_SFXXI || id_opcode == OP_MTSPR ||
                                          id_opcode == OP_SW || id_opcode == OP_SB || id_opcode == OP_SH || id_opcode == OP_ALU || id_opcode == OP_SFXX);
assign except_stop_w[3]  = ex_valid_r && ex_align_err;
assign except_stop_w[4]  = 1'b0;
assign except_stop_w[5]  = 1'b0;
assign except_stop_w[6]  = id_syscall;
assign except_stop_w[7]  = id_trap;
assign except_stop_w[8]  = sig_int;
assign except_stop_w[9]  = sig_tick;
assign except_stop_w[10] = du_hwbkpt;
assign except_stop_w[11] = du_dsr[0];
assign except_stop_w[12] = icpu_rty_i | dcpu_rty_i | icpu_tag_i[0] | dcpu_tag_i[0];

always @* begin
    id_rf_a_r = rf[id_ra];
    id_rf_b_r = rf[id_rb];

    branch_op_r = 3'b000;
    branch_taken_id_r = 1'b0;
    branch_target_id_r = pc_r;
    case (id_opcode)
        OP_J: begin
            branch_op_r = 3'b001;
            branch_taken_id_r = id_valid_r;
            branch_target_id_r = id_jump_target;
        end
        OP_JAL: begin
            branch_op_r = 3'b001;
            branch_taken_id_r = id_valid_r;
            branch_target_id_r = id_jump_target;
        end
        OP_BF: begin
            branch_op_r = 3'b010;
            branch_taken_id_r = id_valid_r && flag_r;
            branch_target_id_r = id_jump_target;
        end
        OP_BNF: begin
            branch_op_r = 3'b011;
            branch_taken_id_r = id_valid_r && !flag_r;
            branch_target_id_r = id_jump_target;
        end
        OP_JR: begin
            branch_op_r = 3'b100;
            branch_taken_id_r = id_valid_r;
            branch_target_id_r = id_rf_a_r;
        end
        OP_JALR: begin
            branch_op_r = 3'b101;
            branch_taken_id_r = id_valid_r;
            branch_target_id_r = id_rf_a_r;
        end
        default: begin
            branch_op_r = 3'b000;
            branch_taken_id_r = 1'b0;
            branch_target_id_r = pc_r;
        end
    endcase

    alu_result_r = 32'h0000_0000;
    sf_result_r = 1'b0;
    case (ex_opcode)
        OP_ADDI:   alu_result_r = ex_op_a_r + ex_imm_r;
        OP_ANDI:   alu_result_r = ex_op_a_r & ex_imm_r;
        OP_ORI:    alu_result_r = ex_op_a_r | ex_imm_r;
        OP_XORI:   alu_result_r = ex_op_a_r ^ ex_imm_r;
        OP_MOVHI:  alu_result_r = {ex_insn_r[15:0], 16'h0000};
        OP_MULI:   alu_result_r = ex_op_a_r * ex_imm_r;
        OP_SHIFTI: begin
            case (ex_insn_r[7:6])
                2'b00: alu_result_r = ex_op_a_r << ex_insn_r[5:0];
                2'b01: alu_result_r = ex_op_a_r >> ex_insn_r[5:0];
                default: alu_result_r = $signed(ex_op_a_r) >>> ex_insn_r[5:0];
            endcase
        end
        OP_ALU: begin
            case (ex_insn_r[3:0])
                4'h0: alu_result_r = ex_op_a_r + ex_op_b_r;
                4'h1: alu_result_r = ex_op_a_r - ex_op_b_r;
                4'h2: alu_result_r = ex_op_a_r & ex_op_b_r;
                4'h3: alu_result_r = ex_op_a_r | ex_op_b_r;
                4'h4: alu_result_r = ex_op_a_r ^ ex_op_b_r;
                4'h5: alu_result_r = ex_op_a_r << ex_op_b_r[4:0];
                4'h6: alu_result_r = ex_op_a_r >> ex_op_b_r[4:0];
                4'h7: alu_result_r = $signed(ex_op_a_r) >>> ex_op_b_r[4:0];
                default: alu_result_r = ex_op_a_r + ex_op_b_r;
            endcase
        end
        OP_JAL,
        OP_JALR:   alu_result_r = ex_link_r;
        OP_MFSPR:  alu_result_r = spr_read_data_r;
        default:   alu_result_r = ex_op_a_r + ex_op_b_r;
    endcase

    case (ex_opcode)
        OP_SFXX,
        OP_SFXXI: begin
            case (ex_insn_r[24:21])
                4'h0: sf_result_r = (ex_op_a_r == ex_op_b_r);
                4'h1: sf_result_r = (ex_op_a_r != ex_op_b_r);
                4'h2: sf_result_r = ($signed(ex_op_a_r) < $signed(ex_op_b_r));
                4'h3: sf_result_r = ($signed(ex_op_a_r) <= $signed(ex_op_b_r));
                4'h4: sf_result_r = ($signed(ex_op_a_r) > $signed(ex_op_b_r));
                4'h5: sf_result_r = ($signed(ex_op_a_r) >= $signed(ex_op_b_r));
                default: sf_result_r = 1'b0;
            endcase
        end
        default: sf_result_r = (alu_result_r == 32'h0000_0000);
    endcase

    spr_cs_r = 32'h0000_0000;
    case (spr_addr_active[15:11])
        5'd0: spr_cs_r[0] = debug_access || ex_mfspr || ex_mtspr;
        5'd1: spr_cs_r[1] = debug_access || ex_mfspr || ex_mtspr;
        5'd2: spr_cs_r[2] = debug_access || ex_mfspr || ex_mtspr;
        5'd3: spr_cs_r[3] = debug_access || ex_mfspr || ex_mtspr;
        5'd4: spr_cs_r[4] = debug_access || ex_mfspr || ex_mtspr;
        5'd5: spr_cs_r[5] = debug_access || ex_mfspr || ex_mtspr;
        5'd6: spr_cs_r[6] = debug_access || ex_mfspr || ex_mtspr;
        5'd7: spr_cs_r[7] = debug_access || ex_mfspr || ex_mtspr;
        default: spr_cs_r = 32'h0000_0000;
    endcase

    spr_read_data_r = 32'h0000_0000;
    case (spr_addr_active[15:11])
        5'd0: spr_read_data_r = rf[spr_addr_active[4:0]];
        5'd1: begin
            case (spr_addr_active[4:0])
                SYS_SR_IDX:   spr_read_data_r = sr_r;
                SYS_NPC_IDX:  spr_read_data_r = npc_r;
                SYS_EPCR_IDX: spr_read_data_r = epcr_r;
                SYS_EEAR_IDX: spr_read_data_r = eear_r;
                SYS_ESR_IDX:  spr_read_data_r = esr_r;
                default:      spr_read_data_r = 32'h0000_0000;
            endcase
        end
        5'd2: spr_read_data_r = spr_dat_pic;
        5'd3: spr_read_data_r = spr_dat_tt;
        5'd4: spr_read_data_r = spr_dat_pm;
        5'd5: spr_read_data_r = spr_dat_dmmu;
        5'd6: spr_read_data_r = spr_dat_immu;
        5'd7: spr_read_data_r = spr_dat_du;
        default: spr_read_data_r = 32'h0000_0000;
    endcase

    du_dat_cpu_r = 32'h0000_0000;
    if (du_read) begin
        du_dat_cpu_r = spr_read_data_r;
    end else begin
        case (du_addr[4:0])
            5'd0: du_dat_cpu_r = sr_r;
            5'd1: du_dat_cpu_r = npc_r;
            5'd2: du_dat_cpu_r = epcr_r;
            5'd3: du_dat_cpu_r = eear_r;
            5'd4: du_dat_cpu_r = esr_r;
            5'd5: du_dat_cpu_r = id_pc_r;
            5'd6: du_dat_cpu_r = ex_insn_r;
            5'd7: du_dat_cpu_r = wb_data_r;
            default: du_dat_cpu_r = rf[du_addr[4:0]];
        endcase
    end

    wb_gpr_we_r = 1'b0;
    wb_data_r = alu_result_r;
    if (ex_valid_r) begin
        case (ex_opcode)
            OP_LWZ: begin
                wb_gpr_we_r = dcpu_ack_i && !dcpu_err_i && !ex_align_err;
                wb_data_r = dcpu_dat_i;
            end
            OP_LBZ: begin
                wb_gpr_we_r = dcpu_ack_i && !dcpu_err_i && !ex_align_err;
                case (lsu_addr[1:0])
                    2'd0: wb_data_r = {24'h0, dcpu_dat_i[7:0]};
                    2'd1: wb_data_r = {24'h0, dcpu_dat_i[15:8]};
                    2'd2: wb_data_r = {24'h0, dcpu_dat_i[23:16]};
                    default: wb_data_r = {24'h0, dcpu_dat_i[31:24]};
                endcase
            end
            OP_LBS: begin
                wb_gpr_we_r = dcpu_ack_i && !dcpu_err_i && !ex_align_err;
                case (lsu_addr[1:0])
                    2'd0: wb_data_r = {{24{dcpu_dat_i[7]}}, dcpu_dat_i[7:0]};
                    2'd1: wb_data_r = {{24{dcpu_dat_i[15]}}, dcpu_dat_i[15:8]};
                    2'd2: wb_data_r = {{24{dcpu_dat_i[23]}}, dcpu_dat_i[23:16]};
                    default: wb_data_r = {{24{dcpu_dat_i[31]}}, dcpu_dat_i[31:24]};
                endcase
            end
            OP_LHZ: begin
                wb_gpr_we_r = dcpu_ack_i && !dcpu_err_i && !ex_align_err;
                wb_data_r = lsu_addr[1] ? {16'h0, dcpu_dat_i[31:16]} : {16'h0, dcpu_dat_i[15:0]};
            end
            OP_LHS: begin
                wb_gpr_we_r = dcpu_ack_i && !dcpu_err_i && !ex_align_err;
                wb_data_r = lsu_addr[1] ? {{16{dcpu_dat_i[31]}}, dcpu_dat_i[31:16]} : {{16{dcpu_dat_i[15]}}, dcpu_dat_i[15:0]};
            end
            OP_SW,
            OP_SB,
            OP_SH: begin
                wb_gpr_we_r = 1'b0;
                wb_data_r = alu_result_r;
            end
            OP_JAL,
            OP_JALR,
            OP_ADDI,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_MOVHI,
            OP_MULI,
            OP_SHIFTI,
            OP_ALU,
            OP_MFSPR: begin
                wb_gpr_we_r = 1'b1;
                wb_data_r = alu_result_r;
            end
            default: begin
                wb_gpr_we_r = 1'b0;
                wb_data_r = alu_result_r;
            end
        endcase
    end

    exception_start_r = 1'b0;
    exception_vector_r = except_base + VEC_ILLEGAL;
    exception_eear_r = id_pc_r;
    exception_epcr_r = id_pc_r;
    if (du_hwbkpt) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_DEBUG;
        exception_eear_r = pc_r;
        exception_epcr_r = pc_r;
    end else if (icpu_err_i) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_BUSERR;
        exception_eear_r = icpu_adr_i;
        exception_epcr_r = pc_r;
    end else if (dcpu_err_i && ex_valid_r && ex_is_memory) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_BUSERR;
        exception_eear_r = lsu_addr;
        exception_epcr_r = ex_pc_r;
    end else if (ex_valid_r && ex_align_err) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_ALIGN;
        exception_eear_r = lsu_addr;
        exception_epcr_r = ex_pc_r;
    end else if (except_stop_w[2]) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_ILLEGAL;
        exception_eear_r = id_pc_r;
        exception_epcr_r = id_pc_r;
    end else if (id_syscall) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_SYSCALL;
        exception_eear_r = id_pc_r;
        exception_epcr_r = id_pc_r;
    end else if (id_trap) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_TRAP;
        exception_eear_r = id_pc_r;
        exception_epcr_r = id_pc_r;
    end else if (sig_int) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_INT;
        exception_eear_r = pc_r;
        exception_epcr_r = pc_r;
    end else if (sig_tick) begin
        exception_start_r = 1'b1;
        exception_vector_r = except_base + VEC_TICK;
        exception_eear_r = pc_r;
        exception_epcr_r = pc_r;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sr_r <= 32'h0000_0001;
        npc_r <= 32'h0000_0000;
        epcr_r <= 32'h0000_0000;
        eear_r <= 32'h0000_0000;
        esr_r <= 32'h0000_0000;
        pc_r <= 32'h0000_0000;
        id_pc_r <= 32'h0000_0000;
        id_insn_r <= 32'h1500_0000;
        id_valid_r <= 1'b0;
        ex_pc_r <= 32'h0000_0000;
        ex_insn_r <= 32'h1500_0000;
        ex_valid_r <= 1'b0;
        ex_op_a_r <= 32'h0000_0000;
        ex_op_b_r <= 32'h0000_0000;
        ex_imm_r <= 32'h0000_0000;
        ex_spr_addr_r <= 32'h0000_0000;
        ex_rd_r <= 5'd0;
        ex_link_r <= 32'h0000_0000;
        flag_r <= 1'b0;
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'h0000_0000;
    end else begin
        rf[0] <= 32'h0000_0000;

        if (wb_allowed && wb_gpr_we_r && (ex_rd_r != 5'd0))
            rf[ex_rd_r] <= wb_data_r;

        if (debug_access && du_write) begin
            case (du_addr[15:11])
                5'd0: if (du_addr[4:0] != 5'd0) rf[du_addr[4:0]] <= du_dat_du;
                5'd1: begin
                    case (du_addr[4:0])
                        SYS_SR_IDX:   sr_r <= du_dat_du;
                        SYS_NPC_IDX: begin npc_r <= du_dat_du; pc_r <= du_dat_du; end
                        SYS_EPCR_IDX: epcr_r <= du_dat_du;
                        SYS_EEAR_IDX: eear_r <= du_dat_du;
                        SYS_ESR_IDX:  esr_r <= du_dat_du;
                        default: begin end
                    endcase
                end
                default: begin end
            endcase
        end

        if (exception_start_r) begin
            esr_r <= sr_r;
            epcr_r <= exception_epcr_r;
            eear_r <= exception_eear_r;
            sr_r[0] <= 1'b1;
            npc_r <= exception_vector_r;
            pc_r <= exception_vector_r;
            id_valid_r <= 1'b0;
            ex_valid_r <= 1'b0;
            id_insn_r <= 32'h1500_0000;
            ex_insn_r <= 32'h1500_0000;
        end else begin
            if (id_rfe && !du_stall && !lsu_wait) begin
                sr_r <= esr_r;
                pc_r <= epcr_r;
                npc_r <= epcr_r;
                id_valid_r <= 1'b0;
                ex_valid_r <= 1'b0;
                id_insn_r <= 32'h1500_0000;
                ex_insn_r <= 32'h1500_0000;
            end else begin
                if (ex_valid_r && (ex_opcode == OP_SFXX || ex_opcode == OP_SFXXI) && !du_stall)
                    flag_r <= sf_result_r;
                else if (ex_valid_r && !du_stall)
                    flag_r <= (alu_result_r == 32'h0000_0000);

                if (ex_valid_r && ex_mtspr && !du_stall) begin
                    case (ex_spr_addr_r[15:11])
                        5'd1: begin
                            case (ex_spr_addr_r[4:0])
                                SYS_SR_IDX:   sr_r <= ex_op_b_r;
                                SYS_NPC_IDX: begin npc_r <= ex_op_b_r; pc_r <= ex_op_b_r; end
                                SYS_EPCR_IDX: epcr_r <= ex_op_b_r;
                                SYS_EEAR_IDX: eear_r <= ex_op_b_r;
                                SYS_ESR_IDX:  esr_r <= ex_op_b_r;
                                default: begin end
                            endcase
                        end
                        default: begin end
                    endcase
                end

                if (!ex_stage_hold) begin
                    ex_pc_r <= id_pc_r;
                    ex_insn_r <= id_insn_r;
                    ex_valid_r <= id_valid_r;
                    ex_op_a_r <= id_rf_a_r;
                    ex_op_b_r <= id_rf_b_r;
                    ex_imm_r <= (id_opcode == OP_ANDI || id_opcode == OP_ORI) ? id_imm_zext : id_imm_sext;
                    ex_spr_addr_r <= id_spr_addr;
                    ex_rd_r <= id_rd;
                    ex_link_r <= id_link_addr;

                    if (icpu_ack_i && !icpu_err_i) begin
                        id_pc_r <= pc_r;
                        id_insn_r <= icpu_dat_i;
                        id_valid_r <= 1'b1;
                        if (branch_taken_id_r) begin
                            pc_r <= branch_target_id_r;
                            npc_r <= branch_target_id_r;
                        end else begin
                            pc_r <= pc_r + 32'd4;
                            npc_r <= pc_r + 32'd4;
                        end
                    end else begin
                        id_valid_r <= 1'b0;
                        if (branch_taken_id_r) begin
                            pc_r <= branch_target_id_r;
                            npc_r <= branch_target_id_r;
                        end
                    end
                end
            end
        end
    end
end

endmodule
