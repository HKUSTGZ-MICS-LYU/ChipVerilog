`include "timescale.v"
`include "or1200_defines.v"

module or1200_operandmuxes(
	clk, rst,
	id_freeze, ex_freeze, rf_dataa, rf_datab, ex_forw, wb_forw,
	simm, sel_a, sel_b, operand_a, operand_b, muxed_b
);

input		clk;
input		rst;
input		id_freeze;
input		ex_freeze;
input	[31:0]	rf_dataa;
input	[31:0]	rf_datab;
input	[31:0]	ex_forw;
input	[31:0]	wb_forw;
input	[31:0]	simm;
input	[1:0]	sel_a;
input	[1:0]	sel_b;
output	[31:0]	operand_a;
output	[31:0]	operand_b;
output	[31:0]	muxed_b;

reg	[31:0]	operand_a;
reg	[31:0]	operand_b;
reg	[31:0]	muxed_a;
reg	[31:0]	muxed_b;
reg		saved_a;
reg		saved_b;

// Operand A register with freeze-aware save logic
always @(posedge clk or posedge rst) begin
	if (rst) begin
		operand_a <= #1 32'd0;
		saved_a   <= #1 1'b0;
	end
	// Capture once when EX can advance but ID is frozen and not yet saved
	else if (!ex_freeze && id_freeze && !saved_a) begin
		operand_a <= #1 muxed_a;
		saved_a   <= #1 1'b1;
	end
	// Normal update when EX can advance and operand not saved
	else if (!ex_freeze && !saved_a) begin
		operand_a <= #1 muxed_a;
	end
	// Clear save flag when both EX and ID can advance
	else if (!ex_freeze && !id_freeze)
		saved_a <= #1 1'b0;
end

// Operand B register with freeze-aware save logic
always @(posedge clk or posedge rst) begin
	if (rst) begin
		operand_b <= #1 32'd0;
		saved_b   <= #1 1'b0;
	end
	// Capture once when EX can advance but ID is frozen and not yet saved
	else if (!ex_freeze && id_freeze && !saved_b) begin
		operand_b <= #1 muxed_b;
		saved_b   <= #1 1'b1;
	end
	// Normal update when EX can advance and operand not saved
	else if (!ex_freeze && !saved_b) begin
		operand_b <= #1 muxed_b;
	end
	// Clear save flag when !ex_freeze && !id_freeze
	else if (!ex_freeze && !id_freeze)
		saved_b <= #1 1'b0;
end

// Combinational mux for operand A
// sel_a selects between RF, EX forwarding, and WB forwarding
always @(ex_forw or wb_forw or rf_dataa or sel_a) begin
	casex (sel_a)	// synopsys parallel_case
		`OR1200_SEL_EX_FORW:	muxed_a = ex_forw;
		`OR1200_SEL_WB_FORW:	muxed_a = wb_forw;
		default:		muxed_a = rf_dataa;
	endcase
end

// Combinational mux for operand B
// sel_b selects between RF, immediate, EX forwarding, and WB forwarding
always @(simm or ex_forw or wb_forw or rf_datab or sel_b) begin
	casex (sel_b)	// synopsys parallel_case
		`OR1200_SEL_IMM:	muxed_b = simm;
		`OR1200_SEL_EX_FORW:	muxed_b = ex_forw;
		`OR1200_SEL_WB_FORW:	muxed_b = wb_forw;
		default:		muxed_b = rf_datab;
	endcase
end

endmodule
