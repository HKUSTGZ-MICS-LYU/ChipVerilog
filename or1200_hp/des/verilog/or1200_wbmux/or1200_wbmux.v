`include "timescale.v"
`include "or1200_defines.v"

module or1200_wbmux(
	// Clock and reset
	clk, rst,

	// Internal i/f
	wb_freeze, rfwb_op,
	muxin_a, muxin_b, muxin_c, muxin_d,
	muxout, muxreg, muxreg_valid
);

//
// I/O
//

//
// Clock and reset
//
input				clk;
input				rst;

//
// Internal i/f
//
input				wb_freeze;
input	[2:0]	rfwb_op;
input	[31:0]		muxin_a;
input	[31:0]		muxin_b;
input	[31:0]		muxin_c;
input	[31:0]		muxin_d;
output	[31:0]		muxout;
output	[31:0]		muxreg;
output				muxreg_valid;

//
// Internal wires and regs
//
reg	[31:0]		muxout;
reg	[31:0]		muxreg;
reg				muxreg_valid;

//
// Registered output from the write-back multiplexer
//
always @(posedge clk or posedge rst) begin
	if (rst) begin
		muxreg <= #1 32'd0;
		muxreg_valid <= #1 1'b0;
	end
	else if (!wb_freeze) begin
		muxreg <= #1 muxout;
		muxreg_valid <= #1 rfwb_op[0];
	end
end

//
// Write-back multiplexer
//
always @(muxin_a or muxin_b or muxin_c or muxin_d or rfwb_op) begin
`ifdef OR1200_ADDITIONAL_SYNOPSYS_DIRECTIVES
	case(rfwb_op[2:1]) // synopsys parallel_case infer_mux
`else
	case(rfwb_op[2:1]) // synopsys parallel_case
`endif
		2'b00: muxout = muxin_a;
		2'b01: begin
			muxout = muxin_b;
`ifdef OR1200_VERBOSE
// synopsys translate_off
			$display("  WBMUX: muxin_b %h", muxin_b);
// synopsys translate_on
`endif
		end
		2'b10: begin
			muxout = muxin_c;
`ifdef OR1200_VERBOSE
// synopsys translate_off
			$display("  WBMUX: muxin_c %h", muxin_c);
// synopsys translate_on
`endif
		end
		2'b11: begin
			muxout = muxin_d + 32'h8;
`ifdef OR1200_VERBOSE
// synopsys translate_off
			$display("  WBMUX: muxin_d %h", muxin_d + 4'h8);
// synopsys translate_on
`endif
		end
	endcase
end

endmodule
