`ifndef OR1200_BRANCHOP_NOP
`define OR1200_BRANCHOP_NOP 3'd0
`endif
`ifndef OR1200_BRANCHOP_J
`define OR1200_BRANCHOP_J 3'd1
`endif
`ifndef OR1200_BRANCHOP_JR
`define OR1200_BRANCHOP_JR 3'd2
`endif
`ifndef OR1200_BRANCHOP_BAL
`define OR1200_BRANCHOP_BAL 3'd3
`endif
`ifndef OR1200_BRANCHOP_BF
`define OR1200_BRANCHOP_BF 3'd4
`endif
`ifndef OR1200_BRANCHOP_BNF
`define OR1200_BRANCHOP_BNF 3'd5
`endif
`ifndef OR1200_BRANCHOP_RFE
`define OR1200_BRANCHOP_RFE 3'd6
`endif
`ifndef OR1200_ITAG_NI
`define OR1200_ITAG_NI 4'b0000
`endif

module or1200_genpc(
    input              clk,
    input              rst,
    output [31:0]      icpu_adr_o,
    output             icpu_cycstb_o,
    output [3:0]       icpu_sel_o,
    output [3:0]       icpu_tag_o,
    input              icpu_rty_i,
    input [31:0]       icpu_adr_i,
    input [2:0]        branch_op,
    input [3:0]        except_type,
    input              except_prefix,
    input [31:2]       branch_addrofs,
    input [31:0]       lr_restor,
    input              flag,
    output reg         taken,
    input              except_start,
    input [31:2]       binsn_addr,
    input [31:0]       epcr,
    input [31:0]       spr_dat_i,
    input              spr_pc_we,
    input              genpc_refetch,
    input              genpc_freeze,
    input              genpc_stop_prefetch,
    input              no_more_dslot
);

localparam [19:0] OR1200_EXCEPT_EPH0_P = 20'h00000;
localparam [19:0] OR1200_EXCEPT_EPH1_P = 20'hF0000;
localparam [3:0]  OR1200_EXCEPT_RESET  = 4'h1;
localparam [31:2] RESET_PCREG_WA       = {OR1200_EXCEPT_EPH0_P, OR1200_EXCEPT_RESET, 6'b00} - 30'd1;

reg [31:2] pcreg;
reg [31:0] pc;
reg        genpc_refetch_r;

wire [31:0] pc_seq;
wire [31:0] pc_branch;
wire [31:0] except_addr;

assign pc_seq     = {pcreg + 30'd1, 2'b00};
assign pc_branch  = {binsn_addr + branch_addrofs, 2'b00};
assign except_addr = {except_prefix ? OR1200_EXCEPT_EPH1_P : OR1200_EXCEPT_EPH0_P, except_type, 8'h00};

always @* begin
    if (spr_pc_we)
        pc = spr_dat_i;
    else if (except_start)
        pc = except_addr;
    else begin
        case (branch_op)
            `OR1200_BRANCHOP_NOP: pc = pc_seq;
            `OR1200_BRANCHOP_J:   pc = {branch_addrofs, 2'b00};
            `OR1200_BRANCHOP_JR:  pc = lr_restor;
            `OR1200_BRANCHOP_BAL: pc = pc_branch;
            `OR1200_BRANCHOP_BF:  pc = flag ? pc_branch : pc_seq;
            `OR1200_BRANCHOP_BNF: pc = flag ? pc_seq : pc_branch;
            `OR1200_BRANCHOP_RFE: pc = epcr;
            default:              pc = pc_seq;
        endcase
    end
end

always @* begin
    if (spr_pc_we)
        taken = 1'b0;
    else if (except_start)
        taken = 1'b1;
    else begin
        case (branch_op)
            `OR1200_BRANCHOP_NOP: taken = 1'b0;
            `OR1200_BRANCHOP_J:   taken = 1'b1;
            `OR1200_BRANCHOP_JR:  taken = 1'b1;
            `OR1200_BRANCHOP_BAL: taken = 1'b1;
            `OR1200_BRANCHOP_BF:  taken = flag;
            `OR1200_BRANCHOP_BNF: taken = ~flag;
            `OR1200_BRANCHOP_RFE: taken = 1'b1;
            default:              taken = 1'b0;
        endcase
    end
end

assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;
assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o = 4'b1111;
assign icpu_tag_o = `OR1200_ITAG_NI;

always @(posedge clk or posedge rst) begin
    if (rst)
        pcreg <= RESET_PCREG_WA;
    else if (spr_pc_we)
        pcreg <= spr_dat_i[31:2];
    else if (no_more_dslot || except_start || (!genpc_freeze && !icpu_rty_i && !genpc_refetch))
        pcreg <= pc[31:2];
end

always @(posedge clk or posedge rst) begin
    if (rst)
        genpc_refetch_r <= 1'b0;
    else if (genpc_refetch)
        genpc_refetch_r <= 1'b1;
    else
        genpc_refetch_r <= 1'b0;
end

wire unused_ok;
assign unused_ok = genpc_stop_prefetch ^ genpc_refetch_r;

endmodule
