`ifndef OR1200_ITAG_TE
`define OR1200_ITAG_TE 4'hA
`endif

`ifndef OR1200_ITAG_PE
`define OR1200_ITAG_PE 4'hB
`endif

`ifndef OR1200_IMMU_CI
`define OR1200_IMMU_CI 1'b0
`endif

module or1200_immu_top(
    input               clk,
    input               rst,
    input               ic_en,
    input               immu_en,
    input               supv,
    input       [31:0]  icpu_adr_i,
    input               icpu_cycstb_i,
    output reg  [31:0]  icpu_adr_o,
    output      [3:0]   icpu_tag_o,
    output              icpu_rty_o,
    output              icpu_err_o,
    input               spr_cs,
    input               spr_write,
    input       [31:0]  spr_addr,
    input       [31:0]  spr_dat_i,
    output      [31:0]  spr_dat_o,
`ifdef OR1200_BIST
    input               mbist_si_i,
    output              mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input               qmemimmu_rty_i,
    input               qmemimmu_err_i,
    input       [3:0]   qmemimmu_tag_i,
    output      [31:0]  qmemimmu_adr_o,
    output              qmemimmu_cycstb_o,
    output              qmemimmu_ci_o
);

wire _unused_ic_en = ic_en;

reg [31:13] icpu_vpn_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        icpu_adr_o <= 32'h0000_0100;
        icpu_vpn_r <= 19'h0;
    end else begin
        icpu_adr_o <= icpu_adr_i;
        icpu_vpn_r <= icpu_adr_i[31:13];
    end
end

assign qmemimmu_ci_o = `OR1200_IMMU_CI;

`ifdef OR1200_NO_IMMU

assign qmemimmu_adr_o    = icpu_adr_i;
assign qmemimmu_cycstb_o = icpu_cycstb_i;
assign icpu_tag_o        = qmemimmu_tag_i;
assign icpu_rty_o        = qmemimmu_rty_i;
assign icpu_err_o        = qmemimmu_err_i;
assign spr_dat_o         = 32'h0000_0000;

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else

wire        itlb_spr_access;
wire [31:13]itlb_ppn;
wire        itlb_hit;
wire        itlb_uxe;
wire        itlb_sxe;
wire [31:0] itlb_dat_o;
wire        itlb_en;
wire        itlb_ci;
wire        itlb_done;
wire        fault;
wire        miss;
wire        page_cross;

reg         itlb_en_r;
reg         dis_spr_access;

assign page_cross      = (icpu_adr_i[31:13] != icpu_vpn_r);
assign itlb_en         = immu_en & icpu_cycstb_i;
assign itlb_done       = itlb_en_r & ~page_cross;
assign miss            = itlb_done & ~itlb_hit;
assign fault           = itlb_done & ((~supv & ~itlb_uxe) | (supv & ~itlb_sxe));
assign itlb_spr_access = spr_cs & ~dis_spr_access;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        itlb_en_r      <= 1'b0;
        dis_spr_access <= 1'b0;
    end else begin
        itlb_en_r <= itlb_en & ~itlb_spr_access;
        if (spr_cs)
            dis_spr_access <= 1'b1;
        else if (~icpu_rty_o)
            dis_spr_access <= 1'b0;
    end
end

assign qmemimmu_adr_o    = itlb_done ? {itlb_ppn, icpu_adr_i[12:0]} : {icpu_vpn_r, icpu_adr_i[12:0]};
assign qmemimmu_cycstb_o = immu_en
                            ? (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross)
                            : (icpu_cycstb_i & ~page_cross);

assign spr_dat_o  = itlb_spr_access ? itlb_dat_o : 32'h0000_0000;
assign icpu_rty_o = qmemimmu_rty_i | (spr_cs & dis_spr_access);
assign icpu_err_o = miss | fault | qmemimmu_err_i;
assign icpu_tag_o = miss ? `OR1200_ITAG_TE :
                    fault ? `OR1200_ITAG_PE :
                    qmemimmu_tag_i;

or1200_immu_tlb itlb (
    .clk            (clk),
    .rst            (rst),
    .vaddr          (icpu_adr_i),
    .en             (itlb_en),
    .hit            (itlb_hit),
    .ppn            (itlb_ppn),
    .uxe            (itlb_uxe),
    .sxe            (itlb_sxe),
    .ci             (itlb_ci),
    .spr_cs         (itlb_spr_access),
    .spr_write      (spr_write),
    .spr_addr       (spr_addr),
    .spr_dat_i      (spr_dat_i),
    .spr_dat_o      (itlb_dat_o)
`ifdef OR1200_BIST
    ,
    .mbist_si_i     (mbist_si_i),
    .mbist_so_o     (mbist_so_o),
    .mbist_ctrl_i   (mbist_ctrl_i)
`endif
);

wire _unused_itlb_ci = itlb_ci;

`endif

endmodule
