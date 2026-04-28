`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_genpc (
    input         clk,
    input         rst,

    // External i/f to IC
    output [31:0] icpu_adr_o,
    output        icpu_cycstb_o,
    output [3:0]  icpu_sel_o,
    output [3:0]  icpu_tag_o,
    input         icpu_rty_i,
    input  [31:0] icpu_adr_i,

    // Internal i/f
    input  [2:0]  branch_op,
    input  [3:0]  except_type,
    input         except_prefix,
    input  [31:2] branch_addrofs,
    input  [31:0] lr_restor,
    input         flag,
    output        taken,
    input         except_start,
    input  [31:2] binsn_addr,
    input  [31:0] epcr,
    input  [31:0] spr_dat_i,
    input         spr_pc_we,
    input         genpc_refetch,
    input         genpc_freeze,
    input         genpc_stop_prefetch,
    input         no_more_dslot
);

    //--------------------------------------------------------------------------
    // Internal signals
    //--------------------------------------------------------------------------
    reg [31:2] pcreg;
    reg [31:0] pc;
    reg        taken_r;
    reg        genpc_refetch_r;

    //--------------------------------------------------------------------------
    // Fixed outputs
    //--------------------------------------------------------------------------
    assign icpu_sel_o    = 4'b1111;
    assign icpu_tag_o    = `OR1200_ITAG_NI;
    assign icpu_cycstb_o = ~genpc_freeze;
    assign taken         = taken_r;

    //--------------------------------------------------------------------------
    // icpu_adr_o: normally pc, but resend icpu_adr_i on retry/refetch
    //--------------------------------------------------------------------------
    assign icpu_adr_o = (~no_more_dslot & ~except_start & ~spr_pc_we &
                         (icpu_rty_i | genpc_refetch)) ?
                        icpu_adr_i : pc;

    //--------------------------------------------------------------------------
    // Exception vector address generation
    //--------------------------------------------------------------------------
    // except_prefix selects EPH0 or EPH1 base, except_type selects offset
    wire [31:0] except_vec =
        except_prefix ?
            {`OR1200_EPH1_BASE, except_type, `OR1200_EXCEPT_VECTOR_LOW} :
            {`OR1200_EPH0_BASE, except_type, `OR1200_EXCEPT_VECTOR_LOW};

    //--------------------------------------------------------------------------
    // Combinational PC selection
    //--------------------------------------------------------------------------
    always @(*) begin
        casex ({spr_pc_we, except_start, branch_op})
            // SPR PC write (highest priority)
            5'b1_x_xxx: begin
                pc      = spr_dat_i;
                taken_r = 1'b0;
            end
            // Exception entry
            5'b0_1_xxx: begin
                pc      = except_vec;
                taken_r = 1'b1;
            end
            // NOP / sequential
            5'b0_0_000: begin
                pc      = {pcreg + 30'h1, 2'b00};
                taken_r = 1'b0;
            end
            // J - direct jump
            5'b0_0_001: begin
                pc      = {branch_addrofs, 2'b00};
                taken_r = 1'b1;
            end
            // JR - jump register
            5'b0_0_010: begin
                pc      = lr_restor;
                taken_r = 1'b1;
            end
            // BAL - branch and link
            5'b0_0_011: begin
                pc      = {binsn_addr + branch_addrofs, 2'b00};
                taken_r = 1'b1;
            end
            // BF - branch if flag
            5'b0_0_100: begin
                pc      = flag ? {binsn_addr + branch_addrofs, 2'b00}
                               : {pcreg + 30'h1, 2'b00};
                taken_r = flag;
            end
            // BNF - branch if not flag
            5'b0_0_101: begin
                pc      = ~flag ? {binsn_addr + branch_addrofs, 2'b00}
                                : {pcreg + 30'h1, 2'b00};
                taken_r = ~flag;
            end
            // RFE - return from exception
            5'b0_0_110: begin
                pc      = epcr;
                taken_r = 1'b1;
            end
            default: begin
                pc      = {pcreg + 30'h1, 2'b00};
                taken_r = 1'b0;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Sequential: pcreg and genpc_refetch_r
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pcreg           <= (`OR1200_EXCEPT_EPH0_P >> 2) - 30'h1;
            genpc_refetch_r <= 1'b0;
        end else begin
            // genpc_refetch_r: one-cycle delayed copy (not used in active logic)
            genpc_refetch_r <= genpc_refetch;

            // pcreg update
            if (spr_pc_we) begin
                pcreg <= spr_dat_i[31:2];
            end else if (no_more_dslot || except_start ||
                         (!genpc_freeze && !icpu_rty_i && !genpc_refetch)) begin
                pcreg <= pc[31:2];
            end
        end
    end

endmodule