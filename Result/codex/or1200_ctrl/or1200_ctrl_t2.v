module or1200_ctrl(
    input              clk,
    input              rst,
    input              id_freeze,
    input              ex_freeze,
    input              wb_freeze,
    input              flushpipe,
    input      [31:0]  if_insn,
    output reg [31:0]  ex_insn,
    output reg [2:0]   branch_op,
    input              branch_taken,
    output     [4:0]   rf_addra,
    output     [4:0]   rf_addrb,
    output             rf_rda,
    output             rf_rdb,
    output reg [3:0]   alu_op,
    output reg [1:0]   mac_op,
    output reg [1:0]   shrot_op,
    output reg [3:0]   comp_op,
    output reg [4:0]   rf_addrw,
    output reg [2:0]   rfwb_op,
    output reg [31:0]  wb_insn,
    output     [31:0]  simm,
    output     [31:2]  branch_addrofs,
    output     [31:0]  lsu_addrofs,
    output reg [1:0]   sel_a,
    output reg [1:0]   sel_b,
    output reg [3:0]   lsu_op,
    output     [4:0]   cust5_op,
    output     [5:0]   cust5_limm,
    output     [1:0]   multicycle,
    output reg [15:0]  spr_addrimm,
    input              wbforw_valid,
    input              du_hwbkpt,
    output reg         sig_syscall,
    output             sig_trap,
    output             force_dslot_fetch,
    output             no_more_dslot,
    output             ex_void,
    output             id_macrc_op,
    output reg         ex_macrc_op,
    output             rfe,
    output reg         except_illegal
);

localparam [31:0] OR1200_NOP_INSN = 32'h1401_0000;

localparam [5:0] OP_J      = 6'h00;
localparam [5:0] OP_JAL    = 6'h01;
localparam [5:0] OP_BNF    = 6'h03;
localparam [5:0] OP_BF     = 6'h04;
localparam [5:0] OP_NOP    = 6'h05;
localparam [5:0] OP_MOVHI  = 6'h06;
localparam [5:0] OP_MISC   = 6'h08;
localparam [5:0] OP_RFE    = 6'h09;
localparam [5:0] OP_JR     = 6'h11;
localparam [5:0] OP_JALR   = 6'h12;
localparam [5:0] OP_MACI   = 6'h13;
localparam [5:0] OP_LWZ    = 6'h21;
localparam [5:0] OP_LWS    = 6'h22;
localparam [5:0] OP_LBZ    = 6'h23;
localparam [5:0] OP_LBS    = 6'h24;
localparam [5:0] OP_LHZ    = 6'h25;
localparam [5:0] OP_LHS    = 6'h26;
localparam [5:0] OP_ADDI   = 6'h27;
localparam [5:0] OP_ADDIC  = 6'h28;
localparam [5:0] OP_ANDI   = 6'h29;
localparam [5:0] OP_ORI    = 6'h2a;
localparam [5:0] OP_XORI   = 6'h2b;
localparam [5:0] OP_MULI   = 6'h2c;
localparam [5:0] OP_MFSPR  = 6'h2d;
localparam [5:0] OP_SHROTI = 6'h2e;
localparam [5:0] OP_SFXXI  = 6'h2f;
localparam [5:0] OP_MTSPR  = 6'h30;
localparam [5:0] OP_MACMSB = 6'h31;
localparam [5:0] OP_SW     = 6'h35;
localparam [5:0] OP_SB     = 6'h36;
localparam [5:0] OP_SH     = 6'h37;
localparam [5:0] OP_ALU    = 6'h38;
localparam [5:0] OP_SFXX   = 6'h39;
localparam [5:0] OP_CUST5  = 6'h3a;

localparam [2:0] BRANCHOP_NOP = 3'd0;
localparam [2:0] BRANCHOP_J   = 3'd1;
localparam [2:0] BRANCHOP_JR  = 3'd2;
localparam [2:0] BRANCHOP_BF  = 3'd3;
localparam [2:0] BRANCHOP_BNF = 3'd4;
localparam [2:0] BRANCHOP_RFE = 3'd5;
localparam [2:0] BRANCHOP_BAL = 3'd6;

