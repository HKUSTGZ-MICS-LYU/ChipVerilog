`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_immu_top_gen_from_fixed_desc(
        // Rst and clk
        clk, rst,

        // CPU i/f
        ic_en, immu_en, supv, icpu_adr_i, icpu_cycstb_i,
        icpu_adr_o, icpu_tag_o, icpu_rty_o, icpu_err_o,

        // SPR access
        spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,

`ifdef OR1200_BIST
        // RAM BIST
        mbist_si_i, mbist_so_o, mbist_ctrl_i,
`endif

        // QMEM i/f
        qmemimmu_rty_i, qmemimmu_err_i, qmemimmu_tag_i,
        qmemimmu_adr_o, qmemimmu_cycstb_o, qmemimmu_ci_o
);

input                           clk;
input                           rst;

// CPU i/f
input                           ic_en;
input                           immu_en;
input                           supv;
input   [31:0]                  icpu_adr_i;
input                           icpu_cycstb_i;
output  [31:0]                  icpu_adr_o;
output  [3:0]                   icpu_tag_o;
output                          icpu_rty_o;
output                          icpu_err_o;

// SPR access
input                           spr_cs;
input                           spr_write;
input   [31:0]                  spr_addr;
input   [31:0]                  spr_dat_i;
output  [31:0]                  spr_dat_o;

`ifdef OR1200_BIST
input                           mbist_si_i;
input   [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i;
output                          mbist_so_o;
`endif

// QMEM i/f
input                           qmemimmu_rty_i;
input                           qmemimmu_err_i;
input   [3:0]                   qmemimmu_tag_i;
output  [31:0]                  qmemimmu_adr_o;
output                          qmemimmu_cycstb_o;
output                          qmemimmu_ci_o;

wire                            itlb_spr_access;
wire    [31:13]                 itlb_ppn;
wire                            itlb_hit;
wire                            itlb_uxe;
wire                            itlb_sxe;
wire    [31:0]                  itlb_dat_o;
wire                            itlb_en;
wire                            itlb_ci;
wire                            itlb_done;
wire                            fault;
wire                            miss;
wire                            page_cross;

reg     [31:0]                  icpu_adr_o;
reg     [31:13]                 icpu_vpn_r;
`ifndef OR1200_NO_IMMU
reg                             itlb_en_r;
reg                             dis_spr_access;
`endif

//
// icpu_adr_o is only a registered copy of icpu_adr_i
//
`ifdef OR1200_REGISTERED_OUTPUTS
always @(posedge clk or posedge rst)
        if (rst)
                icpu_adr_o <= #1 32'h0000_0100;
        else
                icpu_adr_o <= #1 icpu_adr_i;
`endif

//
// Detect whether current address moved to a different page relative
// to the previously registered VPN.
//
assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);

always @(posedge clk or posedge rst)
        if (rst)
                icpu_vpn_r <= #1 {32-`OR1200_IMMU_PS{1'b0}};
        else
                icpu_vpn_r <= #1 icpu_adr_i[31:13];

`ifdef OR1200_NO_IMMU

assign spr_dat_o          = 32'h0000_0000;
assign qmemimmu_adr_o     = icpu_adr_i;
assign icpu_tag_o         = qmemimmu_tag_i;
assign qmemimmu_cycstb_o  = icpu_cycstb_i & ~page_cross;
assign icpu_rty_o         = qmemimmu_rty_i;
assign icpu_err_o         = qmemimmu_err_i;
assign qmemimmu_ci_o      = `OR1200_IMMU_CI;
`ifdef OR1200_BIST
assign mbist_so_o         = mbist_si_i;
`endif

`else

assign itlb_spr_access = spr_cs & ~dis_spr_access;

always @(posedge clk or posedge rst)
        if (rst)
                dis_spr_access <= #1 1'b0;
        else if (!icpu_rty_o)
                dis_spr_access <= #1 1'b0;
        else if (spr_cs)
                dis_spr_access <= #1 1'b1;

assign icpu_tag_o = miss ? `OR1200_DTAG_TE :
                    fault ? `OR1200_DTAG_PE :
                    qmemimmu_tag_i;

assign icpu_rty_o = qmemimmu_rty_i | (itlb_spr_access & immu_en);
assign icpu_err_o = miss | fault | qmemimmu_err_i;

always @(posedge clk or posedge rst)
        if (rst)
                itlb_en_r <= #1 1'b0;
        else
                itlb_en_r <= #1 itlb_en & ~itlb_spr_access;

assign itlb_done = itlb_en_r & ~page_cross;

assign qmemimmu_cycstb_o = immu_en ?
                           (~(miss | fault) & icpu_cycstb_i & ~page_cross & itlb_done) :
                           (icpu_cycstb_i & ~page_cross);

assign qmemimmu_adr_o = itlb_done ?
                        {itlb_ppn, icpu_adr_i[12:0]} :
                        {icpu_vpn_r, icpu_adr_i[12:0]};

assign spr_dat_o = spr_cs ? itlb_dat_o : 32'h0000_0000;

assign fault = itlb_done &
               ((!supv & !itlb_uxe) |
                ( supv & !itlb_sxe));

assign miss = itlb_done & !itlb_hit;

assign itlb_en = immu_en & icpu_cycstb_i;

// 修正后版本：不传播 ITLB ci，固定为架构常量
assign qmemimmu_ci_o = `OR1200_IMMU_CI;

or1200_immu_tlb u_itlb(
        .clk(clk),
        .rst(rst),
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

`endif

endmodule
