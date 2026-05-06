module or1200_ctrl(
    input clk,
    input rst,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input flushpipe,
    input [31:0] if_insn,
    output reg [31:0] ex_insn,
    output reg [2:0] branch_op,
    input branch_taken,
    output [4:0] rf_addra,
    output [4:0] rf_addrb,
    output rf_rda,
    output rf_rdb,
    output reg [3:0] alu_op,
    output reg [1:0] mac_op,
    output reg [1:0] shrot_op,
    output reg [3:0] comp_op,
    output reg [4:0] rf_addrw,
    output reg [2:0] rfwb_op,
    output reg [31:0] wb_insn,
    output [31:0] simm,
    output [31:2] branch_addrofs,
    output [31:0] lsu_addrofs,
    output [1:0] sel_a,
    output [1:0] sel_b,
    output reg [3:0] lsu_op,
    output [4:0] cust5_op,
    output [5:0] cust5_limm,
    output [1:0] multicycle,
    output reg [15:0] spr_addrimm,
    input wbforw_valid,
    input du_hwbkpt,
    output reg sig_syscall,
    output reg sig_trap,
    output force_dslot_fetch,
    output no_more_dslot,
    output ex_void,
    output id_macrc_op,
    output reg ex_macrc_op,
    output rfe,
    output reg except_illegal
);

localparam [5:0] OP_J       = 6'b000000;
localparam [5:0] OP_JAL     = 6'b000001;
localparam [5:0] OP_BNF     = 6'b000011;
localparam [5:0] OP_BF      = 6'b000100;
localparam [5:0] OP_NOP     = 6'b000101;
localparam [5:0] OP_MOVHI   = 6'b000110;
localparam [5:0] OP_XSYNC   = 6'b001000;
localparam [5:0] OP_RFE     = 6'b001001;
localparam [5:0] OP_JR      = 6'b010001;
localparam [5:0] OP_JALR    = 6'b010010;
localparam [5:0] OP_MACI    = 6'b010011;
localparam [5:0] OP_LWZ     = 6'b100001;
localparam [5:0] OP_LWS     = 6'b100010;
localparam [5:0] OP_LBZ     = 6'b100011;
localparam [5:0] OP_LBS     = 6'b100100;
localparam [5:0] OP_LHZ     = 6'b100101;
localparam [5:0] OP_LHS     = 6'b100110;
localparam [5:0] OP_ADDI    = 6'b100111;
localparam [5:0] OP_ADDIC   = 6'b101000;
localparam [5:0] OP_ANDI    = 6'b101001;
localparam [5:0] OP_ORI     = 6'b101010;
localparam [5:0] OP_XORI    = 6'b101011;
localparam [5:0] OP_MULI    = 6'b101100;
localparam [5:0] OP_MFSPR   = 6'b101101;
localparam [5:0] OP_SHROTI  = 6'b101110;
localparam [5:0] OP_SFXXI   = 6'b101111;
localparam [5:0] OP_MTSPR   = 6'b110000;
localparam [5:0] OP_MACMSB  = 6'b110001;
localparam [5:0] OP_CUST5   = 6'b110010;
localparam [5:0] OP_SW      = 6'b110101;
localparam [5:0] OP_SB      = 6'b110110;
localparam [5:0] OP_SH      = 6'b110111;
localparam [5:0] OP_ALU     = 6'b111000;
localparam [5:0] OP_SFXX    = 6'b111001;

localparam [2:0] BR_NOP     = 3'd0;
localparam [2:0] BR_J       = 3'd1;
localparam [2:0] BR_JR      = 3'd2;
localparam [2:0] BR_BAL     = 3'd3;
localparam [2:0] BR_BF      = 3'd4;
localparam [2:0] BR_BNF     = 3'd5;
localparam [2:0] BR_RFE     = 3'd6;

localparam [1:0] SEL_RF     = 2'd0;
localparam [1:0] SEL_EX     = 2'd1;
localparam [1:0] SEL_WB     = 2'd2;
localparam [1:0] SEL_IMM    = 2'd3;

localparam [3:0] ALUOP_NOP   = 4'd0;
localparam [3:0] ALUOP_MOVHI = 4'd1;
localparam [3:0] ALUOP_ADD   = 4'd2;
localparam [3:0] ALUOP_ADDC  = 4'd3;
localparam [3:0] ALUOP_AND   = 4'd4;
localparam [3:0] ALUOP_OR    = 4'd5;
localparam [3:0] ALUOP_XOR   = 4'd6;
localparam [3:0] ALUOP_MUL   = 4'd7;
localparam [3:0] ALUOP_SHROT = 4'd8;
localparam [3:0] ALUOP_DIV   = 4'd9;
localparam [3:0] ALUOP_MFSPR = 4'd10;
localparam [3:0] ALUOP_MTSPR = 4'd11;
localparam [3:0] ALUOP_COMP  = 4'd12;
localparam [3:0] ALUOP_CUST5 = 4'd13;

