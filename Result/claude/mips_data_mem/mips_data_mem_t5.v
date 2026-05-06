//=============================================================================
// Module Name  : data_mem
// Project      : MIPS_16 Processor
// Description  : Data Memory Module for MEM_stage in 5-stage pipeline
//                - 16-bit data width
//                - Synchronous write port (write on rising edge of clk)
//                - Asynchronous read port (combinational read)
//                - RAM depth controlled by `DATA_MEM_ADDR_WIDTH macro
//                - Supports LD/ST instructions in MIPS_16 ISA
//                - Can be extended to D-cache or external memory interface
//=============================================================================

// `include "mips_16_defines.v"   // Project-wide defines (uncomment if used)

// Provide a default value if the macro is not defined elsewhere in the project
`ifndef DATA_MEM_ADDR_WIDTH
    `define DATA_MEM_ADDR_WIDTH 8   // Default: 256 entries x 16-bit
`endif

module data_mem (
    input                       clk,

    // address input, shared by read and write port
    input       [15:0]          mem_access_addr,

    // write port
    input       [15:0]          mem_write_data,
    input                       mem_write_en,

    // read port
    output      [15:0]          mem_read_data
);

    //-------------------------------------------------------------------------
    // Internal Signal Declarations
    //-------------------------------------------------------------------------

    // RAM array: depth = 2^DATA_MEM_ADDR_WIDTH, width = 16 bits
    reg     [15:0]  ram [0:(2**`DATA_MEM_ADDR_WIDTH)-1];

    // Internal RAM address: only the lower DATA_MEM_ADDR_WIDTH bits of
    // mem_access_addr are used to index the RAM. This keeps the external
    // interface at 16-bit while allowing flexible RAM depth configuration.
    wire    [`DATA_MEM_ADDR_WIDTH-1:0]  ram_addr;

    assign  ram_addr = mem_access_addr[`DATA_MEM_ADDR_WIDTH-1:0];

    //-------------------------------------------------------------------------
    // Synchronous Write Logic
    //-------------------------------------------------------------------------
    // On the rising edge of clk, if mem_write_en is asserted, write
    // mem_write_data into ram[ram_addr]. Otherwise, RAM contents are
    // preserved. This synchronous write port matches the pipeline timing
    // of the MEM_stage in the MIPS_16 processor.
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write_en) begin
            ram[ram_addr] <= mem_write_data;
        end
    end

    //-------------------------------------------------------------------------
    // Asynchronous Read Logic
    //-------------------------------------------------------------------------
    // mem_read_data is continuously assigned from ram[ram_addr]. When
    // mem_access_addr changes, mem_read_data reflects the new data after
    // combinational propagation delay, without waiting for the next clock
    // edge. This allows the MEM_stage to forward the read data to the
    // WB_stage within the same cycle.
    //-------------------------------------------------------------------------
    assign  mem_read_data = ram[ram_addr];

    //-------------------------------------------------------------------------
    // Optional: Memory Initialization (for simulation)
    //-------------------------------------------------------------------------
    // Uncomment the block below to initialize the RAM contents at simulation
    // start-up. In synthesis, this initial block may be ignored depending on
    // the target FPGA/ASIC tool flow.
    //-------------------------------------------------------------------------
    // integer i;
    // initial begin
    //     for (i = 0; i < (2**`DATA_MEM_ADDR_WIDTH); i = i + 1) begin
    //         ram[i] = 16'h0000;
    //     end
    //     // Optionally load from a hex file:
    //     // $readmemh("data_mem_init.hex", ram);
    // end

endmodule