localparam [1:0] SEL_RF  = 2'b00;
localparam [1:0] SEL_EX  = 2'b01;
localparam [1:0] SEL_WB  = 2'b10;
localparam [1:0] SEL_IMM = 2'b11;

localparam [3:0] ALUOP_NOP   = 4'd0;
localparam [3:0] ALUOP_IMM   = 4'd1;
localparam [3:0] ALUOP_MOVHI = 4'd2;
localparam [3:0] ALUOP_SPR   = 4'd3;
localparam [3:0] ALUOP_ALU   = 4'd4;
localparam [3:0] ALUOP_SHROT = 4'd5;
localparam [3:0] ALUOP_COMP  = 4'd6;
localparam [3:0] ALUOP_CUST5 = 4'd7;

localparam [1:0] MACOP_NOP  = 2'd0;
localparam [1:0] MACOP_MAC  = 2'd1;
localparam [1:0] MACOP_MSB  = 2'd2;
localparam [1:0] MACOP_MACI = 2'd3;

localparam [3:0] LSUOP_NOP = 4'd0;
localparam [3:0] LSUOP_LWZ = 4'd1;
localparam [3:0] LSUOP_LWS = 4'd2;
localparam [3:0] LSUOP_LBZ = 4'd3;
localparam [3:0] LSUOP_LBS = 4'd4;
localparam [3:0] LSUOP_LHZ = 4'd5;
localparam [3:0] LSUOP_LHS = 4'd6;
localparam [3:0] LSUOP_SW  = 4'd8;
localparam [3:0] LSUOP_SB  = 4'd9;
localparam [3:0] LSUOP_SH  = 4'd10;

localparam [2:0] RFWBOP_NOP   = 3'd0;
localparam [2:0] RFWBOP_ALU   = 3'd1;
localparam [2:0] RFWBOP_LSU   = 3'd2;
localparam [2:0] RFWBOP_SPR   = 3'd3;
localparam [2:0] RFWBOP_LR    = 3'd4;
localparam [2:0] RFWBOP_CUST5 = 3'd5;

localparam [1:0] OR1200_ONE_CYCLE = 2'b00;

`ifdef OR1200_MAC_IMPLEMENTED
localparam FEATURE_MAC = 1'b1;
`elsif OR1200_MAC
localparam FEATURE_MAC = 1'b1;
`else
localparam FEATURE_MAC = 1'b0;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
localparam FEATURE_MULT = 1'b1;
`elsif OR1200_MULT
localparam FEATURE_MULT = 1'b1;
`else
localparam FEATURE_MULT = 1'b0;
`endif

`ifdef OR1200_CUST5_IMPLEMENTED
localparam FEATURE_CUST5 = 1'b1;
`elsif OR1200_IMPL_CUST5
localparam FEATURE_CUST5 = 1'b1;
`else
localparam FEATURE_CUST5 = 1'b0;
`endif

reg [31:0] id_insn;
reg [2:0]  pre_branch_op;
reg [4:0]  wb_rfaddrw;
reg        sel_imm;
reg        sig_trap_r;

wire [5:0] if_op = if_insn[31:26];
wire [5:0] id_op = id_insn[31:26];
wire [5:0] ex_op = ex_insn[31:26];

wire       id_void = id_insn[16];
wire       imm_signextend;

wire [15:0] lsu_imm_store = {ex_insn[25:21], ex_insn[10:0]};
wire [15:0] lsu_imm_load  = {ex_insn[15:11], ex_insn[10:0]};

assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda   = if_insn[31];
assign rf_rdb   = if_insn[30];

