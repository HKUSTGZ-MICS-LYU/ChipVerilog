//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 WB Stage — Write-Back Pipeline Stage                ////
////                                                              ////
////  Selects final register-file write-back data from ALU        ////
////  result or memory read data, drives register file write      ////
////  port, and exposes destination register for hazard detection. ////
////  Purely combinational — no pipeline register.                ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module WB_stage (
    // From MEM_stage
    // [36:21] ex_alu_result[15:0]
    // [20:5]  mem_read_data[15:0]
    // [4]     write_back_en
    // [3:1]   write_back_dest[2:0]
    // [0]     write_back_result_mux
    input  [36:0] pipeline_reg_in,

    // To register file
    output        reg_write_en,
    output  [2:0] reg_write_dest,
    output [15:0] reg_write_data,

    // To hazard detection unit
    output  [2:0] wb_op_dest
);

    // ----------------------------------------------------------------
    // Unpack pipeline_reg_in fields
    // ----------------------------------------------------------------
    wire [15:0] ex_alu_result         = pipeline_reg_in[36:21];
    wire [15:0] mem_read_data         = pipeline_reg_in[20:5];
    wire        write_back_en         = pipeline_reg_in[4];
    wire  [2:0] write_back_dest       = pipeline_reg_in[3:1];
    wire        write_back_result_mux = pipeline_reg_in[0];

    // ----------------------------------------------------------------
    // Register file write control — purely combinational
    // ----------------------------------------------------------------
    assign reg_write_en   = write_back_en;
    assign reg_write_dest = write_back_dest;

    // write_back_result_mux: 0 → ALU result, 1 → memory read data
    assign reg_write_data = write_back_result_mux ? mem_read_data : ex_alu_result;

    // ----------------------------------------------------------------
    // Destination register for hazard detection
    // ----------------------------------------------------------------
    assign wb_op_dest = write_back_dest;

endmodule
