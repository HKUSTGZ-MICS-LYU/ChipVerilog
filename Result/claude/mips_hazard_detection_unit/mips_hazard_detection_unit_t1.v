// ============================================================
// hazard_detection_unit.v  –  RAW Hazard Detection for MIPS-16
//
// Detects Read-After-Write (RAW) data hazards by comparing the
// source registers of the instruction currently in ID_stage
// against the destination registers of instructions in EX_stage,
// MEM_stage, and WB_stage.
//
// No forwarding logic is present in this design, so any match
// requires a full pipeline stall.
//
// pipeline_stall_n is ACTIVE LOW:
//   1 → pipeline runs normally
//   0 → stall: freeze IF/ID stages, insert bubble into EX
//
// Register 0 is hardwired-zero and is excluded from all checks.
// ============================================================

module hazard_detection_unit
(
    input        [2:0]  decoding_op_src1,   // ID stage source register 1
    input        [2:0]  decoding_op_src2,   // ID stage source register 2

    input        [2:0]  ex_op_dest,         // EX  stage destination register
    input        [2:0]  mem_op_dest,        // MEM stage destination register
    input        [2:0]  wb_op_dest,         // WB  stage destination register

    output reg          pipeline_stall_n    // Active-low stall signal
);

    // ----------------------------------------------------------
    // Combinational hazard check
    // ----------------------------------------------------------
    always @(*) begin
        // Default: no hazard, pipeline runs freely
        pipeline_stall_n = 1'b1;

        // --- Check source register 1 ---
        // Skip register 0 (hardwired zero – never causes a RAW hazard)
        if (decoding_op_src1 != 3'd0) begin
            if (decoding_op_src1 == ex_op_dest  ||
                decoding_op_src1 == mem_op_dest ||
                decoding_op_src1 == wb_op_dest)
                pipeline_stall_n = 1'b0;    // RAW hazard detected
        end

        // --- Check source register 2 ---
        if (decoding_op_src2 != 3'd0) begin
            if (decoding_op_src2 == ex_op_dest  ||
                decoding_op_src2 == mem_op_dest ||
                decoding_op_src2 == wb_op_dest)
                pipeline_stall_n = 1'b0;    // RAW hazard detected
        end
    end

endmodule
