`include "or1200_defines.v"
`endif

module or1200_dmmu_top(
    input clk,
    input rst,

    input dc_en,
    input dmmu_en,
    input supv,
    input [31:0] dcpu_adr_i,
    input dcpu_cycstb_i,
    input dcpu_we_i,
    output [3:0] dcpu_tag_o,
    output dcpu_err_o,

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

    input qmemdmmu_err_i,
    input [3:0] qmemdmmu_tag_i,
    output [31:0] qmemdmmu_adr_o,
    output qmemdmmu_cycstb_o,
    output qmemdmmu_ci_o
);

`ifdef OR1200_NO_DMMU

    assign qmemdmmu_adr_o    = dcpu_adr_i;
    assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
    assign dcpu_tag_o        = qmemdmmu_tag_i;
    assign dcpu_err_o        = qmemdmmu_err_i;
    assign spr_dat_o         = 32'd0;
    assign qmemdmmu_ci_o     = dcpu_adr_i[31];

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else

    wire dtlb_en;
    reg  dtlb_done;
    wire dtlb_hit;
    wire [31:13] dtlb_ppn;
    wire dtlb_uwe, dtlb_ure, dtlb_swe, dtlb_sre;
    wire dtlb_ci;
    wire dtlb_spr_access;
    wire [31:0] dtlb_dat_o;

    reg [31:13] dcpu_vpn_r;

    wire miss;
    wire fault;
    wire user;
    wire we;

    assign dtlb_en          = dmmu_en & dcpu_cycstb_i;
    assign dtlb_spr_access  = spr_cs;

    always @(posedge clk or posedge rst) begin
        if (rst)
            dtlb_done <= 1'b0;
        else if (dtlb_en)
            dtlb_done <= dcpu_cycstb_i;
        else
            dtlb_done <= 1'b0;
    end

    always @(posedge clk) begin
        dcpu_vpn_r <= dcpu_adr_i[31:13];
    end

    or1200_dmmu_tlb or1200_dmmu_tlb (
        .clk           (clk),
        .rst           (rst),
        .tlb_en        (dtlb_en),
        .vaddr         (dcpu_adr_i),
        .hit           (dtlb_hit),
        .ppn           (dtlb_ppn),
        .uwe           (dtlb_uwe),
        .ure           (dtlb_ure),
        .swe           (dtlb_swe),
        .sre           (dtlb_sre),
        .ci            (dtlb_ci),
        .spr_access    (dtlb_spr_access),
        .spr_write     (spr_write),
        .spr_addr      (spr_addr),
        .spr_dat_i     (spr_dat_i),
        .spr_dat_o     (dtlb_dat_o)
`ifdef OR1200_BIST
        ,
        .mbist_si_i    (mbist_si_i),
        .mbist_so_o    (mbist_so_o),
        .mbist_ctrl_i  (mbist_ctrl_i)
`endif
    );

    assign user = ~supv;
    assign we   = dcpu_we_i;

    assign miss  = dtlb_done & !dtlb_hit;

    assign fault = dtlb_done & (
                     (user & we & !dtlb_uwe) |
                     (user & !we & !dtlb_ure) |
                     (!user & we & !dtlb_swe) |
                     (!user & !we & !dtlb_sre)
                   );

    assign dcpu_err_o = miss | fault | qmemdmmu_err_i;

    assign dcpu_tag_o = miss ? `OR1200_DTAG_TE :
                        fault ? `OR1200_DTAG_PE :
                        qmemdmmu_tag_i;

    assign qmemdmmu_adr_o = dmmu_en ? {dtlb_ppn, dcpu_adr_i[12:0]} : dcpu_adr_i;

    assign qmemdmmu_cycstb_o = dcpu_cycstb_i & !miss & !fault &
                               (!(dmmu_en & ~dc_en) | dtlb_done);

    assign qmemdmmu_ci_o = dmmu_en ? (dtlb_ci & dtlb_done) : dcpu_adr_i[31];

    assign spr_dat_o = dtlb_spr_access ? dtlb_dat_o : 32'd0;

`endif

endmodule