function [2:0] f_pre_branch_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_J:      f_pre_branch_op = BRANCHOP_J;
            OP_JAL:    f_pre_branch_op = BRANCHOP_BAL;
            OP_JR:     f_pre_branch_op = BRANCHOP_JR;
            OP_JALR:   f_pre_branch_op = BRANCHOP_BAL;
            OP_BF:     f_pre_branch_op = BRANCHOP_BF;
            OP_BNF:    f_pre_branch_op = BRANCHOP_BNF;
            OP_RFE:    f_pre_branch_op = BRANCHOP_RFE;
            default:   f_pre_branch_op = BRANCHOP_NOP;
        endcase
    end
endfunction

function f_sel_imm;
    input [5:0] op;
    begin
        case (op)
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
            OP_MACMSB: f_sel_imm = 1'b0;
            default:   f_sel_imm = 1'b1;
        endcase
    end
endfunction

function f_imm_signext;
    input [5:0] op;
    begin
        case (op)
            OP_ADDI,
            OP_ADDIC,
            OP_XORI,
            OP_SFXXI:  f_imm_signext = 1'b1;
            OP_MULI:   f_imm_signext = FEATURE_MULT;
            OP_MACI:   f_imm_signext = FEATURE_MAC;
            default:   f_imm_signext = 1'b0;
        endcase
    end
endfunction

function [3:0] f_decode_alu_op;
    input [31:0] insn;
    reg [5:0] op;
    begin
        op = insn[31:26];
        case (op)
            OP_MOVHI:                 f_decode_alu_op = ALUOP_MOVHI;
            OP_MFSPR, OP_MTSPR:       f_decode_alu_op = ALUOP_SPR;
            OP_ADDI,
            OP_ADDIC,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_MULI,
            OP_MACI,
            OP_LWZ, OP_LWS, OP_LBZ, OP_LBS, OP_LHZ, OP_LHS,
            OP_SW, OP_SB, OP_SH:      f_decode_alu_op = ALUOP_IMM;
            OP_SHROTI:                f_decode_alu_op = ALUOP_SHROT;
            OP_SFXX, OP_SFXXI:        f_decode_alu_op = ALUOP_COMP;
            OP_ALU:                   f_decode_alu_op = ALUOP_ALU;
            OP_CUST5:                 f_decode_alu_op = FEATURE_CUST5 ? ALUOP_CUST5 : ALUOP_NOP;
            default:                  f_decode_alu_op = ALUOP_NOP;
        endcase
    end
endfunction

function [1:0] f_decode_mac_op;
    input [31:0] insn;
    reg [5:0] op;
    begin
        op = insn[31:26];
        if (!FEATURE_MAC) begin
            f_decode_mac_op = MACOP_NOP;
        end
        else begin
            case (op)
                OP_MACI:   f_decode_mac_op = MACOP_MACI;
                OP_MACMSB: f_decode_mac_op = insn[1] ? MACOP_MSB : MACOP_MAC;
                default:   f_decode_mac_op = MACOP_NOP;
            endcase
        end
    end
endfunction

function [3:0] f_decode_lsu_op;
    input [31:0] insn;
    begin
        case (insn[31:26])
            OP_LWZ:   f_decode_lsu_op = LSUOP_LWZ;
            OP_LWS:   f_decode_lsu_op = LSUOP_LWS;
            OP_LBZ:   f_decode_lsu_op = LSUOP_LBZ;
            OP_LBS:   f_decode_lsu_op = LSUOP_LBS;
            OP_LHZ:   f_decode_lsu_op = LSUOP_LHZ;
            OP_LHS:   f_decode_lsu_op = LSUOP_LHS;
            OP_SW:    f_decode_lsu_op = LSUOP_SW;
            OP_SB:    f_decode_lsu_op = LSUOP_SB;
            OP_SH:    f_decode_lsu_op = LSUOP_SH;
            default:  f_decode_lsu_op = LSUOP_NOP;
        endcase
    end
endfunction

