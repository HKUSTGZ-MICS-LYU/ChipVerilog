`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_operandmuxes(
	// Clock and reset
	clk, rst,

	// Internal i/f
	id_freeze, ex_freeze, rf_dataa, rf_datab, ex_forw, wb_forw,
	simm, sel_a, sel_b, operand_a, operand_b, muxed_b
);

parameter width = `OR1200_OPERAND_WIDTH;

//
// I/O
//
input				clk;
input				rst;
input				id_freeze;
input				ex_freeze;
input	[width-1:0]		rf_dataa;
input	[width-1:0]		rf_datab;
input	[width-1:0]		ex_forw;
input	[width-1:0]		wb_forw;
input	[width-1:0]		simm;
input	[`OR1200_SEL_WIDTH-1:0]	sel_a;
input	[`OR1200_SEL_WIDTH-1:0]	sel_b;
output	[width-1:0]		operand_a;
output	[width-1:0]		operand_b;
output	[width-1:0]		muxed_b;

//
// Internal wires and regs
//
reg	[width-1:0]		operand_a;
reg	[width-1:0]		operand_b;
reg	[width-1:0]		muxed_a;
reg	[width-1:0]		muxed_b;
reg				saved_a;
reg				saved_b;

//
// Operand A register
//
always @(posedge clk or posedge rst) begin
	if (rst) begin
		operand_a <= #1 32'd0;
		saved_a <= #1 1'b0;
	end else if (!ex_freeze && id_freeze && !saved_a) begin
		operand_a <= #1 muxed_a;
		saved_a <= #1 1'b1;
	end else if (!ex_freeze && !saved_a) begin
		operand_a <= #1 muxed_a;
	end else if (!ex_freeze && !id_freeze)
		saved_a <= #1 1'b0;
end

//
// Operand B register
//
always @(posedge clk or posedge rst) begin
	if (rst) begin
		operand_b <= #1 32'd0;
		saved_b <= #1 1'b0;
	end else if (!ex_freeze && id_freeze && !saved_b) begin
		operand_b <= #1 muxed_b;
		saved_b <= #1 1'b1;
	end else if (!ex_freeze && !saved_b) begin
		operand_b <= #1 muxed_b;
	end else if (!ex_freeze && !id_freeze)
		saved_b <= #1 1'b0;
end

//
// Forwarding logic for operand A register
//
always @(ex_forw or wb_forw or rf_dataa or sel_a) begin
`ifdef OR1200_ADDITIONAL_SYNOPSYS_DIRECTIVES
	casex (sel_a)	// synopsys parallel_case infer_mux
`else
	casex (sel_a)	// synopsys parallel_case
`endif
		`OR1200_SEL_EX_FORW:
			muxed_a = ex_forw;
		`OR1200_SEL_WB_FORW:
			muxed_a = wb_forw;
		default:
			muxed_a = rf_dataa;
	endcase
end

//
// Forwarding logic for operand B register
//
always @(simm or ex_forw or wb_forw or rf_datab or sel_b) begin
`ifdef OR1200_ADDITIONAL_SYNOPSYS_DIRECTIVES
	casex (sel_b)	// synopsys parallel_case infer_mux
`else
	casex (sel_b)	// synopsys parallel_case
`endif
		`OR1200_SEL_IMM:
			muxed_b = simm;
		`OR1200_SEL_EX_FORW:
			muxed_b = ex_forw;
		`OR1200_SEL_WB_FORW:
			muxed_b = wb_forw;
		default:
			muxed_b = rf_datab;
	endcase
end

endmodule
