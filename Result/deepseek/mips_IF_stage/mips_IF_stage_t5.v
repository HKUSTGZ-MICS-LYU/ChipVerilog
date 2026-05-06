module IF_stage (
    input                       clk,
    input                       rst,
    input                       instruction_fetch_en,
    input [5:0]                 branch_offset_imm,
    input                       branch_taken,
    output reg [`PC_WIDTH-1:0]  pc,
    output [15:0]               instruction
);

wire [15:0] mem_data;
instruction_mem imem (
    .addr(pc),
    .data(mem_data)
);

assign instruction = mem_data;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 0;
    end else if (instruction_fetch_en) begin
        if (branch_taken) begin
            pc <= pc + { {(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm };
        end else begin
            pc <= pc + 1;
        end
    end
end

endmodule
