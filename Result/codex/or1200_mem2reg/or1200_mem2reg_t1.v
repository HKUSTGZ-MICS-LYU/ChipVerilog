module or1200_mem2reg(addr, lsu_op, memdata, regdata);

input [1:0] addr;
input [3:0] lsu_op;
input [31:0] memdata;
output [31:0] regdata;

reg [7:0] regdata_hh;
reg [7:0] regdata_hl;
reg [7:0] regdata_lh;
reg [7:0] regdata_ll;
reg [31:0] aligned;
reg [3:0] sel_byte0;
reg [3:0] sel_byte1;
reg [3:0] sel_byte2;
reg [3:0] sel_byte3;
reg [31:0] regdata;

localparam [3:0] LSUOP_LBZ = 4'b0000;
localparam [3:0] LSUOP_LBS = 4'b0001;
localparam [3:0] LSUOP_LHZ = 4'b0010;
localparam [3:0] LSUOP_LHS = 4'b0011;
localparam [3:0] LSUOP_LWZ = 4'b0100;
localparam [3:0] LSUOP_LWS = 4'b0101;

localparam [3:0] SEL_ZERO  = 4'd0;
localparam [3:0] SEL_BYTE0 = 4'd1;
localparam [3:0] SEL_BYTE1 = 4'd2;
localparam [3:0] SEL_BYTE2 = 4'd3;
localparam [3:0] SEL_BYTE3 = 4'd4;
localparam [3:0] SEL_SIGN  = 4'd5;

function [7:0] select_byte;
	input [3:0] sel;
	input [31:0] data;
	begin
		case (sel)
			SEL_ZERO:  select_byte = 8'h00;
			SEL_BYTE0: select_byte = data[7:0];
			SEL_BYTE1: select_byte = data[15:8];
			SEL_BYTE2: select_byte = data[23:16];
			SEL_BYTE3: select_byte = data[31:24];
			SEL_SIGN:  select_byte = {8{data[31]}};
			default:   select_byte = 8'h00;
		endcase
	end
endfunction

always @* begin
	case (addr)
		2'b00: aligned = memdata;
		2'b01: aligned = {memdata[23:0], 8'h00};
		2'b10: aligned = {memdata[15:0], 16'h0000};
		default: aligned = {memdata[7:0], 24'h000000};
	endcase
end

always @* begin
	sel_byte0 = SEL_ZERO;
	sel_byte1 = SEL_ZERO;
	sel_byte2 = SEL_ZERO;
	sel_byte3 = SEL_ZERO;

	case (lsu_op)
		LSUOP_LBZ: begin
			sel_byte0 = SEL_BYTE3;
		end
		LSUOP_LBS: begin
			sel_byte0 = SEL_BYTE3;
			sel_byte1 = SEL_SIGN;
			sel_byte2 = SEL_SIGN;
			sel_byte3 = SEL_SIGN;
		end
		LSUOP_LHZ: begin
			sel_byte0 = SEL_BYTE2;
			sel_byte1 = SEL_BYTE3;
		end
		LSUOP_LHS: begin
			sel_byte0 = SEL_BYTE2;
			sel_byte1 = SEL_BYTE3;
			sel_byte2 = SEL_SIGN;
			sel_byte3 = SEL_SIGN;
		end
		LSUOP_LWZ,
		LSUOP_LWS: begin
			sel_byte0 = SEL_BYTE0;
			sel_byte1 = SEL_BYTE1;
			sel_byte2 = SEL_BYTE2;
			sel_byte3 = SEL_BYTE3;
		end
		default: begin
			sel_byte0 = SEL_ZERO;
			sel_byte1 = SEL_ZERO;
			sel_byte2 = SEL_ZERO;
			sel_byte3 = SEL_ZERO;
		end
	endcase
end

always @* begin
	regdata_ll = select_byte(sel_byte0, aligned);
	regdata_lh = select_byte(sel_byte1, aligned);
	regdata_hl = select_byte(sel_byte2, aligned);
	regdata_hh = select_byte(sel_byte3, aligned);
	regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
end

endmodule
