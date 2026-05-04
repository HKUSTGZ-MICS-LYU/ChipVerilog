//=============================================================================
// Module Name : WB_stage
// Description : Write-Back stage of the MIPS_16 5-stage pipeline processor.
//               This is the final pipeline stage. It selects the final 
//               write-back data (either ALU result or memory read data) and 
//               drives the register file write port. It also forwards the
//               destination register number to the hazard detection unit
//               for RAW hazard checking.
//
// Pipeline Register Format (37 bits, from MEM_stage):
//   pipeline_reg_in[36:21] : ex_alu_result[15:0]   - ALU computation result
//   pipeline_reg_in[20:5]  : mem_read_data[15:0]   - Data memory read data
//   pipeline_reg_in[4]     : write_back_en         - WB enable
//   pipeline_reg_in[3:1]   : write_back_dest[2:0]  - Destination register
//   pipeline_reg_in[0]     : write_back_result_mux - 0:ALU, 1:MEM
//
// Note : This stage is purely combinational. The register file performs the
//        actual sequential write on the rising edge of clk.
//=============================================================================
module WB_stage
(
    //input                   clk,

    // from MEM stage (pipeline register)
    input       [36:0]      pipeline_reg_in,    //  [36:21],16bits: ex_alu_result[15:0]
                                                //  [20:5], 16bits: mem_read_data[15:0]
                                                //  [4:0],   5bits: write_back_en, write_back_dest[2:0], write_back_result_mux

    // to register file
    output                  reg_write_en,
    output      [2:0]       reg_write_dest,
    output      [15:0]      reg_write_data,

    // to hazard detection unit
    output      [2:0]       wb_op_dest
);

    //-------------------------------------------------------------------------
    // 1. Unpack the pipeline register from MEM_stage
    //-------------------------------------------------------------------------
    wire    [15:0]  ex_alu_result;
    wire    [15:0]  mem_read_data;
    wire            write_back_en;
    wire    [2:0]   write_back_dest;
    wire            write_back_result_mux;

    assign  ex_alu_result         = pipeline_reg_in[36:21];
    assign  mem_read_data         = pipeline_reg_in[20:5];
    assign  write_back_en         = pipeline_reg_in[4];
    assign  write_back_dest       = pipeline_reg_in[3:1];
    assign  write_back_result_mux = pipeline_reg_in[0];

    //-------------------------------------------------------------------------
    // 2. Drive register file write enable and destination
    //    - Store / branch instructions clear write_back_en, so the register
    //      file is not updated for those instructions.
    //-------------------------------------------------------------------------
    assign  reg_write_en   = write_back_en;
    assign  reg_write_dest = write_back_dest;

    //-------------------------------------------------------------------------
    // 3. Final write-back data MUX
    //    write_back_result_mux == 1'b0 : ALU result   (arith / logic / shift / imm)
    //    write_back_result_mux == 1'b1 : Memory data  (load instructions)
    //-------------------------------------------------------------------------
    assign  reg_write_data = (write_back_result_mux == 1'b0) ? ex_alu_result
                                                             : mem_read_data;

    //-------------------------------------------------------------------------
    // 4. Forward destination register to the hazard detection unit
    //    Used by the ID_stage to detect RAW hazards against the instruction
    //    currently in the WB_stage.
    //-------------------------------------------------------------------------
    assign  wb_op_dest = pipeline_reg_in[3:1];

endmodule