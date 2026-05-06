`ifndef OR1200_ITAG_NI
`define OR1200_ITAG_NI 4'b0000
`endif

`ifndef OR1200_EXCEPT_EPH0
`define OR1200_EXCEPT_EPH0 20'h00000
`endif

`ifndef OR1200_EXCEPT_EPH1
`define OR1200_EXCEPT_EPH1 20'hf0000
`endif

`ifndef OR1200_EXCEPT_V
`define OR1200_EXCEPT_V 8'h00
`endif

`ifndef OR1200_EXCEPT_RESET
`define OR1200_EXCEPT_RESET 4'h1
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
    output             taken,
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

localparam [2:0] OR1200_BRANCHOP_NOP = 3'b000;
localparam [2:0] OR1200_BRANCHOP_J   = 3'b001;
localparam [2:0] OR1200_BRANCHOP_JR  = 3'b010;
localparam [2:0] OR1200_BRANCHOP_BAL = 3'b011;
localparam [2:0] OR1200_BRANCHOP_BF  = 3'b100;
localparam [2:0] OR1200_BRANCHOP_BNF = 3'b101;
localparam [2:0] OR1200_BRANCHOP_RFE = 3'b110;

reg [31:2] pcreg;
reg [31:0] pc;
reg        taken_r;
reg        genpc_refetch_r;

wire [31:0] seq_pc;
wire [31:0] branch_target_pc;
wire [31:0] except_pc;
wire [31:0] reset_except_pc;
wire [19:0] except_prefix_sel;

assign seq_pc          = {pcreg + 30'd1, 2'b00};
assign branch_target_pc = {binsn_addr + branch_addrofs, 2'b00};
assign except_prefix_sel = except_prefix ? `OR1200_EXCEPT_EPH1 : `OR1200_EXCEPT_EPH0;
assign except_pc       = {except_prefix_sel, except_type, `OR1200_EXCEPT_V};
assign reset_except_pc = {`OR1200_EXCEPT_EPH0, `OR1200_EXCEPT_RESET, `OR1200_EXCEPT_V};

always @* begin
    if (spr_pc_we)
        pc = spr_dat_i;
    else if (except_start)
        pc = except_pc;
    else begin
        case (branch_op)
            OR1200_BRANCHOP_NOP: pc = seq_pc;
            OR1200_BRANCHOP_J:   pc = {branch_addrofs, 2'b00};
            OR1200_BRANCHOP_JR:  pc = lr_restor;
            OR1200_BRANCHOP_BAL: pc = branch_target_pc;
            OR1200_BRANCHOP_BF:  pc = flag ? branch_target_pc : seq_pc;
            OR1200_BRANCHOP_BNF: pc = flag ? seq_pc : branch_target_pc;
            OR1200_BRANCHOP_RFE: pc = epcr;
            default:             pc = seq_pc;
        endcase
    end
end

always @* begin
    if (spr_pc_we)
        taken_r = 1'b0;
    else if (except_start)
        taken_r = 1'b1;
    else begin
        case (branch_op)
            OR1200_BRANCHOP_NOP: taken_r = 1'b0;
            OR1200_BRANCHOP_J:   taken_r = 1'b1;
            OR1200_BRANCHOP_JR:  taken_r = 1'b1;
            OR1200_BRANCHOP_BAL: taken_r = 1'b1;
            OR1200_BRANCHOP_BF:  taken_r = flag;
            OR1200_BRANCHOP_BNF: taken_r = ~flag;
            OR1200_BRANCHOP_RFE: taken_r = 1'b1;
            default:             taken_r = 1'b0;
        endcase
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        pcreg <= reset_except_pc[31:2] - 30'd1;
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

assign icpu_adr_o    = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch)) ? icpu_adr_i : pc;
assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o    = 4'b1111;
assign icpu_tag_o    = `OR1200_ITAG_NI;
assign taken         = taken_r;

wire _unused_ok;
assign _unused_ok = genpc_stop_prefetch | genpc_refetch_r;

endmodule
