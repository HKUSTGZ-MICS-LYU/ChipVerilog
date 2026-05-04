//=============================================================================
// Module Name : register_file
// Description : MIPS_16 General-Purpose Register File
//               - 8 entries x 16-bit
//               - 1 synchronous write port
//               - 2 asynchronous read ports
//               - Register 0 is hard-wired to zero on read
//               - Synchronous reset clears all registers
//=============================================================================
module register_file
(
    input               clk,
    input               rst,

    // write port
    input               reg_write_en,
    input       [2:0]   reg_write_dest,
    input       [15:0]  reg_write_data,

    // read port 1
    input       [2:0]   reg_read_addr_1,
    output      [15:0]  reg_read_data_1,

    // read port 2
    input       [2:0]   reg_read_addr_2,
    output      [15:0]  reg_read_data_2
);

    //-------------------------------------------------------------------------
    // Internal storage : 8 x 16-bit register array
    //-------------------------------------------------------------------------
    reg [15:0] reg_array [0:7];

    integer i;

    //-------------------------------------------------------------------------
    // Synchronous write port
    //   - On rising edge of clk:
    //       * If rst asserted -> clear all 8 registers to zero
    //       * Else if reg_write_en high -> write reg_write_data into the
    //         register selected by reg_write_dest
    //   - Note: writes to address 0 are not explicitly blocked here, because
    //     the read logic forces register 0 to read as zero, so software
    //     observability of register 0 is preserved as constant zero.
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                reg_array[i] <= 16'b0;
            end
        end
        else if (reg_write_en) begin
            reg_array[reg_write_dest] <= reg_write_data;
        end
    end

    //-------------------------------------------------------------------------
    // Asynchronous read port 1
    //   - If reg_read_addr_1 == 0 -> output zero (register 0 is constant-zero)
    //   - Otherwise -> output reg_array[reg_read_addr_1]
    //-------------------------------------------------------------------------
    assign reg_read_data_1 = (reg_read_addr_1 == 3'b000) ?
                              16'b0 : reg_array[reg_read_addr_1];

    //-------------------------------------------------------------------------
    // Asynchronous read port 2
    //   - If reg_read_addr_2 == 0 -> output zero (register 0 is constant-zero)
    //   - Otherwise -> output reg_array[reg_read_addr_2]
    //-------------------------------------------------------------------------
    assign reg_read_data_2 = (reg_read_addr_2 == 3'b000) ?
                              16'b0 : reg_array[reg_read_addr_2];

endmodule