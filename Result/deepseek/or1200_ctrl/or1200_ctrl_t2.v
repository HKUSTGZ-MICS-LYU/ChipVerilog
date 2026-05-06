// or1200_ctrl.v
// OR1200 control unit

`include "or1200_defines.v"

module or1200_ctrl (
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

    // ========================================================================
    // Local parameters
    // ========================================================================
    localparam OR1200_NOP = 32'h1500_0000;

    // ========================================================================
    // Internal registers and wires
    // ========================================================================
    reg [31:0] id_insn;
    reg [31:0] ex_insn;
    reg [31:0] wb_insn;

    reg [4:0] wb_rfaddrw;
    wire [4:0] ex_rfaddrw;

    wire id_void;
    wire ex_void;

    reg [3:0] alu_op;
    reg [1:0] mac_op;
    reg [1:0] shrot_op;
    reg [3:0] comp_op;
    reg [2:0] rfwb_op;
    reg [2:0] branch_op;
    reg [3:0] lsu_op;
    reg sig_syscall;
    reg sig_trap;
    reg except_illegal;
    reg [15:0] spr_addrimm;

    wire [2:0] pre_branch_op;
    wire pre_rfe;
    wire id_rfe;

    wire [1:0] multicycle;

    wire [31:0] simm;
    wire imm_signextend;

    wire [31:2] branch_addrofs;

    wire [31:0] lsu_addrofs;

    wire [1:0] sel_a;
    wire [1:0] sel_b;
    wire sel_imm;

    wire [4:0] rf_addra;
    wire [4:0] rf_addrb;
    wire rf_rda;
    wire rf_rdb;

    wire [4:0] rf_addrw;

    wire id_macrc_op;
    reg ex_macrc_op;

    wire [4:0] cust5_op;
    wire [5:0] cust5_limm;

    wire force_dslot_fetch;
    wire no_more_dslot;
    wire rfe;

    // ========================================================================
    // Pipeline void / NOP detection
    // ========================================================================
    assign id_void = id_insn[16];
    assign ex_void = ex_insn[16];

    // ========================================================================
    // Register file source addresses and read enables
    // ========================================================================
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda   = if_insn[31];
    assign rf_rdb   = if_insn[30];

    // ========================================================================
    // ID-stage instruction capture
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            id_insn <= OR1200_NOP;
        else if (flushpipe)
            id_insn <= OR1200_NOP;
        else if (!id_freeze)
            id_insn <= if_insn;
    end

    // ========================================================================
    // EX-stage instruction capture
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            ex_insn <= OR1200_NOP;
        else if (flushpipe)
            ex_insn <= OR1200_NOP;
        else if (!ex_freeze) begin
            if (id_freeze)
                ex_insn <= OR1200_NOP;
            else
                ex_insn <= id_insn;
        end
    end

    // ========================================================================
    // WB-stage instruction capture
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            wb_insn <= OR1200_NOP;
        else if (flushpipe)
            wb_insn <= OR1200_NOP;
        else if (!wb_freeze)
            wb_insn <= ex_insn;
    end

    // ========================================================================
    // WB register address for forwarding
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst)
            wb_rfaddrw <= 5'd0;
        else if (flushpipe)
            wb_rfaddrw <= 5'd0;
        else if (!ex_freeze)
            wb_rfaddrw <= ex_rfaddrw;
    end

    // ========================================================================
    // Immediate selection logic
    // ========================================================================
    assign sel_imm = !(
        (if_insn[31:26] == `OR1200_OR32_ALU)  ||
        (if_insn[31:26] == `OR1200_OR32_BF)   ||
        (if_insn[31:26] == `OR1200_OR32_BNF)  ||
        (if_insn[31:26] == `OR1200_OR32_JP)   ||
        (if_insn[31:26] == `OR1200_OR32_JR)   ||
        (if_insn[31:26] == `OR1200_OR32_JPBAL)||
        (if_insn[31:26] == `OR1200_OR32_JRBAL)||
        (if_insn[31:26] == `OR1200_OR32_MFSPR)||
        (if_insn[31:26] == `OR1200_OR32_MTSPR)||
        (if_insn[31:26] == `OR1200_OR32_STORE)||
        (if_insn[31:26] == `OR1200_OR32_SFXX) ||
        (if_insn[31:26] == `OR1200_OR32_CUST5)||
        (if_insn[31:26] == `OR1200_OR32_NOP)
    );

    // ========================================================================
    // Forwarding selectors for A and B operands
    // ========================================================================
    wire ex_forw_a, wb_forw_a;
    wire ex_forw_b, wb_forw_b;

    assign ex_forw_a = (id_insn[20:16] == ex_rfaddrw) && (ex_rfaddrw != 5'd0) && !ex_void;
    assign wb_forw_a = (id_insn[20:16] == wb_rfaddrw) && (wb_rfaddrw != 5'd0) && wbforw_valid;

    assign ex_forw_b = (id_insn[15:11] == ex_rfaddrw) && (ex_rfaddrw != 5'd0) && !ex_void;
    assign wb_forw_b = (id_insn[15:11] == wb_rfaddrw) && (wb_rfaddrw != 5'd0) && wbforw_valid;

    assign sel_a = ex_forw_a ? 2'b10 : (wb_forw_a ? 2'b01 : 2'b00);
    assign sel_b = sel_imm ? 2'b11 : (ex_forw_b ? 2'b10 : (wb_forw_b ? 2'b01 : 2'b00));

    // ========================================================================
    // Immediate generation
    // ========================================================================
    assign imm_signextend =
        (id_insn[31:26] == `OR1200_OR32_ADDI)   ||
        (id_insn[31:26] == `OR1200_OR32_ADDIC)  ||
        (id_insn[31:26] == `OR1200_OR32_XORI)   ||
        (id_insn[31:26] == `OR1200_OR32_MULI)   ||
        (id_insn[31:26] == `OR1200_OR32_MACI)   ||
        (id_insn[31:26] == `OR1200_OR32_SFXXI);

    assign simm = imm_signextend ?
        {{16{id_insn[15]}}, id_insn[15:0]} :
        {16'd0, id_insn[15:0]};

    // ========================================================================
    // Branch offset generation (EX stage)
    // ========================================================================
    assign branch_addrofs = {{6{ex_insn[25]}}, ex_insn[25:0]};

    // ========================================================================
    // LSU address offset generation (EX stage)
    // ========================================================================
    assign lsu_addrofs =
        (ex_insn[31:26] == `OR1200_OR32_STORE) ?
            {{16{ex_insn[25]}}, ex_insn[25:21], ex_insn[10:0]} :
            {{16{ex_insn[15]}}, ex_insn[15:11], ex_insn[10:0]};

    // ========================================================================
    // Write-back address generation
    // ========================================================================
    assign ex_rfaddrw =
        ((pre_branch_op == `OR1200_BRANCH_OP_JR) || (pre_branch_op == `OR1200_BRANCH_OP_BAL)) ?
            5'd9 : id_insn[25:21];

    assign rf_addrw = ex_rfaddrw;

    // ========================================================================
    // Multicycle determination
    // ========================================================================
    assign multicycle =
        (id_insn[31:26] == `OR1200_OR32_ALU) ?
            id_insn[9:8] :
            `OR1200_ONE_CYCLE;

    // ========================================================================
    // Pre-branch decode (ID stage)
    // ========================================================================
    reg [2:0] pre_branch_op;

    always @(*) begin
        if (id_freeze)
            pre_branch_op = `OR1200_BRANCH_OP_NOP;
        else begin
            case (if_insn[31:26])
                `OR1200_OR32_BF:   pre_branch_op = `OR1200_BRANCH_OP_BF;
                `OR1200_OR32_BNF:  pre_branch_op = `OR1200_BRANCH_OP_BNF;
                `OR1200_OR32_JP:   pre_branch_op = `OR1200_BRANCH_OP_J;
                `OR1200_OR32_JR:   pre_branch_op = `OR1200_BRANCH_OP_JR;
                `OR1200_OR32_JPBAL:pre_branch_op = `OR1200_BRANCH_OP_BAL;
                `OR1200_OR32_JRBAL:pre_branch_op = `OR1200_BRANCH_OP_JR;
                `OR1200_OR32_RFE:  pre_branch_op = `OR1200_BRANCH_OP_RFE;
                default:           pre_branch_op = `OR1200_BRANCH_OP_NOP;
            endcase
        end
    end

    assign pre_rfe = (pre_branch_op == `OR1200_BRANCH_OP_RFE);
    assign id_rfe  = (if_insn[31:26] == `OR1200_OR32_RFE);

    // ========================================================================
    // EX-stage control signal capture
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_op         <= `OR1200_ALU_OP_NOP;
            mac_op         <= `OR1200_MAC_OP_NOP;
            shrot_op       <= `OR1200_SHROT_OP_NOP;
            comp_op        <= `OR1200_COMP_OP_NOP;
            rfwb_op        <= `OR1200_RFWB_OP_NOP;
            branch_op      <= `OR1200_BRANCH_OP_NOP;
            lsu_op         <= `OR1200_LSU_OP_NOP;
            sig_syscall    <= 1'b0;
            sig_trap       <= 1'b0;
            except_illegal <= 1'b0;
            spr_addrimm    <= 16'd0;
            ex_macrc_op    <= 1'b0;
        end else if (flushpipe) begin
            alu_op         <= `OR1200_ALU_OP_NOP;
            mac_op         <= `OR1200_MAC_OP_NOP;
            shrot_op       <= `OR1200_SHROT_OP_NOP;
            comp_op        <= `OR1200_COMP_OP_NOP;
            rfwb_op        <= `OR1200_RFWB_OP_NOP;
            branch_op      <= `OR1200_BRANCH_OP_NOP;
            lsu_op         <= `OR1200_LSU_OP_NOP;
            sig_syscall    <= 1'b0;
            sig_trap       <= 1'b0;
            except_illegal <= 1'b0;
            spr_addrimm    <= 16'd0;
            ex_macrc_op    <= 1'b0;
        end else if (!ex_freeze) begin
            if (id_freeze) begin
                alu_op         <= `OR1200_ALU_OP_NOP;
                mac_op         <= `OR1200_MAC_OP_NOP;
                shrot_op       <= `OR1200_SHROT_OP_NOP;
                comp_op        <= `OR1200_COMP_OP_NOP;
                rfwb_op        <= `OR1200_RFWB_OP_NOP;
                branch_op      <= `OR1200_BRANCH_OP_NOP;
                lsu_op         <= `OR1200_LSU_OP_NOP;
                sig_syscall    <= 1'b0;
                sig_trap       <= 1'b0;
                except_illegal <= 1'b0;
                spr_addrimm    <= 16'd0;
                ex_macrc_op    <= 1'b0;
            end else begin
                // ALU operation decode
                case (id_insn[31:26])
                    `OR1200_OR32_ALU: begin
                        case (id_insn[3:0])
                            4'b0000: alu_op <= `OR1200_ALU_OP_ADD;
                            4'b0001: alu_op <= `OR1200_ALU_OP_SUB;
                            4'b0010: alu_op <= `OR1200_ALU_OP_AND;
                            4'b0011: alu_op <= `OR1200_ALU_OP_OR;
                            4'b0100: alu_op <= `OR1200_ALU_OP_XOR;
                            4'b0101: alu_op <= `OR1200_ALU_OP_MOVHI;
                            4'b0110: alu_op <= `OR1200_ALU_OP_SHROT;
                            4'b0111: alu_op <= `OR1200_ALU_OP_COMP;
                            default: alu_op <= `OR1200_ALU_OP_NOP;
                        endcase
                    end
                    `OR1200_OR32_ADDI:    alu_op <= `OR1200_ALU_OP_ADDI;
                    `OR1200_OR32_ADDIC:   alu_op <= `OR1200_ALU_OP_ADDIC;
                    `OR1200_OR32_ANDI:    alu_op <= `OR1200_ALU_OP_ANDI;
                    `OR1200_OR32_ORI:     alu_op <= `OR1200_ALU_OP_ORI;
                    `OR1200_OR32_XORI:    alu_op <= `OR1200_ALU_OP_XORI;
                    `OR1200_OR32_MOVHI:   alu_op <= `OR1200_ALU_OP_MOVHI;
                    `OR1200_OR32_MFSPR:   alu_op <= `OR1200_ALU_OP_MFSPR;
                    `OR1200_OR32_MTSPR:   alu_op <= `OR1200_ALU_OP_MTSPR;
                    `OR1200_OR32_CUST5:   alu_op <= `OR1200_ALU_OP_CUST5;
                    default:              alu_op <= `OR1200_ALU_OP_NOP;
                endcase

                // Shift/rotate operation
                if (id_insn[31:26] == `OR1200_OR32_ALU && id_insn[3:0] == 4'b0110)
                    shrot_op <= id_insn[7:6];
                else
                    shrot_op <= `OR1200_SHROT_OP_NOP;

                // Compare operation
                if (id_insn[31:26] == `OR1200_OR32_ALU && id_insn[3:0] == 4'b0111)
                    comp_op <= id_insn[24:21];
                else if (id_insn[31:26] == `OR1200_OR32_SFXX)
                    comp_op <= id_insn[24:21];
                else if (id_insn[31:26] == `OR1200_OR32_SFXXI)
                    comp_op <= id_insn[24:21];
                else
                    comp_op <= `OR1200_COMP_OP_NOP;

                // MAC operation decode
`ifdef OR1200_MAC_IMPLEMENTED
                case (id_insn[31:26])
                    `OR1200_OR32_MAC:  mac_op <= `OR1200_MAC_OP_MAC;
                    `OR1200_OR32_MSB:  mac_op <= `OR1200_MAC_OP_MSB;
                    `OR1200_OR32_MACI: mac_op <= `OR1200_MAC_OP_MACI;
                    default:            mac_op <= `OR1200_MAC_OP_NOP;
                endcase
`else
                mac_op <= `OR1200_MAC_OP_NOP;
`endif

                // LSU operation decode
                case (id_insn[31:26])
                    `OR1200_OR32_LOAD: begin
                        case (id_insn[1:0])
                            2'b00: lsu_op <= `OR1200_LSU_OP_LW;
                            2'b01: lsu_op <= `OR1200_LSU_OP_LB;
                            2'b10: lsu_op <= `OR1200_LSU_OP_LH;
                            default: lsu_op <= `OR1200_LSU_OP_NOP;
                        endcase
                    end
                    `OR1200_OR32_STORE: begin
                        case (id_insn[1:0])
                            2'b00: lsu_op <= `OR1200_LSU_OP_SW;
                            2'b01: lsu_op <= `OR1200_LSU_OP_SB;
                            2'b10: lsu_op <= `OR1200_LSU_OP_SH;
                            default: lsu_op <= `OR1200_LSU_OP_NOP;
                        endcase
                    end
                    default: lsu_op <= `OR1200_LSU_OP_NOP;
                endcase

                // RF write-back operation
                case (id_insn[31:26])
                    `OR1200_OR32_ALU,
                    `OR1200_OR32_ADDI,
                    `OR1200_OR32_ADDIC,
                    `OR1200_OR32_ANDI,
                    `OR1200_OR32_ORI,
                    `OR1200_OR32_XORI,
                    `OR1200_OR32_MOVHI,
                    `OR1200_OR32_MFSPR,
                    `OR1200_OR32_LOAD,
                    `OR1200_OR32_MULI,
                    `OR1200_OR32_MACI,
                    `OR1200_OR32_MAC,
                    `OR1200_OR32_MSB,
                    `OR1200_OR32_CUST5:
                        rfwb_op <= `OR1200_RFWB_OP_ALU;
                    `OR1200_OR32_JPBAL,
                    `OR1200_OR32_JRBAL:
                        rfwb_op <= `OR1200_RFWB_OP_LR;
                    default:
                        rfwb_op <= `OR1200_RFWB_OP_NOP;
                endcase

                // Branch operation
                branch_op <= pre_branch_op;

                // SPR immediate address
                if (id_insn[31:26] == `OR1200_OR32_MFSPR)
                    spr_addrimm <= id_insn[15:0];
                else if (id_insn[31:26] == `OR1200_OR32_MTSPR)
                    spr_addrimm <= {id_insn[25:21], id_insn[10:0]};
                else
                    spr_addrimm <= 16'd0;

                // Exceptions
                sig_syscall <= (id_insn[31:26] == `OR1200_OR32_SYS);
                sig_trap    <= (id_insn[31:26] == `OR1200_OR32_TRAP) || du_hwbkpt;

                // Illegal instruction detection
                except_illegal <= 1'b0;
                case (id_insn[31:26])
                    `OR1200_OR32_ALU,
                    `OR1200_OR32_ADDI,
                    `OR1200_OR32_ADDIC,
                    `OR1200_OR32_ANDI,
                    `OR1200_OR32_ORI,
                    `OR1200_OR32_XORI,
                    `OR1200_OR32_MOVHI,
                    `OR1200_OR32_MFSPR,
                    `OR1200_OR32_MTSPR,
                    `OR1200_OR32_LOAD,
                    `OR1200_OR32_STORE,
                    `OR1200_OR32_BF,
                    `OR1200_OR32_BNF,
                    `OR1200_OR32_JP,
                    `OR1200_OR32_JR,
                    `OR1200_OR32_JPBAL,
                    `OR1200_OR32_JRBAL,
                    `OR1200_OR32_SFXX,
                    `OR1200_OR32_SFXXI,
                    `OR1200_OR32_NOP,
                    `OR1200_OR32_SYS,
                    `OR1200_OR32_TRAP,
                    `OR1200_OR32_RFE: begin
                        except_illegal <= 1'b0;
                    end
`ifdef OR1200_MULT_IMPLEMENTED
                    `OR1200_OR32_MULI: except_illegal <= 1'b0;
`else
                    `OR1200_OR32_MULI: except_illegal <= 1'b1;
`endif
`ifdef OR1200_MAC_IMPLEMENTED
                    `OR1200_OR32_MAC,
                    `OR1200_OR32_MSB,
                    `OR1200_OR32_MACI: except_illegal <= 1'b0;
`else
                    `OR1200_OR32_MAC,
                    `OR1200_OR32_MSB,
                    `OR1200_OR32_MACI: except_illegal <= 1'b1;
`endif
`ifdef OR1200_CUST5_IMPLEMENTED
                    `OR1200_OR32_CUST5: except_illegal <= 1'b0;
`else
                    `OR1200_OR32_CUST5: except_illegal <= 1'b1;
`endif
                    default: except_illegal <= 1'b1;
                endcase

                // MAC result read in EX stage
`ifdef OR1200_MAC_IMPLEMENTED
                ex_macrc_op <= (id_insn[31:26] == `OR1200_OR32_MACRC);
`else
                ex_macrc_op <= 1'b0;
`endif
            end
        end
    end

    // ========================================================================
    // Custom instruction fields (EX stage)
    // ========================================================================
    assign cust5_op   = ex_insn[4:0];
    assign cust5_limm = ex_insn[5:0];

    // ========================================================================
    // MAC result read in ID stage
    // ========================================================================
`ifdef OR1200_MAC_IMPLEMENTED
    assign id_macrc_op = (id_insn[31:26] == `OR1200_OR32_MACRC);
`else
    assign id_macrc_op = 1'b0;
`endif

    // ========================================================================
    // RFE control
    // ========================================================================
    assign rfe = pre_rfe | (branch_op == `OR1200_BRANCH_OP_RFE);

    // ========================================================================
    // Delay-slot and force_dslot_fetch control
    // ========================================================================
    assign no_more_dslot = ((pre_branch_op != `OR1200_BRANCH_OP_NOP) && !id_void && branch_taken) ||
                           (pre_branch_op == `OR1200_BRANCH_OP_RFE);

    assign force_dslot_fetch = 1'b0;

endmodule
