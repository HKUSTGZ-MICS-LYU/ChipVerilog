`include "timescale.v"
`include "or1200_defines.v"

module or1200_pic(
	clk, rst, spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
	pic_wakeup, intr,
	pic_int
);

input		clk;
input		rst;
input		spr_cs;
input		spr_write;
input	[31:0]	spr_addr;
input	[31:0]	spr_dat_i;
output	[31:0]	spr_dat_o;
output		pic_wakeup;
output		intr;
input	[19:0]	pic_int;

`ifdef OR1200_PIC_IMPLEMENTED

`ifdef OR1200_PIC_PICMR
reg	[19:2]	picmr;
`else
wire	[19:2]	picmr;
`endif

`ifdef OR1200_PIC_PICSR
reg	[19:0]	picsr;
`else
wire	[19:0]	picsr;
`endif

wire		picmr_sel;
wire		picsr_sel;
// um_ints: unmasked interrupt vector; computed as pic_int & {picmr, 2'b11}
wire	[19:0]	um_ints;
reg	[31:0]	spr_dat_o;

assign picmr_sel = (spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR)) ? 1'b1 : 1'b0;
assign picsr_sel = (spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR)) ? 1'b1 : 1'b0;

// REVISED: picmr reset to {1'b1, {OR1200_PIC_INTS-3{1'b0}}}
`ifdef OR1200_PIC_PICMR
always @(posedge clk or posedge rst)
	if (rst)
		picmr <= {1'b1, {`OR1200_PIC_INTS-3{1'b0}}};
	else if (picmr_sel && spr_write)
		picmr <= #1 spr_dat_i[19:2];
`else
assign picmr = (`OR1200_PIC_INTS)'b1;
`endif

// REVISED: PICSR write path includes | um_ints
`ifdef OR1200_PIC_PICSR
always @(posedge clk or posedge rst)
	if (rst)
		picsr <= {`OR1200_PIC_INTS{1'b0}};
	else if (picsr_sel && spr_write)
		picsr <= #1 spr_dat_i[19:0] | um_ints;
	else
		picsr <= #1 picsr | um_ints;
`else
assign picsr = pic_int;
`endif

always @(spr_addr or picmr or picsr)
	case (spr_addr[1:0])
`ifdef OR1200_PIC_READREGS
		`OR1200_PIC_OFS_PICMR: begin
			spr_dat_o[19:0] = {picmr, 2'b0};
`ifdef OR1200_PIC_UNUSED_ZERO
			spr_dat_o[31:20] = {32-`OR1200_PIC_INTS{1'b0}};
`endif
		end
`endif
		default: begin
			spr_dat_o[19:0] = picsr;
`ifdef OR1200_PIC_UNUSED_ZERO
			spr_dat_o[31:20] = {32-`OR1200_PIC_INTS{1'b0}};
`endif
		end
	endcase

// REVISED: um_ints = pic_int & {picmr, 2'b11} (bits [1:0] always unmasked)
assign um_ints = pic_int & {picmr, 2'b11};

assign intr      = |um_ints;
assign pic_wakeup = intr;

`else

assign intr      = pic_int[1] | pic_int[0];
assign pic_wakeup = intr;

`ifdef OR1200_PIC_READREGS
assign spr_dat_o[19:0] = `OR1200_PIC_INTS'b0;
`ifdef OR1200_PIC_UNUSED_ZERO
assign spr_dat_o[31:20] = 32-`OR1200_PIC_INTS'b0;
`endif
`endif

`endif

endmodule
