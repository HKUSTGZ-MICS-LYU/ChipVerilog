module instruction_mem
(
    input                    clk,
    input  [`PC_WIDTH-1:0]   pc,
    output reg [15:0]        instruction
);

wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

always @(*) begin
    case (rom_addr)
        `INSTR_MEM_ADDR_WIDTH'd0: instruction = 16'h8041;
        `INSTR_MEM_ADDR_WIDTH'd1: instruction = 16'h8082;
        `INSTR_MEM_ADDR_WIDTH'd2: instruction = 16'h0530;
        `INSTR_MEM_ADDR_WIDTH'd3: instruction = 16'hD0C0;
        `INSTR_MEM_ADDR_WIDTH'd4: instruction = 16'hC100;
        `INSTR_MEM_ADDR_WIDTH'd5: instruction = 16'h18C0;
        `INSTR_MEM_ADDR_WIDTH'd6: instruction = 16'hE03E;
        default:                instruction = 16'h0000;
    endcase
end

endmodule
