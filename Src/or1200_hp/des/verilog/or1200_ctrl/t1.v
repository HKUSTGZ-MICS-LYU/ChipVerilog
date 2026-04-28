`include "timescale.v"
`include "or1200_defines.v"

module or1200_ctrl(
    clk, rst,
    id_freeze, ex_freeze, wb_freeze, flushpipe,
    if_insn, ex_insn, branch_op, branch_taken,
    rf_addra, rf_addrb, rf_rda, rf_rdb,
    alu_op, mac_op, shrot_op, comp_op,
    rf_addrw, rfwb_op, wb_insn,
    simm, branch_addrofs, lsu_addrofs,
    sel_a, sel_b, lsu_op,
    cust5_op, cust5_limm, multicycle, spr_addrimm,
    wbforw_valid, du_hwbkpt,
    sig_syscall, sig_trap, force_dslot_fetch, no_more_dslot,
    ex_void, id_macrc_op, ex_macrc_op, rfe, except_illegal
);

input         clk, rst;
input         id_freeze, ex_freeze, wb_freeze, flushpipe;
input  [31:0] if_insn;
output [31:0] ex_insn;
output [2:0]  branch_op;
input         branch_taken;
output [4:0]  rf_addra, rf_addrb;
output        rf_rda, rf_rdb;
output [3:0]  alu_op;
output [1:0]  mac_op;
output [1:0]  shrot_op;
output [3:0]  comp_op;
output [4:0]  rf_addrw;
output [2:0]  rfwb_op;
output [31:0] wb_insn;
output [31:0] simm;
output [31:2] branch_addrofs;
output [31:0] lsu_addrofs;
output [1:0]  sel_a, sel_b;
output [3:0]  lsu_op;
output [4:0]  cust5_op;
output [5:0]  cust5_limm;
output [1:0]  multicycle;
output [15:0] spr_addrimm;
input         wbforw_valid;
input         du_hwbkpt;
output        sig_syscall, sig_trap;
output        force_dslot_fetch, no_more_dslot;
output        ex_void;
output        id_macrc_op, ex_macrc_op;
output        rfe;
output        except_illegal;

// Pipeline instruction registers
reg [31:0] id_insn;
reg [31:0] ex_insn;
reg [31:0] wb_insn;

// Register-file addresses (combinational from if_insn)
assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda   = if_insn[31];
assign rf_rdb   = if_insn[30];

// Write-back destination
reg [4:0] rf_addrw;
reg [4:0] wb_rfaddrw;

// Pre-decoded branch op (IF stage)
reg [2:0] pre_branch_op;

// Registered control outputs
reg [3:0]  alu_op;
reg [1:0]  mac_op;
reg [1:0]  shrot_op;
reg [3:0]  comp_op;
reg [2:0]  rfwb_op;
reg [3:0]  lsu_op;
reg [2:0]  branch_op;
reg [15:0] spr_addrimm;
reg        sig_syscall;
reg        sig_trap;
reg        except_illegal;
reg        ex_macrc_op;

// Immediate selection
reg sel_imm;
reg imm_signextend;

// Void detection
assign id_void = id_insn[16];
assign ex_void = ex_insn[16];
assign force_dslot_fetch = 1'b0;

// MAC result read
`ifdef OR1200_MAC_IMPLEMENTED
reg id_macrc_op;
assign ex_macrc_op = ex_macrc_op;
`else
assign id_macrc_op = 1'b0;
assign ex_macrc_op = 1'b0;
`endif

// RFE
assign rfe = (pre_branch_op == `OR1200_BRANCHOP_RFE) |
             (branch_op     == `OR1200_BRANCHOP_RFE);

// no_more_dslot
assign no_more_dslot = ((|branch_op) & !id_void & branch_taken) |
                       (branch_op == `OR1200_BRANCHOP_RFE);

// Forwarding selectors
reg [1:0] sel_a, sel_b;

// Immediate extension
wire [31:0] simm;
reg  [31:0] simm_r;
assign simm = simm_r;

