module instruction_mem
(
    input                   clk,
    input  [`PC_WIDTH-1:0]  pc,
    output reg [15:0]       instruction
);

wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

always @(*) begin
    case (rom_addr)
        `INSTR_MEM_ADDR_WIDTH'd0: instruction = 16'b0010_0000_0000_0001;
        `INSTR_MEM_ADDR_WIDTH'd1: instruction = 16'b0010_0100_0000_0001;
        `INSTR_MEM_ADDR_WIDTH'd2: instruction = 16'b0000_0110_0101_0000;
        `INSTR_MEM_ADDR_WIDTH'd3: instruction = 16'b0110_0000_1100_0000;
        `INSTR_MEM_ADDR_WIDTH'd4: instruction = 16'b0101_1000_0000_0000;
        `INSTR_MEM_ADDR_WIDTH'd5: instruction = 16'b0001_1011_0001_1000;
        `INSTR_MEM_ADDR_WIDTH'd6: instruction = 16'b0111_1010_0000_0001;
        default:                  instruction = 16'b0000_0000_0000_0000;
    endcase
end

endmodule
