module instruction_mem
(
    input                   clk,
    input   [`PC_WIDTH-1:0] pc,
    output  [15:0]          instruction
);

reg  [15:0] instruction;
wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;

assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

always @* begin
    case (rom_addr)
        default: instruction = 16'b0000000000000000;
    endcase
end

endmodule
