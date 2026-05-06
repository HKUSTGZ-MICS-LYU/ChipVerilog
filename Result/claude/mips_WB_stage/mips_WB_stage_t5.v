module WB_stage
(
    //input               clk,

    // From MEM stage
    input       [36:0]  pipeline_reg_in,    // [36:21] 16b: ex_alu_result[15:0]
                                            // [20: 5] 16b: mem_read_data[15:0]
                                            // [ 4: 0]  5b: write_back_en,
                                            //              write_back_dest[2:0],
                                            //              write_back_result_mux

    // To register file
    output              reg_write_en,
    output      [2:0]   reg_write_dest,
    output      [15:0]  reg_write_data,

    // To hazard detection unit
    output      [2:0]   wb_op_dest
);

    //--------------------------------------------------------------------------
    // Unpack pipeline register bus
    //--------------------------------------------------------------------------
    wire [15:0] ex_alu_result;
    wire [15:0] mem_read_data;
    wire        write_back_en;
    wire [2:0]  write_back_dest;
    wire        write_back_result_mux;

    assign ex_alu_result        = pipeline_reg_in[36:21];
    assign mem_read_data        = pipeline_reg_in[20:5];
    assign write_back_en        = pipeline_reg_in[4];
    assign write_back_dest      = pipeline_reg_in[3:1];
    assign write_back_result_mux = pipeline_reg_in[0];

    //--------------------------------------------------------------------------
    // Register file write control
    //--------------------------------------------------------------------------

    // Pass write-back enable directly to register file
    assign reg_write_en   = write_back_en;

    // Pass destination register directly to register file
    assign reg_write_dest = write_back_dest;

    // Mux: 0 -> ALU result (arithmetic/logic/immediate)
    //      1 -> memory read data (load)
    assign reg_write_data = write_back_result_mux ? mem_read_data
                                                  : ex_alu_result;

    //--------------------------------------------------------------------------
    // Hazard detection: expose destination register of WB-stage instruction
    //--------------------------------------------------------------------------
    assign wb_op_dest = write_back_dest;

endmodule