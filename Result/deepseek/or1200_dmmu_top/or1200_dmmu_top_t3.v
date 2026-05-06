module or1200_dmmu_top(
    // Rst and clk
    input clk,
    input rst,

    // CPU i/f
    input dc_en,
    input dmmu_en,
    input supv,
    input [31:0] dcpu_adr_i,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    output [3:0] dcpu_tag_o,
    output dcpu_err_o,

    // SPR access
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // DC i/f
    input qmemdmmu_err_i,
    input [3:0] qmemdmmu_tag_i,
    output [31:0] qmemdmmu_adr_o,
    output qmemdmmu_cycstb_o,
    output qmemdmmu_ci_o
);

    // local parameters for exception tags
    localparam [3:0] OR1200_DTAG_TE = 4'd5; // TLB miss
    localparam [3:0] OR1200_DTAG_PE = 4'd6; // page fault

`ifdef OR1200_NO_DMMU

    // -- Bypass mode (DMMU not compiled) --
    assign qmemdmmu_adr_o = dcpu_adr_i;
    assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
    assign qmemdmmu_ci_o = dcpu_adr_i[31];
    assign dcpu_tag_o = qmemdmmu_tag_i;
    assign dcpu_err_o = qmemdmmu_err_i;
    assign spr_dat_o = 32'd0;

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else // !OR1200_NO_DMMU

    // internal wires and regs
    wire dtlb_en;
    reg dtlb_done;
    reg [18:0] dcpu_vpn_r; // not used but kept for spec compliance

    // DTLB output signals
    wire dtlb_hit;
    wire [18:0] dtlb_ppn; // physical page number bits 31:13
    wire dtlb_uwe;
    wire dtlb_ure;
    wire dtlb_swe;
    wire dtlb_sre;
    wire dtlb_ci;
    wire [31:0] dtlb_dat_o;

    // miss and fault
    wire miss;
    wire fault;

    // DTLB enable
    assign dtlb_en = dmmu_en & dcpu_cycstb_i;

    // dtlb_done register
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dtlb_done <= 1'b0;
        end else if (dtlb_en) begin
            dtlb_done <= dcpu_cycstb_i;
        end else begin
            dtlb_done <= 1'b0;
        end
    end

    // dcpu_vpn_r register (not used in output generation)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dcpu_vpn_r <= 19'd0;
        end else begin
            dcpu_vpn_r <= dcpu_adr_i[31:13];
        end
    end

    // miss detection
    assign miss = dtlb_done & !dtlb_hit;

    // fault detection (not masked by dtlb_hit)
    assign fault = dtlb_done & (
        (dcpu_we_i & !supv & !dtlb_uwe) |
        (dcpu_we_i & supv  & !dtlb_swe) |
        (!dcpu_we_i & !supv & !dtlb_ure) |
        (!dcpu_we_i & supv  & !dtlb_sre)
    );

    // downstream address
    assign qmemdmmu_adr_o = dmmu_en ? {dtlb_ppn, dcpu_adr_i[12:0]} : dcpu_adr_i;

    // downstream request (gated by miss, fault, and dtlb_done when dc disabled and DMMU enabled)
    assign qmemdmmu_cycstb_o = dcpu_cycstb_i & !miss & !fault &
                                ((dc_en | !dmmu_en) | dtlb_done);

    // cache-inhibit output
    assign qmemdmmu_ci_o = dmmu_en ? (dtlb_ci & dtlb_done) : dcpu_adr_i[31];

    // CPU tag output (priority: miss > fault > downstream tag)
    assign dcpu_tag_o = miss ? OR1200_DTAG_TE :
                        fault ? OR1200_DTAG_PE :
                        qmemdmmu_tag_i;

    // CPU error output
    assign dcpu_err_o = miss | fault | qmemdmmu_err_i;

    // SPR read data
    assign spr_dat_o = spr_cs ? dtlb_dat_o : 32'd0;

    // Instantiating the DTLB submodule
    or1200_dmmu_tlb #(
        .TAG(0)
    ) dtlb_inst (
        .clk(clk),
        .rst(rst),
        .tlb_en(dtlb_en),
        .spr_access(spr_cs),
        .spr_write(spr_write),
        .spr_addr(spr_addr),
        .spr_dat_i(spr_dat_i),
        .spr_dat_o(dtlb_dat_o),
        .tlb_hit(dtlb_hit),
        .tlb_ppn(dtlb_ppn),
        .tlb_uwe(dtlb_uwe),
        .tlb_ure(dtlb_ure),
        .tlb_swe(dtlb_swe),
        .tlb_sre(dtlb_sre),
        .tlb_ci(dtlb_ci)
`ifdef OR1200_BIST
        .mbist_si_i(mbist_si_i),
        .mbist_so_o(mbist_so_o),
        .mbist_ctrl_i(mbist_ctrl_i)
`endif
    );

`endif // OR1200_NO_DMMU

endmodule
