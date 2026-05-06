module or1200_genpc #(
    parameter [2:0] OR1200_BRANCHOP_NOP = 3'd0,
    parameter [2:0] OR1200_BRANCHOP_J   = 3'd1,
    parameter [2:0] OR1200_BRANCHOP_JR  = 3'd2,
    parameter [2:0] OR1200_BRANCHOP_BAL = 3'd3,
    parameter [2:0] OR1200_BRANCHOP_BF  = 3'd4,
    parameter [2:0] OR1200_BRANCHOP_BNF = 3'd5,
    parameter [2:0] OR1200_BRANCHOP_RFE = 3'd6,
    parameter [19:0] OR1200_EXCEPT_EPH0_P = 20'h00000,
    parameter [19:0] OR1200_EXCEPT_EPH1_P = 20'hf0000,
    parameter [7:0] OR1200_EXCEPT_V = 8'h00,
    parameter [3:0] OR1200_RESET_EXCEPT = 4'h1,
    parameter [3:0] OR1200_ITAG_NI = 4'b0000
) (
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

reg [31:2] pcreg;
reg [31:0] pc;
reg taken;
reg genpc_refetch_r;

wire [31:2] seq_pc_word;
wire [31:2] branch_target_word;
wire [31:0] seq_pc;
wire [31:0] branch_target_pc;
wire [31:0] except_pc;
wire [31:0] reset_except_pc;
wire unused_genpc_stop_prefetch;

assign seq_pc_word = pcreg + 30'd1;
assign branch_target_word = binsn_addr + branch_addrofs;
assign seq_pc = {seq_pc_word, 2'b00};
assign branch_target_pc = {branch_target_word, 2'b00};
assign except_pc = {(except_prefix ? OR1200_EXCEPT_EPH1_P : OR1200_EXCEPT_EPH0_P), except_type, OR1200_EXCEPT_V};
assign reset_except_pc = {OR1200_EXCEPT_EPH0_P, OR1200_RESET_EXCEPT, OR1200_EXCEPT_V};
assign unused_genpc_stop_prefetch = genpc_stop_prefetch;

always @* begin
    if (spr_pc_we) begin
        pc = spr_dat_i;
    end else if (except_start) begin
        pc = except_pc;
    end else begin
        case (branch_op)
            OR1200_BRANCHOP_J: begin
                pc = {branch_addrofs, 2'b00};
            end
            OR1200_BRANCHOP_JR: begin
                pc = lr_restor;
            end
            OR1200_BRANCHOP_BAL: begin
                pc = branch_target_pc;
            end
            OR1200_BRANCHOP_BF: begin
                pc = flag ? branch_target_pc : seq_pc;
            end
            OR1200_BRANCHOP_BNF: begin
                pc = flag ? seq_pc : branch_target_pc;
            end
            OR1200_BRANCHOP_RFE: begin
                pc = epcr;
            end
            default: begin
                pc = seq_pc;
            end
        endcase
    end
end

always @* begin
    if (spr_pc_we) begin
        taken = 1'b0;
    end else if (except_start) begin
        taken = 1'b1;
    end else begin
        case (branch_op)
            OR1200_BRANCHOP_J,
            OR1200_BRANCHOP_JR,
            OR1200_BRANCHOP_BAL,
            OR1200_BRANCHOP_RFE: begin
                taken = 1'b1;
            end
            OR1200_BRANCHOP_BF: begin
                taken = flag;
            end
            OR1200_BRANCHOP_BNF: begin
                taken = ~flag;
            end
            default: begin
                taken = 1'b0;
            end
        endcase
    end
end

assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;
assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = OR1200_ITAG_NI;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pcreg <= (reset_except_pc - 32'd4) >> 2;
    end else if (spr_pc_we) begin
        pcreg <= spr_dat_i[31:2];
    end else if (no_more_dslot || except_start || (!genpc_freeze && !icpu_rty_i && !genpc_refetch)) begin
        pcreg <= pc[31:2];
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        genpc_refetch_r <= 1'b0;
    end else begin
        genpc_refetch_r <= genpc_refetch;
    end
end

endmodule
