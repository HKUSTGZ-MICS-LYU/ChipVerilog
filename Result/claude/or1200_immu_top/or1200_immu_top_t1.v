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

    // Internal signals
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

    reg [31:13] icpu_vpn_r;
    reg itlb_en_r;
    reg dis_spr_access;

    // Instruction TLB instance
    or1200_immu_tlb immu_tlb(
        .clk(clk),
        .rst(rst),
        .tlb_en(itlb_en),
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
        .spr_dat_o(spr_dat_o),
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i),
`endif
    );

    // SPR access control
    assign itlb_spr_access = spr_cs & ~dis_spr_access;

    // TLB enable logic
    assign itlb_en = (immu_en & ic_en & icpu_cycstb_i) & ~page_cross;

    // Page crossing detection
    assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);

    // TLB lookup completes one cycle after the request beat.
    assign itlb_done = itlb_en_r & ~page_cross;

    // TLB miss and fault detection
    assign miss = itlb_done & ~itlb_hit;
    assign fault = itlb_done & itlb_hit & (supv ? ~itlb_sxe : ~itlb_uxe);

    // Physical address output
    assign qmemimmu_adr_o = itlb_done ? {itlb_ppn, icpu_adr_i[12:0]} : {icpu_vpn_r, icpu_adr_i[12:0]};

    // Cache inhibit output (fixed to architectural constant)
    assign qmemimmu_ci_o = 1'b0;

    // Request control to downstream
    assign qmemimmu_cycstb_o = immu_en ? 
                               (icpu_cycstb_i & ~miss & ~fault & ~page_cross & itlb_done) :
                               (icpu_cycstb_i & ~page_cross);

    // Retry/wait output
    assign icpu_rty_o = qmemimmu_rty_i | (itlb_spr_access & immu_en);

    // Error output
    assign icpu_err_o = qmemimmu_err_i | miss | fault;

    // Tag output with priority: miss > fault > downstream tag
    assign icpu_tag_o = miss ? 4'h1 :
                        fault ? 4'h2 :
                        qmemimmu_tag_i;

    // SPR read data output
    assign spr_dat_o = itlb_spr_access ? itlb_dat_o : 32'h0;

    // Sequential logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icpu_adr_o <= 32'h00000100;
            icpu_vpn_r <= 19'h0;
            itlb_en_r <= 1'b0;
            dis_spr_access <= 1'b0;
        end else begin
            // Update registered output address
            icpu_adr_o <= icpu_adr_i;

            // Always latch the current virtual page number
            icpu_vpn_r <= icpu_adr_i[31:13];

            // Delay itlb_en by one beat and suppress during SPR access
            itlb_en_r <= itlb_en & ~itlb_spr_access;

            // SPR access disable control
            if (spr_cs) begin
                dis_spr_access <= 1'b1;
            end else if (~icpu_rty_o) begin
                dis_spr_access <= 1'b0;
            end
        end
    end

endmodule
