// =============================================================================
// Module:      alu
// Description: Core combinational ALU for the EX_stage of the MIPS-16 processor.
//              Supports 16-bit arithmetic, logic, and shift operations.
// =============================================================================

`include "mips_16_defs.v"

module alu
(
    input       [15:0]  a,      // src1: first source operand
    input       [15:0]  b,      // src2: second source operand / shift amount
    input       [2:0]   cmd,    // function sel: ALU control signal

    output  reg [15:0]  r       // result: 16-bit combinational output
);

    always @(*) begin
        case (cmd)

            // ----------------------------------------------------------------
            // Arithmetic Operations
            // ----------------------------------------------------------------
            ALU_ADD: r = a + b;             // ADD, ADDI, LD/ST address calc
            ALU_SUB: r = a - b;             // SUB, comparison

            // ----------------------------------------------------------------
            // Logical Operations
            // ----------------------------------------------------------------
            ALU_AND: r = a & b;             // Bitwise AND
            ALU_OR:  r = a | b;             // Bitwise OR
            ALU_XOR: r = a ^ b;             // Bitwise XOR

            // ----------------------------------------------------------------
            // Shift Operations
            // ----------------------------------------------------------------
            ALU_SL:  r = a << b;            // Logical left shift

            ALU_SR:  begin                  // Arithmetic right shift (sign-preserving)
                r = {{16{a[15]}}, a} >> b;
            end

            ALU_SRU: begin                  // Logical right shift (zero-fill)
                r = {16'b0, a} >> b;
            end

            // ----------------------------------------------------------------
            // No-operation / Don't-care
            // ----------------------------------------------------------------
            ALU_NC: r = 16'bx;             // ALU result not needed

            // ----------------------------------------------------------------
            // Default: unknown command
            // ----------------------------------------------------------------
            default: begin
                r = 16'b0;
                `ifndef CODE_FOR_SYNTHESIS
                    $display("[ALU ERROR] Unknown ALU cmd: %0b (time=%0t)", cmd, $time);
                `endif
            end

        endcase
    end

endmodule
