module instruction_mem
(
    input                   clk,
    input   [`PC_WIDTH-1:0] pc,
    output  reg [15:0]      instruction
);

wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

always @* begin
    case (rom_addr)
        0: instruction = 16'b0100_0001_0000_0001;
        1: instruction = 16'b0100_0010_0000_0010;
        2: instruction = 16'b0000_0011_0001_0010;
        3: instruction = 16'b0111_0011_0000_0000;
        4: instruction = 16'b1000_0100_0000_0000;
        5: instruction = 16'b0001_0101_0100_0001;
        6: instruction = 16'b1001_0101_0000_0001;
        default: instruction = 16'b0000_0000_0000_0000;
    endcase
end

endmodule
