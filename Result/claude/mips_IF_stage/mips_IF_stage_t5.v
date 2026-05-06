//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 IF Stage — Instruction Fetch Pipeline Stage         ////
////                                                              ////
////  Maintains program counter, fetches 16-bit instructions      ////
////  from instruction memory, supports branch redirection and    ////
////  pipeline stall via PC hold.                                  ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module IF_stage (
    input                       clk,
    input                       rst,                // active-high
    input                       instruction_fetch_en,

    // Branch control from ID_stage
    input  [5:0]                branch_offset_imm,
    input                       branch_taken,

    // Outputs
    output reg [`PC_WIDTH-1:0]  pc,
    output     [15:0]           instruction
);

    // ----------------------------------------------------------------
    // Sign-extend 6-bit branch offset to PC_WIDTH bits
    // ----------------------------------------------------------------
    wire [`PC_WIDTH-1:0] branch_offset_sext =
        {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

    // ----------------------------------------------------------------
    // Program counter — synchronous update, async reset
    // ----------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= {`PC_WIDTH{1'b0}};
        end else if (instruction_fetch_en) begin
            if (branch_taken)
                pc <= pc + branch_offset_sext;
            else
                pc <= pc + {{(`PC_WIDTH-1){1'b0}}, 1'b1};  // +1
        end
        // else: instruction_fetch_en == 0 → hold PC (pipeline stall)
    end

    // ----------------------------------------------------------------
    // Instruction memory — asynchronous read
    // ----------------------------------------------------------------
    instruction_mem imem (
        .clk         (clk),
        .pc          (pc),
        .instruction (instruction)
    );

endmodule
