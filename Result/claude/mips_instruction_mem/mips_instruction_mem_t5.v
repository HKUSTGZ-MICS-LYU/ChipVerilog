//=============================================================================
// Module      : instruction_mem
// Description : Instruction Memory for MIPS_16 IF_stage
//               - Asynchronous read ROM
//               - Two implementations selected by USE_SIMULATION_CODE macro
//                 * Simulation ROM : reg array, initialized by testbench
//                 * Synthesizable  : case-statement ROM with sample program
// Architecture: MIPS_16 (16-bit instruction width)
//=============================================================================

`include "define.v"   // expects `PC_WIDTH and `INSTR_MEM_ADDR_WIDTH

module instruction_mem      // a rtl simulation rom, rom initial code can be found in the testbench
(
    input                       clk,            // asynchronized!!
    input   [`PC_WIDTH-1:0]     pc,

    output  [15:0]              instruction
);

    //-------------------------------------------------------------------------
    // Address generation
    // Use only the lower INSTR_MEM_ADDR_WIDTH bits of PC as ROM address,
    // so the PC interface stays flexible while the ROM depth is decoupled.
    //-------------------------------------------------------------------------
    wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
    assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];


`ifdef USE_SIMULATION_CODE
    //=========================================================================
    // Simulation ROM implementation
    // -----------------------------------------------------------------------
    // ROM contents are NOT hardcoded here. The testbench is responsible for
    // loading the program (e.g. via $readmemb / $readmemh or direct hierarchical
    // assignment). The instruction output is produced by an asynchronous
    // continuous assignment.
    //=========================================================================
    reg  [15:0] rom [0 : (2**`INSTR_MEM_ADDR_WIDTH) - 1];

    assign instruction = rom[rom_addr];

`else
    //=========================================================================
    // Synthesizable ROM implementation
    // -----------------------------------------------------------------------
    // A predefined sample program is encoded with a combinational case
    // statement. The program corresponds to the basic instruction / RAW
    // hazard protection test described in the MIPS_16 specification:
    //   ADDI, ADD, ST, LD, SUB, BZ ...
    // Undefined addresses output 16'h0000 (NOP).
    //=========================================================================
    reg [15:0] instruction_r;
    assign instruction = instruction_r;

    always @(*) begin
        case (rom_addr)
            //-----------------------------------------------------------------
            // Sample program : basic instruction & RAW hazard protection test
            //-----------------------------------------------------------------
            // Instruction encoding format (MIPS_16, illustrative):
            //   [15:12] opcode | [11:9] rs | [8:6] rt | [5:3] rd | [2:0] func/imm
            //
            // The exact opcode encodings below follow the MIPS_16 spec used in
            // the project. Adjust the constants if the encoding table differs.
            //-----------------------------------------------------------------
            'd0  : instruction_r = 16'b0011_001_000_000100;  // ADDI R1, R0, #4    ; R1 <= 4
            'd1  : instruction_r = 16'b0011_010_000_000010;  // ADDI R2, R0, #2    ; R2 <= 2
            'd2  : instruction_r = 16'b0011_011_000_000001;  // ADDI R3, R0, #1    ; R3 <= 1
            'd3  : instruction_r = 16'b0001_001_010_011_000; // ADD  R3, R1, R2    ; R3 <= R1+R2 (RAW after ADDI)
            'd4  : instruction_r = 16'b1000_011_000_000000;  // ST   R3, 0(R0)     ; MEM[0] <= R3
            'd5  : instruction_r = 16'b1001_100_000_000000;  // LD   R4, 0(R0)     ; R4 <= MEM[0]
            'd6  : instruction_r = 16'b0010_101_100_001_000; // SUB  R5, R4, R1    ; R5 <= R4-R1 (RAW after LD)
            'd7  : instruction_r = 16'b1100_101_111111100;   // BZ   R5, -4        ; branch if R5==0

            //-----------------------------------------------------------------
            // Default : NOP for any unmapped address
            //-----------------------------------------------------------------
            default : instruction_r = 16'h0000;
        endcase
    end
`endif

endmodule