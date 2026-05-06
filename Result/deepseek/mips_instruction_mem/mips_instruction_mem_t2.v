`timescale 1ns / 1ps

module instruction_mem
#(
    parameter PC_WIDTH = 32,
    parameter INSTR_MEM_ADDR_WIDTH = 8
)
(
    input                   clk,
    input  [PC_WIDTH-1:0]   pc,
    output [15:0]           instruction
);

    localparam ROM_DEPTH = 1 << INSTR_MEM_ADDR_WIDTH;
    wire [INSTR_MEM_ADDR_WIDTH-1:0] rom_addr = pc[INSTR_MEM_ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE
    reg [15:0] rom [0:ROM_DEPTH-1];
    assign instruction = rom[rom_addr];
`else
    reg [15:0] instruction;
    always @(*) begin
        case(rom_addr)
            // Predefined sample program
            // ADDI r1, r0, 5
            8'd0:   instruction = 16'b001000_0001_0101;
            // ADDI r2, r0, 10
            8'd1:   instruction = 16'b001000_0010_1010;
            // ADD r3, r1, r2
            8'd2:   instruction = 16'b000000_0011_0001_0010_0;
            // ST r3, 0(r0)
            8'd3:   instruction = 16'b010000_0011_0000_0000;
            // LD r4, 0(r0)
            8'd4:   instruction = 16'b010001_0100_0000_0000;
            // SUB r5, r4, r1
            8'd5:   instruction = 16'b000001_0101_0100_0001_0;
            // BZ r5, +2
            8'd6:   instruction = 16'b100000_0101_000010;
            // NOP after branch
            8'd7:   instruction = 16'b000000_0000_0000_0000_0;
            // NOP
            8'd8:   instruction = 16'b000000_0000_0000_0000_0;
            default: instruction = 16'b0000000000000000; // NOP
        endcase
    end
`endif

endmodule
