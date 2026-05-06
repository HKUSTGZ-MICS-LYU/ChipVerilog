module instruction_mem		// a rtl simulation rom, rom initial code can be found in the testbench
(
	input					clk,		// asynchronized!!
	input	[`PC_WIDTH-1:0]	pc,
	
	output	[15:0]			instruction
);

	wire [`INSTR_MEM_ADDR_WIDTH-1:0] rom_addr;
	assign rom_addr = pc[`INSTR_MEM_ADDR_WIDTH-1:0];

`ifdef USE_SIMULATION_CODE
	reg [15:0] rom [0:(2**`INSTR_MEM_ADDR_WIDTH)-1];
	assign instruction = rom[rom_addr];
`else
	reg [15:0] instruction;
	always @(*) begin
		case (rom_addr)
			// Sample program: ADDI, ADD, ST, LD, SUB, BZ
			// Address 0: ADDI R1, R0, 5  (opcode 01000, rd=1, rs=0, imm=5)
			0: instruction = 16'b01000_001_000_00101; // 0x2105
			// Address 1: ADDI R2, R0, 10
			1: instruction = 16'b01000_010_000_01010; // 0x220A
			// Address 2: ADD R3, R1, R2 (opcode 00000, rd=3, rs1=1, rs2=2) 
			2: instruction = 16'b00000_011_001_01000; // 0x0328 (assuming rs2 in [4:2], rs1[7:5])
			// Address 3: ST R3, 5(R0)  (store opcode 01100, base=R0, offset=5, src=R3)
			3: instruction = 16'b01100_011_000_00101; // 0x6305? adjust
			// Address 4: LD R4, 5(R0)  (load opcode 01101, base=R0, offset=5, dest=R4)
			4: instruction = 16'b01101_100_000_00101; // 0x6C05
			// Address 5: SUB R5, R4, R1 (sub opcode 00001, dest=R5, src1=R4, src2=R1)
			5: instruction = 16'b00001_101_100_00100; // 0x1B04? Let's use 0x1B04.
			// Address 6: BZ R5, 8 (branch if zero, opcode 10000, reg=R5, offset=8)
			6: instruction = 16'b10000_101_00001000; // 0x8508
			// Address 7: NOP (no operation, all zeros)
			7: instruction = 16'b0000000000000000;
			// Fill few more NOPs
			8: instruction = 16'b0000000000000000;
			9: instruction = 16'b0000000000000000;
			10: instruction = 16'b0000000000000000;
			11: instruction = 16'b0000000000000000;
			12: instruction = 16'b0000000000000000;
			13: instruction = 16'b0000000000000000;
			14: instruction = 16'b0000000000000000;
			15: instruction = 16'b0000000000000000;
			default: instruction = 16'b0000000000000000;
		endcase
	end
`endif

endmodule
