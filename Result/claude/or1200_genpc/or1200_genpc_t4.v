// ============================================================
//  or1200_genpc.v
//  Program-Counter Generation block for the OR1200 processor.
//
//  Responsibilities
//    - Combinationally compute the candidate next PC (pc)
//    - Generate the taken signal for branch/jump/exception
//    - Select icpu_adr_o (retry/refetch vs. newly computed pc)
//    - Drive icpu_cycstb_o, icpu_sel_o, icpu_tag_o
//    - Maintain the sequential PC register (pcreg, bits [31:2])
//    - Maintain genpc_refetch_r (historical; not used by active logic)
//
//  Priority for pc selection
//    1. spr_pc_we  → spr_dat_i
//    2. except_start → exception vector
//    3. branch_op  → NOP / J / JR / BAL / BF / BNF / RFE
// ============================================================

`include "or1200_defines.v"

module or1200_genpc (
    // Clock and reset
    input             clk,
    input             rst,

    // External i/f to IC / instruction-fetch subsystem
    output     [31:0] icpu_adr_o,
    output            icpu_cycstb_o,
    output      [3:0] icpu_sel_o,
    output      [3:0] icpu_tag_o,
    input             icpu_rty_i,
    input      [31:0] icpu_adr_i,

    // Internal control i/f
    input       [2:0] branch_op,
    input       [3:0] except_type,
    input             except_prefix,
    input      [31:2] branch_addrofs,
    input      [31:0] lr_restor,
    input             flag,
    output            taken,
    input             except_start,
    input      [31:2] binsn_addr,
    input      [31:0] epcr,
    input      [31:0] spr_dat_i,
    input             spr_pc_we,
    input             genpc_refetch,
    input             genpc_freeze,
    input             genpc_stop_prefetch,   // currently unused by active logic
    input             no_more_dslot
);

// ---------------------------------------------------------------
//  Internal state
// ---------------------------------------------------------------
reg [31:2] pcreg;           // current PC, word-address form
reg [31:0] pc;              // combinational next-fetch byte address
reg        taken;           // combinational taken signal
reg        genpc_refetch_r; // registered copy of genpc_refetch (historical)

// ---------------------------------------------------------------
//  Exception vector construction
//  {20-bit prefix, 4-bit except_type, 8'h00}
//  except_prefix selects EPH0 or EPH1 region
// ---------------------------------------------------------------
wire [31:0] except_vector =
    { except_prefix ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P,
      except_type,
      8'h00 };

// ---------------------------------------------------------------
//  Combinational: next PC and taken
// ---------------------------------------------------------------
always @(*) begin
    // Defaults
    pc    = {pcreg + 30'd1, 2'b00};   // sequential: PC + 4 (word+1, bytes+4)
    taken = 1'b0;

    casez ({spr_pc_we, except_start, branch_op})

        // ---- SPR-based PC write (highest priority) -----------
        // taken is intentionally NOT set for SPR writes
        5'b1_?_???: begin
            pc    = spr_dat_i;
            taken = 1'b0;
        end

        // ---- Exception entry ---------------------------------
        5'b0_1_???: begin
            pc    = except_vector;
            taken = 1'b1;
        end

        // ---- Normal branch / jump / sequential ---------------

        // NOP: sequential
        5'b0_0_000: begin   // `OR1200_BRANCHOP_NOP
            pc    = {pcreg + 30'd1, 2'b00};
            taken = 1'b0;
        end

        // J: direct jump — target is branch_addrofs
        5'b0_0_001: begin   // `OR1200_BRANCHOP_J
            pc    = {branch_addrofs, 2'b00};
            taken = 1'b1;
        end

        // JR: register jump — target is lr_restor
        5'b0_0_010: begin   // `OR1200_BRANCHOP_JR
            pc    = lr_restor;
            taken = 1'b1;
        end

        // BAL: branch-and-link — target is binsn_addr + branch_addrofs
        5'b0_0_011: begin   // `OR1200_BRANCHOP_BAL
            pc    = {binsn_addr + branch_addrofs, 2'b00};
            taken = 1'b1;
        end

        // BF: branch if flag — taken only when flag=1
        5'b0_0_100: begin   // `OR1200_BRANCHOP_BF
            if (flag) begin
                pc    = {binsn_addr + branch_addrofs, 2'b00};
                taken = 1'b1;
            end else begin
                pc    = {pcreg + 30'd1, 2'b00};
                taken = 1'b0;
            end
        end

        // BNF: branch if not flag — taken only when flag=0
        5'b0_0_101: begin   // `OR1200_BRANCHOP_BNF
            if (!flag) begin
                pc    = {binsn_addr + branch_addrofs, 2'b00};
                taken = 1'b1;
            end else begin
                pc    = {pcreg + 30'd1, 2'b00};
                taken = 1'b0;
            end
        end

        // RFE: return from exception — target is epcr
        5'b0_0_110: begin   // `OR1200_BRANCHOP_RFE
            pc    = epcr;
            taken = 1'b1;
        end

        // Catch-all: sequential, not taken
        default: begin
            pc    = {pcreg + 30'd1, 2'b00};
            taken = 1'b0;
        end

    endcase
end

// ---------------------------------------------------------------
//  icpu_adr_o: normally the newly computed pc, but during a
//  retry or refetch (when no higher-priority redirection is
//  active) the previous address icpu_adr_i is re-issued.
//
//  Re-issue condition:
//    ~no_more_dslot & ~except_start & ~spr_pc_we &
//    (icpu_rty_i | genpc_refetch)
// ---------------------------------------------------------------
assign icpu_adr_o =
    (~no_more_dslot & ~except_start & ~spr_pc_we &
     (icpu_rty_i | genpc_refetch))
        ? icpu_adr_i
        : pc;

// ---------------------------------------------------------------
//  Fixed / simple instruction-side interface signals
// ---------------------------------------------------------------
assign icpu_cycstb_o = ~genpc_freeze;          // active when not frozen
assign icpu_sel_o    = 4'b1111;                // all byte lanes selected
assign icpu_tag_o    = `OR1200_ITAG_NI;        // normal instruction tag

// ---------------------------------------------------------------
//  Sequential state: pcreg and genpc_refetch_r
//
//  Reset value of pcreg:
//    The reset exception vector (EPH0) is at
//    {OR1200_EXCEPT_EPH0_P, OR1200_EXCEPT_RESET, 8'h00} = 0x0000_0100.
//    pcreg is initialised to (0x100 - 4) >> 2 = 0x3F so that the
//    first normal sequential update reaches 0x0000_0100.
//
//  Update priority (after reset):
//    1. spr_pc_we                   → load spr_dat_i[31:2]
//    2. no_more_dslot               → load pc[31:2]
//    3. except_start                → load pc[31:2]
//    4. normal advance condition    → load pc[31:2]
//       (requires ~genpc_freeze & ~icpu_rty_i & ~genpc_refetch)
// ---------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Initialise pcreg to (reset_exception_vector - 4) >> 2.
        //
        // The reset exception vector in EPH0 is:
        //   { OR1200_EXCEPT_EPH0_P[19:0], OR1200_EXCEPT_RESET[3:0], 8'h00 }
        //   = 32'h0000_0100 (for the default OR1200 configuration)
        //
        // Storing {EPH0_P, EXCEPT_RESET, 6'h3F} as the 30-bit word address
        // means the value is (reset_vector - 4) >> 2, so the very first
        // sequential pcreg+1 update produces the correct reset-vector word
        // address, which maps to reset_vector as a byte address.
        pcreg           <= {`OR1200_EXCEPT_EPH0_P, `OR1200_EXCEPT_RESET, 6'h3F};
        genpc_refetch_r <= 1'b0;
    end else begin
        // genpc_refetch_r: registered copy (historical, not used by active logic)
        genpc_refetch_r <= genpc_refetch;

        // pcreg update
        if (spr_pc_we) begin
            // Highest priority: SPR-directed PC write
            pcreg <= spr_dat_i[31:2];
        end else if (no_more_dslot | except_start |
                     (~genpc_freeze & ~icpu_rty_i & ~genpc_refetch)) begin
            // Load the candidate next PC
            pcreg <= pc[31:2];
        end
        // else: hold pcreg (frozen, retry, or refetch)
    end
end

endmodule