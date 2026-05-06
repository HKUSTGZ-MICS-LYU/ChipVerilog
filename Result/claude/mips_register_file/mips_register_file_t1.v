//////////////////////////////////////////////////////////////////////
////                                                              ////
////  MIPS_16 Register File                                       ////
////                                                              ////
////  8 x 16-bit GPRs, one synchronous write port,               ////
////  two asynchronous read ports. Register 0 always reads zero.  ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "defines.v"

module register_file (
    input         clk,
    input         rst,

    // Write port (from WB_stage)
    input         reg_write_en,
    input   [2:0] reg_write_dest,
    input  [15:0] reg_write_data,

    // Read port 1 (to ID_stage)
    input   [2:0] reg_read_addr_1,
    output [15:0] reg_read_data_1,

    // Read port 2 (to ID_stage)
    input   [2:0] reg_read_addr_2,
    output [15:0] reg_read_data_2
);

    // ----------------------------------------------------------------
    // Register storage — 8 x 16-bit
    // ----------------------------------------------------------------
    reg [15:0] reg_array [7:0];

    // ----------------------------------------------------------------
    // Synchronous write port with asynchronous active-high reset
    // ----------------------------------------------------------------
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                reg_array[i] <= 16'h0000;
        end else if (reg_write_en) begin
            reg_array[reg_write_dest] <= reg_write_data;
        end
    end

    // ----------------------------------------------------------------
    // Asynchronous read ports — register 0 always returns zero
    // ----------------------------------------------------------------
    assign reg_read_data_1 = (reg_read_addr_1 == 3'b000) ? 16'h0000
                                                          : reg_array[reg_read_addr_1];

    assign reg_read_data_2 = (reg_read_addr_2 == 3'b000) ? 16'h0000
                                                          : reg_array[reg_read_addr_2];

endmodule
