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

localparam [5:0] OP_J        = 6'b000000;
localparam [5:0] OP_JAL      = 6'b000001;
localparam [5:0] OP_BNF      = 6'b000011;
localparam [5:0] OP_BF       = 6'b000100;
localparam [5:0] OP_NOP      = 6'b000101;
localparam [5:0] OP_MOVHI    = 6'b000110;
localparam [5:0] OP_MACRC    = 6'b000111;
localparam [5:0] OP_SYSTRAP  = 6'b001000;
localparam [5:0] OP_RFE      = 6'b001001;
localparam [5:0] OP_JR       = 6'b001010;
localparam [5:0] OP_JALR     = 6'b001011;
localparam [5:0] OP_LWZ      = 6'b100001;
localparam [5:0] OP_LWS      = 6'b100010;
localparam [5:0] OP_LBZ      = 6'b100011;
localparam [5:0] OP_LBS      = 6'b100100;
localparam [5:0] OP_LHZ      = 6'b100101;
localparam [5:0] OP_LHS      = 6'b100110;
localparam [5:0] OP_ADDI     = 6'b100111;
localparam [5:0] OP_ADDIC    = 6'b101000;
localparam [5:0] OP_ANDI     = 6'b101001;
localparam [5:0] OP_ORI      = 6'b101010;
localparam [5:0] OP_XORI     = 6'b101011;
localparam [5:0] OP_MULI     = 6'b101100;
localparam [5:0] OP_MFSPR    = 6'b101101;
localparam [5:0] OP_SHROTI   = 6'b101110;
localparam [5:0] OP_SFXXI    = 6'b101111;
localparam [5:0] OP_MTSPR    = 6'b110000;
localparam [5:0] OP_MACI     = 6'b110001;
localparam [5:0] OP_CUST5    = 6'b110100;
localparam [5:0] OP_SW       = 6'b110101;
localparam [5:0] OP_SB       = 6'b110110;
localparam [5:0] OP_SH       = 6'b110111;
localparam [5:0] OP_ALU      = 6'b111000;
localparam [5:0] OP_SFXX     = 6'b111001;
localparam [5:0] OP_MACMSB   = 6'b111010;

localparam [31:0] OR1200_NOP_INSN = 32'h1401_0000;

localparam [2:0] BR_NOP  = 3'd0;
localparam [2:0] BR_J    = 3'd1;
localparam [2:0] BR_JR   = 3'd2;
localparam [2:0] BR_BAL  = 3'd3;
localparam [2:0] BR_BF   = 3'd4;
localparam [2:0] BR_BNF  = 3'd5;
localparam [2:0] BR_RFE  = 3'd6;

localparam [3:0] ALUOP_NOP    = 4'd0;
localparam [3:0] ALUOP_MOVHI  = 4'd1;
localparam [3:0] ALUOP_ADD    = 4'd2;
localparam [3:0] ALUOP_ADDC   = 4'd3;
localparam [3:0] ALUOP_SUB    = 4'd4;
localparam [3:0] ALUOP_AND    = 4'd5;
localparam [3:0] ALUOP_OR     = 4'd6;
localparam [3:0] ALUOP_XOR    = 4'd7;
localparam [3:0] ALUOP_MUL    = 4'd8;
localparam [3:0] ALUOP_SHROT  = 4'd9;
localparam [3:0] ALUOP_COMP   = 4'd10;
localparam [3:0] ALUOP_SPR    = 4'd11;
localparam [3:0] ALUOP_MAC    = 4'd12;
localparam [3:0] ALUOP_CUST5  = 4'd13;

localparam [1:0] MACOP_NOP  = 2'd0;
localparam [1:0] MACOP_MAC  = 2'd1;
localparam [1:0] MACOP_MSB  = 2'd2;

localparam [3:0] LSUOP_NOP  = 4'd0;
localparam [3:0] LSUOP_LWZ  = 4'd1;
localparam [3:0] LSUOP_LWS  = 4'd2;
localparam [3:0] LSUOP_LBZ  = 4'd3;
localparam [3:0] LSUOP_LBS  = 4'd4;
localparam [3:0] LSUOP_LHZ  = 4'd5;
localparam [3:0] LSUOP_LHS  = 4'd6;
localparam [3:0] LSUOP_SW   = 4'd9;
localparam [3:0] LSUOP_SB   = 4'd10;
localparam [3:0] LSUOP_SH   = 4'd11;

localparam [2:0] RFWBOP_NOP   = 3'd0;
localparam [2:0] RFWBOP_LSU   = 3'd1;
localparam [2:0] RFWBOP_ALU   = 3'd2;
localparam [2:0] RFWBOP_SPR   = 3'd3;
localparam [2:0] RFWBOP_LR    = 3'd4;
localparam [2:0] RFWBOP_CUST5 = 3'd5;

