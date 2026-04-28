`include "timescale.v"
`include "or1200_defines.v"

module or1200_immu_top(
    clk, rst,
    ic_en, immu_en, supv,
    icpu_adr_i, icpu_cycstb_i,
    icpu_adr_o, icpu_tag_o, icpu_rty_o, icpu_err_o,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
`ifdef OR1200_BIST
    mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif
    qmemimmu_rty_i, qmemimmu_err_i, qmemimmu_tag_i,
    qmemimmu_adr_o, qmemimmu_cycstb_o, qmemimmu_ci_o
);

input         clk, rst;
input         ic_en;
input         immu_en;
input         supv;
input  [31:0] icpu_adr_i;
input         icpu_cycstb_i;
output [31:0] icpu_adr_o;
output [3:0]  icpu_tag_o;
output        icpu_rty_o;
output        icpu_err_o;
input         spr_cs, spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;
`ifdef OR1200_BIST
input         mbist_si_i;
output        mbist_so_o;
input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i;
`endif
input         qmemimmu_rty_i, qmemimmu_err_i;
input  [3:0]  qmemimmu_tag_i;
output [31:0] qmemimmu_adr_o;
output        qmemimmu_cycstb_o;
output        qmemimmu_ci_o;

// Fixed cache-inhibit output
assign qmemimmu_ci_o = `OR1200_IMMU_CI;

`ifdef OR1200_NO_IMMU

// Pass-through mode
assign spr_dat_o        = 32'h00000000;
assign qmemimmu_adr_o   = icpu_adr_i;
assign icpu_tag_o       = qmemimmu_tag_i;
assign qmemimmu_cycstb_o = icpu_cycstb_i;
assign icpu_rty_o       = qmemimmu_rty_i;
assign icpu_err_o       = qmemimmu_err_i;
`ifdef OR1200_BIST
assign mbist_so_o       = mbist_si_i;
`endif

// Registered CPU-side address output (reset to 0x0000_0100)
reg [31:0] icpu_adr_o;
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_adr_o <= 32'h0000_0100;
    else
        icpu_adr_o <= icpu_adr_i;
end

// VPN register (needed for page_cross even in no-IMMU mode)
reg [31:13] icpu_vpn_r;
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_vpn_r <= {32-`OR1200_IMMU_PS{1'b0}};
    else
        icpu_vpn_r <= icpu_adr_i[31:13];
end

`else // Normal IMMU build

// Internal wires
wire [31:13] itlb_ppn;
wire         itlb_hit;
wire         itlb_uxe;
wire         itlb_sxe;
wire [31:0]  itlb_dat_o;
wire         itlb_en;
wire         itlb_ci;
wire         itlb_done;
wire         fault;
wire         miss;
wire         page_cross;

// Internal registers
reg [31:0]  icpu_adr_o;
reg [31:13] icpu_vpn_r;
reg          itlb_en_r;
reg          dis_spr_access;

// Registered CPU-side address output
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_adr_o <= 32'h0000_0100;
    else
        icpu_adr_o <= icpu_adr_i;
end

// VPN register
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_vpn_r <= {32-`OR1200_IMMU_PS{1'b0}};
    else
        icpu_vpn_r <= icpu_adr_i[31:13];
end

// page_cross: current VPN differs from previous-cycle VPN
assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);

// ITLB enable
assign itlb_en = immu_en & icpu_cycstb_i;

// itlb_en_r: one-cycle delayed, suppressed during SPR access
wire itlb_spr_access = spr_cs & ~dis_spr_access;

always @(posedge clk or posedge rst) begin
    if (rst)
        itlb_en_r <= 1'b0;
    else
        itlb_en_r <= itlb_en & ~itlb_spr_access;
end

// itlb_done: lookup from previous cycle is usable
assign itlb_done = itlb_en_r & ~page_cross;

// miss and fault (only when itlb_done)
assign miss  = itlb_done & ~itlb_hit;
assign fault = itlb_done & itlb_hit &
               ((!supv & !itlb_uxe) |
                ( supv & !itlb_sxe));

// dis_spr_access: set by spr_cs, cleared when icpu_rty_o deasserts
always @(posedge clk or posedge rst) begin
    if (rst)
        dis_spr_access <= 1'b0;
    else if (!icpu_rty_o)
        dis_spr_access <= 1'b0;
    else if (spr_cs)
        dis_spr_access <= 1'b1;
end

// CPU-side error and tag
assign icpu_err_o = miss | fault | qmemimmu_err_i;
assign icpu_tag_o = miss  ? `OR1200_DTAG_TE :
                   fault ? `OR1200_DTAG_PE :
                            qmemimmu_tag_i;

// CPU-side retry
assign icpu_rty_o = qmemimmu_rty_i | (itlb_spr_access & immu_en);

// Downstream address
assign qmemimmu_adr_o = itlb_done ?
                        {itlb_ppn, icpu_adr_i[12:0]} :
                        {icpu_vpn_r, icpu_adr_i[12:0]};

// Downstream request
assign qmemimmu_cycstb_o = immu_en ?
    (~(miss | fault) & icpu_cycstb_i & ~page_cross & itlb_done) :
    (icpu_cycstb_i & ~page_cross);

// SPR read data
assign spr_dat_o = spr_cs ? itlb_dat_o : 32'h00000000;

// ITLB instantiation
or1200_immu_tlb or1200_immu_tlb(
    .clk(clk), .rst(rst),
    .tlb_en(itlb_en),
    .vaddr(icpu_adr_i),
    .hit(itlb_hit),
    .ppn(itlb_ppn),
    .uxe(itlb_uxe),
    .sxe(itlb_sxe),
    .ci(itlb_ci),
`ifdef OR1200_BIST
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i),
`endif
    .spr_cs(itlb_spr_access),
    .spr_write(spr_write),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_i),
    .spr_dat_o(itlb_dat_o)
);

`endif // OR1200_NO_IMMU

endmodule