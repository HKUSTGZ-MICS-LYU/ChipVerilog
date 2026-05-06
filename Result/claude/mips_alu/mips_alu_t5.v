//=============================================================================
// File        : alu.v
// Module      : alu
// Project     : MIPS_16 (16-bit, 5-stage static pipeline)
// Stage       : EX_stage
// Description : Combinational Arithmetic Logic Unit.
//
//               Receives two 16-bit source operands (a, b) and a 3-bit
//               control signal (cmd), and produces a 16-bit result (r).
//               The result is consumed by MEM_stage / WB_stage downstream.
//
//               Although r is declared `reg` (so it can be assigned inside
//               an always block), it is purely combinational logic driven
//               by `always @(*)`. There is no clock or reset in this block.
//
// Operations  :
//   ALU_ADD : r = a + b               (also used for ADDI, LD/ST addr calc)
//   ALU_SUB : r = a - b
//   ALU_AND : r = a & b
//   ALU_OR  : r = a | b
//   ALU_XOR : r = a ^ b
//   ALU_SL  : r = a << b              (logical left shift)
//   ALU_SR  : r = a >>> b             (arithmetic right shift, sign extended)
//   ALU_SRU : r = a >>  b             (logical right shift, zero filled)
//   ALU_NC  : r = 16'bx               (don't-care; ALU result unused)
//   default : r = 16'b0  + sim-only $display warning
//
// Synthesis  : Define CODE_FOR_SYNTHESIS to strip the simulation-only
//              $display in the default branch.
//=============================================================================
`include "mips_16_defs.v"

module alu
(
    input      [15:0] a,    // src1: from RF read port / forwarded value
    input      [15:0] b,    // src2: from RF read port, sign-ext imm, or shamt
    input      [ 2:0] cmd,  // ALU function select (see mips_16_defs.v)

    output reg [15:0] r     // ALU result (combinational; not a flip-flop)
);

    // -------------------------------------------------------------------
    // Combinational ALU
    //
    // Sensitivity list `*` makes the block re-evaluate whenever any of
    // a, b, or cmd changes. Because every cmd encoding (including the
    // default) writes r, no inferred latch is created.
    // -------------------------------------------------------------------
    always @(*) begin
        case (cmd)
            // -------- Arithmetic --------
            `ALU_ADD : r = a + b;
            `ALU_SUB : r = a - b;

            // -------- Bitwise logic --------
            `ALU_AND : r = a & b;
            `ALU_OR  : r = a | b;
            `ALU_XOR : r = a ^ b;

            // -------- Shifts --------
            // Logical left shift: zeros shifted in from the right.
            `ALU_SL  : r = a << b;

            // Arithmetic right shift:
            //   Sign-extend a to 32 bits by replicating a[15] into the
            //   upper half, then shift right. The lower 16 bits of the
            //   shifted 32-bit value form the signed-correct result.
            //   This preserves the sign bit during the shift.
            `ALU_SR  : r = ({{16{a[15]}}, a} >> b);

            // Logical right shift (unsigned):
            //   Zero-extend a to 32 bits, then shift right. Zeros are
            //   shifted into the MSB side; the original sign bit is not
            //   preserved.
            `ALU_SRU : r = ({16'b0, a} >> b);

            // -------- No-care / invalid --------
            // Driving 'x lets synthesis treat r as don't-care here, and
            // helps simulation flag any consumer that mistakenly relies
            // on the ALU output during this cycle.
            `ALU_NC  : r = 16'bx;

            default  : begin
                r = 16'b0;
`ifndef CODE_FOR_SYNTHESIS
                // Simulation-only diagnostic. Stripped by defining
                // CODE_FOR_SYNTHESIS at compile time for synthesis runs.
                $display("[%0t] alu: ERROR - unknown ALU cmd = %b", $time, cmd);
`endif
            end
        endcase
    end

endmodule