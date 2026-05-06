// IF_stage module for MIPS_16 processor
module IF_stage
(
    input                           clk,
    input                           rst,                // active high
    input                           instruction_fetch_en,
    
    input   [5:0]                   branch_offset_imm,
    input                           branch_taken,
    
    output  reg [`PC_WIDTH-1:0]     pc,
    output  [15:0]                  instruction
);

    // Internal signals for PC update
    wire [`PC_WIDTH-1:0] next_pc;
    wire [`PC_WIDTH-1:0] pc_plus_one;
    wire [`PC_WIDTH-1:0] branch_target;
    wire [`PC_WIDTH-1:0] sign_extended_offset;
    
    // Sign extend the 6-bit branch offset to PC_WIDTH
    assign sign_extended_offset = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};
    
    // Calculate PC+1 and branch target
    assign pc_plus_one = pc + 1'b1;
    assign branch_target = pc + sign_extended_offset;
    
    // Select next PC based on branch_taken
    assign next_pc = branch_taken ? branch_target : pc_plus_one;
    
    // PC register update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= {`PC_WIDTH{1'b0}};
        end else if (instruction_fetch_en) begin
            pc <= next_pc;
        end
        // if instruction_fetch_en is low, PC holds its value
    end
    
    // Instantiate instruction memory
    instruction_mem imem (
        .addr(pc),
        .instruction(instruction)
    );

endmodule
