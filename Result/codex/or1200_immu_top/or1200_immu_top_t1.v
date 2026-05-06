module or1200_immu_top(
    input clk,
    input rst,
    input ic_en,
    input immu_en,
    input supv,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    output reg [31:0] icpu_adr_o,
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

localparam [3:0] ITLB_MISS_TAG = 4'h1;
localparam [3:0] PAGE_FAULT_TAG = 4'h2;
localparam IMMU_CI_CONST = 1'b0;

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
wire spr_wait;
reg [31:13] icpu_vpn_r;
reg itlb_en_r;
reg dis_spr_access;

wire unused_signals;
assign unused_signals = ic_en ^ itlb_ci;

assign itlb_spr_access = spr_cs & ~dis_spr_access;
assign itlb_en = immu_en & icpu_cycstb_i;
assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);
assign itlb_done = itlb_en_r & ~page_cross;
assign miss = itlb_done & ~itlb_hit;
assign fault = itlb_done & itlb_hit & ((~supv & ~itlb_uxe) | (supv & ~itlb_sxe));
assign spr_wait = spr_cs & ~dis_spr_access;

assign icpu_tag_o = miss ? ITLB_MISS_TAG :
                    fault ? PAGE_FAULT_TAG :
                    qmemimmu_tag_i;
assign icpu_err_o = miss | fault | qmemimmu_err_i;
assign icpu_rty_o = qmemimmu_rty_i | spr_wait;
assign spr_dat_o = (itlb_spr_access & ~spr_write) ? itlb_dat_o : 32'd0;

assign qmemimmu_adr_o = itlb_done ? {itlb_ppn, icpu_adr_i[12:0]} :
                                    {icpu_vpn_r, icpu_adr_i[12:0]};
assign qmemimmu_cycstb_o = immu_en ?
                            (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross) :
                            (icpu_cycstb_i & ~page_cross);
assign qmemimmu_ci_o = IMMU_CI_CONST;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        icpu_adr_o <= 32'h0000_0100;
        icpu_vpn_r <= 19'd0;
        itlb_en_r <= 1'b0;
        dis_spr_access <= 1'b0;
    end else begin
        icpu_adr_o <= icpu_adr_i;
        icpu_vpn_r <= icpu_adr_i[31:13];

        if (itlb_spr_access) begin
            itlb_en_r <= 1'b0;
        end else begin
            itlb_en_r <= itlb_en;
        end

        if (!icpu_rty_o) begin
            dis_spr_access <= 1'b0;
        end else if (itlb_spr_access) begin
            dis_spr_access <= 1'b1;
        end
    end
end

or1200_immu_top_itlb u_itlb (
    .clk(clk),
    .rst(rst),
    .en(itlb_en),
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
    , .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

endmodule

module or1200_immu_top_itlb(
    input clk,
    input rst,
    input en,
    input [31:0] vaddr,
    output reg hit,
    output reg [31:13] ppn,
    output reg uxe,
    output reg sxe,
    output reg ci,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);

localparam integer ENTRY_COUNT = 8;

reg [31:13] vpn_mem [0:ENTRY_COUNT-1];
reg [31:13] ppn_mem [0:ENTRY_COUNT-1];
reg valid_mem [0:ENTRY_COUNT-1];
reg uxe_mem [0:ENTRY_COUNT-1];
reg sxe_mem [0:ENTRY_COUNT-1];
reg ci_mem [0:ENTRY_COUNT-1];

wire [2:0] spr_index;
wire spr_is_translate;
integer i;

assign spr_index = spr_addr[3:1];
assign spr_is_translate = spr_addr[0];

`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i ^ mbist_ctrl_i[0];
`endif

always @(*) begin
    hit = 1'b0;
    ppn = 19'd0;
    uxe = 1'b0;
    sxe = 1'b0;
    ci = 1'b0;

    if (en) begin
        for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
            if (!hit && valid_mem[i] && (vpn_mem[i] == vaddr[31:13])) begin
                hit = 1'b1;
                ppn = ppn_mem[i];
                uxe = uxe_mem[i];
                sxe = sxe_mem[i];
                ci = ci_mem[i];
            end
        end
    end
end

always @(*) begin
    spr_dat_o = 32'd0;
    if (spr_cs) begin
        if (spr_is_translate) begin
            spr_dat_o[31:13] = ppn_mem[spr_index];
            spr_dat_o[2] = ci_mem[spr_index];
            spr_dat_o[1] = sxe_mem[spr_index];
            spr_dat_o[0] = uxe_mem[spr_index];
        end else begin
            spr_dat_o[31:13] = vpn_mem[spr_index];
            spr_dat_o[0] = valid_mem[spr_index];
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
            vpn_mem[i] <= 19'd0;
            ppn_mem[i] <= 19'd0;
            valid_mem[i] <= 1'b0;
            uxe_mem[i] <= 1'b0;
            sxe_mem[i] <= 1'b0;
            ci_mem[i] <= 1'b0;
        end
    end else if (spr_cs & spr_write) begin
        if (spr_is_translate) begin
            ppn_mem[spr_index] <= spr_dat_i[31:13];
            ci_mem[spr_index] <= spr_dat_i[2];
            sxe_mem[spr_index] <= spr_dat_i[1];
            uxe_mem[spr_index] <= spr_dat_i[0];
        end else begin
            vpn_mem[spr_index] <= spr_dat_i[31:13];
            valid_mem[spr_index] <= spr_dat_i[0];
        end
    end
end

endmodule
