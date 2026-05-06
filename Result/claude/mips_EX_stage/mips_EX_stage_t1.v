// =============================================================================
// Module:      EX_stage
// Description: Execution stage of the MIPS-16 five-stage pipeline.
//              Instantiates the ALU, computes the operation result, and
//              registers ALU result + pass-through control signals for MEM_stage.
//              Also exposes the destination register to the hazard detection unit.
// =============================================================================

`include "mips_16_defs.v"

module EX_stage
(
    input                   clk,
    input                   rst,

    // From ID_stage
    // [56:54]  3b  : alu_cmd
    // [53:38] 16b  : alu_src1
    // [37:22] 16b  : alu_src2
    // [21:5]  17b  : mem_write_en, mem_write_data[15:0]
    // [4:0]    5b  : write_back_en, write_back_dest[2:0], write_back_result_mux
    input       [56:0]      pipeline_reg_in,

    // To MEM_stage
    // [37:22] 16b  : ex_alu_result[15:0]
    // [21:5]  17b  : mem_write_en, mem_write_data[15:0]
    // [4:0]    5b  : write_back_en, write_back_dest[2:0], write_back_result_mux
    output  reg [37:0]      pipeline_reg_out,

    // To hazard detection unit
    output      [2:0]       ex_op_dest
);

    // -------------------------------------------------------------------------
    // Pipeline register field extraction
    // -------------------------------------------------------------------------
    wire [2:0]  alu_cmd  = pipeline_reg_in[56:54];  // ALU operation selector
    wire [15:0] alu_src1 = pipeline_reg_in[53:38];  // First ALU operand
    wire [15:0] alu_src2 = pipeline_reg_in[37:22];  // Second ALU operand / shift amount

    // -------------------------------------------------------------------------
    // ALU result wire
    // -------------------------------------------------------------------------
    wire [15:0] ex_alu_result;

    // -------------------------------------------------------------------------
    // ALU instantiation
    // -------------------------------------------------------------------------
    alu alu_inst
    (
        .a   (alu_src1),
        .b   (alu_src2),
        .cmd (alu_cmd),
        .r   (ex_alu_result)
    );

    // -------------------------------------------------------------------------
    // Output pipeline register — synchronous write, synchronous reset
    //   On rst  : clear entire output register to zero
    //   On !rst : latch ALU result into [37:22];
    //             pass through mem + write-back control bits [21:0] unchanged
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 38'b0;
        end else begin
            pipeline_reg_out[37:22] <= ex_alu_result;       // ALU result
            pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0]; // MEM + WB ctrl pass-through
        end
    end

    // -------------------------------------------------------------------------
    // Destination register output to hazard detection unit (combinational)
    //   Taken from pipeline_reg_in[3:1] = write_back_dest[2:0]
    // -------------------------------------------------------------------------
    assign ex_op_dest = pipeline_reg_in[3:1];

endmodule