localparam [1:0] SEL_RF  = 2'd0;
localparam [1:0] SEL_EX  = 2'd1;
localparam [1:0] SEL_WB  = 2'd2;
localparam [1:0] SEL_IMM = 2'd3;

localparam [1:0] OR1200_ONE_CYCLE = 2'd0;

reg [31:0] id_insn;
reg [31:0] ex_insn;
reg [31:0] wb_insn;
reg [2:0] branch_op;
reg [3:0] alu_op;
reg [1:0] mac_op;
reg [1:0] shrot_op;
reg [3:0] comp_op;
reg [4:0] rf_addrw;
reg [2:0] rfwb_op;
reg [3:0] lsu_op;
reg [15:0] spr_addrimm;
reg sig_syscall;
reg sig_trap;
reg ex_macrc_op;
reg except_illegal;

reg [2:0] pre_branch_op;
reg sel_imm;
reg [4:0] wb_rfaddrw;

wire [5:0] if_opcode;
wire [5:0] id_opcode;
wire [5:0] ex_opcode;
wire id_void;
wire ex_writes_rf;
wire wb_writes_rf;
wire imm_signextend;

assign if_opcode = if_insn[31:26];
assign id_opcode = id_insn[31:26];
assign ex_opcode = ex_insn[31:26];

assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda = if_insn[31];
assign rf_rdb = if_insn[30];

