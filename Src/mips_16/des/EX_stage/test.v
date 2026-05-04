//==============================================================================
// Module      : EX_stage
// Project     : MIPS_16 Five-Stage Pipeline Processor
// Description : Execution stage of the MIPS_16 pipeline. Instantiates the ALU
//               to perform arithmetic / logic / address-calc operations, and
//               forwards MEM and WB control signals to the next stage through
//               a pipeline register. Also exposes the EX-stage destination
//               register to the hazard detection unit for RAW hazard checking.
//
// Pipeline IN  (pipeline_reg_in [56:0], from ID_stage):
//   [56:54] ex_alu_cmd        (3 bits)   -- ALU operation code
//   [53:38] ex_alu_src1       (16 bits)  -- ALU operand 1
//   [37:22] ex_alu_src2       (16 bits)  -- ALU operand 2
//   [21]    mem_write_en      (1 bit)    -- Memory write enable
//   [20:5]  mem_write_data    (16 bits)  -- Memory write data
//   [4]     write_back_en     (1 bit)    -- Register file write enable
//   [3:1]   write_back_dest   (3 bits)   -- Destination register index
//   [0]     write_back_result_mux (1 bit)-- WB result select (ALU vs MEM)
//
// Pipeline OUT (pipeline_reg_out [37:0], to MEM_stage):
//   [37:22] ex_alu_result     (16 bits)  -- ALU computation result
//   [21:5]  mem control       (17 bits)  -- Passed through from input
//   [4:0]   wb  control       (5  bits)  -- Passed through from input
//==============================================================================
module EX_stage
(
    input                   clk,
    input                   rst,

    // From ID_stage : decoded control + operands
    input       [56:0]      pipeline_reg_in,

    // To MEM_stage : ALU result + MEM/WB control
    output reg  [37:0]      pipeline_reg_out,

    // To hazard detection unit : current EX-stage destination register
    output      [2:0]       ex_op_dest
);

    //--------------------------------------------------------------------------
    // 1. Field extraction from the input pipeline register
    //--------------------------------------------------------------------------
    wire [2:0]  ex_alu_cmd;
    wire [15:0] ex_alu_src1;
    wire [15:0] ex_alu_src2;
    wire [21:0] mem_wb_ctrl;     // lower 22 bits forwarded as-is to MEM_stage

    assign ex_alu_cmd  = pipeline_reg_in[56:54];
    assign ex_alu_src1 = pipeline_reg_in[53:38];
    assign ex_alu_src2 = pipeline_reg_in[37:22];
    assign mem_wb_ctrl = pipeline_reg_in[21:0];

    //--------------------------------------------------------------------------
    // 2. ALU instantiation
    //    The ALU performs arithmetic / logic operations and also computes
    //    effective addresses for load / store instructions.
    //--------------------------------------------------------------------------
    wire [15:0] ex_alu_result;

    alu  alu_inst (
        .alu_cmd    (ex_alu_cmd   ),
        .alu_src1   (ex_alu_src1  ),
        .alu_src2   (ex_alu_src2  ),
        .alu_result (ex_alu_result)
    );

    //--------------------------------------------------------------------------
    // 3. Hazard detection feedback (combinational)
    //    Expose the destination register of the instruction currently in EX
    //    so that the hazard unit can compare it against the source registers
    //    of younger instructions in IF/ID to detect RAW hazards.
    //--------------------------------------------------------------------------
    assign ex_op_dest = pipeline_reg_in[3:1];

    //--------------------------------------------------------------------------
    // 4. EX/MEM pipeline register
    //    Synchronous reset clears the register to prevent stale or invalid
    //    control signals from leaking into MEM/WB after reset.
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 38'b0;
        end
        else begin
            pipeline_reg_out[37:22] <= ex_alu_result;   // ALU result
            pipeline_reg_out[21:0]  <= mem_wb_ctrl;     // pass-through
        end
    end

endmodule