module instruction_mem
(
	input					clk,		// asynchronized!!
	input	[`PC_WIDTH-1:0]	pc,
	
	output	[15:0]			instruction
);

	// ===== Memory Configuration Macros =====
	`ifndef PC_WIDTH
		`define PC_WIDTH 16
	`endif

	`ifndef INSTR_MEM_ADDR_WIDTH
		`define INSTR_MEM_ADDR_WIDTH 10  // Default: 1024 instructions (1K x 16-bit)
	`endif

	// ===== ROM Address Extraction =====
	// Use only the lower INSTR_MEM_ADDR_WIDTH bits of the PC
	wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
	assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

	// ===== Simulation ROM Implementation =====
	`ifdef USE_SIMULATION_CODE

		// Declare ROM as a register array for simulation
		reg [15:0] rom [2**`INSTR_MEM_ADDR_WIDTH-1 : 0];

		// Asynchronous read: instruction directly from ROM
		assign instruction = rom[rom_addr];

		// Optional: Initialize ROM from file during simulation
		initial begin
			// Uncomment one of the following to load a program:
			// $readmemh("program.hex", rom);  // Load hex format
			// $readmemb("program.bin", rom);  // Load binary format
		end

	// ===== Synthesizable ROM Implementation =====
	`else

		// Declare instruction as a register (output of combinational logic)
		reg [15:0] instruction;

		// Combinational ROM using case statement
		// This implements a sample program for testing
		always @(*) begin
			case (rom_addr)
				// Sample Program: Basic arithmetic, memory access, and branch test
				// This corresponds to the test program described in the specification

				10'h000: instruction = 16'b0110_011_001_010_000;  // ADDI r3, r1, 0x10
				10'h001: instruction = 16'b0001_010_011_001_000;  // ADD r2, r3, r1
				10'h002: instruction = 16'b1000_001_010_000_000;  // ST r2, r1, 0x00
				10'h003: instruction = 16'b0111_011_001_010_000;  // LD r3, r1, 0x10
				10'h004: instruction = 16'b0010_100_011_010_000;  // SUB r4, r3, r2
				10'h005: instruction = 16'b1001_100_000_000_000;  // BZ r4, offset

				// Fill remaining ROM locations with NOP (all zeros)
				default: instruction = 16'h0000;
			endcase
		end

	`endif

endmodule