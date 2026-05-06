module or1200_genpc(
    // Clock and reset
    input clk,
    input rst,

    // External i/f to IC
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,

    // Internal i/f
    input [2:0] branch_op,
    input [3:0] except_type,
    input except_prefix,
    input [31:2] branch_addrofs,
    input [31:0] lr_restor,
    input flag,
    output taken,
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

    // Local parameters for branch operations
    localparam OR1200_BRANCHOP_NOP = 3'd0;
    localparam OR1200_BRANCHOP_J   = 3'd1;
    localparam OR1200_BRANCHOP_JR  = 3'd2;
    localparam OR1200_BRANCHOP_BAL = 3'd3;
    localparam OR1200_BRANCHOP_BF  = 3'd4;
    localparam OR1200_BRANCHOP_BNF = 3'd5;
    localparam OR1200_BRANCHOP_RFE = 3'd6;

    // ITAG constant
    localparam OR1200_ITAG_NI = 4'b0010;

    // Reset exception vector base
    localparam [31:0] RESET_VECTOR = 32'h100;

    reg [31:2] pcreg;
    reg [31:0] pc;
    reg        taken_reg;
    reg        genpc_refetch_r;

    wire [31:0] exception_vector;
    wire [31:0] branch_target;
    wire [31:0] seq_pc;

    // Sequential PC
    assign seq_pc = {pcreg + 1'b1, 2'b00};

    // Exception vector generation
    assign exception_vector = {except_prefix ? 8'hF0 : 8'h00, except_type, 20'h0};

    // Branch target for BAL, BF, BNF
    assign branch_target = {binsn_addr + branch_addrofs, 2'b00};

    // Combinational PC selection
    always @* begin
        if (spr_pc_we) begin
            pc = spr_dat_i;
        end
        else if (except_start) begin
            pc = exception_vector;
        end
        else begin
            case (branch_op)
                OR1200_BRANCHOP_NOP: pc = seq_pc;
                OR1200_BRANCHOP_J:   pc = {branch_addrofs, 2'b00};
                OR1200_BRANCHOP_JR:  pc = lr_restor;
                OR1200_BRANCHOP_BAL: pc = branch_target;
                OR1200_BRANCHOP_BF:  pc = flag ? branch_target : seq_pc;
                OR1200_BRANCHOP_BNF: pc = flag ? seq_pc : branch_target;
                OR1200_BRANCHOP_RFE: pc = epcr;
                default:             pc = seq_pc;
            endcase
        end
    end

    // Combinational taken generation
    always @* begin
        if (spr_pc_we) begin
            taken_reg = 1'b0;
        end
        else if (except_start) begin
            taken_reg = 1'b1;
        end
        else begin
            case (branch_op)
                OR1200_BRANCHOP_NOP: taken_reg = 1'b0;
                OR1200_BRANCHOP_J:   taken_reg = 1'b1;
                OR1200_BRANCHOP_JR:  taken_reg = 1'b1;
                OR1200_BRANCHOP_BAL: taken_reg = 1'b1;
                OR1200_BRANCHOP_BF:  taken_reg = flag;
                OR1200_BRANCHOP_BNF: taken_reg = ~flag;
                OR1200_BRANCHOP_RFE: taken_reg = 1'b1;
                default:             taken_reg = 1'b0;
            endcase
        end
    end

    assign taken = taken_reg;

    // IC address output
    assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;

    // IC control outputs
    assign icpu_cycstb_o = ~genpc_freeze;
    assign icpu_sel_o    = 4'b1111;
    assign icpu_tag_o    = OR1200_ITAG_NI;

    // Sequential logic for pcreg and genpc_refetch_r
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pcreg <= RESET_VECTOR[31:2] - 1'b1;
            genpc_refetch_r <= 1'b0;
        end
        else begin
            // Update genpc_refetch_r
            genpc_refetch_r <= genpc_refetch;

            // Update pcreg
            if (spr_pc_we) begin
                pcreg <= spr_dat_i[31:2];
            end
            else if (no_more_dslot || except_start) begin
                pcreg <= pc[31:2];
            end
            else if (!genpc_freeze && !icpu_rty_i && !genpc_refetch) begin
                pcreg <= pc[31:2];
            end
        end
    end

endmodule
