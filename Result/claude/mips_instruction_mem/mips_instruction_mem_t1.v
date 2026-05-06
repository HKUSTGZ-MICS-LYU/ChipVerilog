//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 Instruction Memory                                  ////
////                                                              ////
////  Asynchronous ROM providing 16-bit instructions to IF_stage. ////
////  Two implementations selected at compile time:               ////
////    USE_SIMULATION_CODE — register-array ROM (TB-initialized) ////
////    default             — synthesizable case-statement ROM     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module instruction_mem (
    input                       clk,            // present for interface consistency; read is async
    input  [`PC_WIDTH-1:0]      pc,
    output [15:0]               instruction
);

    // Use only the lower address bits to index the ROM
    wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
    assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

// ====================================================================
// Path 1 — Simulation ROM (register array, TB-initialized)
// ====================================================================
`ifdef USE_SIMULATION_CODE

    reg [15:0] rom [2**`INSTR_MEM_ADDR_WIDTH-1:0];

    // Asynchronous read — instruction follows rom_addr combinationally
    assign instruction = rom[rom_addr];

// ====================================================================
// Path 2 — Synthesizable ROM (combinational case statement)
// ====================================================================
`else

    reg [15:0] instruction;

    // Instruction encoding helper comments (MIPS_16, 16-bit):
    //   [15:13] opcode  [12:10] rs  [9:7] rt  [6:0] imm/rd
    //
    // Sample program: basic arithmetic, store/load, branch (RAW hazard test)
    always @(rom_addr) begin
        case (rom_addr)
            // ADDI  r1, r0, 5    -> r1 = 0 + 5 = 5
            `INSTR_MEM_ADDR_WIDTH'h0: instruction = 16'b001_000_001_0000101;
            // ADDI  r2, r0, 3    -> r2 = 0 + 3 = 3
            `INSTR_MEM_ADDR_WIDTH'h1: instruction = 16'b001_000_010_0000011;
            // ADD   r3, r1, r2   -> r3 = r1 + r2 = 8
            `INSTR_MEM_ADDR_WIDTH'h2: instruction = 16'b000_001_010_011_0000;
            // ST    r3, 0(r0)    -> mem[0] = r3
            `INSTR_MEM_ADDR_WIDTH'h3: instruction = 16'b101_000_011_0000000;
            // LD    r4, 0(r0)    -> r4 = mem[0] = 8
            `INSTR_MEM_ADDR_WIDTH'h4: instruction = 16'b100_000_100_0000000;
            // SUB   r5, r3, r1   -> r5 = r3 - r1 = 3
            `INSTR_MEM_ADDR_WIDTH'h5: instruction = 16'b000_011_001_101_0001;
            // BZ    r5, +1       -> branch to PC+1+1 if r5 == 0
            `INSTR_MEM_ADDR_WIDTH'h6: instruction = 16'b110_101_000_0000001;
            // NOP (default fall-through target)
            `INSTR_MEM_ADDR_WIDTH'h7: instruction = 16'b0000000000000000;
            // All other addresses return NOP
            default: instruction = 16'b0000000000000000;
        endcase
    end

`endif  // USE_SIMULATION_CODE

endmodule
