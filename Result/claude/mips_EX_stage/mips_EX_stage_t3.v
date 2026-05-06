// ============================================================
// EX_stage.v  –  Execution Stage for the MIPS-16 Pipeline
//
// pipeline_reg_in  [56:0]  from ID_stage:
//   [56:54]  alu_cmd    (3-bit ALU control)
//   [53:38]  alu_src1   (16-bit first operand)
//   [37:22]  alu_src2   (16-bit second operand)
//   [21:5]   mem control: mem_write_en, mem_write_data[15:0]
//   [4:0]    WB control : write_back_en, write_back_dest[2:0], write_back_result_mux
//
// pipeline_reg_out [37:0]  to MEM_stage:
//   [37:22]  ex_alu_result  (16-bit ALU result)
//   [21:5]   mem control    (passed through from pipeline_reg_in)
//   [4:0]    WB control     (passed through from pipeline_reg_in)
//
// ex_op_dest [2:0]  to hazard detection unit  (= pipeline_reg_in[3:1])
// ============================================================

`include "mips_16_defs.v"

module EX_stage
(
    input                   clk,
    input                   rst,

    // from ID_stage
    input        [56:0]     pipeline_reg_in,    // [56:54] ex_alu_cmd[2:0]
                                                // [53:38] ex_alu_src1[15:0]
                                                // [37:22] ex_alu_src2[15:0]
                                                // [21:5]  mem_write_en, mem_write_data[15:0]
                                                // [4:0]   write_back_en, write_back_dest[2:0],
                                                //         write_back_result_mux

    // to MEM_stage
    output reg   [37:0]     pipeline_reg_out,   // [37:22] ex_alu_result[15:0]
                                                // [21:5]  mem_write_en, mem_write_data[15:0]
                                                // [4:0]   write_back_en, write_back_dest[2:0],
                                                //         write_back_result_mux

    // to hazard detection unit
    output       [2:0]      ex_op_dest
);

    // ----------------------------------------------------------
    // Unpack pipeline_reg_in fields
    // ----------------------------------------------------------
    wire [2:0]  alu_cmd;
    wire [15:0] alu_src1;
    wire [15:0] alu_src2;

    assign alu_cmd  = pipeline_reg_in[56:54];
    assign alu_src1 = pipeline_reg_in[53:38];
    assign alu_src2 = pipeline_reg_in[37:22];

    // ----------------------------------------------------------
    // ALU instantiation
    // ----------------------------------------------------------
    wire [15:0] ex_alu_result;

    alu alu_inst
    (
        .a   (alu_src1),
        .b   (alu_src2),
        .cmd (alu_cmd),
        .r   (ex_alu_result)
    );

    // ----------------------------------------------------------
    // Pipeline register : synchronous update, synchronous reset
    // On rst  : clear entire output register to 0 to prevent
    //           invalid control / data from reaching MEM_stage.
    // On !rst : latch ALU result into [37:22] and pass the lower
    //           22 bits (mem + WB control) straight through.
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pipeline_reg_out <= 38'b0;
        else begin
            pipeline_reg_out[37:22] <= ex_alu_result;           // ALU result
            pipeline_reg_out[21:0]  <= pipeline_reg_in[21:0];   // mem + WB ctrl pass-through
        end
    end

    // ----------------------------------------------------------
    // Destination register to hazard detection unit
    // Combinational – always reflects the current EX instruction.
    // pipeline_reg_in[3:1] = write_back_dest[2:0]
    // ----------------------------------------------------------
    assign ex_op_dest = pipeline_reg_in[3:1];

endmodule
