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

localparam [31:0] OR1200_NOP = 32'h1500_0000;
localparam [31:0] SPR_SR_ADDR   = 32'h0000_0011;
localparam [31:0] SPR_EPCR_ADDR = 32'h0000_0020;
localparam [31:0] SPR_EEAR_ADDR = 32'h0000_0030;
localparam [31:0] SPR_ESR_ADDR  = 32'h0000_0040;
localparam [31:0] SPR_NPC_ADDR  = 32'h0000_0010;

localparam [5:0] OP_J      = 6'b000000;
localparam [5:0] OP_JAL    = 6'b000001;
localparam [5:0] OP_BNF    = 6'b000011;
localparam [5:0] OP_BF     = 6'b000100;
localparam [5:0] OP_NOP    = 6'b000101;
localparam [5:0] OP_RFE    = 6'b001001;
localparam [5:0] OP_SYS    = 6'b001000;
localparam [5:0] OP_TRAP   = 6'b010000;
localparam [5:0] OP_LWZ    = 6'b100001;
localparam [5:0] OP_ADDI   = 6'b100111;
localparam [5:0] OP_ANDI   = 6'b101001;
localparam [5:0] OP_ORI    = 6'b101010;
localparam [5:0] OP_XORI   = 6'b101011;
localparam [5:0] OP_MFSPR  = 6'b101101;
localparam [5:0] OP_MTSPR  = 6'b110000;
localparam [5:0] OP_SW     = 6'b110101;
localparam [5:0] OP_ALU    = 6'b111000;

localparam [3:0] ALU_ADD   = 4'd0;
localparam [3:0] ALU_SUB   = 4'd1;
localparam [3:0] ALU_AND   = 4'd2;
localparam [3:0] ALU_OR    = 4'd3;
localparam [3:0] ALU_XOR   = 4'd4;
localparam [3:0] ALU_SLTU  = 4'd5;
localparam [3:0] ALU_SLL   = 4'd6;
localparam [3:0] ALU_SRL   = 4'd7;
localparam [3:0] ALU_PASSB = 4'd8;

reg [31:0] rf [0:31];
integer i;

reg [31:0] sr_r;
reg [31:0] epcr_r;
reg [31:0] eear_r;
reg [31:0] esr_r;

reg [31:0] pc_r;
reg [31:0] if_pc_r;
reg [31:0] id_pc_r;
reg [31:0] ex_pc_r;

reg [31:0] if_insn_r;
reg [31:0] id_insn_r;
reg [31:0] ex_insn_r;

reg [31:0] ex_op_a_r;
reg [31:0] ex_op_b_r;
reg [31:0] ex_imm_r;
reg [31:0] ex_spr_addr_r;
reg [4:0] ex_rd_r;
reg [3:0] ex_alu_op_r;
reg ex_use_imm_r;
reg ex_is_load_r;
reg ex_is_store_r;
reg ex_is_mfspr_r;
reg ex_is_mtspr_r;
reg ex_is_sys_r;
reg ex_is_trap_r;
reg ex_illegal_r;
reg ex_wb_spr_r;
reg ex_wb_link_r;
reg ex_we_r;
reg ex_multicycle_r;

reg [2:0] branch_op_r;
reg flag_r;
reg carry_r;

reg [31:0] lsu_addr_r;
reg [31:0] lsu_store_data_r;
reg [31:0] lsu_load_data_r;
reg [3:0] lsu_sel_r;
reg [3:0] lsu_tag_r;
reg [4:0] lsu_rd_r;
reg lsu_req_r;
reg lsu_we_r;

reg [1:0] multicycle_cnt_r;

reg [31:0] wb_data_r;
reg [4:0] wb_rd_r;
reg wb_valid_r;
reg [1:0] rfwb_op_r;

reg except_start_r;
reg [7:0] except_type_r;
reg [12:0] except_stop_r;