localparam [1:0] MACOP_NOP   = 2'd0;
localparam [1:0] MACOP_MAC   = 2'd1;
localparam [1:0] MACOP_MSB   = 2'd2;
localparam [1:0] MACOP_MACI  = 2'd3;

localparam [3:0] LSUOP_NOP   = 4'd0;
localparam [3:0] LSUOP_LWZ   = 4'd1;
localparam [3:0] LSUOP_LWS   = 4'd2;
localparam [3:0] LSUOP_LBZ   = 4'd3;
localparam [3:0] LSUOP_LBS   = 4'd4;
localparam [3:0] LSUOP_LHZ   = 4'd5;
localparam [3:0] LSUOP_LHS   = 4'd6;
localparam [3:0] LSUOP_SW    = 4'd7;
localparam [3:0] LSUOP_SB    = 4'd8;
localparam [3:0] LSUOP_SH    = 4'd9;

localparam [2:0] RFWB_NOP    = 3'd0;
localparam [2:0] RFWB_ALU    = 3'd1;
localparam [2:0] RFWB_LSU    = 3'd2;
localparam [2:0] RFWB_SPR    = 3'd3;
localparam [2:0] RFWB_LR     = 3'd4;
localparam [2:0] RFWB_CUST5  = 3'd5;

localparam [1:0] ONE_CYCLE   = 2'b00;
localparam [31:0] NOP_INSN   = {OP_NOP, 26'h010000};

reg [31:0] id_insn;
reg [2:0] pre_branch_op;
reg sel_imm;
reg [4:0] wb_rfaddrw;

function is_macrc;
    input [31:0] insn;
    begin
        is_macrc = (insn[31:26] == OP_MACMSB) && (insn[1:0] == 2'b10);
    end
endfunction

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
            OP_NOP,
            OP_JR,
            OP_JALR,
            OP_RFE,
            OP_MFSPR,
            OP_MTSPR,
            OP_SW,
            OP_SB,
            OP_SH,
            OP_ALU,
            OP_SFXX,
            OP_CUST5,
            OP_MACMSB,
            OP_XSYNC:  decode_sel_imm = 1'b0;
            default:   decode_sel_imm = 1'b1;
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
            OP_SFXXI:  decode_imm_signextend = 1'b1;
            default:   decode_imm_signextend = 1'b0;
        endcase
    end
endfunction

function [1:0] decode_mac_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_MACI:   decode_mac_op = MACOP_MACI;
            OP_MACMSB: begin
                if (is_macrc(insn))
                    decode_mac_op = MACOP_NOP;
                else if (insn[1:0] == 2'b01)
                    decode_mac_op = MACOP_MSB;
                else
                    decode_mac_op = MACOP_MAC;
            end
            default:   decode_mac_op = MACOP_NOP;
        endcase
    end
endfunction

function [3:0] decode_lsu_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_LWZ:    decode_lsu_op = LSUOP_LWZ;
            OP_LWS:    decode_lsu_op = LSUOP_LWS;
            OP_LBZ:    decode_lsu_op = LSUOP_LBZ;
            OP_LBS:    decode_lsu_op = LSUOP_LBS;
            OP_LHZ:    decode_lsu_op = LSUOP_LHZ;
            OP_LHS:    decode_lsu_op = LSUOP_LHS;
            OP_SW:     decode_lsu_op = LSUOP_SW;
            OP_SB:     decode_lsu_op = LSUOP_SB;
            OP_SH:     decode_lsu_op = LSUOP_SH;
            default:   decode_lsu_op = LSUOP_NOP;
        endcase
    end
endfunction

function [3:0] decode_alu_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_MOVHI:  decode_alu_op = ALUOP_MOVHI;
            OP_LWZ,
            OP_LWS,
            OP_LBZ,
            OP_LBS,
            OP_LHZ,
            OP_LHS,
            OP_SW,
            OP_SB,
            OP_SH,
            OP_ADDI:   decode_alu_op = ALUOP_ADD;
            OP_ADDIC:  decode_alu_op = ALUOP_ADDC;
            OP_ANDI:   decode_alu_op = ALUOP_AND;
            OP_ORI:    decode_alu_op = ALUOP_OR;
            OP_XORI:   decode_alu_op = ALUOP_XOR;
            OP_MULI:   decode_alu_op = ALUOP_MUL;
            OP_MFSPR:  decode_alu_op = ALUOP_MFSPR;
            OP_MTSPR:  decode_alu_op = ALUOP_MTSPR;
            OP_SHROTI: decode_alu_op = ALUOP_SHROT;
            OP_SFXX,
            OP_SFXXI:  decode_alu_op = ALUOP_COMP;
            OP_CUST5:  decode_alu_op = ALUOP_CUST5;
            OP_ALU: begin
                case (insn[3:0])
                    4'h1:    decode_alu_op = ALUOP_ADDC;
                    4'h3:    decode_alu_op = ALUOP_AND;
                    4'h4:    decode_alu_op = ALUOP_OR;
                    4'h5:    decode_alu_op = ALUOP_XOR;
                    4'h6,
                    4'hb:    decode_alu_op = ALUOP_MUL;
                    4'h8:    decode_alu_op = ALUOP_SHROT;
                    4'h9,
                    4'ha:    decode_alu_op = ALUOP_DIV;
                    default: decode_alu_op = ALUOP_ADD;
                endcase
            end
            default:   decode_alu_op = ALUOP_NOP;
        endcase
    end
endfunction

function [2:0] decode_rfwb_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_JAL,
            OP_JALR:   decode_rfwb_op = RFWB_LR;
            OP_LWZ,
            OP_LWS,
            OP_LBZ,
            OP_LBS,
            OP_LHZ,
            OP_LHS:    decode_rfwb_op = RFWB_LSU;
            OP_MFSPR:  decode_rfwb_op = RFWB_SPR;
            OP_MOVHI,
            OP_ADDI,
            OP_ADDIC,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_MULI,
            OP_SHROTI,
            OP_ALU:    decode_rfwb_op = RFWB_ALU;
            OP_CUST5:  decode_rfwb_op = RFWB_CUST5;
            OP_MACMSB: begin
                if (is_macrc(insn))
                    decode_rfwb_op = RFWB_ALU;
                else
                    decode_rfwb_op = RFWB_NOP;
            end
            default:   decode_rfwb_op = RFWB_NOP;
        endcase
    end
endfunction

function [4:0] decode_rf_addrw_fn;
    input [31:0] insn;
    input [2:0] pre_br;
    begin
        decode_rf_addrw_fn = insn[25:21];
        if ((pre_br == BR_JR) || (pre_br == BR_BAL))
            decode_rf_addrw_fn = 5'd9;
    end
endfunction

function is_syscall;
    input [31:0] insn;
    begin
        is_syscall = (insn[31:26] == OP_XSYNC) && (insn[25:23] == 3'b000);
    end
endfunction

function is_trap;
    input [31:0] insn;
    begin
        is_trap = (insn[31:26] == OP_XSYNC) && (insn[25:23] == 3'b001);
    end
endfunction

function is_illegal;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_J,
            OP_JAL,
            OP_BNF,
            OP_BF,
            OP_NOP,
            OP_MOVHI,
            OP_XSYNC,
            OP_RFE,
            OP_JR,
            OP_JALR,
            OP_MACI,
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
            OP_MACMSB,
            OP_CUST5,
            OP_SW,
            OP_SB,
            OP_SH,
            OP_ALU,
            OP_SFXX:   is_illegal = 1'b0;
            default:   is_illegal = 1'b1;
        endcase
    end
endfunction

wire id_void;
wire imm_signextend;
wire [15:0] ex_lsu_imm;
wire ex_rf_write;
wire ex_match_a;
wire ex_match_b;
wire wb_match_a;
wire wb_match_b;
wire [4:0] dec_rf_addrw;
wire [2:0] dec_rfwb_op;
wire [3:0] dec_alu_op;
wire [1:0] dec_mac_op;
wire [3:0] dec_lsu_op;
wire dec_syscall;
wire dec_trap;
wire dec_illegal;

assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda = if_insn[31];
assign rf_rdb = if_insn[30];

assign id_void = (id_insn[31:26] == OP_NOP) && id_insn[16];
assign ex_void = (ex_insn[31:26] == OP_NOP) && ex_insn[16];
assign imm_signextend = decode_imm_signextend(id_insn);
assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'b0, id_insn[15:0]};
assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0]};
assign ex_lsu_imm = ((ex_insn[31:26] == OP_SW) || (ex_insn[31:26] == OP_SB) || (ex_insn[31:26] == OP_SH)) ?
                    {ex_insn[25:21], ex_insn[10:0]} : {ex_insn[15:11], ex_insn[10:0]};
assign lsu_addrofs = {{16{ex_lsu_imm[15]}}, ex_lsu_imm};
assign cust5_op = ex_insn[4:0];
assign cust5_limm = ex_insn[10:5];
assign multicycle = (id_insn[31:26] == OP_ALU) ? id_insn[9:8] : ONE_CYCLE;
assign id_macrc_op = is_macrc(id_insn);
assign force_dslot_fetch = 1'b0;
assign no_more_dslot = (((branch_op != BR_NOP) && !id_void && branch_taken) || (branch_op == BR_RFE));
assign rfe = (pre_branch_op == BR_RFE) || (branch_op == BR_RFE);

assign dec_rf_addrw = decode_rf_addrw_fn(id_insn, pre_branch_op);
assign dec_rfwb_op = decode_rfwb_op(id_insn);
assign dec_alu_op = decode_alu_op(id_insn);
assign dec_mac_op = decode_mac_op(id_insn);
assign dec_lsu_op = decode_lsu_op(id_insn);
assign dec_syscall = is_syscall(id_insn);
assign dec_trap = is_trap(id_insn);
assign dec_illegal = is_illegal(id_insn);

assign ex_rf_write = (rfwb_op != RFWB_NOP);
assign ex_match_a = ex_rf_write && (rf_addra == rf_addrw);
assign ex_match_b = ex_rf_write && (rf_addrb == rf_addrw);
assign wb_match_a = wbforw_valid && (rf_addra == wb_rfaddrw);
assign wb_match_b = wbforw_valid && (rf_addrb == wb_rfaddrw);

assign sel_a = ex_match_a ? SEL_EX : (wb_match_a ? SEL_WB : SEL_RF);
assign sel_b = sel_imm ? SEL_IMM : (ex_match_b ? SEL_EX : (wb_match_b ? SEL_WB : SEL_RF));

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_insn <= NOP_INSN;
        pre_branch_op <= BR_NOP;
        sel_imm <= 1'b0;
    end else begin
        if (flushpipe) begin
            id_insn <= NOP_INSN;
            pre_branch_op <= BR_NOP;
        end else if (!id_freeze) begin
            id_insn <= if_insn;
            pre_branch_op <= decode_pre_branch(if_insn);
            sel_imm <= decode_sel_imm(if_insn);
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ex_insn <= NOP_INSN;
        branch_op <= BR_NOP;
        alu_op <= ALUOP_NOP;
        mac_op <= MACOP_NOP;
        shrot_op <= 2'b00;
        comp_op <= 4'b0000;
        rf_addrw <= 5'd0;
        rfwb_op <= RFWB_NOP;
        lsu_op <= LSUOP_NOP;
        spr_addrimm <= 16'd0;
        sig_syscall <= 1'b0;
        sig_trap <= 1'b0;
        ex_macrc_op <= 1'b0;
        except_illegal <= 1'b0;
    end else if (flushpipe) begin
        ex_insn <= NOP_INSN;
        branch_op <= BR_NOP;
        alu_op <= ALUOP_NOP;
        mac_op <= MACOP_NOP;
        shrot_op <= 2'b00;
        comp_op <= 4'b0000;
        rfwb_op <= RFWB_NOP;
        lsu_op <= LSUOP_NOP;
        spr_addrimm <= 16'd0;
        sig_syscall <= 1'b0;
        sig_trap <= 1'b0;
        ex_macrc_op <= 1'b0;
        except_illegal <= 1'b0;
    end else if (!ex_freeze) begin
        if (id_freeze) begin
            ex_insn <= NOP_INSN;
            branch_op <= BR_NOP;
            alu_op <= ALUOP_NOP;
            mac_op <= MACOP_NOP;
            shrot_op <= 2'b00;
            comp_op <= 4'b0000;
            rf_addrw <= 5'd0;
            rfwb_op <= RFWB_NOP;
            lsu_op <= LSUOP_NOP;
            spr_addrimm <= 16'd0;
            sig_syscall <= 1'b0;
            sig_trap <= 1'b0;
            ex_macrc_op <= 1'b0;
            except_illegal <= 1'b0;
        end else begin
            ex_insn <= id_insn;
            branch_op <= pre_branch_op;
            alu_op <= dec_alu_op;
            mac_op <= dec_mac_op;
            shrot_op <= id_insn[7:6];
            comp_op <= id_insn[24:21];
            rf_addrw <= dec_rf_addrw;
            rfwb_op <= dec_rfwb_op;
            lsu_op <= dec_lsu_op;
            spr_addrimm <= (id_insn[31:26] == OP_MFSPR) ? id_insn[15:0] : {id_insn[25:21], id_insn[10:0]};
            sig_syscall <= dec_syscall;
            sig_trap <= dec_trap | du_hwbkpt;
            ex_macrc_op <= is_macrc(id_insn);
            except_illegal <= dec_illegal;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wb_insn <= NOP_INSN;
        wb_rfaddrw <= 5'd0;
    end else if (flushpipe) begin
        wb_insn <= NOP_INSN;
    end else if (!wb_freeze) begin
        wb_insn <= ex_insn;
        wb_rfaddrw <= rf_addrw;
    end
end

endmodule
