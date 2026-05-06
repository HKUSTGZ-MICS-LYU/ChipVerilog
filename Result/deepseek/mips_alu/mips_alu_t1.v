module alu
(
	input		[15:0]	a,		//src1
	input		[15:0]	b,		//src2
	input		[2:0]	cmd,	//function sel
	
	output	reg	[15:0]	r		//result	
);

// ALU control macros
`define ALU_ADD  3'b000
`define ALU_SUB  3'b001
`define ALU_AND  3'b010
`define ALU_OR   3'b011
`define ALU_XOR  3'b100
`define ALU_SL   3'b101
`define ALU_SR   3'b110
`define ALU_SRU  3'b111

always @(*) begin
	case(cmd)
		`ALU_ADD: r = a + b;
		`ALU_SUB: r = a - b;
		`ALU_AND: r = a & b;
		`ALU_OR:  r = a | b;
		`ALU_XOR: r = a ^ b;
		`ALU_SL:  r = a << b;
		`ALU_SR:  r = {{16{a[15]}}, a} >> b;
		`ALU_SRU: r = {16'b0, a} >> b;
		default: begin
			r = 16'b0;
			`ifndef CODE_FOR_SYNTHESIS
				$display("Error: Unknown ALU command %b", cmd);
			`endif
		end
	endcase
end

endmodule
