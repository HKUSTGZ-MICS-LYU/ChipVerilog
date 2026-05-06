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
    output [4:0] rf_addrw,
    output [4:0] rf_addra,
    output [4:0] rf_addrb,
    output rf_rda,
    output rf_rdb,
    output reg [3:0] alu_op,
    output reg [1:0] mac_op,
    output reg [1:0] shrot_op,
    output reg [3:0] comp_op,
    output [4:0] rf_addrw_out,
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

// Parameter definitions
localparam [5:0] OP_J      = 6'b000000;
localparam [5:0] OP_JAL    = 6'b000001;
localparam [5:0] OP_JR     = 6'b000010;
localparam [5:0] OP_JALR   = 6'b000011;
localparam [5:0] OP_BF     = 6'b000100;
localparam [5:0] OP_BNF    = 6'b000101;
localparam [5:0] OP_RFE    = 6'b000110;
localparam [5:0] OP_ALU    = 6'b001100;
localparam [5:0] OP_ALUI   = 6'b001101;
localparam [5:0] OP_MOVHI  = 6'b001110;
localparam [5:0] OP_MACI   = 6'b001111;
localparam [5:0] OP_LD     = 6'b010001;
localparam [5:0] OP_ST     = 6'b010101;
localparam [5:0] OP_SFXX   = 6'b011000;
localparam [5:0] OP_CUST1  = 6'b100000;
localparam [5:0] OP_CUST2  = 6'b100001;
localparam [5:0] OP_CUST3  = 6'b100010;
localparam [5:0] OP_CUST4  = 6'b100011;
localparam [5:0] OP_CUST5  = 6'b100100;
localparam [5:0] OP_SPR    = 6'b100101; // l.mfspr, l.mtspr usually have same opcode? In OR1K, SPR main opcode is 0x00? But we define.
localparam [5:0] OP_SYSC   = 6'b101101;
localparam [5:0] OP_TRAP   = 6'b101110;
localparam [5:0] OP_NOP_ENC = 6'b010101; // Not used directly.

localparam [2:0] BRANCH_NOP  = 3'd0;
localparam [2:0] BRANCH_J    = 3'd1;
localparam [2:0] BRANCH_JAL  = 3'd2;
localparam [2:0] BRANCH_JR   = 3'd3;
localparam [2:0] BRANCH_JALR = 3'd4;
localparam [2:0] BRANCH_BF   = 3'd5;
localparam [2:0] BRANCH_BNF  = 3'd6;
localparam [2:0] BRANCH_RFE  = 3'd7;

localparam [1:0] ONE_CYCLE  = 2'b00;
localparam [1:0] TWO_CYCLE  = 2'b01;
localparam [1:0] MULTI_CYCLE = 2'b10;

localparam [4:0] SPR_MAC = 5'd0; // example SPR address for MAC result

// Internal registers
reg [31:0] id_insn;
reg [31:0] wb_insn_reg;
reg [4:0] rf_addrw_reg;
reg [4:0] wb_rfaddrw;
reg [2:0] branch_op_reg;
reg [3:0] alu_op_reg, comp_op_reg;
reg [1:0] mac_op_reg, shrot_op_reg, multicycle_reg;
reg [3:0] lsu_op_reg;
reg [2:0] rfwb_op_reg;
reg sig_syscall_reg, sig_trap_reg, except_illegal_reg;
reg ex_macrc_op_reg;
reg [15:0] spr_addrimm_reg;

// Internal wires
wire [31:0] id_insn_w = id_insn;
wire [31:0] ex_insn_w = ex_insn;
wire id_void = id_insn[16];
wire ex_void = ex_insn[16];

// rf_addra, rf_addrb, rf_rda, rf_rdb combinational from if_insn
assign rf_addra = if_insn[20:16];
assign rf_addrb = if_insn[15:11];
assign rf_rda = if_insn[31];
assign rf_rdb = if_insn[30];

// pre_branch_op from if_insn (only valid when id not frozen)
wire [2:0] pre_branch_op_if;
assign pre_branch_op_if = id_freeze ? BRANCH_NOP : decode_branch(if_insn);

// branch_op from id_insn for EX stage
wire [2:0] branch_op_id = decode_branch(id_insn);

function [2:0] decode_branch(input [31:0] insn);
begin
    case (insn[31:26])
        OP_J:     decode_branch = BRANCH_J;
        OP_JAL:   decode_branch = BRANCH_JAL;
        OP_JR:    decode_branch = BRANCH_JR;
        OP_JALR:  decode_branch = BRANCH_JALR;
        OP_BF:    decode_branch = BRANCH_BF;
        OP_BNF:   decode_branch = BRANCH_BNF;
        OP_RFE:   decode_branch = BRANCH_RFE;
        default:  decode_branch = BRANCH_NOP;
    endcase