assign id_void = id_insn[16];
assign ex_void = ex_insn[16];
assign force_dslot_fetch = 1'b0;
assign rfe = (pre_branch_op == BR_RFE) | (branch_op == BR_RFE);
assign id_macrc_op = (id_opcode == OP_MACRC);
assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0]};
assign cust5_op = ex_insn[4:0];
assign cust5_limm = ex_insn[10:5];
assign no_more_dslot = (((branch_op != BR_NOP) && !id_void) && branch_taken) || (branch_op == BR_RFE);
assign ex_writes_rf = (rfwb_op != RFWBOP_NOP) && (rf_addrw != 5'd0);
assign wb_writes_rf = wbforw_valid && (wb_rfaddrw != 5'd0);

function [2:0] decode_pre_branch;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_J:      decode_pre_branch = BR_J;
            OP_JAL:    decode_pre_branch = BR_BAL;
            OP_JR:     decode_pre_branch = BR_JR;
            OP_JALR:   decode_pre_branch = BR_BAL;
            OP_BF:     decode_pre_branch = BR_BF;
            OP_BNF:    decode_pre_branch = BR_BNF;
            OP_RFE:    decode_pre_branch = BR_RFE;
            default:   decode_pre_branch = BR_NOP;
        endcase
    end
endfunction

function decode_sel_imm;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_J,
            OP_JAL,
            OP_BF,
            OP_BNF,
            OP_NOP,
            OP_RFE,
            OP_JR,
            OP_JALR,
            OP_MACRC,
            OP_MFSPR,
            OP_MTSPR,
            OP_SW,
            OP_SB,
            OP_SH,
            OP_ALU,
            OP_SFXX,
            OP_CUST5,
            OP_MACMSB:
                decode_sel_imm = 1'b0;
            default:
                decode_sel_imm = 1'b1;
        endcase
    end
endfunction

function decode_imm_signextend;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_ADDI,
            OP_ADDIC,
            OP_XORI,
            OP_MULI,
            OP_MACI,
            OP_SFXXI:
                decode_imm_signextend = 1'b1;
            default:
                decode_imm_signextend = 1'b0;
        endcase
    end
endfunction

function [3:0] decode_alu_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_MOVHI:   decode_alu_op = ALUOP_MOVHI;
            OP_ADDI:    decode_alu_op = ALUOP_ADD;
            OP_ADDIC:   decode_alu_op = ALUOP_ADDC;
            OP_ANDI:    decode_alu_op = ALUOP_AND;
            OP_ORI:     decode_alu_op = ALUOP_OR;
            OP_XORI:    decode_alu_op = ALUOP_XOR;
            OP_MULI:    decode_alu_op = ALUOP_MUL;
            OP_MFSPR,
            OP_MTSPR:   decode_alu_op = ALUOP_SPR;
            OP_SHROTI:  decode_alu_op = ALUOP_SHROT;
            OP_SFXX,
            OP_SFXXI:   decode_alu_op = ALUOP_COMP;
            OP_MACRC,
            OP_MACI,
            OP_MACMSB:  decode_alu_op = ALUOP_MAC;
            OP_CUST5:   decode_alu_op = ALUOP_CUST5;
            OP_ALU: begin
                case (insn[3:0])
                    4'h0: decode_alu_op = ALUOP_ADD;
                    4'h1: decode_alu_op = ALUOP_ADDC;
                    4'h2: decode_alu_op = ALUOP_SUB;
                    4'h3: decode_alu_op = ALUOP_AND;
                    4'h4: decode_alu_op = ALUOP_OR;
                    4'h5: decode_alu_op = ALUOP_XOR;
                    4'h6: decode_alu_op = ALUOP_MUL;
                    4'h7: decode_alu_op = ALUOP_SHROT;
                    4'h8: decode_alu_op = ALUOP_COMP;
                    default: decode_alu_op = ALUOP_ADD;
                endcase
            end
            default:    decode_alu_op = ALUOP_NOP;
        endcase
    end
endfunction

function [1:0] decode_mac_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_MACI:    decode_mac_op = MACOP_MAC;
            OP_MACMSB:  decode_mac_op = insn[0] ? MACOP_MSB : MACOP_MAC;
            default:    decode_mac_op = MACOP_NOP;
        endcase
    end
endfunction

function [3:0] decode_lsu_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_LWZ:     decode_lsu_op = LSUOP_LWZ;
            OP_LWS:     decode_lsu_op = LSUOP_LWS;
            OP_LBZ:     decode_lsu_op = LSUOP_LBZ;
            OP_LBS:     decode_lsu_op = LSUOP_LBS;
            OP_LHZ:     decode_lsu_op = LSUOP_LHZ;
            OP_LHS:     decode_lsu_op = LSUOP_LHS;
            OP_SW:      decode_lsu_op = LSUOP_SW;
            OP_SB:      decode_lsu_op = LSUOP_SB;
            OP_SH:      decode_lsu_op = LSUOP_SH;
            default:    decode_lsu_op = LSUOP_NOP;
        endcase
    end
endfunction

function [2:0] decode_rfwb_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_JAL,
            OP_JALR:    decode_rfwb_op = RFWBOP_LR;
            OP_LWZ,
            OP_LWS,
            OP_LBZ,
            OP_LBS,
            OP_LHZ,
            OP_LHS:     decode_rfwb_op = RFWBOP_LSU;
            OP_MFSPR:   decode_rfwb_op = RFWBOP_SPR;
            OP_CUST5:   decode_rfwb_op = RFWBOP_CUST5;
            OP_MOVHI,
            OP_MACRC,
            OP_ADDI,
            OP_ADDIC,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_MULI,
            OP_SHROTI,
            OP_SFXXI,
            OP_ALU,
            OP_SFXX:    decode_rfwb_op = RFWBOP_ALU;
            default:    decode_rfwb_op = RFWBOP_NOP;
        endcase
    end
endfunction

function [15:0] decode_spr_addrimm;
    input [31:0] insn;
    begin
        if (insn[31:26] == OP_MFSPR)
            decode_spr_addrimm = insn[15:0];
        else
            decode_spr_addrimm = {insn[25:21], insn[10:0]};
    end
endfunction

function decode_sig_syscall;
    input [31:0] insn;
    begin
        decode_sig_syscall = (insn[31:26] == OP_SYSTRAP) && !insn[16];
    end
endfunction

function decode_sig_trap;
    input [31:0] insn;
    begin
        decode_sig_trap = (insn[31:26] == OP_SYSTRAP) && insn[16];
    end
endfunction

function decode_except_illegal;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_J,
            OP_JAL,
            OP_BNF,
            OP_BF,
            OP_NOP,
            OP_MOVHI,
            OP_MACRC,
            OP_SYSTRAP,
            OP_RFE,
            OP_JR,
            OP_JALR,
            OP_LWZ,
            OP_LWS,
            OP_LBZ,
            OP_LBS,
            OP_LHZ,
            OP_LHS,
            OP_ADDI,
            OP_ADDIC,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_MULI,
            OP_MFSPR,
            OP_SHROTI,
            OP_SFXXI,
            OP_MTSPR,
            OP_MACI,
            OP_CUST5,
            OP_SW,
            OP_SB,
            OP_SH,
            OP_ALU,
            OP_SFXX,
            OP_MACMSB:
                decode_except_illegal = 1'b0;
            default:
                decode_except_illegal = 1'b1;
        endcase
    end
endfunction

function [4:0] decode_rf_addrw;
    input [31:0] insn;
    input [2:0] branch_dec;
    begin
        if ((branch_dec == BR_JR) || (branch_dec == BR_BAL))
            decode_rf_addrw = 5'd9;
        else
            decode_rf_addrw = insn[25:21];
    end
endfunction

assign imm_signextend = decode_imm_signextend(id_insn);
assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'h0000, id_insn[15:0]};
assign multicycle = (id_opcode == OP_ALU) ? id_insn[9:8] : OR1200_ONE_CYCLE;
assign lsu_addrofs = ((ex_opcode == OP_SW) || (ex_opcode == OP_SB) || (ex_opcode == OP_SH)) ?
                     {{16{ex_insn[25]}}, ex_insn[25:21], ex_insn[10:0]} :
                     {{16{ex_insn[15]}}, ex_insn[15:11], ex_insn[10:0]};

assign sel_a = (rf_rda && ex_writes_rf && (rf_addra == rf_addrw)) ? SEL_EX :
               (rf_rda && wb_writes_rf && (rf_addra == wb_rfaddrw)) ? SEL_WB :
               SEL_RF;

assign sel_b = sel_imm ? SEL_IMM :
               ((rf_rdb && ex_writes_rf && (rf_addrb == rf_addrw)) ? SEL_EX :
               ((rf_rdb && wb_writes_rf && (rf_addrb == wb_rfaddrw)) ? SEL_WB :
               SEL_RF));

always @(posedge clk or posedge rst) begin
    if (rst)
        id_insn <= OR1200_NOP_INSN;
    else if (flushpipe)
        id_insn <= OR1200_NOP_INSN;
    else if (!id_freeze)
        id_insn <= if_insn;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pre_branch_op <= BR_NOP;
        sel_imm <= 1'b0;
    end
    else if (!id_freeze) begin
        pre_branch_op <= decode_pre_branch(if_insn);
        sel_imm <= decode_sel_imm(if_insn);
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_addrw <= 5'd0;
    else if (!ex_freeze && !id_freeze)
        rf_addrw <= decode_rf_addrw(id_insn, pre_branch_op);
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ex_insn <= OR1200_NOP_INSN;
        branch_op <= BR_NOP;
        alu_op <= ALUOP_NOP;
        mac_op <= MACOP_NOP;
        shrot_op <= 2'd0;
        comp_op <= 4'd0;
        rfwb_op <= RFWBOP_NOP;
        lsu_op <= LSUOP_NOP;
        spr_addrimm <= 16'h0000;
        sig_syscall <= 1'b0;
        sig_trap <= 1'b0;
        ex_macrc_op <= 1'b0;
        except_illegal <= 1'b0;
    end
    else if (flushpipe) begin
        ex_insn <= OR1200_NOP_INSN;
        branch_op <= BR_NOP;
        alu_op <= ALUOP_NOP;
        mac_op <= MACOP_NOP;
        shrot_op <= 2'd0;
        comp_op <= 4'd0;
        rfwb_op <= RFWBOP_NOP;
        lsu_op <= LSUOP_NOP;
        spr_addrimm <= 16'h0000;
        sig_syscall <= 1'b0;
        sig_trap <= 1'b0;
        ex_macrc_op <= 1'b0;
        except_illegal <= 1'b0;
    end
    else if (!ex_freeze) begin
        if (id_freeze) begin
            ex_insn <= OR1200_NOP_INSN;
            branch_op <= BR_NOP;
            alu_op <= ALUOP_NOP;
            mac_op <= MACOP_NOP;
            shrot_op <= 2'd0;
            comp_op <= 4'd0;
            rfwb_op <= RFWBOP_NOP;
            lsu_op <= LSUOP_NOP;
            spr_addrimm <= 16'h0000;
            sig_syscall <= 1'b0;
            sig_trap <= 1'b0;
            ex_macrc_op <= 1'b0;
            except_illegal <= 1'b0;
        end
        else begin
            ex_insn <= id_insn;
            branch_op <= pre_branch_op;
            alu_op <= decode_alu_op(id_insn);
            mac_op <= decode_mac_op(id_insn);
            shrot_op <= id_insn[7:6];
            comp_op <= id_insn[24:21];
            rfwb_op <= decode_rfwb_op(id_insn);
            lsu_op <= decode_lsu_op(id_insn);
            spr_addrimm <= decode_spr_addrimm(id_insn);
            sig_syscall <= decode_sig_syscall(id_insn);
            sig_trap <= decode_sig_trap(id_insn) | du_hwbkpt;
            ex_macrc_op <= (id_opcode == OP_MACRC);
            except_illegal <= decode_except_illegal(id_insn);
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        wb_insn <= OR1200_NOP_INSN;
    else if (flushpipe)
        wb_insn <= OR1200_NOP_INSN;
    else if (!wb_freeze)
        wb_insn <= ex_insn;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        wb_rfaddrw <= 5'd0;
    else if (!wb_freeze)
        wb_rfaddrw <= rf_addrw;
end

endmodule
