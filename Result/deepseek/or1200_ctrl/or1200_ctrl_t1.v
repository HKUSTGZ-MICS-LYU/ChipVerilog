module or1200_ctrl(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
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
    output [4:0] rf_addrw,
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
    output reg [1:0] multicycle,
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

    // OR1200 NOP encoding: bit 16 is set.
    localparam OR1200_NOP = 32'h0000_0000 | 32'h0001_0000;

    // Branch opcodes
    localparam BRANCH_OP_NOP = 3'd0;
    localparam BRANCH_OP_J   = 3'd1;
    localparam BRANCH_OP_JR  = 3'd2;
    localparam BRANCH_OP_BAL = 3'd3;
    localparam BRANCH_OP_BF  = 3'd4;
    localparam BRANCH_OP_BNF = 3'd5;
    localparam BRANCH_OP_RFE = 3'd6;

    // ALU opcodes
    localparam ALU_OP_NOP    = 4'd0;
    localparam ALU_OP_IMM    = 4'd1;
    localparam ALU_OP_MOVHI  = 4'd2;
    localparam ALU_OP_SPR    = 4'd3;
    localparam ALU_OP_ARITH  = 4'd4;
    localparam ALU_OP_LOGIC  = 4'd5;
    localparam ALU_OP_SHROT  = 4'd6;
    localparam ALU_OP_COMP   = 4'd7;
    localparam ALU_OP_CUST   = 4'd8;

    // LSU opcodes
    localparam LSU_OP_NOP     = 4'd0;
    localparam LSU_OP_LW      = 4'd1;
    localparam LSU_OP_LH      = 4'd2;
    localparam LSU_OP_LB      = 4'd3;
    localparam LSU_OP_LHU     = 4'd4;
    localparam LSU_OP_LBU     = 4'd5;
    localparam LSU_OP_SW      = 4'd6;
    localparam LSU_OP_SH      = 4'd7;
    localparam LSU_OP_SB      = 4'd8;

    // MAC opcodes
    localparam MAC_OP_NOP = 2'd0;
    localparam MAC_OP_MAC = 2'd1;
    localparam MAC_OP_MSB = 2'd2;
    localparam MAC_OP_MACI= 2'd3;

    // Write-back opcodes
    localparam RFWB_OP_NOP  = 3'd0;
    localparam RFWB_OP_ALU  = 3'd1;
    localparam RFWB_OP_LSU  = 3'd2;
    localparam RFWB_OP_SPR  = 3'd3;
    localparam RFWB_OP_MAC  = 3'd4;
    localparam RFWB_OP_LR   = 3'd5;

    // Multi-cycle codes
    localparam OR1200_ONE_CYCLE = 2'd0;
    localparam OR1200_TWO_CYCLE = 2'd1;

    // Pipeline registers
    reg [31:0] id_insn;
    reg [31:0] wb_rfaddrw;

    // ID stage combinational signals
    wire id_void;
    wire [2:0] pre_branch_op;
    wire imm_signextend;
    wire sel_imm;
    wire [4:0] ex_dest;
    wire [4:0] wb_dest;
    reg [1:0] sel_a;
    reg [1:0] sel_b;
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda = if_insn[31];
    assign rf_rdb = if_insn[30];

    // Immediate generation
    reg [31:0] simm;
    wire [31:0] sign_ext_imm;
    wire [31:0] zero_ext_imm;

    // ID void detection
    assign id_void = id_insn[16];

    // EX void detection
    assign ex_void = ex_insn[16];

    // Destination registers for forwarding
    assign ex_dest = ex_insn[25:21];
    assign wb_dest = wb_rfaddrw;

    // Immediate sign/zero extension
    assign sign_ext_imm = {{16{id_insn[15]}}, id_insn[15:0]};
    assign zero_ext_imm = {16'd0, id_insn[15:0]};

    // Immediate sign-extension selection
    assign imm_signextend = (id_insn[31:26] == 6'b111000) ||   // l.addi
                            (id_insn[31:26] == 6'b111001) ||   // l.addic
                            (id_insn[31:26] == 6'b111100) ||   // l.xori
                            (id_insn[31:26] == 6'b111101) ||   // l.muli (if present)
                            (id_insn[31:26] == 6'b111110) ||   // l.maci (if present)
                            (id_insn[31:26] == 6'b111111);     // immediate compares

    // Immediate select decode
    assign sel_imm = !((id_insn[31:26] == 6'b111000) ||   // l.addi
                       (id_insn[31:26] == 6'b111001) ||   // l.addic
                       (id_insn[31:26] == 6'b111010) ||   // l.andi
                       (id_insn[31:26] == 6'b111011) ||   // l.ori
                       (id_insn[31:26] == 6'b111100) ||   // l.xori
                       (id_insn[31:26] == 6'b111101) ||   // l.muli
                       (id_insn[31:26] == 6'b111110) ||   // l.maci
                       (id_insn[31:26] == 6'b111111) ||   // immediate compares
                       (id_insn[31:26] == 6'b000000) ||   // l.j/l.jal/l.jr/l.jalr/l.bnf/l.bf
                       (id_insn[31:26] == 6'b001000) ||   // l.nop
                       (id_insn[31:26] == 6'b001001) ||   // l.movhi
                       (id_insn[31:26] == 6'b001010) ||   // l.mfspr
                       (id_insn[31:26] == 6'b001011) ||   // l.mtspr
                       (id_insn[31:26] == 6'b001100) ||   // l.sys
                       (id_insn[31:26] == 6'b001101) ||   // l.trap
                       (id_insn[31:26] == 6'b001110) ||   // l.rfe
                       (id_insn[31:26] == 6'b001111) ||   // l.cust5
                       (id_insn[31:26] == 6'b010000) ||   // l.mac
                       (id_insn[31:26] == 6'b010001) ||   // l.msb
                       (id_insn[31:26] == 6'b010010) ||   // l.macrc
                       (id_insn[31:26] == 6'b100000) ||   // l.lw
                       (id_insn[31:26] == 6'b100001) ||   // l.lh
                       (id_insn[31:26] == 6'b100010) ||   // l.lb
                       (id_insn[31:26] == 6'b100011) ||   // l.lhu
                       (id_insn[31:26] == 6'b100100) ||   // l.lbu
                       (id_insn[31:26] == 6'b100101) ||   // l.sw
                       (id_insn[31:26] == 6'b100110) ||   // l.sh
                       (id_insn[31:26] == 6'b100111) ||   // l.sb
                       (id_insn[31:26] == 6'b110000) ||   // l.sfxx
                       (id_insn[31:26] == 6'b110001) ||   // l.bf
                       (id_insn[31:26] == 6'b110010) ||   // l.bnf
                       (id_insn[31:26] == 6'b110011) ||   // l.cust1-l.cust4
                       (id_insn[31:26] == 6'b110100) ||
                       (id_insn[31:26] == 6'b110101) ||
                       (id_insn[31:26] == 6'b110110) ||
                       (id_insn[31:26] == 6'b110111));

    // Forwarding selection for operand A
    always @* begin
        if (rf_addra == 5'd0)
            sel_a = 2'd0; // use register file (R0 hardwired to 0)
        else if (rf_addra == ex_dest && rfwb_op != RFWB_OP_NOP && !ex_void)
            sel_a = 2'd1; // EX forwarding
        else if (rf_addra == wb_dest && wbforw_valid)
            sel_a = 2'd2; // WB forwarding
        else
            sel_a = 2'd0;
    end

    // Forwarding selection for operand B
    always @* begin
        if (sel_imm)
            sel_b = 2'd3; // Immediate
        else if (rf_addrb == 5'd0)
            sel_b = 2'd0;
        else if (rf_addrb == ex_dest && rfwb_op != RFWB_OP_NOP && !ex_void)
            sel_b = 2'd1;
        else if (rf_addrb == wb_dest && wbforw_valid)
            sel_b = 2'd2;
        else
            sel_b = 2'd0;
    end

    // Immediate value generation
    always @* begin
        if (imm_signextend)
            simm = sign_ext_imm;
        else
            simm = zero_ext_imm;
    end

    // Pre-branch decode
    assign pre_branch_op = id_freeze ? BRANCH_OP_NOP :
                           (if_insn[31:26] == 6'b000000) ? (
                               (if_insn[25:21] == 5'd9 && if_insn[15:11] == 5'd9) ? BRANCH_OP_JR :
                               (if_insn[25:21] == 5'd9) ? BRANCH_OP_BAL :
                               (if_insn[15:11] == 5'd9) ? BRANCH_OP_JR :
                               BRANCH_OP_J
                           ) :
                           (if_insn[31:26] == 6'b110001) ? BRANCH_OP_BF :
                           (if_insn[31:26] == 6'b110010) ? BRANCH_OP_BNF :
                           (if_insn[31:26] == 6'b001110) ? BRANCH_OP_RFE :
                           BRANCH_OP_NOP;

    // RFE signal
    assign rfe = (pre_branch_op == BRANCH_OP_RFE) || (branch_op == BRANCH_OP_RFE);

    // No more delay slot logic
    assign no_more_dslot = ((pre_branch_op != BRANCH_OP_NOP && !id_void && branch_taken) ||
                            (pre_branch_op == BRANCH_OP_RFE));

    // Force delay slot fetch (hardwired to 0 as per spec)
    assign force_dslot_fetch = 1'b0;

    // MAC result read detection
    assign id_macrc_op = (id_insn[31:26] == 6'b010010); // l.macrc

    // Write-back destination generation
    assign rf_addrw = (pre_branch_op == BRANCH_OP_JR || pre_branch_op == BRANCH_OP_BAL) ? 5'd9 : id_insn[25:21];

    // Branch offset generation
    assign branch_addrofs = {{6{ex_insn[25]}}, ex_insn[25:0]};

    // LSU offset generation
    assign lsu_addrofs = (ex_insn[31:26] == 6'b100101 || ex_insn[31:26] == 6'b100110 || ex_insn[31:26] == 6'b100111) ?
                         {{16{ex_insn[25]}}, ex_insn[25:21], ex_insn[10:0]} :
                         {{16{ex_insn[15]}}, ex_insn[15:11], ex_insn[10:0]};

    // Custom instruction outputs
    assign cust5_op = ex_insn[25:21];
    assign cust5_limm = ex_insn[5:0];

    // Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_insn <= OR1200_NOP;
            ex_insn <= OR1200_NOP;
            wb_insn <= OR1200_NOP;
            alu_op <= ALU_OP_NOP;
            mac_op <= MAC_OP_NOP;
            shrot_op <= 2'd0;
            comp_op <= 4'd0;
            rfwb_op <= RFWB_OP_NOP;
            branch_op <= BRANCH_OP_NOP;
            lsu_op <= LSU_OP_NOP;
            multicycle <= OR1200_ONE_CYCLE;
            spr_addrimm <= 16'd0;
            sig_syscall <= 1'b0;
            sig_trap <= 1'b0;
            except_illegal <= 1'b0;
            ex_macrc_op <= 1'b0;
            wb_rfaddrw <= 5'd0;
        end else begin
            if (flushpipe) begin
                id_insn <= OR1200_NOP;
                ex_insn <= OR1200_NOP;
                wb_insn <= OR1200_NOP;
                alu_op <= ALU_OP_NOP;
                mac_op <= MAC_OP_NOP;
                shrot_op <= 2'd0;
                comp_op <= 4'd0;
                rfwb_op <= RFWB_OP_NOP;
                branch_op <= BRANCH_OP_NOP;
                lsu_op <= LSU_OP_NOP;
                multicycle <= OR1200_ONE_CYCLE;
                spr_addrimm <= 16'd0;
                sig_syscall <= 1'b0;
                sig_trap <= 1'b0;
                except_illegal <= 1'b0;
                ex_macrc_op <= 1'b0;
                wb_rfaddrw <= 5'd0;
            end else begin
                // ID stage update
                if (!id_freeze) begin
                    id_insn <= if_insn;
                end
                // EX stage update
                if (!ex_freeze) begin
                    if (id_freeze) begin
                        // Insert NOP into EX when ID is frozen
                        ex_insn <= OR1200_NOP;
                        alu_op <= ALU_OP_NOP;
                        mac_op <= MAC_OP_NOP;
                        shrot_op <= 2'd0;
                        comp_op <= 4'd0;
                        rfwb_op <= RFWB_OP_NOP;
                        branch_op <= BRANCH_OP_NOP;
                        lsu_op <= LSU_OP_NOP;
                        multicycle <= OR1200_ONE_CYCLE;
                        spr_addrimm <= 16'd0;
                        sig_syscall <= 1'b0;
                        sig_trap <= 1'b0;
                        except_illegal <= 1'b0;
                        ex_macrc_op <= 1'b0;
                    end else begin
                        ex_insn <= id_insn;
                        ex_macrc_op <= id_macrc_op;
                        branch_op <= pre_branch_op;

                        // Decode signals from id_insn
                        case (id_insn[31:26])
                            6'b111000: begin // l.addi
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111001: begin // l.addic
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111010: begin // l.andi
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111011: begin // l.ori
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111100: begin // l.xori
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111101: begin // l.muli
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b111110: begin // l.maci
                                alu_op <= ALU_OP_IMM;
                                rfwb_op <= RFWB_OP_ALU;
                                mac_op <= MAC_OP_MACI;
                            end
                            6'b111111: begin // immediate compare
                                alu_op <= ALU_OP_COMP;
                                comp_op <= id_insn[24:21];
                                rfwb_op <= RFWB_OP_NOP;
                            end
                            6'b000000: begin // branch/jump
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                // Write-back for JAL/JALR
                                if ((id_insn[25:21] == 5'd9 && id_insn[15:11] != 5'd9) ||
                                    (id_insn[15:11] == 5'd9 && id_insn[25:21] != 5'd9))
                                    rfwb_op <= RFWB_OP_LR;
                            end
                            6'b001000: begin // l.nop
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                            end
                            6'b001001: begin // l.movhi
                                alu_op <= ALU_OP_MOVHI;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b001010: begin // l.mfspr
                                alu_op <= ALU_OP_SPR;
                                rfwb_op <= RFWB_OP_SPR;
                                spr_addrimm <= id_insn[15:0];
                            end
                            6'b001011: begin // l.mtspr
                                alu_op <= ALU_OP_SPR;
                                rfwb_op <= RFWB_OP_NOP;
                                spr_addrimm <= {id_insn[25:21], id_insn[10:0]};
                            end
                            6'b001100: begin // l.sys
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                sig_syscall <= 1'b1;
                            end
                            6'b001101: begin // l.trap
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                sig_trap <= 1'b1;
                            end
                            6'b001110: begin // l.rfe
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                            end
                            6'b001111: begin // l.cust5
                                alu_op <= ALU_OP_CUST;
                                rfwb_op <= RFWB_OP_ALU;
                            end
                            6'b010000: begin // l.mac
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                mac_op <= MAC_OP_MAC;
                            end
                            6'b010001: begin // l.msb
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                mac_op <= MAC_OP_MSB;
                            end
                            6'b010010: begin // l.macrc
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_MAC;
                            end
                            6'b100000: begin // l.lw
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_LSU;
                                lsu_op <= LSU_OP_LW;
                            end
                            6'b100001: begin // l.lh
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_LSU;
                                lsu_op <= LSU_OP_LH;
                            end
                            6'b100010: begin // l.lb
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_LSU;
                                lsu_op <= LSU_OP_LB;
                            end
                            6'b100011: begin // l.lhu
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_LSU;
                                lsu_op <= LSU_OP_LHU;
                            end
                            6'b100100: begin // l.lbu
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_LSU;
                                lsu_op <= LSU_OP_LBU;
                            end
                            6'b100101: begin // l.sw
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                lsu_op <= LSU_OP_SW;
                            end
                            6'b100110: begin // l.sh
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                lsu_op <= LSU_OP_SH;
                            end
                            6'b100111: begin // l.sb
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                                lsu_op <= LSU_OP_SB;
                            end
                            6'b110000: begin // l.sfxx
                                alu_op <= ALU_OP_COMP;
                                comp_op <= id_insn[24:21];
                                rfwb_op <= RFWB_OP_NOP;
                            end
                            6'b110001, 6'b110010: begin // l.bf, l.bnf
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                            end
                            default: begin
                                alu_op <= ALU_OP_NOP;
                                rfwb_op <= RFWB_OP_NOP;
                            end
                        endcase

                        // Shift/rotate op
                        shrot_op <= id_insn[7:6];

                        // Multi-cycle decode
                        if (id_insn[31:26] == 6'b111000 && id_insn[9:8] == 2'd1)
                            multicycle <= OR1200_TWO_CYCLE;
                        else
                            multicycle <= OR1200_ONE_CYCLE;

                        // Illegal instruction detection
                        except_illegal <= !((id_insn[31:26] == 6'b111000) ||   // l.addi
                                             (id_insn[31:26] == 6'b111001) ||   // l.addic
                                             (id_insn[31:26] == 6'b111010) ||   // l.andi
                                             (id_insn[31:26] == 6'b111011) ||   // l.ori
                                             (id_insn[31:26] == 6'b111100) ||   // l.xori
                                             (id_insn[31:26] == 6'b111101) ||   // l.muli
                                             (id_insn[31:26] == 6'b111110) ||   // l.maci
                                             (id_insn[31:26] == 6'b111111) ||   // immediate compares
                                             (id_insn[31:26] == 6'b000000) ||   // branches
                                             (id_insn[31:26] == 6'b001000) ||   // l.nop
                                             (id_insn[31:26] == 6'b001001) ||   // l.movhi
                                             (id_insn[31:26] == 6'b001010) ||   // l.mfspr
                                             (id_insn[31:26] == 6'b001011) ||   // l.mtspr
                                             (id_insn[31:26] == 6'b001100) ||   // l.sys
                                             (id_insn[31:26] == 6'b001101) ||   // l.trap
                                             (id_insn[31:26] == 6'b001110) ||   // l.rfe
                                             (id_insn[31:26] == 6'b001111) ||   // l.cust5
                                             (id_insn[31:26] == 6'b010000) ||   // l.mac
                                             (id_insn[31:26] == 6'b010001) ||   // l.msb
                                             (id_insn[31:26] == 6'b010010) ||   // l.macrc
                                             (id_insn[31:26] == 6'b100000) ||   // l.lw
                                             (id_insn[31:26] == 6'b100001) ||   // l.lh
                                             (id_insn[31:26] == 6'b100010) ||   // l.lb
                                             (id_insn[31:26] == 6'b100011) ||   // l.lhu
                                             (id_insn[31:26] == 6'b100100) ||   // l.lbu
                                             (id_insn[31:26] == 6'b100101) ||   // l.sw
                                             (id_insn[31:26] == 6'b100110) ||   // l.sh
                                             (id_insn[31:26] == 6'b100111) ||   // l.sb
                                             (id_insn[31:26] == 6'b110000) ||   // l.sfxx
                                             (id_insn[31:26] == 6'b110001) ||   // l.bf
                                             (id_insn[31:26] == 6'b110010) ||   // l.bnf
                                             (id_insn[31:26] == 6'b110011) ||   // l.cust1
                                             (id_insn[31:26] == 6'b110100) ||   // l.cust2
                                             (id_insn[31:26] == 6'b110101) ||   // l.cust3
                                             (id_insn[31:26] == 6'b110110) ||   // l.cust4
                                             (id_insn[31:26] == 6'b110111));    // l.cust5
                    end
                end
                // WB stage update
                if (!wb_freeze) begin
                    wb_insn <= ex_insn;
                    wb_rfaddrw <= ex_insn[25:21];
                end

                // Trap from debug unit
                if (du_hwbkpt)
                    sig_trap <= 1'b1;
            end
        end
    end

endmodule
