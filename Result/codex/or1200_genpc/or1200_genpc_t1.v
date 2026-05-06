`ifndef OR1200_ITAG_NI
`define OR1200_ITAG_NI 4'b0000
`endif

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

localparam [2:0] OR1200_BRANCHOP_NOP = 3'b000;
localparam [2:0] OR1200_BRANCHOP_J   = 3'b001;
localparam [2:0] OR1200_BRANCHOP_JR  = 3'b010;
localparam [2:0] OR1200_BRANCHOP_BAL = 3'b011;
localparam [2:0] OR1200_BRANCHOP_BF  = 3'b100;
localparam [2:0] OR1200_BRANCHOP_BNF = 3'b101;
localparam [2:0] OR1200_BRANCHOP_RFE = 3'b110;

localparam [19:0] OR1200_EXCEPT_EPH0 = 20'h00000;
localparam [19:0] OR1200_EXCEPT_EPH1 = 20'hF0000;
localparam [31:0] OR1200_RESET_VECTOR = {OR1200_EXCEPT_EPH0, 4'h1, 8'h00};

reg [31:2] pcreg;
reg [31:0] pc;
reg taken;
reg genpc_refetch_r;

wire [31:0] seq_pc;
wire [31:0] except_pc;
wire [31:2] branch_base_sum;
wire unused_genpc_stop_prefetch;

assign seq_pc = {pcreg + 30'd1, 2'b00};
assign branch_base_sum = binsn_addr + branch_addrofs;
assign except_pc = {{(except_prefix ? OR1200_EXCEPT_EPH1 : OR1200_EXCEPT_EPH0)}, except_type, 8'h00};
assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;
assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = `OR1200_ITAG_NI;
assign unused_genpc_stop_prefetch = genpc_stop_prefetch;

always @* begin
    if (spr_pc_we) begin
        pc = spr_dat_i;
    end else if (except_start) begin
        pc = except_pc;
    end else begin
        case (branch_op)
            OR1200_BRANCHOP_NOP: pc = seq_pc;
            OR1200_BRANCHOP_J:   pc = {branch_addrofs, 2'b00};
            OR1200_BRANCHOP_JR:  pc = lr_restor;
            OR1200_BRANCHOP_BAL: pc = {branch_base_sum, 2'b00};
            OR1200_BRANCHOP_BF:  pc = flag ? {branch_base_sum, 2'b00} : seq_pc;
            OR1200_BRANCHOP_BNF: pc = flag ? seq_pc : {branch_base_sum, 2'b00};
            OR1200_BRANCHOP_RFE: pc = epcr;
            default:             pc = seq_pc;
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
            OR1200_BRANCHOP_NOP: taken = 1'b0;
            OR1200_BRANCHOP_J:   taken = 1'b1;
            OR1200_BRANCHOP_JR:  taken = 1'b1;
            OR1200_BRANCHOP_BAL: taken = 1'b1;
            OR1200_BRANCHOP_BF:  taken = flag;
            OR1200_BRANCHOP_BNF: taken = !flag;
            OR1200_BRANCHOP_RFE: taken = 1'b1;
            default:             taken = 1'b0;
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pcreg <= (OR1200_RESET_VECTOR - 32'd4) >> 2;
    end else if (spr_pc_we) begin
        pcreg <= spr_dat_i[31:2];
    end else if (no_more_dslot || except_start || (!genpc_freeze && !icpu_rty_i && !genpc_refetch)) begin
        pcreg <= pc[31:2];
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        genpc_refetch_r <= 1'b0;
    end else if (genpc_refetch) begin
        genpc_refetch_r <= 1'b1;
    end else begin
        genpc_refetch_r <= 1'b0;
    end
end

endmodule
