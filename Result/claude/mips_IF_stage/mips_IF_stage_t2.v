// ============================================================
// IF_stage.v  –  Instruction Fetch Stage for MIPS-16
//
// Responsibilities:
//   1. Maintain the Program Counter (pc)
//   2. Fetch 16-bit instruction from asynchronous instruction ROM
//   3. Support sequential advance (pc + 1) and branch redirection
//   4. Freeze pc during pipeline stalls (instruction_fetch_en == 0)
//
// PC update rules (evaluated on posedge clk):
//   rst == 1                          → pc = 0
//   instruction_fetch_en == 0         → pc unchanged  (stall)
//   instruction_fetch_en == 1
//       branch_taken == 1             → pc = pc + sign_ext(branch_offset_imm)
//       branch_taken == 0             → pc = pc + 1
//
// Note: MIPS_16 uses one branch delay slot.  The slot instruction
// is already being fetched when branch_taken arrives from ID_stage,
// and it will execute normally before the branch target takes effect.
// This module implements the PC redirect; slot management is handled
// by the surrounding pipeline control logic.
// ============================================================

`include "mips_16_defs.v"

module IF_stage
(
    input                           clk,
    input                           rst,                // active high
    input                           instruction_fetch_en,

    // branch interface (from ID_stage)
    input  [5:0]                    branch_offset_imm,
    input                           branch_taken,

    // outputs
    output reg [`PC_WIDTH-1:0]      pc,
    output     [15:0]               instruction
);

    // ----------------------------------------------------------
    // Sign-extended branch offset: 6-bit → PC_WIDTH bits
    // ----------------------------------------------------------
    wire [`PC_WIDTH-1:0] branch_offset_sign_ext =
        {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

    // ----------------------------------------------------------
    // Program counter update
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pc <= {`PC_WIDTH{1'b0}};
        end else if (instruction_fetch_en) begin
            if (branch_taken)
                pc <= pc + branch_offset_sign_ext;  // branch redirect
            else
                pc <= pc + {{(`PC_WIDTH-1){1'b0}}, 1'b1};  // pc + 1
            // else: stall – pc holds current value (no update)
        end
    end

    // ----------------------------------------------------------
    // Instruction memory instantiation (asynchronous ROM)
    // The current pc is used directly as the read address.
    // mem output is combinational – no extra latency.
    // ----------------------------------------------------------
    instruction_mem imem
    (
        .addr        (pc),
        .instruction (instruction)
    );

endmodule
