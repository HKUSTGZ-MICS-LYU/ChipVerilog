module instruction_mem
(
    input                   clk,
    input [`PC_WIDTH-1:0]   pc,
    output [15:0]           instruction
);

wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE
reg [15:0] rom [0:(1<<`INSTR_MEM_ADDR_WIDTH)-1];
assign instruction = rom[rom_addr];
`else
reg [15:0] instruction_reg;
assign instruction = instruction_reg;

always @* begin
    case (rom_addr)
        0: instruction_reg = 16'b0101000100000001; // sample ADDI
        1: instruction_reg = 16'b0101001000000010; // sample ADDI
        2: instruction_reg = 16'b0000011011000000; // sample ADD
        3: instruction_reg = 16'b1000001100000000; // sample ST
        4: instruction_reg = 16'b0111001000000000; // sample LD
        5: instruction_reg = 16'b0000100111000001; // sample SUB
        6: instruction_reg = 16'b1100110000000000; // sample BZ
        default: instruction_reg = 16'b0000000000000000; // NOP
    endcase
end
`endif

endmodule
