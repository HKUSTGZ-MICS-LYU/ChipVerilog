//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 Hazard Detection Unit                               ////
////                                                              ////
////  Detects RAW data hazards by comparing ID-stage source       ////
////  registers against EX/MEM/WB destination registers.          ////
////  No forwarding — stalls pipeline on any match.               ////
////  Register 0 is excluded from hazard comparison.              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module hazard_detection_unit (
    input  [2:0] decoding_op_src1,  // ID stage source register 1
    input  [2:0] decoding_op_src2,  // ID stage source register 2

    input  [2:0] ex_op_dest,        // EX  stage destination register
    input  [2:0] mem_op_dest,       // MEM stage destination register
    input  [2:0] wb_op_dest,        // WB  stage destination register

    output reg   pipeline_stall_n   // Active-low stall
);

    // ----------------------------------------------------------------
    // Combinational RAW hazard detection
    // ----------------------------------------------------------------
    always @(*) begin
        // Default: no hazard — pipeline runs normally
        pipeline_stall_n = 1'b1;

        // Check source register 1 (skip if r0)
        if (decoding_op_src1 != 3'b000) begin
            if (decoding_op_src1 == ex_op_dest  ||
                decoding_op_src1 == mem_op_dest ||
                decoding_op_src1 == wb_op_dest)
                pipeline_stall_n = 1'b0;
        end

        // Check source register 2 (skip if r0)
        if (decoding_op_src2 != 3'b000) begin
            if (decoding_op_src2 == ex_op_dest  ||
                decoding_op_src2 == mem_op_dest ||
                decoding_op_src2 == wb_op_dest)
                pipeline_stall_n = 1'b0;
        end
    end

endmodule