function [2:0] f_decode_rfwb_op;
    input [31:0] insn;
    reg [5:0] op;
    begin
        op = insn[31:26];
        case (op)
            OP_JAL,
            OP_JALR:                  f_decode_rfwb_op = RFWBOP_LR;
            OP_MOVHI,
            OP_ADDI,
            OP_ADDIC,
            OP_ANDI,
            OP_ORI,
            OP_XORI,
            OP_SHROTI,
            OP_ALU:                   f_decode_rfwb_op = RFWBOP_ALU;
            OP_MULI:                  f_decode_rfwb_op = FEATURE_MULT ? RFWBOP_ALU : RFWBOP_NOP;
            OP_LWZ, OP_LWS, OP_LBZ,
            OP_LBS, OP_LHZ, OP_LHS:   f_decode_rfwb_op = RFWBOP_LSU;
            OP_MFSPR:                 f_decode_rfwb_op = RFWBOP_SPR;
            OP_CUST5:                 f_decode_rfwb_op = FEATURE_CUST5 ? RFWBOP_CUST5 : RFWBOP_NOP;
            default:                  f_decode_rfwb_op = RFWBOP_NOP;
        endcase
    end
endfunction

function f_is_syscall;
    input [31:0] insn;
    begin
        f_is_syscall = (insn[31:26] == OP_MISC) && (insn[25:24] == 2'b00);
    end
endfunction

function f_is_trap;
    input [31:0] insn;
    begin
        f_is_trap = (insn[31:26] == OP_MISC) && (insn[25:24] == 2'b01);
    end
endfunction

function f_is_legal;
    input [31:0] insn;
    reg [5:0] op;
    begin
        op = insn[31:26];
        case (op)
            OP_J, OP_JAL, OP_BNF, OP_BF, OP_NOP, OP_MOVHI, OP_MISC, OP_RFE,
            OP_JR, OP_JALR,
            OP_LWZ, OP_LWS, OP_LBZ, OP_LBS, OP_LHZ, OP_LHS,
            OP_ADDI, OP_ADDIC, OP_ANDI, OP_ORI, OP_XORI,
            OP_MFSPR, OP_SHROTI, OP_SFXXI, OP_MTSPR,
            OP_SW, OP_SB, OP_SH,
            OP_ALU, OP_SFXX:          f_is_legal = 1'b1;
            OP_MULI:                  f_is_legal = FEATURE_MULT;
            OP_MACI, OP_MACMSB:       f_is_legal = FEATURE_MAC;
            OP_CUST5:                 f_is_legal = FEATURE_CUST5;
            default:                  f_is_legal = 1'b0;
        endcase
    end
endfunction

assign imm_signextend = f_imm_signext(id_op);
assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'h0000, id_insn[15:0]};

assign multicycle = (id_op == OP_ALU) ? id_insn[9:8] : OR1200_ONE_CYCLE;

assign branch_addrofs = {{4{ex_insn[25]}}, ex_insn[25:0]};
assign lsu_addrofs = ((ex_op == OP_SW) || (ex_op == OP_SB) || (ex_op == OP_SH)) ?
                     {{16{lsu_imm_store[15]}}, lsu_imm_store} :
                     {{16{lsu_imm_load[15]}}, lsu_imm_load};

assign cust5_op   = ex_insn[4:0];
assign cust5_limm = ex_insn[15:10];

assign ex_void = ex_insn[16];

assign id_macrc_op = FEATURE_MAC && (id_op == OP_ALU) && (id_insn[9:6] == 4'b1111);

assign force_dslot_fetch = 1'b0;
assign no_more_dslot = (((branch_op != BRANCHOP_NOP) && !id_void && branch_taken) ||
                        (branch_op == BRANCHOP_RFE));
assign rfe = (pre_branch_op == BRANCHOP_RFE) || (branch_op == BRANCHOP_RFE);
assign sig_trap = sig_trap_r | du_hwbkpt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_insn        <= OR1200_NOP_INSN;
        pre_branch_op  <= BRANCHOP_NOP;
        sel_imm        <= 1'b1;
    end
    else begin
        if (flushpipe) begin
            id_insn       <= OR1200_NOP_INSN;
            pre_branch_op <= BRANCHOP_NOP;
        end
        else if (!id_freeze) begin
            id_insn       <= if_insn;
            pre_branch_op <= f_pre_branch_op(if_insn);
        end

        if (!id_freeze)
            sel_imm <= f_sel_imm(if_op);
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ex_insn         <= OR1200_NOP_INSN;
        branch_op       <= BRANCHOP_NOP;
        alu_op          <= ALUOP_NOP;
        mac_op          <= MACOP_NOP;
        shrot_op        <= 2'b00;
        comp_op         <= 4'h0;
        lsu_op          <= LSUOP_NOP;
        rfwb_op         <= RFWBOP_NOP;
        spr_addrimm     <= 16'h0000;
        sig_syscall     <= 1'b0;
        sig_trap_r      <= 1'b0;
        ex_macrc_op     <= 1'b0;
        except_illegal  <= 1'b0;
    end
    else if (!ex_freeze) begin
        if (flushpipe || id_freeze) begin
            ex_insn         <= OR1200_NOP_INSN;
            branch_op       <= BRANCHOP_NOP;
            alu_op          <= ALUOP_NOP;
            mac_op          <= MACOP_NOP;
            shrot_op        <= 2'b00;
            comp_op         <= 4'h0;
            lsu_op          <= LSUOP_NOP;
            rfwb_op         <= RFWBOP_NOP;
            spr_addrimm     <= 16'h0000;
            sig_syscall     <= 1'b0;
            sig_trap_r      <= 1'b0;
            ex_macrc_op     <= 1'b0;
            except_illegal  <= 1'b0;
        end
        else begin
            ex_insn         <= id_insn;
            branch_op       <= pre_branch_op;
            alu_op          <= f_decode_alu_op(id_insn);
            mac_op          <= f_decode_mac_op(id_insn);
            shrot_op        <= id_insn[7:6];
            comp_op         <= id_insn[24:21];
            lsu_op          <= f_decode_lsu_op(id_insn);
            rfwb_op         <= f_decode_rfwb_op(id_insn);
            spr_addrimm     <= (id_op == OP_MFSPR) ? id_insn[15:0] : {id_insn[25:21], id_insn[10:0]};
            sig_syscall     <= f_is_syscall(id_insn);
            sig_trap_r      <= f_is_trap(id_insn);
            ex_macrc_op     <= id_macrc_op;
            except_illegal  <= !f_is_legal(id_insn);
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_addrw <= 5'd0;
    end
    else if (!ex_freeze && !id_freeze) begin
        if ((pre_branch_op == BRANCHOP_JR) || (pre_branch_op == BRANCHOP_BAL))
            rf_addrw <= 5'd9;
        else
            rf_addrw <= id_insn[25:21];
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wb_insn <= OR1200_NOP_INSN;
    end
    else if (flushpipe) begin
        wb_insn <= OR1200_NOP_INSN;
    end
    else if (!wb_freeze) begin
        wb_insn <= ex_insn;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        wb_rfaddrw <= 5'd0;
    end
    else if (!wb_freeze) begin
        wb_rfaddrw <= rf_addrw;
    end
end

always @* begin
    sel_a = SEL_RF;
    if (rf_rda && (rf_addra != 5'd0)) begin
        if ((rfwb_op != RFWBOP_NOP) && (rf_addra == rf_addrw))
            sel_a = SEL_EX;
        else if (wbforw_valid && (rf_addra == wb_rfaddrw))
            sel_a = SEL_WB;
    end
end

always @* begin
    if (sel_imm) begin
        sel_b = SEL_IMM;
    end
    else begin
        sel_b = SEL_RF;
        if (rf_rdb && (rf_addrb != 5'd0)) begin
            if ((rfwb_op != RFWBOP_NOP) && (rf_addrb == rf_addrw))
                sel_b = SEL_EX;
            else if (wbforw_valid && (rf_addrb == wb_rfaddrw))
                sel_b = SEL_WB;
        end
    end
end

endmodule
