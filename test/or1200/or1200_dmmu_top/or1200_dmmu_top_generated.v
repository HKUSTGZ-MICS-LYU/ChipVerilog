`include "timescale.v"
`include "or1200_defines.v"

module or1200_dmmu_top(
	clk, rst,
	dc_en, dmmu_en, supv, dcpu_adr_i, dcpu_cycstb_i, dcpu_we_i,
	dcpu_tag_o, dcpu_err_o,
	spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,

`ifdef OR1200_BIST
	mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

	qmemdmmu_err_i, qmemdmmu_tag_i, qmemdmmu_adr_o, qmemdmmu_cycstb_o, qmemdmmu_ci_o
);

input			clk;
input			rst;
input			dc_en;
input			dmmu_en;
input			supv;
input	[31:0]		dcpu_adr_i;
input			dcpu_cycstb_i;
input			dcpu_we_i;
output	[3:0]		dcpu_tag_o;
output			dcpu_err_o;
input			spr_cs;
input			spr_write;
input	[31:0]		spr_addr;
input	[31:0]		spr_dat_i;
output	[31:0]		spr_dat_o;

`ifdef OR1200_BIST
input			mbist_si_i;
input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output			mbist_so_o;
`endif

input			qmemdmmu_err_i;
input	[3:0]		qmemdmmu_tag_i;
output	[31:0]		qmemdmmu_adr_o;
output			qmemdmmu_cycstb_o;
output			qmemdmmu_ci_o;

wire			dtlb_spr_access;
wire	[31:13]		dtlb_ppn;
wire			dtlb_hit;
wire			dtlb_uwe;
wire			dtlb_ure;
wire			dtlb_swe;
wire			dtlb_sre;
wire	[31:0]		dtlb_dat_o;
wire			dtlb_en;
wire			dtlb_ci;
wire			fault;
wire			miss;

`ifdef OR1200_NO_DMMU
`else
reg			dtlb_done;
reg	[31:13]		dcpu_vpn_r;
`endif

`ifdef OR1200_NO_DMMU

// Transparent pass-through when DMMU is disabled
assign spr_dat_o        = 32'h00000000;
assign qmemdmmu_adr_o   = dcpu_adr_i;
assign dcpu_tag_o       = qmemdmmu_tag_i;
assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
assign dcpu_err_o       = qmemdmmu_err_i;
assign qmemdmmu_ci_o    = dcpu_adr_i[31];
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

// SPR access routes to DTLB block when spr_cs is active
assign dtlb_spr_access = spr_cs;

// Output tagging: miss > fault > downstream tag
assign dcpu_tag_o = miss  ? `OR1200_DTAG_TE :
                    fault ? `OR1200_DTAG_PE :
                    qmemdmmu_tag_i;

// dcpu_err_o: asserted on miss, fault, or downstream error
assign dcpu_err_o = miss | fault | qmemdmmu_err_i;

// dtlb_done: one-cycle delayed indication that translation results are available
always @(posedge clk or posedge rst)
	if (rst)
		dtlb_done <= #1 1'b0;
	else if (dtlb_en)
		dtlb_done <= #1 dcpu_cycstb_i;
	else
		dtlb_done <= #1 1'b0;

// Request forwarding gated by miss/fault; delayed by dtlb_done when dc_en=0, dmmu_en=1
assign qmemdmmu_cycstb_o = (!dc_en & dmmu_en) ?
                            ~(miss | fault) & dtlb_done & dcpu_cycstb_i :
                            ~(miss | fault) & dcpu_cycstb_i;

// Cache inhibit from TLB when DMMU enabled, qualified with dtlb_done
assign qmemdmmu_ci_o = dmmu_en ? dtlb_done & dtlb_ci : dcpu_adr_i[31];

// VPN register (historical; current bypass path uses dcpu_adr_i directly)
always @(posedge clk or posedge rst)
	if (rst)
		dcpu_vpn_r <= #1 {31-`OR1200_DMMU_PS{1'b0}};
	else
		dcpu_vpn_r <= #1 dcpu_adr_i[31:13];

// Physical address: translated when dmmu_en, else pass-through
assign qmemdmmu_adr_o = dmmu_en ? {dtlb_ppn, dcpu_adr_i[12:0]} : dcpu_adr_i;

// SPR read data from DTLB when spr_cs active
assign spr_dat_o = dtlb_spr_access ? dtlb_dat_o : 32'h00000000;

// Page fault: permission-based fault detection after dtlb_done
// load user: ure required; load supv: sre required
// store user: uwe required; store supv: swe required
assign fault = dtlb_done &
               (  (!dcpu_we_i & !supv & !dtlb_ure)
               || (!dcpu_we_i &  supv & !dtlb_sre)
               || ( dcpu_we_i & !supv & !dtlb_uwe)
               || ( dcpu_we_i &  supv & !dtlb_swe));

// TLB miss: dtlb_done high but no hit
assign miss = dtlb_done & !dtlb_hit;

// DTLB enable
assign dtlb_en = dmmu_en & dcpu_cycstb_i;

// Instantiation of DTLB
or1200_dmmu_tlb or1200_dmmu_tlb(
	.clk(clk), .rst(rst),
	.tlb_en(dtlb_en),
	.vaddr(dcpu_adr_i),
	.hit(dtlb_hit),
	.ppn(dtlb_ppn),
	.uwe(dtlb_uwe),
	.ure(dtlb_ure),
	.swe(dtlb_swe),
	.sre(dtlb_sre),
	.ci(dtlb_ci),
`ifdef OR1200_BIST
	.mbist_si_i(mbist_si_i),
	.mbist_so_o(mbist_so_o),
	.mbist_ctrl_i(mbist_ctrl_i),
`endif
	.spr_cs(dtlb_spr_access),
	.spr_write(spr_write),
	.spr_addr(spr_addr),
	.spr_dat_i(spr_dat_i),
	.spr_dat_o(dtlb_dat_o)
);

`endif

endmodule
