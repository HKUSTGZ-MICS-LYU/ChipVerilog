`timescale 1ns / 1ps

module instruction_mem
#(
    parameter PC_WIDTH = 32,
    parameter INSTR_MEM_ADDR_WIDTH = 10
)
(
    input                       clk,
    input   [PC_WIDTH-1:0]      pc,
    output  [15:0]              instruction
);

    localparam ROM_DEPTH = 1 << INSTR_MEM_ADDR_WIDTH;
    wire [INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
    assign rom_addr = pc[INSTR_MEM_ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE
    reg [15:0] rom [0:ROM_DEPTH-1];
    assign instruction = rom[rom_addr];
`else
    reg [15:0] instruction;
    always @(*) begin
        case (rom_addr)
            // Sample program: basic instructions and RAW hazard protection test
            // ADDI r1, r0, 5   -> op:ADDI(3'b000), rs:r0(3'b000), rd:r1(3'b001), imm:5
            10'd0: instruction = {3'b000, 3'b000, 3'b001, 7'd5};
            // ADDI r2, r0, 10  -> op:ADDI, rs:r0, rd:r2(010), imm:10
            10'd1: instruction = {3'b000, 3'b000, 3'b010, 7'd10};
            // ADD r3, r1, r2   -> op:ADD(3'b001), rs:r1, rt:r2, rd:r3(011), funct:0000
            10'd2: instruction = {3'b001, 3'b001, 3'b010, 3'b011, 4'b0000};
            // ST r3, r0, 0     -> op:ST(3'b010), rs:r0, rt:r3, imm:0
            10'd3: instruction = {3'b010, 3'b000, 3'b011, 7'd0};
            // LD r4, r0, 0     -> op:LD(3'b011), rs:r0, rd:r4(100), imm:0
            10'd4: instruction = {3'b011, 3'b000, 3'b100, 7'd0};
            // SUB r5, r4, r1   -> op:SUB(3'b101), rs:r4, rt:r1, rd:r5(101), funct:0001
            10'd5: instruction = {3'b101, 3'b100, 3'b001, 3'b101, 4'b0001};
            // BZ r5, 2         -> op:BZ(3'b100), rs:r5, offset:2
            10'd6: instruction = {3'b100, 3'b101, 7'd2};
            // NOP
            10'd7: instruction = 16'b0000000000000000;
            default: instruction = 16'b0000000000000000;
        endcase
    end
`endif

endmodule
