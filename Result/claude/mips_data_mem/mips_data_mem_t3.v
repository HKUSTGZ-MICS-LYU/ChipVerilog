// ============================================================
// data_mem.v  –  Data Memory for the MIPS-16 MEM stage
//
// Synchronous write  : on rising edge of clk when mem_write_en == 1
// Asynchronous read  : combinational, reflects ram[ram_addr] immediately
//
// RAM depth          : 2 ** `DATA_MEM_ADDR_WIDTH entries, each 16 bits wide
// Address mapping    : only the lower `DATA_MEM_ADDR_WIDTH bits of the
//                      16-bit mem_access_addr are used as ram_addr
// ============================================================

`include "mips_16_defs.v"

module data_mem
(
    input                   clk,

    // address input, shared by read and write port
    input        [15:0]     mem_access_addr,

    // write port
    input        [15:0]     mem_write_data,
    input                   mem_write_en,

    // read port
    output       [15:0]     mem_read_data
);

    // ----------------------------------------------------------
    // Internal RAM array
    //   depth : 2 ** DATA_MEM_ADDR_WIDTH words
    //   width : 16 bits
    // ----------------------------------------------------------
    reg [15:0] ram [0 : (1 << `DATA_MEM_ADDR_WIDTH) - 1];

    // ----------------------------------------------------------
    // Address truncation
    // Only the lower DATA_MEM_ADDR_WIDTH bits are used so that
    // the external 16-bit address interface is preserved while
    // the actual RAM capacity remains parameterisable.
    // ----------------------------------------------------------
    wire [`DATA_MEM_ADDR_WIDTH-1 : 0] ram_addr;
    assign ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH-1 : 0];

    // ----------------------------------------------------------
    // Synchronous write port
    // Data is written on the rising edge of clk only when
    // mem_write_en is asserted (ST instruction).
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write_en)
            ram[ram_addr] <= mem_write_data;
    end

    // ----------------------------------------------------------
    // Asynchronous (combinational) read port
    // mem_read_data reflects ram[ram_addr] immediately after the
    // address settles, with no clock edge required (LD instruction).
    // ----------------------------------------------------------
    assign mem_read_data = ram[ram_addr];

endmodule