wire [5:0] id_op_w = id_insn_r[31:26];
wire [4:0] id_rd_w = id_insn_r[25:21];
wire [4:0] id_ra_w = id_insn_r[20:16];
wire [4:0] id_rb_w = id_insn_r[15:11];
wire [25:0] id_imm26_w = id_insn_r[25:0];
wire [31:0] id_imm16_sext_w = {{16{id_insn_r[15]}}, id_insn_r[15:0]};
wire [31:0] id_imm16_zext_w = {16'd0, id_insn_r[15:0]};
wire [31:0] id_branch_off_w = {{4{id_imm26_w[25]}}, id_imm26_w, 2'b00};
wire [31:0] id_jump_target_w = {id_pc_r[31:28], id_imm26_w, 2'b00};
wire [31:0] id_spr_addr_w = {16'd0, id_insn_r[15:0]};
wire id_is_j_w = (id_op_w == OP_J);
wire id_is_jal_w = (id_op_w == OP_JAL);
wire id_is_bf_w = (id_op_w == OP_BF);
wire id_is_bnf_w = (id_op_w == OP_BNF);
wire id_is_rfe_w = (id_op_w == OP_RFE);
wire id_is_lwz_w = (id_op_w == OP_LWZ);
wire id_is_sw_w = (id_op_w == OP_SW);
wire id_is_mfspr_w = (id_op_w == OP_MFSPR);
wire id_is_mtspr_w = (id_op_w == OP_MTSPR);
wire id_is_addi_w = (id_op_w == OP_ADDI);
wire id_is_andi_w = (id_op_w == OP_ANDI);
wire id_is_ori_w = (id_op_w == OP_ORI);
wire id_is_xori_w = (id_op_w == OP_XORI);
wire id_is_alu_w = (id_op_w == OP_ALU);
wire id_is_sys_w = (id_op_w == OP_SYS);
wire id_is_trap_w = (id_op_w == OP_TRAP);
wire id_is_nop_w = (id_op_w == OP_NOP);
wire id_spr_pc_we_w = id_is_mtspr_w && (id_spr_addr_w == SPR_NPC_ADDR);

reg [31:0] id_op_a_w;
reg [31:0] id_op_b_w;
reg [31:0] id_imm_w;
reg [3:0] id_alu_op_w;
reg id_use_imm_w;
reg id_dec_illegal_w;
reg id_we_w;
reg id_wb_spr_w;
reg id_wb_link_w;
reg id_multicycle_w;
reg [2:0] branch_op_w;

wire [31:0] ex_alu_in_b_w = ex_use_imm_r ? ex_imm_r : ex_op_b_r;
reg [31:0] alu_result_w;
reg alu_flag_w;
reg alu_carry_w;

wire [31:0] ex_mem_addr_w = ex_op_a_r + ex_imm_r;
wire ex_align_err_w = (ex_is_load_r || ex_is_store_r) && (ex_mem_addr_w[1:0] != 2'b00);

wire except_prefix_w = sr_r[14];
wire [31:0] except_base_w = except_prefix_w ? 32'hF000_0000 : 32'h0000_0000;
wire [31:0] except_vector_w = except_base_w | {20'd0, except_type_r, 4'd0};

wire lsu_done_w = lsu_req_r && (dcpu_ack_i || dcpu_rty_i || dcpu_err_i);
wire lsu_stall_w = lsu_req_r && !lsu_done_w;
wire if_stall_w = icpu_cycstb_o && !(icpu_ack_i || icpu_rty_i || icpu_err_i);
wire multicycle_freeze_w = (multicycle_cnt_r != 2'd0);
wire ex_freeze_w = du_stall || lsu_stall_w || multicycle_freeze_w || except_start_r;
wire genpc_freeze_w = du_stall || lsu_stall_w || multicycle_freeze_w;
wire id_freeze_w = ex_freeze_w || if_stall_w;
wire if_freeze_w = genpc_freeze_w || if_stall_w;

wire branch_taken_w =
    (branch_op_w == 3'b001) ||
    (branch_op_w == 3'b010) ||
    ((branch_op_w == 3'b011) && flag_r) ||
    ((branch_op_w == 3'b100) && !flag_r);

wire [31:0] branch_target_w =
    ((branch_op_w == 3'b001) || (branch_op_w == 3'b010)) ? id_jump_target_w :
    (id_pc_r + id_branch_off_w);

wire wb_from_lsu_w = lsu_done_w && !lsu_we_r && dcpu_ack_i && !except_start_r;
wire wb_from_ex_w = !ex_freeze_w && ex_we_r && !ex_is_load_r && !ex_is_store_r && !except_start_r;
wire wb_do_write_w = wb_from_lsu_w || wb_from_ex_w;
wire [4:0] wb_rd_w = wb_from_lsu_w ? lsu_rd_r : ex_rd_r;
wire [31:0] wb_ex_data_w = ex_wb_link_r ? (ex_pc_r + 32'd8) :
                           (ex_wb_spr_r ? 32'd0 : alu_result_w);
wire [31:0] wb_data_w = wb_from_lsu_w ? dcpu_dat_i : wb_ex_data_w;
wire [1:0] rfwb_op_w = wb_from_lsu_w ? 2'b11 : (wb_from_ex_w ? 2'b01 : 2'b00);
wire we_w = rfwb_op_w[0];

function [31:0] spr_read_mux;
    input [31:0] addr;
    begin
        case (addr[15:11])
            5'd0: begin
                case (addr[7:0])
                    8'h11: spr_read_mux = sr_r;
                    8'h20: spr_read_mux = epcr_r;
                    8'h30: spr_read_mux = eear_r;
                    8'h40: spr_read_mux = esr_r;
                    8'h10: spr_read_mux = pc_r + 32'd4;
                    default: spr_read_mux = rf[addr[4:0]];
                endcase
            end
            5'd1: spr_read_mux = spr_dat_pic;
            5'd2: spr_read_mux = spr_dat_tt;
            5'd3: spr_read_mux = spr_dat_pm;
            5'd4: spr_read_mux = spr_dat_dmmu;
            5'd5: spr_read_mux = spr_dat_immu;
            5'd6: spr_read_mux = spr_dat_du;
            default: spr_read_mux = 32'd0;
        endcase
    end
endfunction

wire [31:0] ex_spr_read_data_w = spr_read_mux(ex_spr_addr_r);
wire [31:0] du_read_data_w = spr_read_mux(du_addr);
wire [31:0] rf_ra_data_w = (id_ra_w == 5'd0) ? 32'd0 : rf[id_ra_w];
wire [31:0] rf_rb_data_w = (id_rb_w == 5'd0) ? 32'd0 : rf[id_rb_w];
wire [31:0] wb_forward_w = wb_data_r;
wire wb_forward_valid_w = wb_valid_r;
wire [31:0] id_op_a_pre_w = (wb_forward_valid_w && (id_ra_w != 5'd0) && (id_ra_w == wb_rd_r)) ? wb_forward_w : rf_ra_data_w;
wire [31:0] id_op_b_pre_w = (wb_forward_valid_w && (id_rb_w != 5'd0) && (id_rb_w == wb_rd_r)) ? wb_forward_w : rf_rb_data_w;

reg except_start_w;
reg [7:0] except_type_w;
reg [12:0] except_stop_w;

always @* begin
    id_op_a_w = id_op_a_pre_w;
    id_op_b_w = id_op_b_pre_w;
    id_imm_w = id_imm16_sext_w;
    id_alu_op_w = ALU_ADD;
    id_use_imm_w = 1'b0;
    id_dec_illegal_w = 1'b0;
    id_we_w = 1'b0;
    id_wb_spr_w = 1'b0;
    id_wb_link_w = 1'b0;
    id_multicycle_w = 1'b0;
    branch_op_w = 3'b000;

    if (id_is_j_w) branch_op_w = 3'b001;
    if (id_is_jal_w) branch_op_w = 3'b010;
    if (id_is_bf_w) branch_op_w = 3'b011;
    if (id_is_bnf_w) branch_op_w = 3'b100;
    if (id_is_rfe_w) branch_op_w = 3'b101;

    case (id_op_w)
        OP_J: begin
        end
        OP_JAL: begin
            id_we_w = 1'b1;
            id_wb_link_w = 1'b1;
        end
        OP_BF, OP_BNF, OP_RFE, OP_NOP: begin
        end
        OP_LWZ: begin
            id_use_imm_w = 1'b1;
            id_alu_op_w = ALU_ADD;
            id_we_w = 1'b1;
        end
        OP_SW: begin
            id_use_imm_w = 1'b1;
            id_alu_op_w = ALU_ADD;
        end
        OP_ADDI: begin
            id_use_imm_w = 1'b1;
            id_alu_op_w = ALU_ADD;
            id_we_w = 1'b1;
        end
        OP_ANDI: begin
            id_use_imm_w = 1'b1;
            id_imm_w = id_imm16_zext_w;
            id_alu_op_w = ALU_AND;
            id_we_w = 1'b1;
        end
        OP_ORI: begin
            id_use_imm_w = 1'b1;
            id_imm_w = id_imm16_zext_w;
            id_alu_op_w = ALU_OR;
            id_we_w = 1'b1;
        end
        OP_XORI: begin
            id_use_imm_w = 1'b1;
            id_imm_w = id_imm16_zext_w;
            id_alu_op_w = ALU_XOR;
            id_we_w = 1'b1;
        end
        OP_MFSPR: begin
            id_we_w = 1'b1;
            id_wb_spr_w = 1'b1;
        end
        OP_MTSPR: begin
            id_we_w = 1'b0;
        end
        OP_SYS: begin
        end
        OP_TRAP: begin
        end
        OP_ALU: begin
            id_we_w = 1'b1;
            case (id_insn_r[3:0])
                4'h0: id_alu_op_w = ALU_ADD;
                4'h1: id_alu_op_w = ALU_SUB;
                4'h2: id_alu_op_w = ALU_AND;
                4'h3: id_alu_op_w = ALU_OR;
                4'h4: id_alu_op_w = ALU_XOR;
                4'h5: id_alu_op_w = ALU_SLTU;
                4'h6: id_alu_op_w = ALU_SLL;
                4'h7: id_alu_op_w = ALU_SRL;
                default: id_alu_op_w = ALU_PASSB;
            endcase
            id_multicycle_w = id_insn_r[4];
        end
        default: begin
            id_dec_illegal_w = !id_is_nop_w;
        end
    endcase
end

always @* begin
    alu_result_w = 32'd0;
    alu_flag_w = 1'b0;
    alu_carry_w = 1'b0;
    case (ex_alu_op_r)
        ALU_ADD: begin
            {alu_carry_w, alu_result_w} = {1'b0, ex_op_a_r} + {1'b0, ex_alu_in_b_w};
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_SUB: begin
            {alu_carry_w, alu_result_w} = {1'b0, ex_op_a_r} - {1'b0, ex_alu_in_b_w};
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_AND: begin
            alu_result_w = ex_op_a_r & ex_alu_in_b_w;
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_OR: begin
            alu_result_w = ex_op_a_r | ex_alu_in_b_w;
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_XOR: begin
            alu_result_w = ex_op_a_r ^ ex_alu_in_b_w;
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_SLTU: begin
            alu_result_w = (ex_op_a_r < ex_alu_in_b_w) ? 32'd1 : 32'd0;
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_SLL: begin
            alu_result_w = ex_op_a_r << ex_alu_in_b_w[4:0];
            alu_flag_w = (alu_result_w == 32'd0);
        end
        ALU_SRL: begin
            alu_result_w = ex_op_a_r >> ex_alu_in_b_w[4:0];
            alu_flag_w = (alu_result_w == 32'd0);
        end
        default: begin
            alu_result_w = ex_alu_in_b_w;
            alu_flag_w = (alu_result_w == 32'd0);
        end
    endcase
end

always @* begin
    except_start_w = 1'b0;
    except_type_w = 8'h00;
    except_stop_w = 13'd0;

    if (du_hwbkpt) begin
        except_start_w = 1'b1;
        except_type_w = 8'h0A;
        except_stop_w[12] = 1'b1;
    end else if (icpu_err_i) begin
        except_start_w = 1'b1;
        except_type_w = 8'h01;
        except_stop_w[0] = 1'b1;
    end else if (dcpu_err_i) begin
        except_start_w = 1'b1;
        except_type_w = 8'h02;
        except_stop_w[1] = 1'b1;
    end else if (ex_align_err_w) begin
        except_start_w = 1'b1;
        except_type_w = 8'h03;
        except_stop_w[2] = 1'b1;
    end else if (ex_illegal_r) begin
        except_start_w = 1'b1;
        except_type_w = 8'h04;
        except_stop_w[3] = 1'b1;
    end else if (ex_is_sys_r) begin
        except_start_w = 1'b1;
        except_type_w = 8'h05;
        except_stop_w[4] = 1'b1;
    end else if (ex_is_trap_r) begin
        except_start_w = 1'b1;
        except_type_w = 8'h06;
        except_stop_w[5] = 1'b1;
    end else if (sig_tick) begin
        except_start_w = 1'b1;
        except_type_w = 8'h07;
        except_stop_w[6] = 1'b1;
    end else if (sig_int) begin
        except_start_w = 1'b1;
        except_type_w = 8'h08;
        except_stop_w[7] = 1'b1;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'd0;
        sr_r <= 32'h0000_0001;
        epcr_r <= 32'd0;
        eear_r <= 32'd0;
        esr_r <= 32'd0;
        pc_r <= 32'd0;
        if_pc_r <= 32'd0;
        id_pc_r <= 32'd0;
        ex_pc_r <= 32'd0;
        if_insn_r <= OR1200_NOP;
        id_insn_r <= OR1200_NOP;
        ex_insn_r <= OR1200_NOP;
        ex_op_a_r <= 32'd0;
        ex_op_b_r <= 32'd0;
        ex_imm_r <= 32'd0;
        ex_spr_addr_r <= 32'd0;
        ex_rd_r <= 5'd0;
        ex_alu_op_r <= ALU_ADD;
        ex_use_imm_r <= 1'b0;
        ex_is_load_r <= 1'b0;
        ex_is_store_r <= 1'b0;
        ex_is_mfspr_r <= 1'b0;
        ex_is_mtspr_r <= 1'b0;
        ex_is_sys_r <= 1'b0;
        ex_is_trap_r <= 1'b0;
        ex_illegal_r <= 1'b0;
        ex_wb_spr_r <= 1'b0;
        ex_wb_link_r <= 1'b0;
        ex_we_r <= 1'b0;
        ex_multicycle_r <= 1'b0;
        branch_op_r <= 3'd0;
        flag_r <= 1'b0;
        carry_r <= 1'b0;
        lsu_addr_r <= 32'd0;
        lsu_store_data_r <= 32'd0;
        lsu_load_data_r <= 32'd0;
        lsu_sel_r <= 4'h0;
        lsu_tag_r <= 4'h0;
        lsu_rd_r <= 5'd0;
        lsu_req_r <= 1'b0;
        lsu_we_r <= 1'b0;
        multicycle_cnt_r <= 2'd0;
        wb_data_r <= 32'd0;
        wb_rd_r <= 5'd0;
        wb_valid_r <= 1'b0;
        rfwb_op_r <= 2'b00;
        except_start_r <= 1'b0;
        except_type_r <= 8'd0;
        except_stop_r <= 13'd0;
    end else begin
        except_start_r <= except_start_w;
        except_type_r <= except_type_w;
        except_stop_r <= except_stop_w;

        if (du_write) begin
            case (du_addr)
                SPR_SR_ADDR: sr_r <= du_dat_du;
                SPR_EPCR_ADDR: epcr_r <= du_dat_du;
                SPR_EEAR_ADDR: eear_r <= du_dat_du;
                SPR_ESR_ADDR: esr_r <= du_dat_du;
                SPR_NPC_ADDR: pc_r <= du_dat_du;
                default: begin
                    if (du_addr[15:11] == 5'd0)
                        rf[du_addr[4:0]] <= du_dat_du;
                end
            endcase
        end else if (id_is_mtspr_w && !id_freeze_w) begin
            case (id_spr_addr_w)
                SPR_SR_ADDR: sr_r <= id_op_b_pre_w;
                SPR_EPCR_ADDR: epcr_r <= id_op_b_pre_w;
                SPR_EEAR_ADDR: eear_r <= id_op_b_pre_w;
                SPR_ESR_ADDR: esr_r <= id_op_b_pre_w;
                SPR_NPC_ADDR: pc_r <= id_op_b_pre_w;
                default: begin
                    if (id_spr_addr_w[15:11] == 5'd0)
                        rf[id_spr_addr_w[4:0]] <= id_op_b_pre_w;
                end
            endcase
        end

        if (except_start_w) begin
            epcr_r <= ex_pc_r;
            eear_r <= (ex_is_load_r || ex_is_store_r) ? ex_mem_addr_w : ex_pc_r;
            esr_r <= sr_r;
            sr_r[0] <= 1'b1;
        end

        if (multicycle_cnt_r != 2'd0)
            multicycle_cnt_r <= multicycle_cnt_r - 2'd1;
        else if (!ex_freeze_w && id_multicycle_w)
            multicycle_cnt_r <= 2'd2;

        if (lsu_req_r) begin
            if (lsu_done_w) begin
                if (!lsu_we_r && dcpu_ack_i)
                    lsu_load_data_r <= dcpu_dat_i;
                lsu_req_r <= 1'b0;
            end
        end else if (!ex_freeze_w && (ex_is_load_r || ex_is_store_r)) begin
            lsu_req_r <= 1'b1;
            lsu_we_r <= ex_is_store_r;
            lsu_addr_r <= ex_mem_addr_w;
            lsu_store_data_r <= ex_op_b_r;
            lsu_sel_r <= 4'b1111;
            lsu_tag_r <= 4'b0001;
            lsu_rd_r <= ex_rd_r;
        end

        wb_valid_r <= wb_do_write_w;
        wb_rd_r <= wb_rd_w;
        wb_data_r <= wb_from_ex_w && ex_wb_spr_r ? ex_spr_read_data_w : wb_data_w;
        rfwb_op_r <= rfwb_op_w;
        if (wb_do_write_w && we_w && (wb_rd_w != 5'd0))
            rf[wb_rd_w] <= (wb_from_ex_w && ex_wb_spr_r) ? ex_spr_read_data_w : wb_data_w;

        if (!ex_freeze_w) begin
            flag_r <= alu_flag_w;
            carry_r <= alu_carry_w;
        end

        if (except_start_w) begin
            if_insn_r <= OR1200_NOP;
            id_insn_r <= OR1200_NOP;
            ex_insn_r <= OR1200_NOP;
            branch_op_r <= 3'b000;
        end else begin
            if (!if_freeze_w && (icpu_ack_i || icpu_err_i || icpu_rty_i)) begin
                if_insn_r <= icpu_ack_i ? icpu_dat_i : OR1200_NOP;
                if_pc_r <= icpu_adr_i;
            end

            if (!id_freeze_w) begin
                id_insn_r <= if_insn_r;
                id_pc_r <= if_pc_r;
                branch_op_r <= branch_op_w;
            end

            if (!ex_freeze_w) begin
                ex_insn_r <= id_insn_r;
                ex_pc_r <= id_pc_r;
                ex_op_a_r <= id_op_a_w;
                ex_op_b_r <= id_op_b_w;
                ex_imm_r <= id_imm_w;
                ex_spr_addr_r <= id_spr_addr_w;
                ex_rd_r <= id_rd_w;
                ex_alu_op_r <= id_alu_op_w;
                ex_use_imm_r <= id_use_imm_w;
                ex_is_load_r <= id_is_lwz_w;
                ex_is_store_r <= id_is_sw_w;
                ex_is_mfspr_r <= id_is_mfspr_w;
                ex_is_mtspr_r <= id_is_mtspr_w;
                ex_is_sys_r <= id_is_sys_w;
                ex_is_trap_r <= id_is_trap_w;
                ex_illegal_r <= id_dec_illegal_w;
                ex_wb_spr_r <= id_wb_spr_w;
                ex_wb_link_r <= id_wb_link_w;
                ex_we_r <= id_we_w;
                ex_multicycle_r <= id_multicycle_w;
            end
        end

        if (!genpc_freeze_w) begin
            if (except_start_w)
                pc_r <= except_base_w | {20'd0, except_type_w, 4'd0};
            else if (id_is_rfe_w && !id_freeze_w)
                pc_r <= epcr_r;
            else if (id_spr_pc_we_w && !id_freeze_w)
                pc_r <= id_op_b_pre_w;
            else if (branch_taken_w && !id_freeze_w)
                pc_r <= branch_target_w;
            else if (icpu_ack_i || icpu_err_i || icpu_rty_i)
                pc_r <= pc_r + 32'd4;
        end
    end
end

assign ic_en = sr_r[4];
assign immu_en = sr_r[6];
assign dc_en = sr_r[3];
assign dmmu_en = sr_r[5];
assign supv = sr_r[0];

assign icpu_adr_o = pc_r;
assign icpu_cycstb_o = !rst && !du_stall;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = {except_prefix_w, 3'b000};

assign dcpu_adr_o = lsu_addr_r;
assign dcpu_cycstb_o = lsu_req_r;
assign dcpu_we_o = lsu_we_r;
assign dcpu_sel_o = lsu_sel_r;
assign dcpu_tag_o = lsu_tag_r;
assign dcpu_dat_o = lsu_store_data_r;

assign spr_addr = (du_read || du_write) ? du_addr : id_spr_addr_w;
assign spr_dat_cpu = du_write ? du_dat_du : id_op_b_pre_w;
assign spr_cs = (du_read || du_write || id_is_mfspr_w || id_is_mtspr_w) ? (32'h0000_0001 << spr_addr[15:11]) : 32'd0;
assign spr_we = du_write || (id_is_mtspr_w && !id_freeze_w);

assign ex_insn = ex_insn_r;
assign ex_freeze = ex_freeze_w;
assign id_pc = id_pc_r;
assign branch_op = branch_op_r;
assign spr_dat_npc = pc_r + 32'd4;
assign rf_dataw = wb_data_r;
assign du_except = except_stop_r;
assign du_dat_cpu = du_read_data_w;

endmodule