// Branch/LSU address offsets (combinational from ex_insn)
assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0], 2'b00};
assign lsu_addrofs =
    (ex_insn[31:26] == `OR1200_OR32_SW) |
    (ex_insn[31:26] == `OR1200_OR32_SB) |
    (ex_insn[31:26] == `OR1200_OR32_SH) ?
    {{16{ex_insn[25]}}, ex_insn[25:21], ex_insn[10:0]} :
    {{16{ex_insn[15]}}, ex_insn[15:11], ex_insn[10:0]};

// cust5
assign cust5_op   = ex_insn[8:4];
assign cust5_limm = ex_insn[10:5];

// Multicycle
assign multicycle =
    (id_insn[31:26] == `OR1200_OR32_ALU) ? id_insn[9:8] : `OR1200_ONE_CYCLE;

// spr_dat_npc placeholder for id_pc tracking (not in this module directly)

//----------------------------------------------------------------------
// IF-stage pre-decode: branch op and sel_imm
//----------------------------------------------------------------------
always @(if_insn or id_freeze) begin
    if (!id_freeze) begin
        // Pre-decode branch op
        case (if_insn[31:26])
            `OR1200_OR32_J:    pre_branch_op = `OR1200_BRANCHOP_NOP;
            `OR1200_OR32_JAL:  pre_branch_op = `OR1200_BRANCHOP_NOP;
            `OR1200_OR32_BNF:  pre_branch_op = `OR1200_BRANCHOP_BNF;
            `OR1200_OR32_BF:   pre_branch_op = `OR1200_BRANCHOP_BF;
            `OR1200_OR32_JR:   pre_branch_op = `OR1200_BRANCHOP_JR;
            `OR1200_OR32_JALR: pre_branch_op = `OR1200_BRANCHOP_JALR;
            `OR1200_OR32_RFE:  pre_branch_op = `OR1200_BRANCHOP_RFE;
            default:           pre_branch_op = `OR1200_BRANCHOP_NOP;
        endcase

        // Immediate selection: 0=reg, 1=immediate
        casex (if_insn[31:26])
            `OR1200_OR32_ALU,
            `OR1200_OR32_SFXX,
            `OR1200_OR32_SW,
            `OR1200_OR32_SB,
            `OR1200_OR32_SH,
            `OR1200_OR32_MTSPR,
            `OR1200_OR32_J,
            `OR1200_OR32_JAL,
            `OR1200_OR32_JR,
            `OR1200_OR32_JALR,
            `OR1200_OR32_BF,
            `OR1200_OR32_BNF,
            `OR1200_OR32_NOP,
            `OR1200_OR32_RFE:
                sel_imm = 1'b0;
`ifdef OR1200_MAC_IMPLEMENTED
            `OR1200_OR32_MACI:
                sel_imm = 1'b0;
`endif
`ifdef OR1200_MULT_IMPLEMENTED
`endif
`ifdef OR1200_IMPL_CUS5
            `OR1200_OR32_CUST5:
                sel_imm = 1'b0;
`endif
            default:
                sel_imm = 1'b1;
        endcase
    end
end

