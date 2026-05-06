module or1200_ctrl(
    input clk,
    input rst,
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

parameter FEATURE_MAC   = 1'b1;
parameter FEATURE_MUL   = 1'b1;
parameter FEATURE_CUST5 = 1'b1;

localparam [31:0] OR1200_NOP_INSN = 32'h1401_0000;

localparam [5:0] OR32_J      = 6'b000000;
localparam [5:0] OR32_JAL    = 6'b000001;
localparam [5:0] OR32_BNF    = 6'b000011;
localparam [5:0] OR32_BF     = 6'b000100;
localparam [5:0] OR32_NOP    = 6'b000101;
localparam [5:0] OR32_MOVHI  = 6'b000110;
localparam [5:0] OR32_MISC   = 6'b001000;
localparam [5:0] OR32_RFE    = 6'b001001;
localparam [5:0] OR32_JR     = 6'b010001;
localparam [5:0] OR32_JALR   = 6'b010010;
localparam [5:0] OR32_MACI   = 6'b010011;
localparam [5:0] OR32_LWZ    = 6'b100001;
localparam [5:0] OR32_LWS    = 6'b100010;
localparam [5:0] OR32_LBZ    = 6'b100011;
localparam [5:0] OR32_LBS    = 6'b100100;
localparam [5:0] OR32_LHZ    = 6'b100101;
localparam [5:0] OR32_LHS    = 6'b100110;
localparam [5:0] OR32_ADDI   = 6'b100111;
localparam [5:0] OR32_ADDIC  = 6'b101000;
localparam [5:0] OR32_ANDI   = 6'b101001;
localparam [5:0] OR32_ORI    = 6'b101010;
localparam [5:0] OR32_XORI   = 6'b101011;
localparam [5:0] OR32_MULI   = 6'b101100;
localparam [5:0] OR32_MFSPR  = 6'b101101;
localparam [5:0] OR32_SHRTI  = 6'b101110;
localparam [5:0] OR32_SFXXI  = 6'b101111;
localparam [5:0] OR32_MTSPR  = 6'b110000;
localparam [5:0] OR32_MACMSB = 6'b110001;
localparam [5:0] OR32_SW     = 6'b110101;
localparam [5:0] OR32_SB     = 6'b110110;
localparam [5:0] OR32_SH     = 6'b110111;
localparam [5:0] OR32_ALU    = 6'b111000;
localparam [5:0] OR32_SFXX   = 6'b111001;
localparam [5:0] OR32_CUST5  = 6'b111100;
localparam [5:0] OR32_MACRC  = 6'b111101;

localparam [2:0] BRANCHOP_NOP = 3'd0;
localparam [2:0] BRANCHOP_J   = 3'd1;
localparam [2:0] BRANCHOP_JR  = 3'd2;
localparam [2:0] BRANCHOP_BF  = 3'd3;
localparam [2:0] BRANCHOP_BNF = 3'd4;
localparam [2:0] BRANCHOP_RFE = 3'd5;
localparam [2:0] BRANCHOP_BAL = 3'd6;

localparam [3:0] ALUOP_NOP    = 4'd0;
localparam [3:0] ALUOP_IMM    = 4'd1;
localparam [3:0] ALUOP_MOVHI  = 4'd2;
localparam [3:0] ALUOP_ALU    = 4'd3;
localparam [3:0] ALUOP_SPR    = 4'd4;
localparam [3:0] ALUOP_SHIFTI = 4'd5;
localparam [3:0] ALUOP_SFXX   = 4'd6;
localparam [3:0] ALUOP_CUST5  = 4'd7;

localparam [1:0] MACOP_NOP = 2'd0;
localparam [1:0] MACOP_MAC = 2'd1;
localparam [1:0] MACOP_MSB = 2'd2;
localparam [1:0] MACOP_MACI = 2'd3;

localparam [2:0] RFWBOP_NONE = 3'd0;
localparam [2:0] RFWBOP_ALU  = 3'd1;
localparam [2:0] RFWBOP_LSU  = 3'd2;
localparam [2:0] RFWBOP_SPR  = 3'd3;
localparam [2:0] RFWBOP_LR   = 3'd4;

localparam [3:0] LSUOP_NOP = 4'd0;
localparam [3:0] LSUOP_LWZ = 4'd1;
localparam [3:0] LSUOP_LWS = 4'd2;
localparam [3:0] LSUOP_LBZ = 4'd3;
localparam [3:0] LSUOP_LBS = 4'd4;
localparam [3:0] LSUOP_LHZ = 4'd5;
localparam [3:0] LSUOP_LHS = 4'd6;
localparam [3:0] LSUOP_SW  = 4'd7;
localparam [3:0] LSUOP_SB  = 4'd8;
localparam [3:0] LSUOP_SH  = 4'd9;

localparam [1:0] SEL_RF  = 2'd0;
localparam [1:0] SEL_EX  = 2'd1;
localparam [1:0] SEL_WB  = 2'd2;
localparam [1:0] SEL_IMM = 2'd3;

localparam [1:0] OR1200_ONE_CYCLE = 2'b00;

reg [31:0] id_insn;
reg [31:0] ex_insn_r;
reg [31:0] wb_insn_r;
reg [2:0] branch_op_r;
reg [4:0] rf_addrw_r;
reg [4:0] wb_rfaddrw;
reg [3:0] alu_op_r;
reg [1:0] mac_op_r;
reg [1:0] shrot_op_r;
reg [3:0] comp_op_r;
reg [2:0] rfwb_op_r;
reg [3:0] lsu_op_r;
reg [15:0] spr_addrimm_r;
reg sig_syscall_r;
reg sig_trap_r;
reg ex_macrc_op_r;
reg except_illegal_r;
reg [2:0] pre_branch_op;
reg sel_imm;
reg imm_signextend;
reg [1:0] sel_a_r;
reg [1:0] sel_b_r;
reg [1:0] multicycle_r;
reg id_macrc_op_r;

wire [5:0] if_op = if_insn[31:26];
wire [5:0] id_op = id_insn[31:26];
wire [5:0] ex_op = ex_insn_r[31:26];

wire id_void_w = id_insn[16];
wire ex_void_w = ex_insn_r[16];
wire ex_rfwb_valid = (rfwb_op_r != RFWBOP_NONE);

assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda = if_insn[31];
assign rf_rdb = if_insn[30];

assign ex_insn = ex_insn_r;
assign wb_insn = wb_insn_r;
assign branch_op = branch_op_r;
assign rf_addrw = rf_addrw_r;
assign alu_op = alu_op_r;
assign mac_op = mac_op_r;
assign shrot_op = shrot_op_r;
assign comp_op = comp_op_r;
assign rfwb_op = rfwb_op_r;
assign lsu_op = lsu_op_r;
assign spr_addrimm = spr_addrimm_r;
assign sig_syscall = sig_syscall_r;
assign sig_trap = sig_trap_r | du_hwbkpt;
assign ex_macrc_op = ex_macrc_op_r;
assign except_illegal = except_illegal_r;
assign ex_void = ex_void_w;
assign id_macrc_op = id_macrc_op_r;
assign sel_a = sel_a_r;
assign sel_b = sel_b_r;
assign multicycle = multicycle_r;
assign force_dslot_fetch = 1'b0;
assign rfe = (pre_branch_op == BRANCHOP_RFE) | (branch_op_r == BRANCHOP_RFE);

assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'h0000, id_insn[15:0]};
assign branch_addrofs = {{4{ex_insn_r[25]}}, ex_insn_r[25:0]};
assign lsu_addrofs =
    ((ex_op == OR32_SW) || (ex_op == OR32_SB) || (ex_op == OR32_SH)) ?
    {{16{ex_insn_r[25]}}, ex_insn_r[25:21], ex_insn_r[10:0]} :
    {{16{ex_insn_r[15]}}, ex_insn_r[15:11], ex_insn_r[10:0]};
assign cust5_op = ex_insn_r[4:0];
assign cust5_limm = ex_insn_r[10:5];

assign no_more_dslot = (((branch_op_r != BRANCHOP_NOP) && !id_void_w && branch_taken) ||
                        (branch_op_r == BRANCHOP_RFE));

always @* begin
    case (id_op)
        OR32_ADDI, OR32_ADDIC, OR32_XORI, OR32_SFXXI: imm_signextend = 1'b1;
        OR32_MULI: imm_signextend = FEATURE_MUL;
        OR32_MACI: imm_signextend = FEATURE_MAC;
        default: imm_signextend = 1'b0;
    endcase
end

always @* begin
    sel_a_r = SEL_RF;
    if (ex_rfwb_valid && (rf_addrw_r != 5'd0) && (id_insn[20:16] == rf_addrw_r))
        sel_a_r = SEL_EX;
    else if (wbforw_valid && (wb_rfaddrw != 5'd0) && (id_insn[20:16] == wb_rfaddrw))
        sel_a_r = SEL_WB;

    if (sel_imm) begin
        sel_b_r = SEL_IMM;
    end else begin
        sel_b_r = SEL_RF;
        if (ex_rfwb_valid && (rf_addrw_r != 5'd0) && (id_insn[15:11] == rf_addrw_r))
            sel_b_r = SEL_EX;
        else if (wbforw_valid && (wb_rfaddrw != 5'd0) && (id_insn[15:11] == wb_rfaddrw))
            sel_b_r = SEL_WB;
    end
end

always @* begin
    if (id_op == OR32_ALU)
        multicycle_r = id_insn[9:8];
    else
        multicycle_r = OR1200_ONE_CYCLE;
end

always @* begin
    id_macrc_op_r = FEATURE_MAC && (id_op == OR32_MACRC);
end

always @* begin
    case (id_op)
        OR32_LWZ:   alu_op_r = ALUOP_IMM;
        OR32_LWS:   alu_op_r = ALUOP_IMM;
        OR32_LBZ:   alu_op_r = ALUOP_IMM;
        OR32_LBS:   alu_op_r = ALUOP_IMM;
        OR32_LHZ:   alu_op_r = ALUOP_IMM;
        OR32_LHS:   alu_op_r = ALUOP_IMM;
        OR32_SW:    alu_op_r = ALUOP_IMM;
        OR32_SB:    alu_op_r = ALUOP_IMM;
        OR32_SH:    alu_op_r = ALUOP_IMM;
        OR32_ADDI:  alu_op_r = ALUOP_IMM;
        OR32_ADDIC: alu_op_r = ALUOP_IMM;
        OR32_ANDI:  alu_op_r = ALUOP_IMM;
        OR32_ORI:   alu_op_r = ALUOP_IMM;
        OR32_XORI:  alu_op_r = ALUOP_IMM;
        OR32_MULI:  alu_op_r = ALUOP_IMM;
        OR32_MACI:  alu_op_r = ALUOP_IMM;
        OR32_MOVHI: alu_op_r = ALUOP_MOVHI;
        OR32_MFSPR: alu_op_r = ALUOP_SPR;
        OR32_MTSPR: alu_op_r = ALUOP_SPR;
        OR32_SHRTI: alu_op_r = ALUOP_SHIFTI;
        OR32_ALU:   alu_op_r = ALUOP_ALU;
        OR32_SFXX:  alu_op_r = ALUOP_SFXX;
        OR32_SFXXI: alu_op_r = ALUOP_SFXX;
        OR32_CUST5: alu_op_r = FEATURE_CUST5 ? ALUOP_CUST5 : ALUOP_NOP;
        default:    alu_op_r = ALUOP_NOP;
    endcase
end

wire [1:0] mac_op_d = (!FEATURE_MAC) ? MACOP_NOP :
                      (id_op == OR32_MACI)   ? MACOP_MACI :
                      (id_op == OR32_MACMSB) ? (id_insn[2] ? MACOP_MSB : MACOP_MAC) :
                      MACOP_NOP;

wire [3:0] lsu_op_d = (id_op == OR32_LWZ) ? LSUOP_LWZ :
                      (id_op == OR32_LWS) ? LSUOP_LWS :
                      (id_op == OR32_LBZ) ? LSUOP_LBZ :
                      (id_op == OR32_LBS) ? LSUOP_LBS :
                      (id_op == OR32_LHZ) ? LSUOP_LHZ :
                      (id_op == OR32_LHS) ? LSUOP_LHS :
                      (id_op == OR32_SW)  ? LSUOP_SW  :
                      (id_op == OR32_SB)  ? LSUOP_SB  :
                      (id_op == OR32_SH)  ? LSUOP_SH  :
                      LSUOP_NOP;

wire [2:0] rfwb_op_d = ((id_op == OR32_LWZ) || (id_op == OR32_LWS) || (id_op == OR32_LBZ) ||
                        (id_op == OR32_LBS) || (id_op == OR32_LHZ) || (id_op == OR32_LHS)) ? RFWBOP_LSU :
                       (id_op == OR32_MFSPR) ? RFWBOP_SPR :
                       ((id_op == OR32_JAL) || (id_op == OR32_JALR)) ? RFWBOP_LR :
                       ((id_op == OR32_ADDI) || (id_op == OR32_ADDIC) || (id_op == OR32_ANDI) ||
                        (id_op == OR32_ORI)  || (id_op == OR32_XORI)  || (id_op == OR32_MULI) ||
                        (id_op == OR32_MOVHI)|| (id_op == OR32_ALU)   || (id_op == OR32_SHRTI) ||
                        (id_op == OR32_CUST5)) ? RFWBOP_ALU :
                       RFWBOP_NONE;

wire [2:0] branch_op_d = (id_op == OR32_J)    ? BRANCHOP_J   :
                         (id_op == OR32_JR)   ? BRANCHOP_JR  :
                         (id_op == OR32_BF)   ? BRANCHOP_BF  :
                         (id_op == OR32_BNF)  ? BRANCHOP_BNF :
                         ((id_op == OR32_JAL) || (id_op == OR32_JALR)) ? BRANCHOP_BAL :
                         (id_op == OR32_RFE)  ? BRANCHOP_RFE :
                         BRANCHOP_NOP;

wire syscall_d = (id_op == OR32_MISC) && (id_insn[7:0] == 8'h00);
wire trap_d    = (id_op == OR32_MISC) && (id_insn[7:0] == 8'h01);

wire legal_op_d = (id_op == OR32_J)     || (id_op == OR32_JAL)   || (id_op == OR32_BNF)   ||
                  (id_op == OR32_BF)    || (id_op == OR32_NOP)   || (id_op == OR32_MOVHI) ||
                  (id_op == OR32_MISC)  || (id_op == OR32_RFE)   || (id_op == OR32_JR)    ||
                  (id_op == OR32_JALR)  || (id_op == OR32_LWZ)   || (id_op == OR32_LWS)   ||
                  (id_op == OR32_LBZ)   || (id_op == OR32_LBS)   || (id_op == OR32_LHZ)   ||
                  (id_op == OR32_LHS)   || (id_op == OR32_ADDI)  || (id_op == OR32_ADDIC) ||
                  (id_op == OR32_ANDI)  || (id_op == OR32_ORI)   || (id_op == OR32_XORI)  ||
                  (id_op == OR32_MFSPR) || (id_op == OR32_SHRTI) || (id_op == OR32_SFXXI) ||
                  (id_op == OR32_MTSPR) || (id_op == OR32_SW)    || (id_op == OR32_SB)    ||
                  (id_op == OR32_SH)    || (id_op == OR32_ALU)   || (id_op == OR32_SFXX)  ||
                  (FEATURE_MUL   && (id_op == OR32_MULI))        ||
                  (FEATURE_MAC   && (id_op == OR32_MACI))        ||
                  (FEATURE_MAC   && (id_op == OR32_MACMSB))      ||
                  (FEATURE_MAC   && (id_op == OR32_MACRC))       ||
                  (FEATURE_CUST5 && (id_op == OR32_CUST5));

always @(posedge clk or posedge rst) begin
    if (rst)
        id_insn <= OR1200_NOP_INSN;
    else if (flushpipe)
        id_insn <= OR1200_NOP_INSN;
    else if (!id_freeze)
        id_insn <= if_insn;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        ex_insn_r <= OR1200_NOP_INSN;
    else if (flushpipe)
        ex_insn_r <= OR1200_NOP_INSN;
    else if (!ex_freeze)
        ex_insn_r <= id_freeze ? OR1200_NOP_INSN : id_insn;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        wb_insn_r <= OR1200_NOP_INSN;
    else if (flushpipe)
        wb_insn_r <= OR1200_NOP_INSN;
    else if (!wb_freeze)
        wb_insn_r <= ex_insn_r;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        pre_branch_op <= BRANCHOP_NOP;
    else if (!id_freeze) begin
        case (if_op)
            OR32_J:    pre_branch_op <= BRANCHOP_J;
            OR32_JR:   pre_branch_op <= BRANCHOP_JR;
            OR32_BF:   pre_branch_op <= BRANCHOP_BF;
            OR32_BNF:  pre_branch_op <= BRANCHOP_BNF;
            OR32_JAL,
            OR32_JALR: pre_branch_op <= BRANCHOP_BAL;
            OR32_RFE:  pre_branch_op <= BRANCHOP_RFE;
            default:   pre_branch_op <= BRANCHOP_NOP;
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        sel_imm <= 1'b0;
    else if (!id_freeze) begin
        case (if_op)
            OR32_J, OR32_JAL, OR32_JR, OR32_JALR, OR32_BF, OR32_BNF, OR32_RFE,
            OR32_MFSPR, OR32_MTSPR, OR32_SW, OR32_SB, OR32_SH, OR32_ALU, OR32_SFXX,
            OR32_CUST5, OR32_NOP:
                sel_imm <= 1'b0;
            default:
                sel_imm <= 1'b1;
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_addrw_r <= 5'd0;
    else if (!ex_freeze) begin
        if ((pre_branch_op == BRANCHOP_JR) || (pre_branch_op == BRANCHOP_BAL))
            rf_addrw_r <= 5'd9;
        else
            rf_addrw_r <= id_insn[25:21];
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        wb_rfaddrw <= 5'd0;
    else if (!wb_freeze)
        wb_rfaddrw <= rf_addrw_r;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        branch_op_r <= BRANCHOP_NOP;
        mac_op_r <= MACOP_NOP;
        shrot_op_r <= 2'b00;
        comp_op_r <= 4'b0000;
        rfwb_op_r <= RFWBOP_NONE;
        lsu_op_r <= LSUOP_NOP;
        spr_addrimm_r <= 16'h0000;
        sig_syscall_r <= 1'b0;
        sig_trap_r <= 1'b0;
        ex_macrc_op_r <= 1'b0;
        except_illegal_r <= 1'b0;
    end else if (!ex_freeze) begin
        if (flushpipe || id_freeze) begin
            branch_op_r <= BRANCHOP_NOP;
            mac_op_r <= MACOP_NOP;
            shrot_op_r <= 2'b00;
            comp_op_r <= 4'b0000;
            rfwb_op_r <= RFWBOP_NONE;
            lsu_op_r <= LSUOP_NOP;
            spr_addrimm_r <= 16'h0000;
            sig_syscall_r <= 1'b0;
            sig_trap_r <= 1'b0;
            ex_macrc_op_r <= 1'b0;
            except_illegal_r <= 1'b0;
        end else begin
            branch_op_r <= branch_op_d;
            mac_op_r <= mac_op_d;
            shrot_op_r <= id_insn[7:6];
            comp_op_r <= id_insn[24:21];
            rfwb_op_r <= rfwb_op_d;
            lsu_op_r <= lsu_op_d;
            spr_addrimm_r <= (id_op == OR32_MFSPR) ? id_insn[15:0] : {id_insn[25:21], id_insn[10:0]};
            sig_syscall_r <= syscall_d;
            sig_trap_r <= trap_d;
            ex_macrc_op_r <= id_macrc_op_r;
            except_illegal_r <= ~legal_op_d;
        end
    end
end

endmodule
