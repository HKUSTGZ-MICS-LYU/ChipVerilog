module or1200_immu_top(
    input clk,
    input rst,
    input ic_en,
    input immu_en,
    input supv,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    output [31:0] icpu_adr_o,
    output [3:0] icpu_tag_o,
    output icpu_rty_o,
    output icpu_err_o,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    output [31:0] qmemimmu_adr_o,
    output qmemimmu_cycstb_o,
    output qmemimmu_ci_o
);

localparam [3:0] TLB_MISS_TAG = 4'h1;
localparam [3:0] PAGE_FAULT_TAG = 4'h2;
localparam       IMMU_CI_CONST = 1'b0;

reg [31:0] icpu_adr_o;

always @(posedge clk or posedge rst)
begin
    if (rst)
        icpu_adr_o <= 32'h0000_0100;
    else
        icpu_adr_o <= icpu_adr_i;
end

`ifndef OR1200_NO_IMMU
wire itlb_spr_access;
wire [31:13] itlb_ppn;
wire itlb_hit;
wire itlb_uxe;
wire itlb_sxe;
wire [31:0] itlb_dat_o;
wire itlb_en;
wire itlb_ci;
wire itlb_done;
wire fault;
wire miss;
wire page_cross;
wire spr_local_rty;
reg [31:13] icpu_vpn_r;
reg itlb_en_r;
reg dis_spr_access;

assign itlb_spr_access = spr_cs & ~dis_spr_access;
assign itlb_en = immu_en & icpu_cycstb_i;
assign page_cross = (icpu_vpn_r != icpu_adr_i[31:13]);
assign itlb_done = itlb_en_r & ~page_cross;
assign miss = itlb_done & ~itlb_hit;
assign fault = itlb_done & itlb_hit & (supv ? ~itlb_sxe : ~itlb_uxe);
assign spr_local_rty = itlb_spr_access;

always @(posedge clk or posedge rst)
begin
    if (rst) begin
        icpu_vpn_r <= 19'h0;
        itlb_en_r <= 1'b0;
        dis_spr_access <= 1'b0;
    end
    else begin
        icpu_vpn_r <= icpu_adr_i[31:13];
        if (itlb_spr_access)
            itlb_en_r <= 1'b0;
        else
            itlb_en_r <= itlb_en;

        if (spr_cs && icpu_rty_o)
            dis_spr_access <= 1'b1;
        else
            dis_spr_access <= 1'b0;
    end
end

assign icpu_tag_o = miss ? TLB_MISS_TAG :
                    fault ? PAGE_FAULT_TAG :
                    qmemimmu_tag_i;
assign icpu_rty_o = qmemimmu_rty_i | spr_local_rty;
assign icpu_err_o = qmemimmu_err_i | miss | fault;
assign spr_dat_o = itlb_spr_access ? itlb_dat_o : 32'h0000_0000;
assign qmemimmu_adr_o = itlb_done ? {itlb_ppn, icpu_adr_i[12:0]} :
                                     {icpu_vpn_r, icpu_adr_i[12:0]};
assign qmemimmu_cycstb_o = spr_cs ? 1'b0 :
                           immu_en ? (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross) :
                                     (icpu_cycstb_i & ~page_cross);
assign qmemimmu_ci_o = IMMU_CI_CONST;

or1200_immu_tlb itlb(
    .clk(clk),
    .rst(rst),
    .ce(itlb_en),
    .vaddr(icpu_adr_i),
    .hit(itlb_hit),
    .ppn(itlb_ppn),
    .uxe(itlb_uxe),
    .sxe(itlb_sxe),
    .ci(itlb_ci),
    .spr_cs(itlb_spr_access),
    .spr_write(spr_write),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_i),
    .spr_dat_o(itlb_dat_o)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);
`else
assign icpu_tag_o = qmemimmu_tag_i;
assign icpu_rty_o = qmemimmu_rty_i;
assign icpu_err_o = qmemimmu_err_i;
assign spr_dat_o = 32'h0000_0000;
assign qmemimmu_adr_o = icpu_adr_i;
assign qmemimmu_cycstb_o = icpu_cycstb_i;
assign qmemimmu_ci_o = IMMU_CI_CONST;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif
`endif

endmodule
