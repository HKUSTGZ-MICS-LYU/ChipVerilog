module hazard_detection_unit
(
    input       [2:0]   decoding_op_src1,       // ID stage source_1 register number
    input       [2:0]   decoding_op_src2,       // ID stage source_2 register number
    
    input       [2:0]   ex_op_dest,             // EX stage destination register number
    input       [2:0]   mem_op_dest,            // MEM stage destination register number
    input       [2:0]   wb_op_dest,             // WB stage destination register number
    
    output  reg         pipeline_stall_n        // Active low
);

    always @(*) begin
        // Default: no hazard, pipeline continues normally
        pipeline_stall_n = 1'b1;
        
        // Check source register 1 (ignore register 0)
        if (decoding_op_src1 != 3'b000) begin
            if ((decoding_op_src1 == ex_op_dest)  ||
                (decoding_op_src1 == mem_op_dest) ||
                (decoding_op_src1 == wb_op_dest)) begin
                pipeline_stall_n = 1'b0;
            end
        end
        
        // Check source register 2 (ignore register 0)
        if (decoding_op_src2 != 3'b000) begin
            if ((decoding_op_src2 == ex_op_dest)  ||
                (decoding_op_src2 == mem_op_dest) ||
                (decoding_op_src2 == wb_op_dest)) begin
                pipeline_stall_n = 1'b0;
            end
        end
    end

endmodule