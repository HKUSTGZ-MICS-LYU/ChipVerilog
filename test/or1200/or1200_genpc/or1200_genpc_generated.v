`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_genpc(
    // Clock and reset
    clk, rst,

    // External i/f to IC
    icpu_adr_o, icpu_cycstb_o, icpu_sel_o, icpu_tag_o,
    icpu_rty_i, icpu_adr_i,

    // Internal i/f
    branch_op, except_type, except_prefix,
    branch_addrofs, lr_restor, flag, taken, except_start,
    binsn_addr, epcr, spr_dat_i, spr_pc_we, genpc_refetch,
    genpc_freeze, genpc_stop_prefetch, no_more_dslot
);

//
// I/O
//
input               clk;
input               rst;

output [31:0]       icpu_adr_o;
output              icpu_cycstb_o;
output [3:0]        icpu_sel_o;
output [3:0]        icpu_tag_o;
input               icpu_rty_i;
input [31:0]        icpu_adr_i;

input [2:0]         branch_op;
input [3:0]         except_type;
input               except_prefix;
input [31:2]        branch_addrofs;
input [31:0]        lr_restor;
input               flag;
output reg          taken;
input               except_start;
input [31:2]        binsn_addr;
input [31:0]        epcr;
input [31:0]        spr_dat_i;
input               spr_pc_we;
input               genpc_refetch;
input               genpc_freeze;
input               genpc_stop_prefetch;
input               no_more_dslot;

//
// Internal state
//
reg [31:2]          pcreg;
reg [31:0]          pc;
reg                 genpc_refetch_r;

wire [31:0]         except_pc;
assign except_pc = {(except_prefix ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P), except_type, `OR1200_EXCEPT_V};

//
// Fetch interface
//
assign icpu_adr_o = (!no_more_dslot && !except_start && !spr_pc_we && (icpu_rty_i || genpc_refetch))
                 ? icpu_adr_i
                 : pc;

assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o    = 4'b1111;
assign icpu_tag_o    = `OR1200_ITAG_NI;

//
// One-cycle refetch history
//
always @(posedge clk or posedge rst) begin
    if (rst)
        genpc_refetch_r <= 1'b0;
    else if (genpc_refetch)
        genpc_refetch_r <= 1'b1;
    else
        genpc_refetch_r <= 1'b0;
end

//
// Next-PC calculation
//
always @(*) begin
    casex ({spr_pc_we, except_start, branch_op})
        {2'b00, `OR1200_BRANCHOP_NOP}: begin
            pc = {pcreg + 30'd1, 2'b0};
        end

        {2'b00, `OR1200_BRANCHOP_J}: begin
            pc = {branch_addrofs, 2'b0};
        end

        {2'b00, `OR1200_BRANCHOP_JR}: begin
            pc = lr_restor;
        end

        {2'b00, `OR1200_BRANCHOP_BAL}: begin
            pc = {binsn_addr + branch_addrofs, 2'b0};
        end

        {2'b00, `OR1200_BRANCHOP_BF}: begin
            if (flag)
                pc = {binsn_addr + branch_addrofs, 2'b0};
            else
                pc = {pcreg + 30'd1, 2'b0};
        end

        {2'b00, `OR1200_BRANCHOP_BNF}: begin
            if (flag)
                pc = {pcreg + 30'd1, 2'b0};
            else
                pc = {binsn_addr + branch_addrofs, 2'b0};
        end

        {2'b00, `OR1200_BRANCHOP_RFE}: begin
            pc = epcr;
        end

        {2'b01, 3'bxxx}: begin
            pc = except_pc;
        end

        default: begin
            pc = spr_dat_i;
        end
    endcase
end

//
// Branch-taken indication
//
always @(*) begin
    casex ({spr_pc_we, except_start, branch_op})
        {2'b00, `OR1200_BRANCHOP_NOP}: taken = 1'b0;
        {2'b00, `OR1200_BRANCHOP_J}:   taken = 1'b1;
        {2'b00, `OR1200_BRANCHOP_JR}:  taken = 1'b1;
        {2'b00, `OR1200_BRANCHOP_BAL}: taken = 1'b1;
        {2'b00, `OR1200_BRANCHOP_BF}:  taken = flag;
        {2'b00, `OR1200_BRANCHOP_BNF}: taken = !flag;
        {2'b00, `OR1200_BRANCHOP_RFE}: taken = 1'b1;
        {2'b01, 3'bxxx}:               taken = 1'b1;
        default:                       taken = 1'b0;
    endcase
end

//
// Program-counter state update
//
always @(posedge clk or posedge rst) begin
    if (rst)
        pcreg <= ({(except_prefix ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P), `OR1200_EXCEPT_RESET, `OR1200_EXCEPT_V} - 1) >> 2;
    else if (spr_pc_we)
        pcreg <= spr_dat_i[31:2];
    else if (no_more_dslot || except_start || (!genpc_freeze && !icpu_rty_i && !genpc_refetch))
        pcreg <= pc[31:2];
end

endmodule
