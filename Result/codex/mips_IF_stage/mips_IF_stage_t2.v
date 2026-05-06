module IF_stage
(
    input                           clk,
    input                           rst,
    input                           instruction_fetch_en,
    input       [5:0]               branch_offset_imm,
    input                           branch_taken,
    output reg  [`PC_WIDTH-1:0]     pc,
    output      [15:0]              instruction
);

wire [`PC_WIDTH-1:0] branch_offset_ext;

assign branch_offset_ext = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= {`PC_WIDTH{1'b0}};
    end else if (instruction_fetch_en) begin
        if (branch_taken) begin
            pc <= pc + branch_offset_ext;
        end else begin
            pc <= pc + {{(`PC_WIDTH-1){1'b0}}, 1'b1};
        end
    end
end

instruction_mem imem (
    .addr(pc),
    .instruction(instruction)
);

endmodule

module instruction_mem
(
    input      [`PC_WIDTH-1:0] addr,
    output reg [15:0]          instruction
);

always @(*) begin
    case (addr)
        default: instruction = 16'h0000;
    endcase
end

endmodule
