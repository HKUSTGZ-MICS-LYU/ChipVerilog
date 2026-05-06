module instruction_mem (
    input clk,
    input [`PC_WIDTH-1:0] pc,
    output [15:0] instruction
);
    wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
    assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE
    reg [15:0] rom [2**`INSTR_MEM_ADDR_WIDTH-1:0];
    assign instruction = rom[rom_addr];
`else
    reg [15:0] instruction_reg;
    always @* begin
        case (rom_addr)
            0: instruction_reg = 16'h0001; // ADDI
            1: instruction_reg = 16'h0002; // ADD
            2: instruction_reg = 16'h0003; // SUB
            3: instruction_reg = 16'h0004; // ST
            4: instruction_reg = 16'h0005; // LD
            5: instruction_reg = 16'h0006; // BZ
            default: instruction_reg = 16'h0000; // NOP
        endcase
    end
    assign instruction = instruction_reg;
`endif
endmodule
