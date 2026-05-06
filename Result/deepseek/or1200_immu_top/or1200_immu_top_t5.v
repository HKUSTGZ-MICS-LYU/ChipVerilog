module or1200_immu_top(
    input clk,
    input rst,
    input ic_en,
    input immu_en,
    input supv,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    output reg [31:0] icpu_adr_o,
    output reg [3:0] icpu_tag_o,
    output reg icpu_rty_o,
    output reg icpu_err_o,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    output reg [31:0] qmemimmu_adr_o,
    output reg qmemimmu_cycstb_o,
    output reg qmemimmu_ci_o
);

parameter TLB_MISS_TAG  = 4'b0001;
parameter PAGE_FAULT_TAG = 4'b0010;

reg [31:13] icpu_vpn_r;
reg itlb_en_r;
reg dis_spr_access;

wire itlb_en;
wire page_cross;
wire itlb_done;
wire miss;
wire fault;
wire itlb_hit;
wire [31:13] itlb_ppn;
wire itlb_uxe;
wire itlb_sxe;
wire itlb_ci;
wire [31:0] itlb_dat_o;

// Page cross detection
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_vpn_r <= 19'b0;
    else
        icpu_vpn_r <= icpu_adr_i[31:13];
end

assign page_cross = (icpu_vpn_r != icpu_adr_i[31:13]);

// ITLB enable
assign itlb_en = immu_en & icpu_cycstb_i;

// ITLB enable delayed, suppressed during SPR access
always @(posedge clk or posedge rst) begin
    if (rst)
        itlb_en_r <= 1'b0;
    else if (~dis_spr_access)
        itlb_en_r <= itlb_en;
end

// dis_spr_access: set on SPR access, cleared when retry released (next cycle)
always @(posedge clk or posedge rst) begin
    if (rst)
        dis_spr_access <= 1'b0;
    else
        dis_spr_access <= spr_cs;
end

// ITLB done when valid lookup from previous cycle and no page change
assign itlb_done = itlb_en_r & ~page_cross;

`ifdef OR1200_IMMU_IMPLEMENTED

// Instantiate the ITLB
or1200_itlb #(
) u_itlb (
    .clk(clk),
    .rst(rst),
    .itlb_en(itlb_en),
    .addr(icpu_adr_i),
    .hit(itlb_hit),
    .ppn(itlb_ppn),
    .uxe(itlb_uxe),
    .sxe(itlb_sxe),
    .ci(itlb_ci),
    .spr_cs(spr_cs & ~dis_spr_access),  // gated by dis_spr_access
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

// Miss and fault detection
assign miss = itlb_done & ~itlb_hit;
assign fault = itlb_done & itlb_hit & ((supv & ~itlb_sxe) | (~supv & ~itlb_uxe));

// Downstream address selection
always @* begin
    if (itlb_done)
        qmemimmu_adr_o = {itlb_ppn, icpu_adr_i[12:0]};
    else
        qmemimmu_adr_o = {icpu_vpn_r, icpu_adr_i[12:0]};
end

// Downstream request generation
always @* begin
    if (immu_en)
        qmemimmu_cycstb_o = icpu_cycstb_i & ~page_cross & itlb_done & ~miss & ~fault;
    else
        qmemimmu_cycstb_o = icpu_cycstb_i & ~page_cross;
end

// SPR read data
always @* begin
    if (spr_cs & ~spr_write)
        spr_dat_o = itlb_dat_o;
    else
        spr_dat_o = 32'b0;
end

`else // not OR1200_IMMU_IMPLEMENTED

// No IMMU: pass-through
assign miss = 1'b0;
assign fault = 1'b0;
assign itlb_hit = 1'b0;
assign itlb_ppn = 19'b0;
assign itlb_uxe = 1'b0;
assign itlb_sxe = 1'b0;
assign itlb_ci = 1'b0;
assign itlb_dat_o = 32'b0;

always @* begin
    qmemimmu_adr_o = icpu_adr_i;
    qmemimmu_cycstb_o = icpu_cycstb_i;
    spr_dat_o = 32'b0;
end

`endif // OR1200_IMMU_IMPLEMENTED

// Common outputs

// icpu_adr_o: registered copy of icpu_adr_i
always @(posedge clk or posedge rst) begin
    if (rst)
        icpu_adr_o <= 32'h00000100;
    else
        icpu_adr_o <= icpu_adr_i;
end

// icpu_tag_o: priority: miss, fault, downstream tag
always @* begin
    if (miss)
        icpu_tag_o = TLB_MISS_TAG;
    else if (fault)
        icpu_tag_o = PAGE_FAULT_TAG;
    else
        icpu_tag_o = qmemimmu_tag_i;
end

// icpu_err_o
always @* begin
    icpu_err_o = miss | fault | qmemimmu_err_i;
end

// icpu_rty_o: from downstream or local SPR wait
always @* begin
    icpu_rty_o = qmemimmu_rty_i | dis_spr_access;
end

// cache inhibit fixed
always @* begin
    qmemimmu_ci_o = 1'b0;
end

`ifdef OR1200_BIST
`ifndef OR1200_IMMU_IMPLEMENTED
assign mbist_so_o = mbist_si_i;
`endif
`endif

endmodule
