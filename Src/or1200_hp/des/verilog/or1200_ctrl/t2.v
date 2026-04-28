`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_ctrl (
    input clk,
    input rst,

    input         id_freeze,
    input         ex_freeze,
    input         wb_freeze,
    input         flushpipe,
    input  [31:0] if_insn,
    output [31:0] ex_insn,
    output [2:0]  branch_op,
    input         branch_taken,
    output [4:0]  rf_addra,
    output [4:0]  rf_addrb,
    output        rf_rda,
    output        rf_rdb,
    output [3:0]  alu_op,
    output [1:0]  mac_op,
    output [1:0]  shrot_op,
    output [3:0]  comp_op,
    output [4:0]  rf_addrw,
    output [2:0]  rfwb_op,
    output [31:0] wb_insn,
    output [31:0] simm,
    output [31:2] branch_addrofs,
    output [31:0] lsu_addrofs,
    output [1:0]  sel_a,
    output [1:0]  sel_b,
    output [3:0]  lsu_op,
    output [4:0]  cust5_op,
    output [5:0]  cust5_limm,
    output [1:0]  multicycle,
    output [15:0] spr_addrimm,
    input         wbforw_valid,
    input         du_hwbkpt,
    output        sig_syscall,
    output        sig_trap,
    output        force_dslot_fetch,
    output        no_more_dslot,
    output        ex_void,
    output        id_macrc_op,
    output        ex_macrc_op,
    output        rfe,
    output        except_illegal
);

    //--------------------------------------------------------------------------
    // NOP encoding: bit[16]=1
    //--------------------------------------------------------------------------
    `define OR1200_OR32_NOP_INSN  32'h1500_0000

    //--------------------------------------------------------------------------
    // Pipeline instruction registers
    //--------------------------------------------------------------------------
    reg [31:0] id_insn;
    reg [31:0] ex_insn_r;
    reg [31:0] wb_insn_r;

    assign ex_insn = ex_insn_r;
    assign wb_insn = wb_insn_r;

    //--------------------------------------------------------------------------
    // Register-file read address / enable (combinational from if_insn)
    //--------------------------------------------------------------------------
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda   = if_insn[31];
    assign rf_rdb   = if_insn[30];

    //--------------------------------------------------------------------------
    // pre_branch_op: decoded from if_insn in fetch stage
    //--------------------------------------------------------------------------
    reg [2:0] pre_branch_op;

    always @(*) begin
        if (!id_freeze) begin
            case (if_insn[31:26])
                `OR1200_OR32_J:    pre_branch_op = `OR1200_BRANCHOP_J;
                `OR1200_OR32_JAL:  pre_branch_op = `OR1200_BRANCHOP_JAL;
                `OR1200_OR32_BNF:  pre_branch_op = `OR1200_BRANCHOP_BNF;
                `OR1200_OR32_BF:   pre_branch_op = `OR1200_BRANCHOP_BF;
                `OR1200_OR32_RFE:  pre_branch_op = `OR1200_BRANCHOP_RFE;
                `OR1200_OR32_JR:   pre_branch_op = `OR1200_BRANCHOP_JR;
                `OR1200_OR32_JALR: pre_branch_op = `OR1200_BRANCHOP_JAL;
                default:           pre_branch_op = `OR1200_BRANCHOP_NOP;
            endcase
        end else begin
            pre_branch_op = `OR1200_BRANCHOP_NOP;
        end
    end

    //--------------------------------------------------------------------------
    // sel_imm: combinational from if_insn (exclusion-style)
    //--------------------------------------------------------------------------
    reg sel_imm_r;

    always @(*) begin
        case (if_insn[31:26])
            `OR1200_OR32_J,
            `OR1200_OR32_JAL,
            `OR1200_OR32_BNF,
            `OR1200_OR32_BF,
            `OR1200_OR32_RFE,
            `OR1200_OR32_JR,
            `OR1200_OR32_JALR,
            `OR1200_OR32_MFSPR,
            `OR1200_OR32_MTSPR,
            `OR1200_OR32_SW,
            `OR1200_OR32_SB,
            `OR1200_OR32_SH,
            `OR1200_OR32_ALU,
            `OR1200_OR32_SFXX,
            `OR1200_OR32_NOP:    sel_imm_r = 1'b0;
`ifdef OR1200_IMPL_CUS5
            `OR1200_OR32_CUST5:  sel_imm_r = 1'b0;
`endif
            default:             sel_imm_r = 1'b1;
        endcase
    end

    //--------------------------------------------------------------------------
    // ID-stage instruction capture
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            id_insn <= `OR1200_OR32_NOP_INSN;
        else if (flushpipe)
            id_insn <= `OR1200_OR32_NOP_INSN;
        else if (!id_freeze)
            id_insn <= if_insn;
    end

    //--------------------------------------------------------------------------
    // id_void / ex_void
    //--------------------------------------------------------------------------
    wire id_void_w = id_insn[16];
    assign ex_void  = ex_insn_r[16];

    //--------------------------------------------------------------------------
    // Immediate sign extension control (combinational from id_insn)
    //--------------------------------------------------------------------------
    reg imm_signextend;
    always @(*) begin
        case (id_insn[31:26])
            `OR1200_OR32_ADDI,
            `OR1200_OR32_ADDIC,
            `OR1200_OR32_XORI,
            `OR1200_OR32_SFXXI: imm_signextend = 1'b1;
