`include "timescale.v"
`include "or1200_defines.v"

module or1200_wb_biu(
	clk, rst, clmode,
	wb_clk_i, wb_rst_i, wb_ack_i, wb_err_i, wb_rty_i, wb_dat_i,
	wb_cyc_o, wb_adr_o, wb_stb_o, wb_we_o, wb_sel_o, wb_dat_o,
`ifdef OR1200_WB_CAB
	wb_cab_o,
`endif
`ifdef OR1200_WB_B3
	wb_cti_o, wb_bte_o,
`endif
	biu_dat_i, biu_adr_i, biu_cyc_i, biu_stb_i, biu_we_i, biu_sel_i, biu_cab_i,
	biu_dat_o, biu_ack_o, biu_err_o
);

input		clk;
input		rst;
input	[1:0]	clmode;
input		wb_clk_i;
input		wb_rst_i;
input		wb_ack_i;
input		wb_err_i;
input		wb_rty_i;
input	[31:0]	wb_dat_i;
output		wb_cyc_o;
output	[31:0]	wb_adr_o;
output		wb_stb_o;
output		wb_we_o;
output	[3:0]	wb_sel_o;
output	[31:0]	wb_dat_o;
`ifdef OR1200_WB_CAB
output		wb_cab_o;
`endif
`ifdef OR1200_WB_B3
output	[2:0]	wb_cti_o;
output	[1:0]	wb_bte_o;
`endif
input	[31:0]	biu_dat_i;
input	[31:0]	biu_adr_i;
input		biu_cyc_i;
input		biu_stb_i;
input		biu_we_i;
input		biu_cab_i;
input	[3:0]	biu_sel_i;
output	[31:0]	biu_dat_o;
output		biu_ack_o;
output		biu_err_o;

reg	[1:0]	valid_div;

`ifdef OR1200_REGISTERED_OUTPUTS
reg	[31:0]	wb_adr_o;
reg		wb_cyc_o;
reg		wb_stb_o;
reg		wb_we_o;
reg	[3:0]	wb_sel_o;
`ifdef OR1200_WB_CAB
reg		wb_cab_o;
`endif
`ifdef OR1200_WB_B3
reg	[1:0]	burst_len;
reg	[2:0]	wb_cti_o;
`endif
reg	[31:0]	wb_dat_o;
`endif

