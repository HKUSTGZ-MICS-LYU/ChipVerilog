//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 MEM Stage — Memory Access Pipeline Stage            ////
////                                                              ////
////  Performs data memory read/write, forwards ALU result and    ////
////  write-back control to WB_stage, and exposes destination     ////
////  register for hazard detection.                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module MEM_stage (
    input             clk,
    input             rst,

    // From EX_stage
    // [37:22] ex_alu_result[15:0]
    // [21]    mem_write_en
    // [20:5]  mem_write_data[15:0]
    // [4:0]   write_back_en, write_back_dest[2:0], write_back_result_mux
    input  [37:0]     pipeline_reg_in,

    // To WB_stage
    // [36:21] ex_alu_result[15:0]
    // [20:5]  mem_read_data[15:0]
    // [4:0]   write_back_en, write_back_dest[2:0], write_back_result_mux
    output reg [36:0] pipeline_reg_out,

    // To hazard detection unit
    output     [2:0]  mem_op_dest
);

    // ----------------------------------------------------------------
    // Unpack pipeline_reg_in fields
    // ----------------------------------------------------------------
    wire [15:0] ex_alu_result   = pipeline_reg_in[37:22];
    wire        mem_write_en    = pipeline_reg_in[21];
    wire [15:0] mem_write_data  = pipeline_reg_in[20:5];
    wire  [4:0] wb_ctrl         = pipeline_reg_in[4:0];

    // ----------------------------------------------------------------
    // Data memory read result
    // ----------------------------------------------------------------
    wire [15:0] mem_read_data;

    // ----------------------------------------------------------------
    // Data memory instantiation
    // ----------------------------------------------------------------
    data_mem dmem (
        .clk             (clk),
        .mem_access_addr (ex_alu_result),
        .mem_write_en    (mem_write_en),
        .mem_write_data  (mem_write_data),
        .mem_read_data   (mem_read_data)
    );

    // ----------------------------------------------------------------
    // Output pipeline register — synchronous, sync reset
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pipeline_reg_out <= 37'b0;
        end else begin
            pipeline_reg_out[36:21] <= ex_alu_result;   // ALU result forwarded
            pipeline_reg_out[20:5]  <= mem_read_data;   // memory read result
            pipeline_reg_out[4:0]   <= wb_ctrl;         // write-back control
        end
    end

    // ----------------------------------------------------------------
    // Destination register for hazard detection (combinational)
    // ----------------------------------------------------------------
    assign mem_op_dest = pipeline_reg_in[3:1];  // write_back_dest[2:0]

endmodule
