module alu
(
	input		[15:0]	a,		//src1
	input		[15:0]	b,		//src2
	input		[2:0]	cmd,	//function sel
	
	output	reg	[15:0]	r		//result	
);

	// ===== ALU Operation Definitions =====
	// These opcodes define which operation the ALU should perform
	localparam ALU_ADD = 3'b000;  // Addition
	localparam ALU_SUB = 3'b001;  // Subtraction
	localparam ALU_AND = 3'b010;  // Bitwise AND
	localparam ALU_OR  = 3'b011;  // Bitwise OR
	localparam ALU_XOR = 3'b100;  // Bitwise XOR
	localparam ALU_SL  = 3'b101;  // Logical left shift
	localparam ALU_SR  = 3'b110;  // Arithmetic right shift
	localparam ALU_SRU = 3'b111;  // Unsigned logical right shift
	localparam ALU_NC  = 3'bxxx;  // Don't care / invalid

	// ===== Combinational ALU Logic =====
	always @(*) begin
		case (cmd)
			ALU_ADD: begin
				// 16-bit addition
				// Used for ADD, ADDI, LD, ST address calculation
				r = a + b;
			end
			
			ALU_SUB: begin
				// 16-bit subtraction
				// Used for SUB and comparison operations
				r = a - b;
			end
			
			ALU_AND: begin
				// Bitwise AND operation
				// Each bit of a is ANDed with corresponding bit of b
				r = a & b;
			end
			
			ALU_OR: begin
				// Bitwise OR operation
				// Each bit of a is ORed with corresponding bit of b
				r = a | b;
			end
			
			ALU_XOR: begin
				// Bitwise XOR operation
				// Each bit of a is XORed with corresponding bit of b
				r = a ^ b;
			end
			
			ALU_SL: begin
				// Logical left shift
				// a is shifted left by the number of bits specified by b[3:0]
				// (b[3:0] allows shifts 0-15 bits for 16-bit operand)
				// Zeros are shifted in from the right
				r = a << b[3:0];
			end
			
			ALU_SR: begin
				// Arithmetic right shift (sign-extended)
				// Upper 16 bits filled with sign bit a[15], then shift right
				// This preserves the sign during right shift
				// Example: if a = 0x8000 (negative), shifting preserves sign bit
				r = {{16{a[15]}}, a} >> b[3:0];
			end
			
			ALU_SRU: begin
				// Unsigned logical right shift
				// Upper 16 bits filled with zeros, then shift right
				// This always shifts in zeros on the left
				// Example: if a = 0x8000, upper bits are zero-filled
				r = {16'b0, a} >> b[3:0];
			end
			
			ALU_NC: begin
				// Don't-care result: operation not needed
				// Used in control paths where ALU result is invalid/unused
				// Output is undefined (x)
				r = 16'bx;
			end
			
			default: begin
				// Unknown ALU command: set result to zero
				// Also print error message in simulation mode
				r = 16'h0000;
				`ifndef CODE_FOR_SYNTHESIS
					$display("ERROR: Unknown ALU command: %b at time %t", cmd, $time);
				`endif
			end
		endcase
	end

endmodule