`ifdef OR1200_REGISTERED_INPUTS
reg		long_ack_o;
reg		long_err_o;
reg	[31:0]	biu_dat_o;
`else
wire		long_ack_o;
wire		long_err_o;
`endif

wire		aborted;
reg		aborted_r;
wire		retry;
`ifdef OR1200_WB_RETRY
reg	[6:0]	retry_cntr;
`endif

// Address
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_adr_o <= #1 {`OR1200_OPERAND_WIDTH{1'b0}};
	else if ((biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~aborted & ~(wb_stb_o & ~wb_ack_i))
		wb_adr_o <= #1 biu_adr_i;
`else
assign wb_adr_o = biu_adr_i;
`endif

// Input data
`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		biu_dat_o <= #1 32'h0;
	else if (wb_ack_i)
		biu_dat_o <= #1 wb_dat_i;
`else
assign biu_dat_o = wb_dat_i;
`endif

// Output data
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_dat_o <= #1 {`OR1200_OPERAND_WIDTH{1'b0}};
	else if ((biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~aborted)
		wb_dat_o <= #1 biu_dat_i;
`else
assign wb_dat_o = biu_dat_i;
`endif

// valid_div: modulo-4 RISC clock counter for clock-division sync
always @(posedge clk or posedge rst)
	if (rst)
		valid_div <= #1 2'b0;
	else
		valid_div <= #1 valid_div + 1'd1;

// biu_ack_o: clock-ratio-qualified ack
assign biu_ack_o = long_ack_o
`ifdef OR1200_CLKDIV_2_SUPPORTED
	& (valid_div[0] | ~clmode[0])
`ifdef OR1200_CLKDIV_4_SUPPORTED
	& (valid_div[1] | ~clmode[1])
`endif
`endif
	;

// long_ack_o
`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		long_ack_o <= #1 1'b0;
	else
		// ⚠️ ORIGINAL: ack described as "from wb_ack_i" without clear aborted masking
		long_ack_o <= #1 wb_ack_i;
`else
// ⚠️ ORIGINAL: may omit ~aborted_r masking
assign long_ack_o = wb_ack_i;
`endif

// biu_err_o
assign biu_err_o = long_err_o
`ifdef OR1200_CLKDIV_2_SUPPORTED
	& (valid_div[0] | ~clmode[0])
`ifdef OR1200_CLKDIV_4_SUPPORTED
	& (valid_div[1] | ~clmode[1])
`endif
`endif
	;

// long_err_o
`ifdef OR1200_REGISTERED_INPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		long_err_o <= #1 1'b0;
	else
		long_err_o <= #1 wb_err_i;
`else
assign long_err_o = wb_err_i;
`endif

// Retry
`ifdef OR1200_WB_RETRY
assign retry = wb_rty_i | (|retry_cntr);
`else
assign retry = 1'b0;
`endif
`ifdef OR1200_WB_RETRY
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		retry_cntr <= #1 1'b0;
	else if (wb_rty_i)
		retry_cntr <= #1 {`OR1200_WB_RETRY{1'b1}};
	else if (retry_cntr)
		retry_cntr <= #1 retry_cntr - 7'd1;
`endif

// ⚠️ ORIGINAL: aborted described vaguely, may be omitted or written incorrectly
assign aborted = wb_stb_o & ~(biu_cyc_i & biu_stb_i) & ~(wb_ack_i | wb_err_i);

// ⚠️ ORIGINAL: aborted_r update condition not clearly specified
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		aborted_r <= #1 1'b0;
	else if (aborted)
		// ⚠️ missing clear condition on wb_ack_i | wb_err_i
		aborted_r <= #1 1'b1;

// wb_cyc_o
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_cyc_o <= #1 1'b0;
	else
`ifdef OR1200_NO_BURSTS
		// ⚠️ ORIGINAL: retry described as simply blocking cyc
		wb_cyc_o <= #1 biu_cyc_i & ~retry;
`else
		wb_cyc_o <= #1 biu_cyc_i & ~retry | biu_cab_i;
`endif
`else
`ifdef OR1200_NO_BURSTS
assign wb_cyc_o = biu_cyc_i & ~retry;
`else
assign wb_cyc_o = biu_cyc_i | biu_cab_i & ~retry;
`endif
`endif

// wb_stb_o
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_stb_o <= #1 1'b0;
	else
		wb_stb_o <= #1 (biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~retry;
`else
assign wb_stb_o = biu_cyc_i & biu_stb_i;
`endif

// wb_we_o
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_we_o <= #1 1'b0;
	else
		wb_we_o <= #1 biu_cyc_i & biu_stb_i & biu_we_i;
`else
assign wb_we_o = biu_cyc_i & biu_stb_i & biu_we_i;
`endif

// wb_sel_o
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_sel_o <= #1 4'b0;
	else
		wb_sel_o <= #1 biu_sel_i;
`else
assign wb_sel_o = biu_sel_i;
`endif

`ifdef OR1200_WB_CAB
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_cab_o <= #1 1'b0;
	else
		wb_cab_o <= #1 biu_cab_i;
`else
assign wb_cab_o = biu_cab_i;
`endif
`endif

`ifdef OR1200_WB_B3
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		burst_len <= #1 2'b00;
	else if (biu_cab_i && burst_len && wb_ack_i)
		burst_len <= #1 burst_len - 1'b1;
	else if (~biu_cab_i)
		burst_len <= #1 2'b11;

`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge wb_clk_i or posedge wb_rst_i)
	if (wb_rst_i)
		wb_cti_o <= #1 3'b000;
`ifdef OR1200_NO_BURSTS
	else
		wb_cti_o <= #1 3'b111;
`else
	else if (biu_cab_i && burst_len[1])
		wb_cti_o <= #1 3'b010;
	else if (biu_cab_i && wb_ack_i)
		wb_cti_o <= #1 3'b111;
`endif
`endif

assign wb_bte_o = 2'b01;
`endif

endmodule