//----------------------------------------------------------------------
// ID stage: instruction latch
//----------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst)
        id_insn <= {`OR1200_OR32_NOP, 26'h041_0000};
    else if (flushpipe)
        id_insn <= {`OR1200_OR32_NOP, 26'h041_0000};
    else if (!id_freeze)
        id_insn <= if_insn;
end

//----------------------------------------------------------------------
// ID stage: immediate generation and forwarding selectors
//----------------------------------------------------------------------
always @(id_insn or sel_imm) begin
    // Immediate sign/zero extension
    case (id_insn[31:26])
        `OR1200_OR32_ADDI,
        `OR1200_OR32_ADDIC,
        `OR1200_OR32_XORI,
        `OR1200_OR32_SFXXI:
            simm_r = {{16{id_insn[15]}}, id_insn[15:0]};
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_OR32_MULI:
            simm_r = {{16{id_insn[15]}}, id_insn[15:0]};
`endif
`ifdef OR1200_MAC_IMPLEMENTED
        `OR1200_OR32_MACI:
            simm_r = {{16{id_insn[15]}}, id_insn[15:0]};
`endif
        default:
            simm_r = {16'h0000, id_insn[15:0]};
    endcase
end

//----------------------------------------------------------------------
// Forwarding sel_a, sel_b
//----------------------------------------------------------------------
always @(id_insn or rf_addrw or wb_rfaddrw or wbforw_valid or sel_imm) begin
    // sel_a
    if (id_insn[20:16] == rf_addrw && |rf_addrw)
        sel_a = `OR1200_SEL_EX_FORW;
    else if (id_insn[20:16] == wb_rfaddrw && |wb_rfaddrw && wbforw_valid)
        sel_a = `OR1200_SEL_WB_FORW;
    else
        sel_a = `OR1200_SEL_RF;

    // sel_b: immediate has highest priority
    if (sel_imm)
        sel_b = `OR1200_SEL_IMM;
    else if (id_insn[15:11] == rf_addrw && |rf_addrw)
        sel_b = `OR1200_SEL_EX_FORW;
    else if (id_insn[15:11] == wb_rfaddrw && |wb_rfaddrw && wbforw_valid)
        sel_b = `OR1200_SEL_WB_FORW;
    else
        sel_b = `OR1200_SEL_RF;
end

//----------------------------------------------------------------------
// EX stage: control registration
//----------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ex_insn       <= {`OR1200_OR32_NOP, 26'h041_0000};
        alu_op        <= `OR1200_ALUOP_NOP;
        mac_op        <= `OR1200_MACOP_NOP;
        shrot_op      <= 2'b00;
        comp_op       <= 4'b0000;
        lsu_op        <= `OR1200_LSUOP_NOP;
        rfwb_op       <= `OR1200_RFWBOP_NOP;
        branch_op     <= `OR1200_BRANCHOP_NOP;
        spr_addrimm   <= 16'h0000;
        sig_syscall   <= 1'b0;
        sig_trap      <= 1'b0;
        except_illegal<= 1'b0;
        rf_addrw      <= 5'h00;
        ex_macrc_op   <= 1'b0;
    end
    else if (flushpipe) begin
        ex_insn       <= {`OR1200_OR32_NOP, 26'h041_0000};
        alu_op        <= `OR1200_ALUOP_NOP;
        mac_op        <= `OR1200_MACOP_NOP;
        shrot_op      <= 2'b00;
        comp_op       <= 4'b0000;
        lsu_op        <= `OR1200_LSUOP_NOP;
        rfwb_op       <= `OR1200_RFWBOP_NOP;
        branch_op     <= `OR1200_BRANCHOP_NOP;
        sig_syscall   <= 1'b0;
        sig_trap      <= 1'b0;
        except_illegal<= 1'b0;
        ex_macrc_op   <= 1'b0;
    end
    else if (!ex_freeze) begin
        if (id_freeze) begin
            // ID frozen, EX advancing: insert bubble
            ex_insn       <= {`OR1200_OR32_NOP, 26'h041_0000};
            alu_op        <= `OR1200_ALUOP_NOP;
            mac_op        <= `OR1200_MACOP_NOP;
            shrot_op      <= 2'b00;
            comp_op       <= 4'b0000;
            lsu_op        <= `OR1200_LSUOP_NOP;
            rfwb_op       <= `OR1200_RFWBOP_NOP;
            branch_op     <= `OR1200_BRANCHOP_NOP;
            sig_syscall   <= 1'b0;
            sig_trap      <= 1'b0;
            except_illegal<= 1'b0;
            ex_macrc_op   <= 1'b0;
        end
        else begin
            ex_insn <= id_insn;
            branch_op <= pre_branch_op;
            ex_macrc_op <= id_macrc_op;

            // rf_addrw
            case (id_insn[31:26])
                `OR1200_OR32_JAL,
                `OR1200_OR32_JALR:
                    rf_addrw <= 5'd9;
                default:
                    rf_addrw <= id_insn[25:21];
            endcase

            // spr_addrimm
            case (id_insn[31:26])
                `OR1200_OR32_MFSPR:
                    spr_addrimm <= id_insn[15:0];
                default:
                    spr_addrimm <= {id_insn[25:21], id_insn[10:0]};
            endcase

            // alu_op
            casex (id_insn[31:26])
                `OR1200_OR32_ADDI:   alu_op <= `OR1200_ALUOP_ADD;
                `OR1200_OR32_ADDIC:  alu_op <= `OR1200_ALUOP_ADDC;
                `OR1200_OR32_ANDI:   alu_op <= `OR1200_ALUOP_AND;
                `OR1200_OR32_ORI:    alu_op <= `OR1200_ALUOP_OR;
                `OR1200_OR32_XORI:   alu_op <= `OR1200_ALUOP_XOR;
                `OR1200_OR32_MOVHI:  alu_op <= `OR1200_ALUOP_MOVHI;
                `OR1200_OR32_MFSPR:  alu_op <= `OR1200_ALUOP_MFSR;
                `OR1200_OR32_MTSPR:  alu_op <= `OR1200_ALUOP_MTSR;
                `OR1200_OR32_ALU:    alu_op <= id_insn[3:0];
                `OR1200_OR32_SFXXI,
                `OR1200_OR32_SFXX:   alu_op <= `OR1200_ALUOP_COMP;
                `OR1200_OR32_CUST5:  alu_op <= `OR1200_ALUOP_CUST5;
                `OR1200_OR32_J,
                `OR1200_OR32_JR:     alu_op <= `OR1200_ALUOP_NOP;
                `OR1200_OR32_JAL,
                `OR1200_OR32_JALR:   alu_op <= `OR1200_ALUOP_MOVHI;
                `OR1200_OR32_LWZ,
                `OR1200_OR32_LBZ,
                `OR1200_OR32_LBS,
                `OR1200_OR32_LHZ,
                `OR1200_OR32_LHS,
                `OR1200_OR32_SW,
                `OR1200_OR32_SB,
                `OR1200_OR32_SH:     alu_op <= `OR1200_ALUOP_ADD;
`ifdef OR1200_MULT_IMPLEMENTED
                `OR1200_OR32_MULI:   alu_op <= `OR1200_ALUOP_MUL;
`endif
                `OR1200_OR32_NOP:    alu_op <= `OR1200_ALUOP_NOP;
                default:             alu_op <= `OR1200_ALUOP_NOP;
            endcase

            // shrot_op
            shrot_op <= id_insn[7:6];

            // comp_op
            comp_op <= id_insn[24:21];

            // lsu_op
            case (id_insn[31:26])
                `OR1200_OR32_LWZ:  lsu_op <= `OR1200_LSUOP_LWZ;
                `OR1200_OR32_LBZ:  lsu_op <= `OR1200_LSUOP_LBZ;
                `OR1200_OR32_LBS:  lsu_op <= `OR1200_LSUOP_LBS;
                `OR1200_OR32_LHZ:  lsu_op <= `OR1200_LSUOP_LHZ;
                `OR1200_OR32_LHS:  lsu_op <= `OR1200_LSUOP_LHS;
                `OR1200_OR32_SW:   lsu_op <= `OR1200_LSUOP_SW;
                `OR1200_OR32_SB:   lsu_op <= `OR1200_LSUOP_SB;
                `OR1200_OR32_SH:   lsu_op <= `OR1200_LSUOP_SH;
                default:           lsu_op <= `OR1200_LSUOP_NOP;
            endcase

            // rfwb_op
            casex (id_insn[31:26])
                `OR1200_OR32_JAL,
                `OR1200_OR32_JALR:  rfwb_op <= `OR1200_RFWBOP_LR;
                `OR1200_OR32_LWZ,
                `OR1200_OR32_LBS,
                `OR1200_OR32_LBZ,
                `OR1200_OR32_LHZ,
                `OR1200_OR32_LHS:   rfwb_op <= `OR1200_RFWBOP_LSU;
                `OR1200_OR32_MFSPR: rfwb_op <= `OR1200_RFWBOP_MFSR;
                `OR1200_OR32_SW,
                `OR1200_OR32_SB,
                `OR1200_OR32_SH,
                `OR1200_OR32_MTSPR,
                `OR1200_OR32_J,
                `OR1200_OR32_JR,
                `OR1200_OR32_BF,
                `OR1200_OR32_BNF,
                `OR1200_OR32_NOP,
                `OR1200_OR32_RFE,
                `OR1200_OR32_SFXX,
                `OR1200_OR32_SFXXI: rfwb_op <= `OR1200_RFWBOP_NOP;
                default:            rfwb_op <= `OR1200_RFWBOP_ALU;
            endcase

            // mac_op
`ifdef OR1200_MAC_IMPLEMENTED
            case (id_insn[31:26])
                `OR1200_OR32_MACI: mac_op <= `OR1200_MACOP_MACI;
                `OR1200_OR32_MACMSB:
                    case (id_insn[3:0])
                        4'h1: mac_op <= `OR1200_MACOP_MAC;
                        4'h2: mac_op <= `OR1200_MACOP_MSB;
                        default: mac_op <= `OR1200_MACOP_NOP;
                    endcase
                default: mac_op <= `OR1200_MACOP_NOP;
            endcase
`else
            mac_op <= `OR1200_MACOP_NOP;
`endif

            // sig_syscall, sig_trap, except_illegal
            sig_syscall <= (id_insn[31:26] == `OR1200_OR32_XSYNC) &
                           (id_insn[25:24] == 2'b00);
            sig_trap    <= ((id_insn[31:26] == `OR1200_OR32_XSYNC) &
                           (id_insn[25:24] == 2'b10)) | du_hwbkpt;

            casex (id_insn[31:26])
                `OR1200_OR32_J,     `OR1200_OR32_JAL,
                `OR1200_OR32_BNF,   `OR1200_OR32_BF,
                `OR1200_OR32_RFE,   `OR1200_OR32_JR,
                `OR1200_OR32_JALR,  `OR1200_OR32_MOVHI,
                `OR1200_OR32_NOP,   `OR1200_OR32_ADDI,
                `OR1200_OR32_ADDIC, `OR1200_OR32_ANDI,
                `OR1200_OR32_ORI,   `OR1200_OR32_XORI,
                `OR1200_OR32_MFSPR, `OR1200_OR32_MTSPR,
                `OR1200_OR32_ALU,   `OR1200_OR32_SFXX,
                `OR1200_OR32_SFXXI, `OR1200_OR32_XSYNC,
                `OR1200_OR32_LWZ,   `OR1200_OR32_LBZ,
                `OR1200_OR32_LBS,   `OR1200_OR32_LHZ,
                `OR1200_OR32_LHS,   `OR1200_OR32_SW,
                `OR1200_OR32_SB,    `OR1200_OR32_SH:
                    except_illegal <= 1'b0;
`ifdef OR1200_MULT_IMPLEMENTED
                `OR1200_OR32_MULI:  except_illegal <= 1'b0;
`endif
`ifdef OR1200_MAC_IMPLEMENTED
                `OR1200_OR32_MACI,
                `OR1200_OR32_MACMSB: except_illegal <= 1'b0;
`endif
`ifdef OR1200_IMPL_CUS5
                `OR1200_OR32_CUST5: except_illegal <= 1'b0;
`endif
                default:            except_illegal <= 1'b1;
            endcase
        end
    end
end

//----------------------------------------------------------------------
// id_macrc_op
//----------------------------------------------------------------------
`ifdef OR1200_MAC_IMPLEMENTED
always @(posedge clk or posedge rst) begin
    if (rst)
        id_macrc_op <= 1'b0;
    else if (!id_freeze)
        id_macrc_op <= (if_insn[31:26] == `OR1200_OR32_MOVHI) & if_insn[16];
end
`else
assign id_macrc_op = 1'b0;
`endif

//----------------------------------------------------------------------
// WB stage: instruction and address tracking
//----------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        wb_insn    <= {`OR1200_OR32_NOP, 26'h041_0000};
        wb_rfaddrw <= 5'h00;
    end
    else if (!wb_freeze) begin
        wb_insn    <= ex_insn;
        wb_rfaddrw <= rf_addrw;
    end
end

endmodule