// ============================================================
// instruction_mem.v  –  Instruction Memory (ROM) for MIPS-16
//
// Asynchronous read: output updates immediately when addr changes.
// Depth : 2 ** INST_MEM_ADDR_WIDTH words (one 16-bit word per entry).
// Initialised from "program.hex" via $readmemh at simulation start.
// In synthesis this will infer a ROM / block RAM as appropriate.
// ============================================================

`include "mips_16_defs.v"

module instruction_mem
(
    input  [`INST_MEM_ADDR_WIDTH-1:0]  addr,       // read address (= pc)
    output [15:0]                      instruction  // fetched instruction
);

    // ROM array
    reg [15:0] mem [0 : (1 << `INST_MEM_ADDR_WIDTH) - 1];

    // Initialise from hex file during simulation
    initial begin
        $readmemh("program.hex", mem);
    end

    // Asynchronous read – no clock needed
    assign instruction = mem[addr];

endmodule
