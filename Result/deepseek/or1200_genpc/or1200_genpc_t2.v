module or1200_genpc(
    input clk,
    input rst,

    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    output [3:0] icpu_tag_o,
    input icpu_rty_i,
    input [31:0] icpu_adr_i,

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

    localparam OR1200_BRANCHOP_NOP = 3'd0;
    localparam OR1200_BRANCHOP_J   = 3'd1;
    localparam OR1200_BRANCHOP_JR  = 3'd2;
    localparam OR1200_BRANCHOP_BAL = 3'd3;
    localparam OR1200_BRANCHOP_BF  = 3'd4;
    localparam OR1200_BRANCHOP_BNF = 3'd5;
    localparam OR1200_BRANCHOP_RFE = 3'd6;

    localparam OR1200_ITAG_NI = 4'd1;

    localparam RESET_VECTOR_ADDR = 32'h100;
    localparam RESET_PC_INIT = (RESET_VECTOR_ADDR - 4) >> 2;

    reg [31:2] pcreg;
    reg genpc_refetch_r;

    wire [31:0] pc;
    wire taken_int;

    wire [31:0] seq_addr = {pcreg + 1'b1, 2'b00};
    wire [31:0] branch_target = {binsn_addr + branch_addrofs, 2'b00};
    wire [31:0] except_vector;
    assign except_vector = { except_prefix ? 30'h3 : 30'h0, except_type, 2'b00 };

    reg [31:0] pc_mux;
    reg taken_mux;

    always @(*) begin
        if (spr_pc_we) begin
            pc_mux = spr_dat_i;
        end
        else if (except_start) begin
            pc_mux = except_vector;
        end
        else begin
            case (branch_op)
                OR1200_BRANCHOP_NOP: pc_mux = seq_addr;
                OR1200_BRANCHOP_J:   pc_mux = {branch_addrofs, 2'b00};
                OR1200_BRANCHOP_JR:  pc_mux = lr_restor;
                OR1200_BRANCHOP_BAL: pc_mux = branch_target;
                OR1200_BRANCHOP_BF:  pc_mux = flag ? branch_target : seq_addr;
                OR1200_BRANCHOP_BNF: pc_mux = flag ? seq_addr : branch_target;
                OR1200_BRANCHOP_RFE: pc_mux = epcr;
                default:             pc_mux = seq_addr;
            endcase
        end
    end

    always @(*) begin
        if (spr_pc_we) begin
            taken_mux = 1'b0;
        end
        else if (except_start) begin
            taken_mux = 1'b1;
        end
        else begin
            case (branch_op)
                OR1200_BRANCHOP_NOP: taken_mux = 1'b0;
                OR1200_BRANCHOP_J:   taken_mux = 1'b1;
                OR1200_BRANCHOP_JR:  taken_mux = 1'b1;
                OR1200_BRANCHOP_BAL: taken_mux = 1'b1;
                OR1200_BRANCHOP_BF:  taken_mux = flag;
                OR1200_BRANCHOP_BNF: taken_mux = ~flag;
                OR1200_BRANCHOP_RFE: taken_mux = 1'b1;
                default:             taken_mux = 1'b0;
            endcase
        end
    end

    assign pc = pc_mux;
    assign taken = taken_mux;

    assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;

    assign icpu_cycstb_o = !genpc_freeze;
    assign icpu_sel_o = 4'b1111;
    assign icpu_tag_o = OR1200_ITAG_NI;

    wire normal_advance = !genpc_freeze && !icpu_rty_i && !genpc_refetch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pcreg <= RESET_PC_INIT;
            genpc_refetch_r <= 1'b0;
        end
        else begin
            if (spr_pc_we) begin
                pcreg <= spr_dat_i[31:2];
            end
            else if (no_more_dslot || except_start || normal_advance) begin
                pcreg <= pc[31:2];
            end

            if (genpc_refetch) begin
                genpc_refetch_r <= 1'b1;
            end
            else begin
                genpc_refetch_r <= 1'b0;
            end
        end
    end

endmodule