`ifdef OR1200_MULT_IMPLEMENTED
            `OR1200_OR32_MULI:  imm_signextend = 1'b1;
`endif
`ifdef OR1200_MAC_IMPLEMENTED
            `OR1200_OR32_MACI:  imm_signextend = 1'b1;
`endif
            default:            imm_signextend = 1'b0;
        endcase
    end

    //--------------------------------------------------------------------------
    // simm: immediate from id_insn
    //--------------------------------------------------------------------------
    assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]}
                                 : {16'h0000,           id_insn[15:0]};

    //--------------------------------------------------------------------------
    // Forwarding: sel_a, sel_b
    //--------------------------------------------------------------------------
    reg [4:0] wb_rfaddrw;

    // EX dest (rf_addrw registered below)
    reg [4:0] ex_rfaddrw_r;

    assign sel_a = (id_insn[20:16] == ex_rfaddrw_r) && (ex_rfaddrw_r != 5'd0) ?
                       `OR1200_SEL_EX_FORW :
                   (id_insn[20:16] == wb_rfaddrw)   && (wb_rfaddrw   != 5'd0) && wbforw_valid ?
                       `OR1200_SEL_WB_FORW :
                       `OR1200_SEL_RF;

    assign sel_b = sel_imm_r ? `OR1200_SEL_IMM :
                   (id_insn[15:11] == ex_rfaddrw_r) && (ex_rfaddrw_r != 5'd0) ?
                       `OR1200_SEL_EX_FORW :
                   (id_insn[15:11] == wb_rfaddrw)   && (wb_rfaddrw   != 5'd0) && wbforw_valid ?
                       `OR1200_SEL_WB_FORW :
                       `OR1200_SEL_RF;

    //--------------------------------------------------------------------------
    // multicycle (combinational from id_insn)
    //--------------------------------------------------------------------------
    reg [1:0] multicycle_r;
    always @(*) begin
        case (id_insn[31:26])
            `OR1200_OR32_ALU: multicycle_r = id_insn[9:8];
            default:          multicycle_r = `OR1200_ONE_CYCLE;
        endcase
    end
    assign multicycle = multicycle_r;

    //--------------------------------------------------------------------------
    // MAC result read (id stage)
    //--------------------------------------------------------------------------
`ifdef OR1200_MAC_IMPLEMENTED
    assign id_macrc_op = (id_insn[31:26] == `OR1200_OR32_MOVHI) && id_insn[16];
`else
    assign id_macrc_op = 1'b0;
`endif

    //--------------------------------------------------------------------------
    // rf_addrw: write destination
    //--------------------------------------------------------------------------
    reg [4:0] rf_addrw_r;

    always @(*) begin
        if (pre_branch_op == `OR1200_BRANCHOP_JR ||
            pre_branch_op == `OR1200_BRANCHOP_JAL)
            rf_addrw_r = 5'd9;   // link register r9
        else
            rf_addrw_r = id_insn[25:21];
    end
    assign rf_addrw = rf_addrw_r;

    //--------------------------------------------------------------------------
    // EX-stage control registers
    //--------------------------------------------------------------------------
    reg [3:0]  alu_op_r;
    reg [1:0]  mac_op_r;
    reg [1:0]  shrot_op_r;
    reg [3:0]  comp_op_r;
    reg [3:0]  lsu_op_r;
    reg [2:0]  rfwb_op_r;
    reg [2:0]  branch_op_r;
    reg [15:0] spr_addrimm_r;
    reg        sig_syscall_r;
    reg        sig_trap_r;
    reg        except_illegal_r;
    reg        ex_macrc_op_r;
    reg        sel_imm_reg;

    assign alu_op       = alu_op_r;
    assign mac_op       = mac_op_r;
    assign shrot_op     = shrot_op_r;
    assign comp_op      = comp_op_r;
    assign lsu_op       = lsu_op_r;
    assign rfwb_op      = rfwb_op_r;
    assign branch_op    = branch_op_r;
    assign spr_addrimm  = spr_addrimm_r;
    assign sig_syscall  = sig_syscall_r;
    assign sig_trap     = sig_trap_r;
    assign except_illegal = except_illegal_r;
    assign ex_macrc_op  = ex_macrc_op_r;

    //--------------------------------------------------------------------------
    // EX-stage sequential update
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_insn_r      <= `OR1200_OR32_NOP_INSN;
            alu_op_r       <= `OR1200_ALUOP_NOP;
            mac_op_r       <= `OR1200_MACOP_NOP;
            shrot_op_r     <= 2'd0;
            comp_op_r      <= 4'd0;
            lsu_op_r       <= `OR1200_LSUOP_NOP;
            rfwb_op_r      <= `OR1200_RFWBOP_NOP;
            branch_op_r    <= `OR1200_BRANCHOP_NOP;
            spr_addrimm_r  <= 16'd0;
            sig_syscall_r  <= 1'b0;
            sig_trap_r     <= 1'b0;
            except_illegal_r <= 1'b0;
            ex_macrc_op_r  <= 1'b0;
            ex_rfaddrw_r   <= 5'd0;
        end else if (flushpipe) begin
            ex_insn_r      <= `OR1200_OR32_NOP_INSN;
            alu_op_r       <= `OR1200_ALUOP_NOP;
            mac_op_r       <= `OR1200_MACOP_NOP;
            shrot_op_r     <= 2'd0;
            comp_op_r      <= 4'd0;
            lsu_op_r       <= `OR1200_LSUOP_NOP;
            rfwb_op_r      <= `OR1200_RFWBOP_NOP;
            branch_op_r    <= `OR1200_BRANCHOP_NOP;
            spr_addrimm_r  <= 16'd0;
            sig_syscall_r  <= 1'b0;
            sig_trap_r     <= 1'b0;
            except_illegal_r <= 1'b0;
            ex_macrc_op_r  <= 1'b0;
            ex_rfaddrw_r   <= 5'd0;
        end else if (!ex_freeze) begin
            if (id_freeze) begin
                // ID frozen, EX not: insert bubble
                ex_insn_r      <= `OR1200_OR32_NOP_INSN;
                alu_op_r       <= `OR1200_ALUOP_NOP;
                mac_op_r       <= `OR1200_MACOP_NOP;
                shrot_op_r     <= 2'd0;
                comp_op_r      <= 4'd0;
                lsu_op_r       <= `OR1200_LSUOP_NOP;
                rfwb_op_r      <= `OR1200_RFWBOP_NOP;
                branch_op_r    <= `OR1200_BRANCHOP_NOP;
                spr_addrimm_r  <= 16'd0;
                sig_syscall_r  <= 1'b0;
                sig_trap_r     <= 1'b0;
                except_illegal_r <= 1'b0;
                ex_macrc_op_r  <= 1'b0;
                ex_rfaddrw_r   <= 5'd0;
            end else begin
                ex_insn_r     <= id_insn;
                ex_rfaddrw_r  <= rf_addrw_r;
                ex_macrc_op_r <= id_macrc_op;

                // alu_op decode
                case (id_insn[31:26])
                    `OR1200_OR32_ALU:    alu_op_r <= id_insn[3:0];
                    `OR1200_OR32_ADDI:   alu_op_r <= `OR1200_ALUOP_ADD;
                    `OR1200_OR32_ADDIC:  alu_op_r <= `OR1200_ALUOP_ADDC;
                    `OR1200_OR32_ANDI:   alu_op_r <= `OR1200_ALUOP_AND;
                    `OR1200_OR32_ORI:    alu_op_r <= `OR1200_ALUOP_OR;
                    `OR1200_OR32_XORI:   alu_op_r <= `OR1200_ALUOP_XOR;
                    `OR1200_OR32_MOVHI:  alu_op_r <= `OR1200_ALUOP_MOVHI;
                    `OR1200_OR32_MFSPR:  alu_op_r <= `OR1200_ALUOP_MFSPR;
                    `OR1200_OR32_MTSPR:  alu_op_r <= `OR1200_ALUOP_MTSPR;
                    `OR1200_OR32_SFXX,
                    `OR1200_OR32_SFXXI:  alu_op_r <= `OR1200_ALUOP_COMP;
                    `OR1200_OR32_LW,`OR1200_OR32_LB,`OR1200_OR32_LBU,
                    `OR1200_OR32_LH,`OR1200_OR32_LHU,`OR1200_OR32_LWZ,
                    `OR1200_OR32_SW,`OR1200_OR32_SB,`OR1200_OR32_SH:
                                         alu_op_r <= `OR1200_ALUOP_IMM;
                    `OR1200_OR32_NOP:    alu_op_r <= `OR1200_ALUOP_NOP;
                    `OR1200_OR32_J,`OR1200_OR32_JAL,
                    `OR1200_OR32_JR,`OR1200_OR32_JALR,
                    `OR1200_OR32_BF,`OR1200_OR32_BNF:
                                         alu_op_r <= `OR1200_ALUOP_NOP;
`ifdef OR1200_MULT_IMPLEMENTED
                    `OR1200_OR32_MULI:   alu_op_r <= `OR1200_ALUOP_MUL;
`endif
`ifdef OR1200_IMPL_CUS5
                    `OR1200_OR32_CUST5:  alu_op_r <= `OR1200_ALUOP_CUST5;
`endif
                    default:             alu_op_r <= `OR1200_ALUOP_NOP;
                endcase

                // shrot_op
                shrot_op_r <= id_insn[7:6];

                // comp_op
                comp_op_r  <= id_insn[24:21];

                // mac_op
`ifdef OR1200_MAC_IMPLEMENTED
                case (id_insn[31:26])
                    `OR1200_OR32_MACI: mac_op_r <= `OR1200_MACOP_MAC;
                    `OR1200_OR32_MAC:
                        case (id_insn[3:0])
                            4'h1:    mac_op_r <= `OR1200_MACOP_MAC;
                            4'h2:    mac_op_r <= `OR1200_MACOP_MSB;
                            default: mac_op_r <= `OR1200_MACOP_NOP;
                        endcase
                    default: mac_op_r <= `OR1200_MACOP_NOP;
                endcase
`else
                mac_op_r <= `OR1200_MACOP_NOP;
`endif

                // lsu_op
                case (id_insn[31:26])
                    `OR1200_OR32_LW:  lsu_op_r <= `OR1200_LSUOP_LW;
                    `OR1200_OR32_LWZ: lsu_op_r <= `OR1200_LSUOP_LW;
                    `OR1200_OR32_LB:  lsu_op_r <= `OR1200_LSUOP_LB;
                    `OR1200_OR32_LBU: lsu_op_r <= `OR1200_LSUOP_LBU;
                    `OR1200_OR32_LH:  lsu_op_r <= `OR1200_LSUOP_LH;
                    `OR1200_OR32_LHU: lsu_op_r <= `OR1200_LSUOP_LHU;
                    `OR1200_OR32_SW:  lsu_op_r <= `OR1200_LSUOP_SW;
                    `OR1200_OR32_SB:  lsu_op_r <= `OR1200_LSUOP_SB;
                    `OR1200_OR32_SH:  lsu_op_r <= `OR1200_LSUOP_SH;
                    default:          lsu_op_r <= `OR1200_LSUOP_NOP;
                endcase

                // rfwb_op
                case (id_insn[31:26])
                    `OR1200_OR32_JAL,
                    `OR1200_OR32_JALR:  rfwb_op_r <= `OR1200_RFWBOP_LNK;
                    `OR1200_OR32_LW,
                    `OR1200_OR32_LWZ,
                    `OR1200_OR32_LB,
                    `OR1200_OR32_LBU,
                    `OR1200_OR32_LH,
                    `OR1200_OR32_LHU:   rfwb_op_r <= `OR1200_RFWBOP_LSU;
                    `OR1200_OR32_MFSPR: rfwb_op_r <= `OR1200_RFWBOP_SPRS;
                    `OR1200_OR32_SW,
                    `OR1200_OR32_SB,
                    `OR1200_OR32_SH,
                    `OR1200_OR32_MTSPR,
                    `OR1200_OR32_NOP,
                    `OR1200_OR32_J,
                    `OR1200_OR32_JR,
                    `OR1200_OR32_BF,
                    `OR1200_OR32_BNF,
                    `OR1200_OR32_RFE,
                    `OR1200_OR32_SFXX,
                    `OR1200_OR32_SFXXI: rfwb_op_r <= `OR1200_RFWBOP_NOP;
                    default:            rfwb_op_r <= `OR1200_RFWBOP_ALU;
                endcase

                // branch_op
                branch_op_r <= pre_branch_op;

                // spr_addrimm
                case (id_insn[31:26])
                    `OR1200_OR32_MFSPR: spr_addrimm_r <= id_insn[15:0];
                    default:            spr_addrimm_r <= {id_insn[25:21], id_insn[10:0]};
                endcase

                // sig_syscall
                sig_syscall_r <= (id_insn[31:26] == `OR1200_OR32_SYSTRAP) &&
                                 (id_insn[25:24] == 2'b00);

                // sig_trap
                sig_trap_r <= ((id_insn[31:26] == `OR1200_OR32_SYSTRAP) &&
                               (id_insn[25:24] == 2'b01)) || du_hwbkpt;

                // except_illegal
                case (id_insn[31:26])
                    `OR1200_OR32_J,    `OR1200_OR32_JAL,
                    `OR1200_OR32_BNF,  `OR1200_OR32_BF,
                    `OR1200_OR32_NOP,  `OR1200_OR32_MOVHI,
                    `OR1200_OR32_ADDI, `OR1200_OR32_ADDIC,
                    `OR1200_OR32_ANDI, `OR1200_OR32_ORI,
                    `OR1200_OR32_XORI, `OR1200_OR32_MFSPR,
                    `OR1200_OR32_MTSPR,`OR1200_OR32_SFXXI,
                    `OR1200_OR32_LW,   `OR1200_OR32_LWZ,
                    `OR1200_OR32_LB,   `OR1200_OR32_LBU,
                    `OR1200_OR32_LH,   `OR1200_OR32_LHU,
                    `OR1200_OR32_SW,   `OR1200_OR32_SB,
                    `OR1200_OR32_SH,   `OR1200_OR32_JR,
                    `OR1200_OR32_JALR, `OR1200_OR32_RFE,
                    `OR1200_OR32_ALU,  `OR1200_OR32_SFXX,
                    `OR1200_OR32_SYSTRAP: except_illegal_r <= 1'b0;
`ifdef OR1200_MULT_IMPLEMENTED
                    `OR1200_OR32_MULI:    except_illegal_r <= 1'b0;
`endif
`ifdef OR1200_MAC_IMPLEMENTED
                    `OR1200_OR32_MACI,
                    `OR1200_OR32_MAC:     except_illegal_r <= 1'b0;
`endif
`ifdef OR1200_IMPL_CUS5
                    `OR1200_OR32_CUST5:   except_illegal_r <= 1'b0;
`endif
                    default:              except_illegal_r <= 1'b1;
                endcase
            end
        end
    end

    //--------------------------------------------------------------------------
    // WB-stage instruction + wb_rfaddrw
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_insn_r  <= `OR1200_OR32_NOP_INSN;
            wb_rfaddrw <= 5'd0;
        end else if (!wb_freeze) begin
            wb_insn_r  <= ex_insn_r;
            wb_rfaddrw <= ex_rfaddrw_r;
        end
    end

    //--------------------------------------------------------------------------
    // EX-stage combinational outputs derived from ex_insn_r
    //--------------------------------------------------------------------------

    // branch_addrofs: sign-extend ex_insn[25:0] << 2
    assign branch_addrofs = {{4{ex_insn_r[25]}}, ex_insn_r[25:0]};

    // lsu_addrofs
    assign lsu_addrofs =
        (ex_insn_r[31:26] == `OR1200_OR32_SW ||
         ex_insn_r[31:26] == `OR1200_OR32_SB ||
         ex_insn_r[31:26] == `OR1200_OR32_SH) ?
            {{21{ex_insn_r[25]}}, ex_insn_r[25:21], ex_insn_r[10:0]} :
            {{21{ex_insn_r[15]}}, ex_insn_r[15:11], ex_insn_r[10:0]};

    // cust5 fields from ex_insn
    assign cust5_op   = ex_insn_r[4:0];
    assign cust5_limm = ex_insn_r[10:5];

    // ex_void already assigned
    // force_dslot_fetch hardwired
    assign force_dslot_fetch = 1'b0;

    // no_more_dslot
    assign no_more_dslot =
        ((branch_op_r != `OR1200_BRANCHOP_NOP) && !id_void_w && branch_taken) ||
        (branch_op_r == `OR1200_BRANCHOP_RFE);

    // rfe
    assign rfe = (pre_branch_op == `OR1200_BRANCHOP_RFE) ||
                 (branch_op_r   == `OR1200_BRANCHOP_RFE);

endmodule