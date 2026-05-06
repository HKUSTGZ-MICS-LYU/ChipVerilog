`timescale 1ns/1ps

module instruction_mem
(
    input                      clk,
    input  [`PC_WIDTH-1:0]     pc,
    output [15:0]              instruction
);

localparam ADDR_WIDTH = `INSTR_MEM_ADDR_WIDTH;
wire [ADDR_WIDTH-1:0] rom_addr = pc[ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE

reg [15:0] rom [0:(1<<ADDR_WIDTH)-1];
assign instruction = rom[rom_addr];

`else

reg [15:0] instruction;

always @(*) begin
    case (rom_addr)
        // sample program: basic instructions and RAW hazard protection test
        0: instruction = 16'b0010000000000001; // ADDI R0, R0, 1
        1: instruction = 16'b0010000100000010; // ADDI R1, R1, 2
        2: instruction = 16'b0010001000000011; // ADDI R2, R2, 3
        3: instruction = 16'b0000000000100000; // ADD R0, R1, R2
        4: instruction = 16'b1001000000000001; // ST R0, 1(R0)
        5: instruction = 16'b1001100000000010; // LD R3, 1(R0)
        6: instruction = 16'b0000001100000010; // SUB R1, R2, R3
        7: instruction = 16'b0110000000000100; // BZ R0, 4
        default: instruction = 16'b0000000000000000; // NOP
    endcase
end

`endif

endmodule
