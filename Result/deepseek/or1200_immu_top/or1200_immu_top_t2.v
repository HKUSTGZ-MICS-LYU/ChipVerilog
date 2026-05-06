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

`ifdef OR1200_NO_IMMU
    // Pass-through mode: no IMMU
    wire [31:0] qmemimmu_adr_o;
    wire qmemimmu_cycstb_o;
    wire qmemimmu_ci_o;
    wire [31:0] icpu_adr_o;
    wire [3:0] icpu_tag_o;
    wire icpu_rty_o;
    wire icpu_err_o;
    wire [31:0] spr_dat_o;
    
    assign qmemimmu_adr_o = icpu_adr_i;
    assign qmemimmu_cycstb_o = icpu_cycstb_i;
    assign qmemimmu_ci_o = 1'b0;  // Architecturally defined constant
    
    assign icpu_adr_o = icpu_adr_i;
    assign icpu_tag_o = qmemimmu_tag_i;
    assign icpu_rty_o = qmemimmu_rty_i;
    assign icpu_err_o = qmemimmu_err_i;
    assign spr_dat_o = 32'd0;
    
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else
    // Normal IMMU build
    wire itlb_en;
    reg itlb_en_r;
    reg [31:13] icpu_vpn_r;
    wire page_cross;
    wire itlb_done;
    wire itlb_hit;
    wire [31:13] itlb_ppn;
    wire itlb_uxe;
    wire itlb_sxe;
    wire itlb_ci;
    wire [31:0] itlb_dat_o;
    reg dis_spr_access;
    wire itlb_spr_access;
    wire miss;
    wire fault;
    wire [31:0] qmemimmu_adr_o;
    wire qmemimmu_cycstb_o;
    wire qmemimmu_ci_o;
    reg [31:0] icpu_adr_o;
    wire [3:0] icpu_tag_o;
    wire icpu_rty_o;
    wire icpu_err_o;
    wire [31:0] spr_dat_o;
    wire spr_access;
    
    // SPR access request
    assign spr_access = spr_cs;
    assign itlb_spr_access = spr_access && !dis_spr_access;
    
    // ITLB enable: active when immu_en and CPU fetch request and not SPR access
    assign itlb_en = immu_en && icpu_cycstb_i && !itlb_spr_access;
    
    // Register control signals
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            itlb_en_r <= 1'b0;
            dis_spr_access <= 1'b0;
        end else begin
            itlb_en_r <= itlb_en;
            if (spr_access && !dis_spr_access)
                dis_spr_access <= 1'b1;
            else if (dis_spr_access && !icpu_rty_o)
                dis_spr_access <= 1'b0;
        end
    end
    
    // Register virtual page number
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icpu_vpn_r <= 19'd0;
        end else begin
            icpu_vpn_r <= icpu_adr_i[31:13];
        end
    end
    
    // Page cross detection
    assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);
    
    // ITLB done: previous cycle enabled and no page cross
    assign itlb_done = itlb_en_r && !page_cross;
    
    // Instantiate the ITLB
    or1200_itlb itlb_inst (
        .clk(clk),
        .rst(rst),
        .itlb_en(itlb_en),
        .vpn(icpu_adr_i[31:13]),
        .spr_access(itlb_spr_access),
        .spr_write(spr_write),
        .spr_addr(spr_addr),
        .spr_dat_i(spr_dat_i),
        .itlb_hit(itlb_hit),
        .itlb_ppn(itlb_ppn),
        .itlb_uxe(itlb_uxe),
        .itlb_sxe(itlb_sxe),
        .itlb_ci(itlb_ci),
        .itlb_dat_o(itlb_dat_o)
`ifdef OR1200_BIST
        ,
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );
    
    // SPR read data
    assign spr_dat_o = spr_access ? itlb_dat_o : 32'd0;
    
    // Miss and fault detection
    assign miss = itlb_done && !itlb_hit;
    assign fault = itlb_done && itlb_hit && 
                   ((!supv && !itlb_uxe) || (supv && !itlb_sxe));
    
    // Downstream address formation
    assign qmemimmu_adr_o = itlb_done ? 
                            {itlb_ppn, icpu_adr_i[12:0]} : 
                            {icpu_vpn_r, icpu_adr_i[12:0]};
    
    // Downstream request gating
    assign qmemimmu_cycstb_o = immu_en ? 
                               (icpu_cycstb_i && itlb_done && !miss && !fault && !page_cross) : 
                               (icpu_cycstb_i && !page_cross);
    
    // Cache inhibit fixed
    assign qmemimmu_ci_o = 1'b0;
    
    // CPU-side registered address output
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icpu_adr_o <= 32'h0000_0100;
        end else begin
            icpu_adr_o <= icpu_adr_i;
        end
    end
    
    // CPU-side tag priority: TLB miss > page fault > downstream tag
    assign icpu_tag_o = miss ? 4'b0001 : 
                        fault ? 4'b0010 : 
                        qmemimmu_tag_i;
    
    // CPU-side error
    assign icpu_err_o = miss || fault || qmemimmu_err_i;
    
    // CPU-side retry: from downstream or during SPR access
    assign icpu_rty_o = qmemimmu_rty_i || (spr_access && !dis_spr_access);
`endif

endmodule