end
endfunction

// sel_imm combinational from id_insn
wire sel_imm;
assign sel_imm = !is_imm_clear(id_insn);

function is_imm_clear(input [31:0] insn);
begin
    is_imm_clear = 1'b0; // default: not clear => immediate
    if (insn[16]) begin // NOP encoding
        is_imm_clear = 1'b1;
    end else begin
        case (insn[31:26])
            OP_ALU, OP_JR, OP_JALR, OP_RFE, OP_ST, OP_SFXX, OP_CUST1, OP_CUST2, OP_CUST3, OP_CUST4, OP_CUST5, OP_SPR: is_imm_clear = 1'b1;
            default: ;
        endcase
    end
end
endfunction

// imm_signextend combinational from id_insn
wire imm_signextend;
assign imm_signextend = is_signextend(id_insn);

function is_signextend(input [31:0] insn);
begin
    is_signextend = 1'b0; // default zero-extend
    case (insn[31:26])
        OP_ALUI: begin
            // sub-opcode to determine which immediate ALU
            case (insn[25:21])
                5'b00000: is_signextend = 1'b1; // l.addi
                5'b00001: is_signextend = 1'b1; // l.addic
                5'b00010: is_signextend = 1'b1; // l.xori? Actually l.xori is sign? In OR1K, l.xori is zero-extend? We'll follow spec: l.xori is sign-extend.
                5'b00101: is_signextend = 1'b1; // l.muli (if MUL)
                // l.maci (if MAC) uses separate opcode OP_MACI
                // other immediate compare? We'll include some
                default: ;
            endcase
        end
        OP_MACI: ifdef OR1200_IMPL_MAC is_signextend = 1'b1; endif
        default: ;
    endcase
end
endfunction

