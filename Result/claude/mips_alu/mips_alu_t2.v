module alu
(
	input		[15:0]	a,		//src1
	input		[15:0]	b,		//src2
	input		[2:0]	cmd,	//function sel
	
	output	reg	[15:0]	r		//result	
);

	// ALU operation definitions (typically from mips_16_defs.v)
	localparam ALU_ADD = 3'b000;
	localparam ALU_SUB = 3'b001;
	localparam ALU_AND = 3'b010;
	localparam ALU_OR  = 3'b011;
	localparam ALU_XOR = 3'b100;
	localparam ALU_SL  = 3'b101;
	localparam ALU_SR  = 3'b110;
	localparam ALU_SRU = 3'b111;
	localparam ALU_NC  = 3'bxxx;

	// Combinational ALU logic
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
				r = a & b;
			end
			
			ALU_OR: begin
				// Bitwise OR operation
				r = a | b;
			end
			
			ALU_XOR: begin
				// Bitwise XOR operation
				r = a ^ b;
			end
			
			ALU_SL: begin
				// Logical left shift
				// a is shifted left by the number of bits specified by b[3:0]
				// (b[3:0] allows shifts 0-15 bits for 16-bit operand)
				r = a << b[3:0];
			end
			
			ALU_SR: begin
				// Arithmetic right shift (sign-extended)
				// Upper 16 bits filled with sign bit a[15], then shift right
				// This preserves the sign during right shift
				r = {{16{a[15]}}, a} >> b[3:0];
			end
			
			ALU_SRU: begin
				// Unsigned logical right shift
				// Upper 16 bits filled with zeros, then shift right
				// This always shifts in zeros on the left
				r = {16'b0, a} >> b[3:0];
			end
			
			ALU_NC: begin
				// Don't-care result: operation not needed
				// Used in control paths where ALU result is invalid/unused
				r = 16'bx;
			end
			
			default: begin
				// Unknown ALU command
				r = 16'h0000;
				`ifndef CODE_FOR_SYNTHESIS
					$display("ERROR: Unknown ALU command: %b", cmd);
				`endif
			end
		endcase
	end

endmodule