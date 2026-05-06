`timescale 1ns / 1ps

//============================================================
// Module: IF_stage
// Description: Instruction Fetch stage of MIPS_16 5-stage pipeline
//              - Maintains the Program Counter (PC)
//              - Fetches 16-bit instructions from instruction memory
//              - Supports sequential fetch, branch redirection,
//                synchronous reset, and pipeline stall (PC hold)
//============================================================
module IF_stage
(
    input                           clk,
    input                           rst,                //active high
    input                           instruction_fetch_en,
    
    input   [5:0]                   branch_offset_imm,
    input                           branch_taken,
    
    output  reg [`PC_WIDTH-1:0]     pc,
    output      [15:0]              instruction
);

    //--------------------------------------------------------
    // Sign-extended branch offset
    // The MSB of branch_offset_imm[5] is used as the sign bit
    // to support both forward and backward branches.
    //--------------------------------------------------------
    wire [`PC_WIDTH-1:0] branch_offset_ext;
    
    assign branch_offset_ext = { {(`PC_WIDTH-6){branch_offset_imm[5]}},
                                 branch_offset_imm };
    
    //--------------------------------------------------------
    // Program Counter update logic
    //
    // Priority:
    //   1. rst                 -> PC <= 0
    //   2. !instruction_fetch_en -> PC holds (pipeline stall)
    //   3. branch_taken        -> PC <= PC + sign_ext(offset)
    //   4. default             -> PC <= PC + 1 (sequential fetch)
    //--------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pc <= {`PC_WIDTH{1'b0}};
        end
        else if (instruction_fetch_en) begin
            if (branch_taken)
                pc <= pc + branch_offset_ext;
            else
                pc <= pc + {{(`PC_WIDTH-1){1'b0}}, 1'b1};
        end
        // else: instruction_fetch_en == 0 -> PC holds its value (stall)
    end
    
    //--------------------------------------------------------
    // Instruction Memory instantiation
    // Asynchronous read ROM, addressed by current PC.
    // Can later be replaced by I-cache or external I-mem interface.
    //--------------------------------------------------------
    instruction_mem imem
    (
        .addr        (pc),
        .instruction (instruction)
    );
    
endmodule