`define PC_WIDTH 32

module IF_stage
(
    input                       clk,
    input                       rst,
    input                       instruction_fetch_en,
    input       [5:0]           branch_offset_imm,
    input                       branch_taken,
    output reg  [`PC_WIDTH-1:0] pc,
    output      [15:0]          instruction
);

    wire [`PC_WIDTH-1:0] next_pc;
    wire [`PC_WIDTH-1:0] sign_ext_offset;

    assign sign_ext_offset = {{(`PC_WIDTH-6){branch_offset_imm[5]}}, branch_offset_imm};

    // Sequential PC update (synchronous reset)
    always @(posedge clk) begin
        if (rst)
            pc <= {`PC_WIDTH{1'b0}};
        else if (instruction_fetch_en) begin
            if (branch_taken)
                pc <= pc + sign_ext_offset;
            else
                pc <= pc + 1;
        end
    end

    // Instruction memory instantiation (asynchronous)
    instruction_mem #(
        .ADDR_WIDTH(`PC_WIDTH),
        .DATA_WIDTH(16)
    ) imem (
        .addr(pc),
        .data(instruction)
    );

endmodule
