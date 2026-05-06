// or1200_lsu - OR1200 Load/Store Unit
// This module generates data access requests, byte selects, alignment checks,
// and data format conversion for the OR1200 processor.

`include "or1200_defines.v"

module or1200_lsu (
    // Internal interface
    input  [31:0] addrbase,
    input  [31:0] addrofs,
    input  [3:0]  lsu_op,
    input  [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output        lsu_stall,
    output        lsu_unstall,
    input         du_stall,
    output        except_align,
    output        except_dtlbmiss,
    output        except_dmmufault,
    output        except_dbuserr,

    // External interface to Data Cache / Data Memory
    output [31:0] dcpu_adr_o,
    output        dcpu_cycstb_o,
    output        dcpu_we_o,
    output [3:0]  dcpu_sel_o,
    output [3:0]  dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input  [31:0] dcpu_dat_i,
    input         dcpu_ack_i,
    input         dcpu_rty_i,
    input         dcpu_err_i,
    input  [3:0]  dcpu_tag_i
);

    // Internal wires
    wire [31:0] effective_addr;
    wire [1:0]  mem2reg_addr;
    wire        aligned;
    wire        lsu_op_nonzero;

    // Effective address generation
    assign effective_addr = addrbase + addrofs;
    assign dcpu_adr_o = effective_addr;
    assign mem2reg_addr = effective_addr[1:0];

    // lsu_op is non-zero check
    assign lsu_op_nonzero = |lsu_op;

    // Alignment check
    // Byte accesses (lsu_op[2:0] == 3'b000 for LBZ/LBS/SB) are always aligned
    // Halfword accesses (lsu_op[2:0] == 3'b001 for LHZ/LHS, 3'b010 for SH) require addr[0] == 0
    // Word accesses (lsu_op[2:0] == 3'b011 for LWZ/LWS, 3'b100 for SW) require addr[1:0] == 2'b00
    reg align_fault;
    always @(*) begin
        casez (lsu_op[2:0])
            // Byte loads and store: no alignment restriction
            3'b?00: align_fault = 1'b0;
            // Halfword loads and store: bit 0 must be 0
            3'b001, 3'b010: align_fault = (mem2reg_addr[0] != 1'b0);
            // Word loads and store: bits 1:0 must be 00
            3'b011, 3'b100: align_fault = (mem2reg_addr != 2'b00);
            default: align_fault = 1'b0; // Treat unknown as byte aligned
        endcase
    end

    assign except_align = align_fault;

    // Request generation
    // dcpu_cycstb_o is asserted when lsu_op is non-zero and there is no blocking condition
    // Blocking conditions: du_stall, lsu_unstall (dcpu_ack_i), except_align
    assign lsu_unstall = dcpu_ack_i;
    assign dcpu_cycstb_o = lsu_op_nonzero & ~du_stall & ~lsu_unstall & ~except_align;

    // Write enable: lsu_op[3] distinguishes stores (1) from loads (0)
    assign dcpu_we_o = lsu_op[3];

    // Tag output: normal data access tag when request active, else idle
    assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

    // Byte select generation
    always @(*) begin
        casez ({lsu_op[2:0], mem2reg_addr})
            // Byte accesses: SB, LBZ, LBS
            {3'b?00, 2'b00}: dcpu_sel_o = 4'b1000;
            {3'b?00, 2'b01}: dcpu_sel_o = 4'b0100;
            {3'b?00, 2'b10}: dcpu_sel_o = 4'b0010;
            {3'b?00, 2'b11}: dcpu_sel_o = 4'b0001;

            // Halfword accesses: SH, LHZ, LHS (aligned cases)
            {3'b001, 2'b00},
            {3'b010, 2'b00}: dcpu_sel_o = 4'b1100;
            {3'b001, 2'b10},
            {3'b010, 2'b10}: dcpu_sel_o = 4'b0011;

            // Word accesses: SW, LWZ, LWS (aligned case)
            {3'b011, 2'b00},
            {3'b100, 2'b00}: dcpu_sel_o = 4'b1111;

            // Misaligned or undefined cases
            default: dcpu_sel_o = 4'b0000;
        endcase
    end

    // Stall generation: asserted when request is active and data side returns rty
    assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;

    // Exception classification from data side
    // These are combinational decodes of dcpu_err_i and dcpu_tag_i
    assign except_dtlbmiss  = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
    assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
    assign except_dbuserr  = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);

    // Data format conversion submodules
    // Memory to register (load data alignment and extension)
    or1200_mem2reg mem2reg (
        .addr    (mem2reg_addr),
        .lsu_op  (lsu_op),
        .memdata (dcpu_dat_i),
        .regdata (lsu_dataout)
    );

    // Register to memory (store data alignment)
    or1200_reg2mem reg2mem (
        .addr    (mem2reg_addr),
        .lsu_op  (lsu_op),
        .regdata (lsu_datain),
        .memdata (dcpu_dat_o)
    );

endmodule
