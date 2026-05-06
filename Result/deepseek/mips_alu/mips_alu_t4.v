`define ALU_ADD 3'd0
`define ALU_SUB 3'd1
`define ALU_AND 3'd2
`define ALU_OR  3'd3
`define ALU_XOR 3'd4
`define ALU_SL  3'd5
`define ALU_SR  3'd6
`define ALU_SRU 3'd7
`define ALU_NC  3'd0
`endif

module alu
(
	input		[15:0]	a,		//src1
	input		[15:0]	b,		//src2
	input		[2:0]	cmd,	//function sel
	
	output	reg	[15:0]	r		//result	
);

always @(*) begin
	case(cmd)
		`ALU_ADD:	r = a + b;
		`ALU_SUB:	r = a - b;
		`ALU_AND:	r = a & b;
		`ALU_OR:	r = a | b;
		`ALU_XOR:	r = a ^ b;
		`ALU_SL:	r = a << b;
		`ALU_SR:	r = ({{16{a[15]}}, a} >> b);
		`ALU_SRU:	r = ({16'b0, a} >> b);
		`ALU_NC:	r = 16'bx;
		default: begin
			r = 16'd0;
			`ifndef CODE_FOR_SYNTHESIS
			$display("ERROR: unknown ALU command %d", cmd);
			`endif
		end
	endcase
end

endmodule
