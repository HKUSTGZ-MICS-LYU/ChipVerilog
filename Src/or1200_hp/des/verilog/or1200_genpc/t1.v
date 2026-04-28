`include "timescale.v"
`include "or1200_defines.v"

module or1200_genpc(
    clk, rst,
    icpu_adr_o, icpu_cycstb_o, icpu_sel_o, icpu_tag_o,
    icpu_rty_i, icpu_adr_i,
    branch_op, except_type, except_prefix,
    branch_addrofs, lr_restor, flag, taken,
    except_start, binsn_addr, epcr,
    spr_dat_i, spr_pc_we,
    genpc_refetch, genpc_freeze, genpc_stop_prefetch,
    no_more_dslot
);

input         clk, rst;
output [31:0] icpu_adr_o;
output        icpu_cycstb_o;
output [3:0]  icpu_sel_o;
output [3:0]  icpu_tag_o;
input         icpu_rty_i;
input  [31:0] icpu_adr_i;
input  [2:0]  branch_op;
input  [3:0]  except_type;
input         except_prefix;
input  [31:2] branch_addrofs;
input  [31:0] lr_restor;
input         flag;
output        taken;
input         except_start;
input  [31:2] binsn_addr;
input  [31:0] epcr;
input  [31:0] spr_dat_i;
input         spr_pc_we;
input         genpc_refetch;
input         genpc_freeze;
input         genpc_stop_prefetch;
input         no_more_dslot;

reg [31:2] pcreg;
reg [31:0] pc;
reg        taken;
reg        genpc_refetch_r;

// Fixed outputs
assign icpu_cycstb_o = !genpc_freeze;
assign icpu_sel_o    = 4'b1111;
assign icpu_tag_o    = `OR1200_ITAG_NI;

// icpu_adr_o
assign icpu_adr_o = (!no_more_dslot & !except_start & !spr_pc_we &
                     (icpu_rty_i | genpc_refetch)) ?
                    icpu_adr_i : pc;

// Combinational PC and taken generation
always @(branch_op or except_type or except_prefix or branch_addrofs or
         lr_restor or flag or except_start or binsn_addr or epcr or
         spr_dat_i or spr_pc_we or pcreg) begin

    casex ({spr_pc_we, except_start, branch_op})

        // SPR PC write (highest priority)
        5'b1_x_xxx: begin
            pc    = spr_dat_i;
            taken = 1'b0;
        end

        // Exception entry
        5'b0_1_xxx: begin
            pc    = except_prefix ?
                    {`OR1200_EXCEPT_EPH1_P, except_type, `OR1200_EXCEPT_V} :
                    {`OR1200_EXCEPT_EPH0_P, except_type, `OR1200_EXCEPT_V};
            taken = 1'b1;
        end

        // NOP: sequential
        5'b0_0_000: begin
            pc    = {pcreg + 30'd1, 2'b00};
            taken = 1'b0;
        end

        // J: direct jump
        5'b0_0_001: begin
            pc    = {branch_addrofs, 2'b00};
            taken = 1'b1;
        end

        // JR: register jump
        5'b0_0_010: begin
            pc    = lr_restor;
            taken = 1'b1;
        end

        // BAL: branch and link
        5'b0_0_011: begin
            pc    = {binsn_addr + branch_addrofs, 2'b00};
            taken = 1'b1;
        end

        // BF: branch if flag set
        5'b0_0_100: begin
            pc    = flag ? {binsn_addr + branch_addrofs, 2'b00} :
                           {pcreg + 30'd1, 2'b00};
            taken = flag;
        end

        // BNF: branch if flag clear
        5'b0_0_101: begin
            pc    = !flag ? {binsn_addr + branch_addrofs, 2'b00} :
                            {pcreg + 30'd1, 2'b00};
            taken = !flag;
        end

        // RFE: return from exception
        5'b0_0_110: begin
            pc    = epcr;
            taken = 1'b1;
        end

        default: begin
            pc    = {pcreg + 30'd1, 2'b00};
            taken = 1'b0;
        end
    endcase
end

// Sequential: pcreg and genpc_refetch_r
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pcreg           <= ((`OR1200_EXCEPT_EPH0_P) >> 2) - 30'd1;
        genpc_refetch_r <= 1'b0;
    end else begin
        genpc_refetch_r <= genpc_refetch;

        if (spr_pc_we)
            pcreg <= spr_dat_i[31:2];
        else if (no_more_dslot | except_start |
                 (!genpc_freeze & !icpu_rty_i & !genpc_refetch))
            pcreg <= pc[31:2];
    end
end

endmodule