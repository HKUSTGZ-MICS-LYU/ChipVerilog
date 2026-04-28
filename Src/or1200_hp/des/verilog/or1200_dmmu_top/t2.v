`include "timescale.v"
`include "or1200_defines.v"

module or1200_dmmu_top(
    clk, rst,
    dc_en, dmmu_en, supv,
    dcpu_adr_i, dcpu_cycstb_i, dcpu_we_i,
    dcpu_tag_o, dcpu_err_o,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif
    qmemdmmu_err_i, qmemdmmu_tag_i,
    qmemdmmu_adr_o, qmemdmmu_cycstb_o, qmemdmmu_ci_o
);

input         clk, rst;
input         dc_en, dmmu_en, supv;
input  [31:0] dcpu_adr_i;
input         dcpu_cycstb_i;
input         dcpu_we_i;
output [3:0]  dcpu_tag_o;
output        dcpu_err_o;
input         spr_cs, spr_write;
input  [31:0] spr_addr;
input  [31:0] spr_dat_i;
output [31:0] spr_dat_o;
`ifdef OR1200_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif
input         qmemdmmu_err_i;
input  [3:0]  qmemdmmu_tag_i;
output [31:0] qmemdmmu_adr_o;
output        qmemdmmu_cycstb_o;
output        qmemdmmu_ci_o;

`ifdef OR1200_NO_DMMU

assign spr_dat_o        = 32'h00000000;
assign qmemdmmu_adr_o   = dcpu_adr_i;
assign dcpu_tag_o       = qmemdmmu_tag_i;
assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
assign dcpu_err_o       = qmemdmmu_err_i;
assign qmemdmmu_ci_o    = dcpu_adr_i[31];
`ifdef OR1200_BIST
assign mbist_so_o       = mbist_si_i;
`endif

`else

// Internal wires
wire [31:13] dtlb_ppn;
wire         dtlb_hit;
wire         dtlb_uwe, dtlb_ure, dtlb_swe, dtlb_sre;
wire         dtlb_ci;
wire [31:0]  dtlb_dat_o;
wire         dtlb_en;
wire         dtlb_spr_access;
wire         miss;
wire         fault;

reg          dtlb_done;
reg  [31:13] dcpu_vpn_r;

// dtlb_en: DMMU enabled and valid request
assign dtlb_en = dmmu_en & dcpu_cycstb_i;

// dtlb_spr_access: SPR access forwarded to DTLB
assign dtlb_spr_access = spr_cs;

// dtlb_done: one-cycle delayed valid DMMU request
always @(posedge clk or posedge rst) begin
    if (rst)
        dtlb_done <= 1'b0;
    else if (dtlb_en)
        dtlb_done <= dcpu_cycstb_i;
    else
        dtlb_done <= 1'b0;
end

// dcpu_vpn_r: track VPN (not used in address output but kept updated)
always @(posedge clk or posedge rst) begin
    if (rst)
        dcpu_vpn_r <= {32-`OR1200_DMMU_PS{1'b0}};
    else
        dcpu_vpn_r <= dcpu_adr_i[31:13];
end

// miss and fault
assign miss  = dtlb_done & !dtlb_hit;
assign fault = dtlb_done &
               ((!supv &  dcpu_we_i & !dtlb_uwe) |
                (!supv & !dcpu_we_i & !dtlb_ure) |
                ( supv &  dcpu_we_i & !dtlb_swe) |
                ( supv & !dcpu_we_i & !dtlb_sre));

// CPU error and tag outputs
assign dcpu_err_o = miss | fault | qmemdmmu_err_i;
assign dcpu_tag_o = miss  ? `OR1200_DTAG_TE :
                   fault ? `OR1200_DTAG_PE :
                            qmemdmmu_tag_i;

// Downstream address (combinational)
assign qmemdmmu_adr_o = dmmu_en ?
                        {dtlb_ppn, dcpu_adr_i[12:0]} :
                        dcpu_adr_i;

// Downstream request
assign qmemdmmu_cycstb_o = (!dc_en & dmmu_en) ?
                            ~(miss | fault) & dcpu_cycstb_i & dtlb_done :
                            ~(miss | fault) & dcpu_cycstb_i;

// Cache inhibit
assign qmemdmmu_ci_o = dmmu_en ? (dtlb_done & dtlb_ci) : dcpu_adr_i[31];

// SPR read data
assign spr_dat_o = spr_cs ? dtlb_dat_o : 32'h00000000;

// DTLB instantiation
or1200_dmmu_tlb or1200_dmmu_tlb(
    .clk(clk), .rst(rst),
    .tlb_en(dtlb_en),
    .vaddr(dcpu_adr_i),
    .hit(dtlb_hit),
    .ppn(dtlb_ppn),
    .uwe(dtlb_uwe), .ure(dtlb_ure),
    .swe(dtlb_swe), .sre(dtlb_sre),
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