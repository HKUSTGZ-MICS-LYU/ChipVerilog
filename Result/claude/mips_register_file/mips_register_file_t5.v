module register_file
(
    input               clk,
    input               rst,

    // Write port
    input               reg_write_en,
    input       [2:0]   reg_write_dest,
    input       [15:0]  reg_write_data,

    // Read port 1
    input       [2:0]   reg_read_addr_1,
    output      [15:0]  reg_read_data_1,

    // Read port 2
    input       [2:0]   reg_read_addr_2,
    output      [15:0]  reg_read_data_2
);

    //--------------------------------------------------------------------------
    // Register Array: 8 x 16-bit general-purpose registers
    //--------------------------------------------------------------------------
    reg [15:0] reg_array [7:0];

    //--------------------------------------------------------------------------
    // Synchronous Write Port + Reset
    //--------------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            // Clear all registers on reset
            for (i = 0; i < 8; i = i + 1)
                reg_array[i] <= 16'h0000;
        end
        else if (reg_write_en) begin
            // Write to destination register (R0 writes are accepted here
            // but reads from R0 always return zero — see read logic below)
            reg_array[reg_write_dest] <= reg_write_data;
        end
    end

    //--------------------------------------------------------------------------
    // Asynchronous Read Port 1
    // Register 0 is hardwired to zero
    //--------------------------------------------------------------------------
    assign reg_read_data_1 = (reg_read_addr_1 == 3'b000) ? 16'h0000
                                                          : reg_array[reg_read_addr_1];

    //--------------------------------------------------------------------------
    // Asynchronous Read Port 2
    // Register 0 is hardwired to zero
    //--------------------------------------------------------------------------
    assign reg_read_data_2 = (reg_read_addr_2 == 3'b000) ? 16'h0000
                                                          : reg_array[reg_read_addr_2];

endmodule