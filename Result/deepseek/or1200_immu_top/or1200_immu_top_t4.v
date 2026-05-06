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
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    output [31:0] qmemimmu_adr_o,
    output qmemimmu_cycstb_o,
    output qmemimmu_ci_o
);

`ifdef OR1200_IMPU
    // ITLB interface wires
    wire itlb_spr_access;
    wire [31:13] itlb_ppn;
    wire itlb_hit;
    wire itlb_uxe;
    wire itlb_sxe;
    wire [31:0] itlb_dat_o;
    wire itlb_ci;
    wire itlb_en;
    reg dis_spr_access;
    reg itlb_en_r;
    wire miss;
    wire fault;
    wire page_cross;
    reg [31:13] icpu_vpn_r;
    wire [31:13] current_vpn;

    // ITLB instantiation
    or1200_immu_tlb itlb(
        .clk(clk),
        .rst(rst),
        .en(itlb_en),
        .vpn(icpu_adr_i[31:13]),
        .hit(itlb_hit),
        .ppn(itlb_ppn),
        .uxe(itlb_uxe),
        .sxe(itlb_sxe),
        .ci(itlb_ci),
        .spr_access(itlb_spr_access),
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

    // itlb_spr_access gated by dis_spr_access
    assign itlb_spr_access = spr_cs & ~dis_spr_access;

    // itlb_en: enabled when immu_en and cpu request
    assign itlb_en = immu_en & icpu_cycstb_i;

    // dis_spr_access control
    always @(posedge clk or posedge rst) begin
        if (rst)
            dis_spr_access <= 1'b0;
        else if (spr_cs & ~dis_spr_access)
            dis_spr_access <= 1'b1;
        else
            dis_spr_access <= 1'b0;
    end

    // icpu_adr_o and icpu_vpn_r registers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            icpu_adr_o <= 32'h0000_0100;
            icpu_vpn_r <= {19{1'b0}};
        end else begin
            icpu_adr_o <= icpu_adr_i;
            icpu_vpn_r <= icpu_adr_i[31:13];
        end
    end

    // itlb_en_r, suppressed during SPR access
    always @(posedge clk or posedge rst) begin
        if (rst)
            itlb_en_r <= 1'b0;
        else if (dis_spr_access)
            itlb_en_r <= 1'b0;
        else
            itlb_en_r <= itlb_en;
    end

    // page cross detection
    assign current_vpn = icpu_adr_i[31:13];
    assign page_cross = (icpu_vpn_r != current_vpn);

    // itlb_done: previous lookup usable and no page cross
    wire itlb_done;
    assign itlb_done = itlb_en_r & ~page_cross;

    // miss and fault
    assign miss = itlb_done & ~itlb_hit;
    assign fault = itlb_done & itlb_hit & ( (supv & ~itlb_sxe) | (~supv & ~itlb_uxe) );

    // SPR read data
    assign spr_dat_o = (spr_cs & ~dis_spr_access) ? itlb_dat_o : 32'd0;

    // Downstream request gating
    wire cycstb_en;
    assign cycstb_en = (immu_en) ?
        (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross & ~dis_spr_access) :
        (icpu_cycstb_i & ~page_cross & ~dis_spr_access);
    assign qmemimmu_cycstb_o = cycstb_en;

    // Downstream address
    assign qmemimmu_adr_o = itlb_done ? {itlb_ppn, icpu_adr_i[12:0]} : {icpu_vpn_r, icpu_adr_i[12:0]};

    // Cache inhibit fixed
    assign qmemimmu_ci_o = 1'b0; // architecturally defined constant

    // CPU-side tag, error, retry
    assign icpu_tag_o = miss ? 4'd1 : (fault ? 4'd2 : qmemimmu_tag_i);
    assign icpu_err_o = miss | fault | qmemimmu_err_i;
    assign icpu_rty_o = qmemimmu_rty_i | dis_spr_access;

`else // !OR1200_IMPU (pass-through mode)

    reg [31:0] icpu_adr_o_reg;
    always @(posedge clk or posedge rst) begin
        if (rst)
            icpu_adr_o_reg <= 32'h0000_0100;
        else
            icpu_adr_o_reg <= icpu_adr_i;
    end
    assign icpu_adr_o = icpu_adr_o_reg;

    assign spr_dat_o = 32'd0;
    assign icpu_tag_o = qmemimmu_tag_i;
    assign icpu_err_o = qmemimmu_err_i;
    assign icpu_rty_o = qmemimmu_rty_i;
    assign qmemimmu_adr_o = icpu_adr_i;
    // For pass-through, we ignore page crossing; simply forward
    assign qmemimmu_cycstb_o = icpu_cycstb_i;
    assign qmemimmu_ci_o = 1'b0;

`ifdef OR1200_BIST
    // bypass BIST chain
    assign mbist_so_o = mbist_si_i;
`endif

`endif // OR1200_IMPU

endmodule
