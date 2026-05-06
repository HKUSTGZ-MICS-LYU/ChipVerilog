// ============================================================
// alu.v  –  16-bit ALU for the MIPS-16 EX stage
//
// Inputs  : a   [15:0]  first source operand  (from register file)
//           b   [15:0]  second source operand (reg / imm / shift amt)
//           cmd [2:0]   ALU control signal
// Output  : r   [15:0]  combinational result (updates with inputs)
// ============================================================

`include "mips_16_defs.v"

module alu
(
    input        [15:0] a,      // src1
    input        [15:0] b,      // src2
    input        [2:0]  cmd,    // function sel

    output reg   [15:0] r       // result
);

    always @(*) begin
        case (cmd)

            // --------------------------------------------------
            // Arithmetic
            // --------------------------------------------------
            `ALU_ADD : r = a + b;           // addition  (ADD, ADDI, LD/ST addr)
            `ALU_SUB : r = a - b;           // subtraction (SUB)

            // --------------------------------------------------
            // Bitwise logic
            // --------------------------------------------------
            `ALU_AND : r = a & b;           // bitwise AND
            `ALU_OR  : r = a | b;           // bitwise OR
            `ALU_XOR : r = a ^ b;           // bitwise XOR

            // --------------------------------------------------
            // Shift operations
            // --------------------------------------------------
            // Logical left shift – zeros fill from the right
            `ALU_SL  : r = a << b;

            // Arithmetic right shift – sign bit (a[15]) is replicated
            // into the vacated upper bits.
            // Technique: sign-extend a to 32 bits, shift right, keep low 16.
            `ALU_SR  : r = {{16{a[15]}}, a} >> b;

            // Logical (unsigned) right shift – zeros fill from the left
            `ALU_SRU : r = {16'b0, a} >> b;

            // --------------------------------------------------
            // Don't-care / no-operation
            // --------------------------------------------------
            // ALU_NC: result is intentionally undefined
            3'bxxx   : r = 16'bx;

            // --------------------------------------------------
            // Catch-all: unknown command
            // --------------------------------------------------
            default  : begin
                r = 16'b0;
`ifndef CODE_FOR_SYNTHESIS
                $display("[ALU ERROR] Unknown cmd = %b at time %0t", cmd, $time);
`endif
            end

        endcase
    end

endmodule
