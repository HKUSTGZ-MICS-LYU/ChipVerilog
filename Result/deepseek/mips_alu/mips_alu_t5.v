module alu
(
	input		[15:0]	a,
	input		[15:0]	b,
	input		[2:0]	cmd,
	output	reg	[15:0]	r
);

localparam	ALU_ADD	= 3'd0;
localparam	ALU_SUB	= 3'd1;
localparam	ALU_AND	= 3'd2;
localparam	ALU_OR	= 3'd3;
localparam	ALU_XOR	= 3'd4;
localparam	ALU_SL	= 3'd5;
localparam	ALU_SR	= 3'd6;
localparam	ALU_SRU	= 3'd7;

always @(*)
begin
	case (cmd)
		ALU_ADD:	r = a + b;
		ALU_SUB:	r = a - b;
		ALU_AND:	r = a & b;
		ALU_OR:		r = a | b;
		ALU_XOR:	r = a ^ b;
		ALU_SL:		r = a << b;
		ALU_SR:		r = ({{16{a[15]}}, a} >> b);
		ALU_SRU:	r = ({16'b0, a} >> b);
		default:	begin
						r = 16'd0;
`ifndef CODE_FOR_SYNTHESIS
						$display("ERROR: unknown ALU command %b", cmd);
`endif
					end
	endcase
end

endmodule
