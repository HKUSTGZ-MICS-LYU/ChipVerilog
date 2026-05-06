module or1200_ic_ram(
    // Clock and reset
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);

	// ===== Instruction Cache RAM Implementation Selection =====
	
	`ifdef OR1200_NO_IC
		// ===== NO INSTRUCTION CACHE MODE =====
		// When instruction cache is not implemented, all reads return zero
		
		assign dataout = 32'h00000000;
		
		`ifdef OR1200_BIST
			// BIST chain bypass: pass-through input to output
			assign mbist_so_o = mbist_si_i;
		`endif
	
	`elsif defined(OR1200_RAM_MODELS_VIRTEX)
		// ===== VIRTEX FPGA RAM IMPLEMENTATION =====
		// Uses FPGA-specific dual-port RAM with separate read/write ports
		
		// Instantiate FPGA RAM module (vendor-specific)
		ic_ram_sub #(
			.depth(2048),        // Default: 2048 x 32 bits (8KB)
			.width(32),
			.addr_width(11)
		) ic_ram_virtex (
			.clk    (clk),
			.ena    (en),           // Write-port enable
			.wea    (we[0]),        // Write-port write-enable (only we[0] used)
			.addra  (addr),         // Write-port address
			.dina   (datain),       // Write-port data input
			.addrb  (addr),         // Read-port address
			.doutb  (dataout)       // Read-port data output
		);
		
		`ifdef OR1200_BIST
			// BIST signals connected to underlying RAM
			// Note: BIST connection depends on ic_ram_sub implementation
			// This is a placeholder for vendor-specific BIST connection
		`endif
	
	`else
		// ===== GENERIC SINGLE-PORT RAM IMPLEMENTATION =====
		// Selects RAM depth based on instruction cache configuration
		
		`ifdef OR1200_IC_1W_512B
			// ===== 512-Byte Instruction Cache (128 x 32-bit words) =====
			or1200_spram_128x32 ic_ram_generic (
				.clk   (clk),
				.rst   (rst),
				.ce    (en),          // Chip-enable (access-enable)
				.we    (we[0]),       // Write-enable (only we[0] used)
				.oe    (1'b1),        // Output-enable always active
				.addr  (addr[6:0]),   // 7-bit address (128 words)
				.di    (datain),      // Data input
				.doq   (dataout)      // Data output
			);
		
		`elsif defined(OR1200_IC_1W_4KB)
			// ===== 4 KB Instruction Cache (1024 x 32-bit words) =====
			or1200_spram_1024x32 ic_ram_generic (
				.clk   (clk),
				.rst   (rst),
				.ce    (en),          // Chip-enable (access-enable)
				.we    (we[0]),       // Write-enable (only we[0] used)
				.oe    (1'b1),        // Output-enable always active
				.addr  (addr[9:0]),   // 10-bit address (1024 words)
				.di    (datain),      // Data input
				.doq   (dataout)      // Data output
			);
		
		`elsif defined(OR1200_IC_1W_8KB)
			// ===== 8 KB Instruction Cache (2048 x 32-bit words) =====
			// Default configuration
			or1200_spram_2048x32 ic_ram_generic (
				.clk   (clk),
				.rst   (rst),
				.ce    (en),          // Chip-enable (access-enable)
				.we    (we[0]),       // Write-enable (only we[0] used)
				.oe    (1'b1),        // Output-enable always active
				.addr  (addr[10:0]),  // 11-bit address (2048 words)
				.di    (datain),      // Data input
				.doq   (dataout)      // Data output
			);
		
		`else
			// ===== DEFAULT: 8 KB Instruction Cache =====
			// Fallback when no specific size is configured
			or1200_spram_2048x32 ic_ram_generic (
				.clk   (clk),
				.rst   (rst),
				.ce    (en),
				.we    (we[0]),
				.oe    (1'b1),
				.addr  (addr[10:0]),
				.di    (datain),
				.doq   (dataout)
			);
		`endif
		
		`ifdef OR1200_BIST
			// BIST signals connected to underlying RAM macro
			// Note: BIST connection to or1200_spram_* macros
			// The actual BIST behavior depends on the macro implementation
		`endif
	
	`endif

endmodule