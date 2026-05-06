module IF_stage
(
    input clk,
    input rst,
    input instruction_fetch_en,
    input [5:0] branch_offset_imm,
    input branch_taken,
    output reg [`PC_WIDTH-1:0] pc,
    output [15:0] instruction
);
wire [`PC_WIDTH-1:0] branch_offset_ext = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};
wire [`PC_WIDTH-1:0] next_pc = branch_taken ? (pc + branch_offset_ext) : (pc + 1);
always @(posedge clk or posedge rst) begin
    if (rst) pc <= 0;
    else if (instruction_fetch_en) pc <= next_pc;
end
instruction_mem #(.WIDTH(`PC_WIDTH)) imem (
    .addr(pc),
    .instruction(instruction)
);
endmodule

module instruction_mem #(
    parameter WIDTH = 16
) (
    input [WIDTH-1:0] addr,
    output reg [15:0] instruction
);
reg [15:0] mem [0:255];
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) mem[i] = 16'h0000;
end
always @(*) begin
    if (addr < 256) instruction = mem[addr];
    else instruction = 16'h0000;
end
endmodule
