module or1200_ctrl (
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

    // Parameters
    localparam [5:0] OR1200_OR32_ALU   = 6'b011100;
    localparam [5:0] OR1200_OR32_MEM   = 6'b100100;
    localparam [5:0] OR1200_OR32_BR    = 6'b000100;
    localparam [5:0] OR1200_OR32_SFXX  = 6'b111010; // system/SPR
    localparam [5:0] OR1200_OR32_CUST5 = 6'b001010;
    localparam [5:0] OR1200_OR32_MAC   = 6'b000010;
    localparam [5:0] OR1200_OR32_RFE   = 6'b001001;
    localparam [5:0] OR1200_OR32_TRAP  = 6'b001000;
    localparam [5:0] OR1200_OR32_SYNC  = 6'b001011;

    // NOP encoding: bit 16 set => 32'h15010000
    localparam [31:0] OR1200_NOP = 32'h15010000;

    // Opcode groups for sel_imm exclusion
    localparam [5:0] OR1200_OR32_REG   = 6'b011100; // register-type ALU
    localparam [5:0] OR1200_OR32_JAL   = 6'b000100; // branch and link
    localparam [5:0] OR1200_OR32_JALR  = 6'b010010; // not standard; use alternate
    localparam [5:0] OR1200_OR32_MFSPR = 6'b111010; // SPR read
    localparam [5:0] OR1200_OR32_MTSPR = 6'b111010; // SPR write (same opcode)
    localparam [5:0] OR1200_OR32_LWZ   = 6'b100100; // load
    localparam [5:0] OR1200_OR32_SW    = 6'b110100; // store
    localparam [5:0] OR1200_OR32_SFXX_IMM = 6'b111010; // SFXX with immediate compare?

    // Other internal constants
    localparam [1:0] ONE_CYCLE = 2'b00;
    localparam [1:0] TWO_CYCLE = 2'b01;
    localparam [1:0] THREE_CYCLE = 2'b10;

    // Instruction pipeline registers
    reg [31:0] id_insn;
    reg [31:0] ex_insn_reg;
    reg [31:0] wb_insn_reg;

    // Control registers (EX stage)
    reg [3:0] alu_op_reg;
    reg [1:0] mac_op_reg;
    reg [1:0] shrot_op_reg;
    reg [3:0] comp_op_reg;
    reg [4:0] rf_addrw_reg;
    reg [2:0] rfwb_op_reg;
    reg [2:0] branch_op_reg;
    reg [15:0] spr_addrimm_reg;
    reg sig_syscall_reg;
    reg sig_trap_reg;
    reg except_illegal_reg;
    reg ex_macrc_op_reg;
    reg [3:0] lsu_op_reg;

    // Other registers
    reg [4:0] wb_rfaddrw_reg;
    reg [31:0] branch_addrofs_comb;
    reg [31:0] lsu_addrofs_comb;
    reg [4:0] cust5_op_comb;
    reg [5:0] cust5_limm_comb;
    reg ex_void_comb;

    // For sel_imm, pre_branch_op, multicycle, id_macrc_op, forwarding
    reg sel_imm;
    reg [2:0] pre_branch_op;
    reg [1:0] multicycle_comb;
    reg id_macrc_op_comb;

    // Wire for forwarding (combinational)
    reg [1:0] sel_a_comb;
    reg [1:0] sel_b_comb;

    // Forwarding constants
    localparam SEL_RF_AB = 2'b00;
    localparam SEL_EX_FORWARD = 2'b01;
    localparam SEL_WB_FORWARD = 2'b10;
    localparam SEL_IMM = 2'b11;

    // Register-file read addresses and enables (direct from if_insn)
    assign rf_addra = if_insn[20:16];
    assign rf_addrb = if_insn[15:11];
    assign rf_rda = if_insn[31];
    assign rf_rdb = if_insn[30];

    // Pre-branch decode (combinational from if_insn, only when ID not frozen)
    always @(*) begin
        if (id_freeze) begin
            pre_branch_op = 3'b000; // keep previous
        end else begin
            case (if_insn[31:26])
                OR1200_OR32_BR: begin
                    case (if_insn[25:21])
                        5'b01000: pre_branch_op = 3'b001; // l.j
                        5'b01001: pre_branch_op = 3'b010; // l.jal
                        5'b01010: pre_branch_op = 3'b011; // l.jr
                        5'b01011: pre_branch_op = 3'b100; // l.jalr
                        5'b01100: pre_branch_op = 3'b101; // l.bnf
                        5'b01101: pre_branch_op = 3'b110; // l.bf
                        default: pre_branch_op = 3'b000;
                    endcase
                end
                OR1200_OR32_RFE: pre_branch_op = 3'b111; // rfe
                default: pre_branch_op = 3'b000;
            endcase
        end
    end

    // Immediate selection decode (combinational from id_insn)
    always @(*) begin
        if (id_freeze) begin
            sel_imm = 1'b0;
        end else begin
            case (id_insn[31:26])
                OR1200_OR32_ALU: sel_imm = 1'b0; // register ALU
                OR1200_OR32_BR: sel_imm = 1'b0; // branch/jump
                OR1200_OR32_SFXX: sel_imm = 1'b0; // SPR/cust
                OR1200_OR32_MEM: begin
                    if (id_insn[25:21] == 5'b00011) sel_imm = 1'b0; // store (l.sw)
                    else sel_imm = 1'b1; // load
                end
                OR1200_OR32_CUST5: sel_imm = 1'b0;
                OR1200_OR32_SYNC: sel_imm = 1'b0;
                OR1200_OR32_TRAP: sel_imm = 1'b0;
                // NOP detection: if id_insn[16] set and opcode 0x15
                (id_insn[31:26] == 6'b010101): sel_imm = 1'b0; // l.nop
                default: sel_imm = 1'b1;
            endcase
        end
    end

    // simm generation (combinational from id_insn)
    assign simm = (imm_signextend) ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'h0, id_insn[15:0]};

    reg imm_signextend;
    always @(*) begin
        if (id_freeze) begin
            imm_signextend = 1'b0;
        end else begin
            case (id_insn[31:26])
                OR1200_OR32_ALU: begin
                    case (id_insn[9:8])
                        2'b10: imm_signextend = 1'b1; // l.addi, l.addic
                        2'b01: imm_signextend = 1'b0; // l.andi, l.ori, l.xori
                        2'b11: imm_signextend = 1'b1; // l.muli (if multiply implemented)
                        default: imm_signextend = 1'b0;
                    endcase
                end
                OR1200_OR32_SFXX: begin
                    if (id_insn[25:21] == 5'b01000) // l.sf??i
                        imm_signextend = 1'b1;
                    else
                        imm_signextend = 1'b0;
                end
                OR1200_OR32_MAC: begin
                    if (id_insn[10] == 1'b1) // l.maci
                        imm_signextend = 1'b1;
                    else
                        imm_signextend = 1'b0;
                end
                default: imm_signextend = 1'b0;
            endcase
        end
    end

    // Forwarding selection logic
    wire [4:0] id_rs1 = id_insn[20:16];
    wire [4:0] id_rs2 = id_insn[15:11];
    wire [4:0] ex_rd = rf_addrw_reg;
    wire [4:0] wb_rd = wb_rfaddrw_reg;
    wire ex_valid = !ex_void_comb; // ex_void defined later
    wire wb_valid = wbforw_valid;

    always @(*) begin
        // sel_a
        if (rf_rda && (id_rs1 != 0)) begin
            if (sel_imm) begin
                sel_a_comb = SEL_IMM; // never for a, but keep
                // Actually sel_imm only affects sel_b, so we use normal
            end
            if (ex_valid && (id_rs1 == ex_rd)) begin
                sel_a_comb = SEL_EX_FORWARD;
            end else if (wb_valid && (id_rs1 == wb_rd)) begin
                sel_a_comb = SEL_WB_FORWARD;
            end else begin
                sel_a_comb = SEL_RF_AB;
            end
        end else begin
            sel_a_comb = SEL_RF_AB;
        end

        // sel_b
        if (sel_imm) begin
            sel_b_comb = SEL_IMM;
        end else if (rf_rdb && (id_rs2 != 0)) begin
            if (ex_valid && (id_rs2 == ex_rd)) begin
                sel_b_comb = SEL_EX_FORWARD;
            end else if (wb_valid && (id_rs2 == wb_rd)) begin
                sel_b_comb = SEL_WB_FORWARD;
            end else begin
                sel_b_comb = SEL_RF_AB;
            end
        end else begin
            sel_b_comb = SEL_RF_AB;
        end
    end

    assign sel_a = sel_a_comb;
    assign sel_b = sel_b_comb;

    // Multicycle decode (combinational from id_insn)
    always @(*) begin
        if (id_freeze) begin
            multicycle_comb = ONE_CYCLE;
        end else begin
            case (id_insn[31:26])
                OR1200_OR32_ALU: begin
                    multicycle_comb = (id_insn[9:8] == 2'b11) ? THREE_CYCLE : ONE_CYCLE;
                end
                OR1200_OR32_MEM: begin
                    multicycle_comb = TWO_CYCLE;
                end
                default: multicycle_comb = ONE_CYCLE;
            endcase
        end
    end
    assign multicycle = multicycle_comb;

    // id_macrc_op
    always @(*) begin
        if (MAC_IMPLEMENTED && (id_insn[31:26] == OR1200_OR32_MAC) && (id_insn[10] == 1'b0) && (id_insn[9] == 1'b0)) begin
            id_macrc_op_comb = 1'b1;
        end else begin
            id_macrc_op_comb = 1'b0;
        end
    end
    assign id_macrc_op = id_macrc_op_comb;

    // --- Pipeline registers (sequential) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_insn <= OR1200_NOP;
            ex_insn_reg <= OR1200_NOP;
            wb_insn_reg <= OR1200_NOP;
            // Control registers
            alu_op_reg <= 4'd0;
            mac_op_reg <= 2'd0;
            shrot_op_reg <= 2'd0;
            comp_op_reg <= 4'd0;
            rf_addrw_reg <= 5'd0;
            rfwb_op_reg <= 3'd0;
            branch_op_reg <= 3'd0;
            spr_addrimm_reg <= 16'd0;
            sig_syscall_reg <= 1'b0;
            sig_trap_reg <= 1'b0;
            except_illegal_reg <= 1'b0;
            ex_macrc_op_reg <= 1'b0;
            lsu_op_reg <= 4'd0;
            wb_rfaddrw_reg <= 5'd0;
        end else begin
            // ID stage
            if (flushpipe || (id_freeze && !ex_freeze)) begin
                id_insn <= OR1200_NOP;
            end else if (!id_freeze) begin
                id_insn <= if_insn;
            end

            // EX stage (and control regs)
            if (flushpipe || (!ex_freeze && (id_freeze || flushpipe))) begin
                ex_insn_reg <= OR1200_NOP;
                alu_op_reg <= 4'd0;
                mac_op_reg <= 2'd0;
                shrot_op_reg <= 2'd0;
                comp_op_reg <= 4'd0;
                rf_addrw_reg <= 5'd0;
                rfwb_op_reg <= 3'd0;
                branch_op_reg <= 3'd0;
                spr_addrimm_reg <= 16'd0;
                sig_syscall_reg <= 1'b0;
                sig_trap_reg <= 1'b0;
                except_illegal_reg <= 1'b0;
                ex_macrc_op_reg <= 1'b0;
                lsu_op_reg <= 4'd0;
            end else if (!ex_freeze) begin
                ex_insn_reg <= id_insn;
                // decode id_insn to control signals and register
                // We'll do that in a function later, but for now, we have a separate always_comb block
                // Actually better to decode here or use a separate assign.
            end

            // WB stage
            if (flushpipe || (!wb_freeze && (ex_freeze || flushpipe))) begin
                wb_insn_reg <= OR1200_NOP;
                wb_rfaddrw_reg <= 5'd0;
            end else if (!wb_freeze) begin
                wb_insn_reg <= ex_insn_reg;
                wb_rfaddrw_reg <= rf_addrw_reg;
            end
        end
    end

    // Control signal decode for EX stage (combinational from id_insn)
    // We'll use a separate always block to compute next values for control regs
    reg [3:0] next_alu_op;
    reg [1:0] next_mac_op;
    reg [1:0] next_shrot_op;
    reg [3:0] next_comp_op;
    reg [4:0] next_rf_addrw;
    reg [2:0] next_rfwb_op;
    reg [2:0] next_branch_op;
    reg [15:0] next_spr_addrimm;
    reg next_sig_syscall;
    reg next_sig_trap;
    reg next_except_illegal;
    reg next_ex_macrc_op;
    reg [3:0] next_lsu_op;

    always @(*) begin
        // Defaults
        next_alu_op = 4'd0;
        next_mac_op = 2'd0;
        next_shrot_op = 2'd0;
        next_comp_op = 4'd0;
        next_rf_addrw = 5'd0;
        next_rfwb_op = 3'd0;
        next_branch_op = pre_branch_op; // from earlier decode
        next_spr_addrimm = 16'd0;
        next_sig_syscall = 1'b0;
        next_sig_trap = 1'b0;
        next_except_illegal = 1'b0;
        next_ex_macrc_op = 1'b0;
        next_lsu_op = 4'd0;

        if (id_freeze || flushpipe) begin
            // Insert NOP
            next_alu_op = 4'd0;
            next_mac_op = 2'd0;
            next_shrot_op = 2'd0;
            next_comp_op = 4'd0;
            next_rf_addrw = 5'd0;
            next_rfwb_op = 3'd0;
            next_branch_op = 3'd0;
            next_spr_addrimm = 16'd0;
            next_sig_syscall = 1'b0;
            next_sig_trap = 1'b0;
            next_except_illegal = 1'b0;
            next_ex_macrc_op = 1'b0;
            next_lsu_op = 4'd0;
        end else begin
            // Decode id_insn
            case (id_insn[31:26])
                OR1200_OR32_ALU: begin
                    // ALU format
                    case (id_insn[9:8])
                        2'b00: next_alu_op = 4'b0001; // l.add
                        2'b01: next_alu_op = 4'b0010; // l.and
                        2'b10: next_alu_op = 4'b0011; // l.addi (immediate)
                        2'b11: next_alu_op = 4'b0100; // l.muli (if multiply)
                        default: next_alu_op = 4'b0000;
                    endcase
                    next_rf_addrw = id_insn[25:21];
                    next_rfwb_op = 3'b001; // write ALU result
                    // shrot_op from id_insn[7:6]
                    next_shrot_op = id_insn[7:6];
                    // comp_op from id_insn[24:21]
                    next_comp_op = id_insn[24:21];
                end
                OR1200_OR32_MEM: begin
                    // Load/Store
                    if (id_insn[25:21] == 5'b00011) begin // store
                        next_lsu_op = 4'b0001; // l.sw
                        next_rfwb_op = 3'b000; // no writeback
                    end else begin // load
                        next_lsu_op = 4'b0010; // l.lwz
                        next_rf_addrw = id_insn[25:21];
                        next_rfwb_op = 3'b010; // write memory load
                    end
                end
                OR1200_OR32_BR: begin
                    next_branch_op = pre_branch_op; // use predecode
                    // For JAL/JALR, set rf_addrw to 9 (link register)
                    if (pre_branch_op == 3'b010 || pre_branch_op == 3'b100) begin
                        next_rf_addrw = 5'd9;
                        next_rfwb_op = 3'b011; // write link register
                    end else begin
                        next_rf_addrw = 5'd0;
                        next_rfwb_op = 3'b000;
                    end
                end
                OR1200_OR32_SFXX: begin
                    case (id_insn[25:21])
                        5'b01000: begin // l.sfxx
                            next_alu_op = 4'b0101; // compare
                            next_comp_op = id_insn[24:21];
                        end
                        5'b00000: begin // l.mfspr
                            next_alu_op = 4'b0110; // SPR read
                            next_spr_addrimm = id_insn[15:0];
                            next_rf_addrw = id_insn[25:21]; // but mfspr writes to rd
                            next_rfwb_op = 3'b100; // write SPR
                        end
                        5'b00001: begin // l.mtspr
                            next_alu_op = 4'b0111; // SPR write
                            next_spr_addrimm = {id_insn[25:21], id_insn[10:0]};
                            next_rfwb_op = 3'b000; // no writeback
                        end
                        default: next_alu_op = 4'b0000;
                    endcase
                end
                OR1200_OR32_CUST5: begin
                    if (CUST5_IMPLEMENTED) begin
                        next_alu_op = 4'b1000; // custom
                        // cust5_op from ex_insn later
                        next_rf_addrw = id_insn[25:21];
                        next_rfwb_op = 3'b001;
                    end else begin
                        next_except_illegal = 1'b1;
                    end
                end
                OR1200_OR32_MAC: begin
                    if (MAC_IMPLEMENTED) begin
                        if (id_insn[10] == 1'b0) begin
                            next_mac_op = {1'b0, id_insn[9]}; // l.mac or l.msb
                            next_rfwb_op = 3'b000;
                        end else begin // l.maci
                            next_mac_op = 2'b10; // l.maci
                            next_rfwb_op = 3'b000;
                        end
                        // macrc detection
                        if (id_insn[10:9] == 2'b00) begin
                            // l.macrc: read MAC result
                            next_ex_macrc_op = 1'b1;
                            next_rf_addrw = id_insn[25:21];
                            next_rfwb_op = 3'b001; // write ALU? Actually MAC result goes to reg file via ALU? We'll keep generic
                            next_alu_op = 4'b1001; // mac result read
                        end
                    end else begin
                        next_except_illegal = 1'b1;
                    end
                end
                OR1200_OR32_RFE: begin
                    next_rfe = 1'b1; // but rfe is output separately
                    next_branch_op = 3'b111;
                end
                OR1200_OR32_TRAP: begin
                    next_sig_trap = 1'b1;
                end
                OR1200_OR32_SYNC: begin
                    // nop
                end
                default: begin
                    if (id_insn[31:26] == 6'b010101) begin // l.nop
                        // nothing
                    end else begin
                        next_except_illegal = 1'b1;
                    end
                end
            endcase
        end
    end

    // Update control regs when EX advances
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_op_reg <= 4'd0;
            mac_op_reg <= 2'd0;
            shrot_op_reg <= 2'd0;
            comp_op_reg <= 4'd0;
            rf_addrw_reg <= 5'd0;
            rfwb_op_reg <= 3'd0;
            branch_op_reg <= 3'd0;
            spr_addrimm_reg <= 16'd0;
            sig_syscall_reg <= 1'b0;
            sig_trap_reg <= 1'b0;
            except_illegal_reg <= 1'b0;
            ex_macrc_op_reg <= 1'b0;
            lsu_op_reg <= 4'd0;
        end else begin
            if (flushpipe || (!ex_freeze && (id_freeze || flushpipe))) begin
                alu_op_reg <= 4'd0;
                mac_op_reg <= 2'd0;
                shrot_op_reg <= 2'd0;
                comp_op_reg <= 4'd0;
                rf_addrw_reg <= 5'd0;
                rfwb_op_reg <= 3'd0;
                branch_op_reg <= 3'd0;
                spr_addrimm_reg <= 16'd0;
                sig_syscall_reg <= 1'b0;
                sig_trap_reg <= 1'b0;
                except_illegal_reg <= 1'b0;
                ex_macrc_op_reg <= 1'b0;
                lsu_op_reg <= 4'd0;
            end else if (!ex_freeze) begin
                alu_op_reg <= next_alu_op;
                mac_op_reg <= next_mac_op;
                shrot_op_reg <= next_shrot_op;
                comp_op_reg <= next_comp_op;
                rf_addrw_reg <= next_rf_addrw;
                rfwb_op_reg <= next_rfwb_op;
                branch_op_reg <= next_branch_op;
                spr_addrimm_reg <= next_spr_addrimm;
                sig_syscall_reg <= next_sig_syscall;
                sig_trap_reg <= next_sig_trap;
                except_illegal_reg <= next_except_illegal;
                ex_macrc_op_reg <= next_ex_macrc_op;
                lsu_op_reg <= next_lsu_op;
            end
        end
    end

    // EX-stage combinational outputs from ex_insn
    assign ex_insn = ex_insn_reg;
    assign wb_insn = wb_insn_reg;

    // ex_void detection: bit 16 set in ex_insn
    assign ex_void = ex_insn_reg[16];

    // branch_addrofs: sign-extend ex_insn[25:0] to [31:2]
    assign branch_addrofs[31:2] = {{6{ex_insn_reg[25]}}, ex_insn_reg[25:0]};

    // lsu_addrofs
    always @(*) begin
        if (ex_insn_reg[31:26] == 5'b11010) begin // store (l.sw or similar)
            lsu_addrofs_comb = $signed({{6{ex_insn_reg[25]}}, ex_insn_reg[25:21]}) + $signed({{21{ex_insn_reg[10]}}, ex_insn_reg[10:0]});
        end else begin // load or default
            lsu_addrofs_comb = $signed({{6{ex_insn_reg[25]}}, ex_insn_reg[15:11]}) + $signed({{21{ex_insn_reg[10]}}, ex_insn_reg[10:0]});
        end
    end
    assign lsu_addrofs = lsu_addrofs_comb;

    // cust5_op and cust5_limm from ex_insn
    assign cust5_op = ex_insn_reg[24:20];
    assign cust5_limm = ex_insn_reg[15:10];

    // no_more_dslot
    assign no_more_dslot = ((branch_op_reg != 3'b000) && (id_insn[16] == 1'b0) && branch_taken) || (branch_op_reg == 3'b111);

    // force_dslot_fetch always 0 in this implementation
    assign force_dslot_fetch = 1'b0;

    // rfe
    assign rfe = (pre_branch_op == 3'b111) || (branch_op_reg == 3'b111);

    // Exception outputs
    assign sig_syscall = sig_syscall_reg | (if_insn[31:26] == 6'b001011 && if_insn[16] set? actually l.sys is opcode 0x2B? We'll keep registered version
    // l.sys is encoded with opcode 0x2B (001011) and immediate field? In OR1200, l.sys is opcode 0x2B with bits [25:0] for immediate. We'll detect in next_sig_syscall already.

    assign sig_trap = sig_trap_reg | du_hwbkpt; // debug HW breakpoint OR trap instruction

    assign except_illegal = except_illegal_reg;

    assign id_macrc_op = id_macrc_op_comb;
    assign ex_macrc_op = ex_macrc_op_reg;

    // End of module
endmodule