// simm
wire [31:0] simm;
assign simm = imm_signextend ? {{16{id_insn[15]}}, id_insn[15:0]} : {16'b0, id_insn[15:0]};

// branch_addrofs from ex_insn
assign branch_addrofs = {{6{ex_insn[25]}}, ex_insn[25:0], 2'b00};

// lsu_addrofs from ex_insn
assign lsu_addrofs = (ex_insn[31:26] == OP_ST) ? {{16{ex_insn[25]}}, ex_insn[25:21], ex_insn[10:0]} : {{16{ex_insn[15]}}, ex_insn[15:11], ex_insn[10:0]};

// sel_a, sel_b combinational
wire [1:0] sel_a;
wire [1:0] sel_b;
wire [4:0] rf_addra_id = if_insn[20:16]; // same as rf_addra
wire [4:0] rf_addrb_id = if_insn[15:11];
assign sel_a = (rf_addra_id == rf_addrw_reg && rf_addrw_reg != 5'd0) ? 2'b01 :
               (rf_addra_id == wb_rfaddrw && wb_rfaddrw != 5'd0 && wbforw_valid) ? 2'b10 : 2'b00;
assign sel_b = sel_imm ? 2'b11 :
               (rf_addrb_id == rf_addrw_reg && rf_addrw_reg != 5'd0) ? 2'b01 :
               (rf_addrb_id == wb_rfaddrw && wb_rfaddrw != 5'd0 && wbforw_valid) ? 2'b10 : 2'b00;

// rf_addrw combinational from id_insn
wire [4:0] rf_addrw_comb;
assign rf_addrw_comb = ((branch_op_id == BRANCH_JR) || (branch_op_id == BRANCH_JAL)) ? 5'd9 : id_insn[25:21];
assign rf_addrw_out = rf_addrw_reg; // output from register

// spr_addrimm combinational from id_insn
wire [15:0] spr_addrimm_comb;
assign spr_addrimm_comb = (id_insn[31:26] == OP_SPR) ? 
           ((id_insn[24:21] == 4'b0000) ? id_insn[15:0] : {id_insn[25:21], id_insn[10:0]}) : 16'b0;
// This needs more detailed decoding: l.mfspr vs l.mtspr. We use subop.

// multicycle combinational from id_insn
wire [1:0] multicycle_comb;
assign multicycle_comb = (id_insn[31:26] == OP_ALU) ? {1'b0, id_insn[9:8]} : ONE_CYCLE;

// alu_op combinational from id_insn
wire [3:0] alu_op_comb;
always_comb begin
    case (id_insn[31:26])
        OP_ALU: alu_op_comb = id_insn[25:22]; // simplified
        OP_ALUI: alu_op_comb = 4'd1; // add immediate
        OP_MOVHI: alu_op_comb = 4'd2;
        OP_SPR: alu_op_comb = 4'd3;
        OP_SFXX: alu_op_comb = 4'd4;
        OP_CUST5: alu_op_comb = 4'd5;
        default: alu_op_comb = 4'd0;
    endcase
end

// shrot_op combinational from id_insn
wire [1:0] shrot_op_comb;
assign shrot_op_comb = id_insn[7:6];

// comp_op combinational from id_insn
wire [3:0] comp_op_comb;
assign comp_op_comb = id_insn[24:21];

// mac_op combinational from id_insn (ifdef MAC)
`ifdef OR1200_IMPL_MAC
wire [1:0] mac_op_comb;
always_comb begin
    case (id_insn[31:26])
        OP_MAC: mac_op_comb = id_insn[9:8]; // l.mac/l.msb etc.
        OP_MACI: mac_op_comb = 2'b10; // mac immediate
        default: mac_op_comb = 2'b00;
    endcase
end
`else
wire [1:0] mac_op_comb = 2'b00;
`endif

// id_macrc_op combinational
`ifdef OR1200_IMPL_MAC
wire id_macrc_op_comb;
assign id_macrc_op_comb = (id_insn[31:26] == OP_SPR) && (spr_addrimm_comb == SPR_MAC); // simplified
`else
wire id_macrc_op_comb = 1'b0;
`endif

// lsu_op combinational from id_insn
wire [3:0] lsu_op_comb;
always_comb begin
    case (id_insn[31:26])
        OP_LD: begin
            case (id_insn[25:23])
                3'b000: lsu_op_comb = 4'd1; // l.lwz
                3'b001: lsu_op_comb = 4'd2; // l.lbz
                3'b010: lsu_op_comb = 4'd3; // l.lhz
                3'b011: lsu_op_comb = 4'd4; // l.lws
                default: lsu_op_comb = 4'd0;
            endcase
        end
        OP_ST: begin
            case (id_insn[25:23])
                3'b000: lsu_op_comb = 4'd5; // l.sw
                3'b001: lsu_op_comb = 4'd6; // l.sb
                3'b010: lsu_op_comb = 4'd7; // l.sh
                default: lsu_op_comb = 4'd0;
            endcase
        end
        default: lsu_op_comb = 4'd0;
    endcase
end

// rfwb_op combinational from id_insn
wire [2:0] rfwb_op_comb;
always_comb begin
    case (id_insn[31:26])
        OP_JAL, OP_JALR: rfwb_op_comb = 3'b001; // write link register
        OP_ALU, OP_ALUI, OP_MOVHI, OP_SFXX: rfwb_op_comb = 3'b010;
        OP_LD: rfwb_op_comb = 3'b011;
        OP_CUST1, OP_CUST2, OP_CUST3, OP_CUST4, OP_CUST5: rfwb_op_comb = 3'b100;
        OP_SPR: rfwb_op_comb = 3'b101; // mfspr
        default: rfwb_op_comb = 3'b000;
    endcase
end

// sig_syscall combinational
wire sig_syscall_comb;
assign sig_syscall_comb = (id_insn[31:26] == OP_SYSC);

// sig_trap combinational
wire sig_trap_comb;
assign sig_trap_comb = (id_insn[31:26] == OP_TRAP) || du_hwbkpt;

// except_illegal combinational
wire except_illegal_comb;
always_comb begin
    if (id_insn[16]) // NOP encoding
        except_illegal_comb = 1'b0;
    else begin
        case (id_insn[31:26])
            OP_J, OP_JAL, OP_JR, OP_JALR, OP_BF, OP_BNF, OP_RFE,
            OP_ALU, OP_ALUI, OP_MOVHI, OP_MACI, OP_LD, OP_ST, OP_SFXX,
            OP_SPR, OP_SYSC, OP_TRAP,
            OP_CUST1, OP_CUST2, OP_CUST3, OP_CUST4, OP_CUST5: except_illegal_comb = 1'b0;
            default: except_illegal_comb = 1'b1;
        endcase
    end
end

// cust5_op, cust5_limm from ex_insn combinational
assign cust5_op = ex_insn[24:20];
assign cust5_limm = ex_insn[5:0];

// rfe
assign rfe = (pre_branch_op_if == BRANCH_RFE) || (branch_op_reg == BRANCH_RFE);

// no_more_dslot
assign no_more_dslot = ((branch_op_reg != BRANCH_NOP) && !id_void && branch_taken) || (branch_op_reg == BRANCH_RFE);

// force_dslot_fetch
assign force_dslot_fetch = 1'b0;

// ex_void output
assign ex_void = ex_insn[16];

// ex_macrc_op output
assign ex_macrc_op = ex_macrc_op_reg;

// id_macrc_op output
assign id_macrc_op = id_macrc_op_comb;

// sig_syscall output
assign sig_syscall = sig_syscall_reg;

// sig_trap output
assign sig_trap = sig_trap_reg;

// except_illegal output
assign except_illegal = except_illegal_reg;

// Sequential logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        id_insn <= 32'h00010000; // NOP with bit 16 set
        ex_insn <= 32'h00010000;
        wb_insn_reg <= 32'h00010000;
        branch_op_reg <= BRANCH_NOP;
        rf_addrw_reg <= 5'd0;
        wb_rfaddrw <= 5'd0;
        spr_addrimm_reg <= 16'd0;
        alu_op_reg <= 4'd0;
        mac_op_reg <= 2'd0;
        shrot_op_reg <= 2'd0;
        comp_op_reg <= 4'd0;
        lsu_op_reg <= 4'd0;
        rfwb_op_reg <= 3'd0;
        multicycle_reg <= ONE_CYCLE;
        sig_syscall_reg <= 1'b0;
        sig_trap_reg <= 1'b0;
        except_illegal_reg <= 1'b0;
        ex_macrc_op_reg <= 1'b0;
    end else begin
        // ID stage
        if (flushpipe)
            id_insn <= 32'h00010000;
        else if (!id_freeze)
            id_insn <= if_insn;

        // EX stage
        if (flushpipe) begin
            ex_insn <= 32'h00010000;
            branch_op_reg <= BRANCH_NOP;
            alu_op_reg <= 4'd0;
            mac_op_reg <= 2'd0;
            shrot_op_reg <= 2'd0;
            comp_op_reg <= 4'd0;
            lsu_op_reg <= 4'd0;
            rfwb_op_reg <= 3'd0;
            spr_addrimm_reg <= 16'd0;
            multicycle_reg <= ONE_CYCLE;
            sig_syscall_reg <= 1'b0;
            sig_trap_reg <= 1'b0;
            except_illegal_reg <= 1'b0;
            ex_macrc_op_reg <= 1'b0;
        end else if (!ex_freeze) begin
            if (id_freeze) begin
                // bubble insertion
                ex_insn <= 32'h00010000;
                branch_op_reg <= BRANCH_NOP;
                alu_op_reg <= 4'd0;
                mac_op_reg <= 2'd0;
                shrot_op_reg <= 2'd0;
                comp_op_reg <= 4'd0;
                lsu_op_reg <= 4'd0;
                rfwb_op_reg <= 3'd0;
                spr_addrimm_reg <= 16'd0;
                multicycle_reg <= ONE_CYCLE;
                sig_syscall_reg <= 1'b0;
                sig_trap_reg <= 1'b0;
                except_illegal_reg <= 1'b0;
                ex_macrc_op_reg <= 1'b0;
            end else begin
                // normal
                ex_insn <= id_insn;
                branch_op_reg <= branch_op_id;
                alu_op_reg <= alu_op_comb;
                mac_op_reg <= mac_op_comb;
                shrot_op_reg <= shrot_op_comb;
                comp_op_reg <= comp_op_comb;
                lsu_op_reg <= lsu_op_comb;
                rfwb_op_reg <= rfwb_op_comb;
                spr_addrimm_reg <= spr_addrimm_comb;
                multicycle_reg <= multicycle_comb;
                sig_syscall_reg <= sig_syscall_comb;
                sig_trap_reg <= sig_trap_comb;
                except_illegal_reg <= except_illegal_comb;
                ex_macrc_op_reg <= id_macrc_op_comb;
                // rf_addrw_reg update
                rf_addrw_reg <= rf_addrw_comb;
            end
        end

        // WB stage
        if (!wb_freeze) begin
            wb_insn_reg <= ex_insn;
            wb_rfaddrw <= rf_addrw_reg;
        end
    end
end

// Output assignments from registers
assign wb_insn = wb_insn_reg;
assign branch_op = branch_op_reg;
assign alu_op = alu_op_reg;
assign mac_op = mac_op_reg;
assign shrot_op = shrot_op_reg;
assign comp_op = comp_op_reg;
assign lsu_op = lsu_op_reg;
assign rfwb_op = rfwb_op_reg;
assign multicycle = multicycle_reg;
assign spr_addrimm = spr_addrimm_reg;
assign rf_addrw = rf_addrw_reg;

endmodule
