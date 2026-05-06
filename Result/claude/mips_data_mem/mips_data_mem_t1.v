// =============================================================================
// Module:      data_mem
// Description: Data memory module for the MEM_stage of the MIPS-16 processor.
//              Implements a synchronous-write / asynchronous-read RAM.
//              RAM depth is 2**DATA_MEM_ADDR_WIDTH entries, each 16 bits wide.
//              Can be extended to a D-cache or external memory interface.
// =============================================================================

`include "mips_16_defs.v"

module data_mem
(
    input                       clk,

    // Address input, shared by read and write port
    input   [15:0]              mem_access_addr,

    // Write port
    input   [15:0]              mem_write_data,
    input                       mem_write_en,

    // Read port
    output  [15:0]              mem_read_data
);

    // -------------------------------------------------------------------------
    // Internal RAM array
    //   - Depth : 2 ** DATA_MEM_ADDR_WIDTH entries
    //   - Width : 16 bits per entry
    // -------------------------------------------------------------------------
    reg [15:0] ram [0 : (1 << `DATA_MEM_ADDR_WIDTH) - 1];

    // -------------------------------------------------------------------------
    // Address truncation
    //   Only the lower DATA_MEM_ADDR_WIDTH bits of the 16-bit external address
    //   are used as the physical RAM index, keeping the external interface
    //   width-agnostic while allowing flexible capacity via macro definition.
    // -------------------------------------------------------------------------
    wire [`DATA_MEM_ADDR_WIDTH-1 : 0] ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH-1 : 0];

    // -------------------------------------------------------------------------
    // Synchronous Write Port
    //   Data is written on the rising edge of clk when mem_write_en is high.
    //   RAM contents are unchanged when mem_write_en is low.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write_en) begin
            ram[ram_addr] <= mem_write_data;
        end
    end

    // -------------------------------------------------------------------------
    // Asynchronous Read Port
    //   mem_read_data reflects ram[ram_addr] combinationally.
    //   Any change in mem_access_addr propagates to the output after the
    //   combinational delay, without waiting for the next clock edge.
    //   This allows MEM_stage to forward the read result to WB_stage within
    //   the same pipeline cycle.
    // -------------------------------------------------------------------------
    assign mem_read_data = ram[ram_addr];

endmodule
