module or1200_genpc (
    input clk,
    input rst,
    output reg [31:0] icpu_adr_o,
    output reg icpu_cycstb_o,
    output reg [3:0] icpu_sel_o,
    output reg [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,
    input [2:0] branch_op,
    input [3:0] except_type,
    input except_prefix,
    input [31:2] branch_addrofs,
    input [31:0] lr_restor,
    input flag,
    output reg taken,
    input except_start,
    input [31:2] binsn_addr,
    input [31:0] epcr,
    input [31:0] spr_dat_i,
    input spr_pc_we,
    input genpc_refetch,
    input genpc_freeze,
    input genpc_stop_prefetch,
    input no_more_dslot
);

// Branch operation constants
localparam [2:0] BRANCHOP_NOP = 3'b000;
localparam [2:0] BRANCHOP_J   = 3'b001;
localparam [2:0] BRANCHOP_JR  = 3'b010;
localparam [2:0] BRANCHOP_BAL = 3'b011;
localparam [2:0] BRANCHOP_BF  = 3'b100;
localparam [2:0] BRANCHOP_BNF = 3'b101;
localparam [2:0] BRANCHOP_RFE = 3'b110;

// Exception vector bases
localparam [31:0] EXCEPT_BASE0 = 32'h00000000;
localparam [31:0] EXCEPT_BASE1 = 32'hF0000000;

// Reset vector word address (0x100 >> 2)
localparam [31:2] RESET_VECTOR_WORD_ADDR = 30'h40;   // 0x100 >> 2 = 0x40
localparam [31:2] PCREG_RESET = RESET_VECTOR_WORD_ADDR - 30'h1;  // 30'h3F

// Instruction tag constant
localparam [3:0] ITAG_NI = 4'b0001;

// Internal registers
reg [31:2] pcreg;
reg genpc_refetch_r;

// Combinational signals
wire [31:0] pc;
wire [31:0] exception_addr;
wire [31:2] exception_addr_word;
wire [31:0] sequential_addr;
wire [31:0] bal_target;
wire [31:0] bf_target;
wire [31:0] bnf_target;
wire [31:0] j_target;
wire [31:0] jr_target;
wire [31:0] rfe_target;
wire [31:0] nop_next;
wire hold_address;

// Exception vector address
assign exception_addr = (except_prefix ? EXCEPT_BASE1 : EXCEPT_BASE0) | ({except_type, 2'b00});
assign exception_addr_word = exception_addr[31:2];

// Sequential address (byte)
assign sequential_addr = {pcreg, 2'b00} + 32'h4;

// Branch target calculations (byte addresses)
assign bal_target = {binsn_addr + branch_addrofs, 2'b00};
assign bf_target = bal_target;
assign bnf_target = bal_target;
assign j_target = {branch_addrofs, 2'b00};
assign jr_target = lr_restor;
assign rfe_target = epcr;
assign nop_next = sequential_addr;

// PC selection (byte address)
assign pc = spr_pc_we ? spr_dat_i :
            except_start ? exception_addr :
            (branch_op == BRANCHOP_NOP) ? nop_next :
            (branch_op == BRANCHOP_J)   ? j_target :
            (branch_op == BRANCHOP_JR)  ? jr_target :
            (branch_op == BRANCHOP_BAL) ? bal_target :
            (branch_op == BRANCHOP_BF)  ? (flag ? bf_target : sequential_addr) :
            (branch_op == BRANCHOP_BNF) ? (flag ? sequential_addr : bnf_target) :
            (branch_op == BRANCHOP_RFE) ? rfe_target :
            sequential_addr;

// Taken signal
always @(*) begin
    if (spr_pc_we) begin
        taken = 1'b0;
    end else if (except_start) begin
        taken = 1'b1;
    end else begin
        case (branch_op)
            BRANCHOP_NOP: taken = 1'b0;
            BRANCHOP_J:   taken = 1'b1;
            BRANCHOP_JR:  taken = 1'b1;
            BRANCHOP_BAL: taken = 1'b1;
            BRANCHOP_BF:  taken = flag;
            BRANCHOP_BNF: taken = !flag;
            BRANCHOP_RFE: taken = 1'b1;
            default:      taken = 1'b0;
        endcase
    end
end

// Hold address condition
assign hold_address = !no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch);

// icpu_adr_o
assign icpu_adr_o = hold_address ? icpu_adr_i : pc;

// icpu_cycstb_o
assign icpu_cycstb_o = !genpc_freeze;

// icpu_sel_o
assign icpu_sel_o = 4'b1111;

// icpu_tag_o
assign icpu_tag_o = ITAG_NI;

// Sequential logic: pcreg and genpc_refetch_r
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pcreg <= PCREG_RESET;
        genpc_refetch_r <= 1'b0;
    end else begin
        genpc_refetch_r <= genpc_refetch;
        if (spr_pc_we) begin
            pcreg <= spr_dat_i[31:2];
        end else if (no_more_dslot || except_start) begin
            pcreg <= pc[31:2];
        end else if (!genpc_freeze && !icpu_rty_i && !genpc_refetch) begin
            pcreg <= pc[31:2];
        end
        // else pcreg unchanged
    end
end

endmodule
