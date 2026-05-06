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

wire [`PC_WIDTH-1:0] branch_offset;
wire [`PC_WIDTH-1:0] pc_plus_one;
wire [`PC_WIDTH-1:0] branch_target;

assign branch_offset = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};
assign pc_plus_one = pc + {{(`PC_WIDTH-1){1'b0}}, 1'b1};
assign branch_target = pc + branch_offset;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= {`PC_WIDTH{1'b0}};
    end else if (instruction_fetch_en) begin
        if (branch_taken) begin
            pc <= branch_target;
        end else begin
            pc <= pc_plus_one;
        end
    end
end

instruction_mem imem (
    .address(pc),
    .instruction(instruction)
);

endmodule

module instruction_mem
(
    input      [`PC_WIDTH-1:0] address,
    output reg [15:0]          instruction
);

always @(*) begin
    case (address)
        default: instruction = 16'h0000;
    endcase
end

endmodule
