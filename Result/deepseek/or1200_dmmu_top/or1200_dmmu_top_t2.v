`timescale 1ns / 1ps

module or1200_dmmu_top (
    input  wire        clk,
    input  wire        rst,

    input  wire        dc_en,
    input  wire        dmmu_en,
    input  wire        supv,
    input  wire [31:0] dcpu_adr_i,
    input  wire        dcpu_cycstb_i,
    input  wire        dcpu_we_i,
    output reg  [3:0]  dcpu_tag_o,
    output reg         dcpu_err_o,

    input  wire        spr_cs,
    input  wire        spr_write,
    input  wire [31:0] spr_addr,
    input  wire [31:0] spr_dat_i,
    output wire [31:0] spr_dat_o,

`ifdef OR1200_BIST
    input  wire        mbist_si_i,
    output wire        mbist_so_o,
    input  wire [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif

    input  wire        qmemdmmu_err_i,
    input  wire [3:0]  qmemdmmu_tag_i,
    output wire [31:0] qmemdmmu_adr_o,
    output wire        qmemdmmu_cycstb_o,
    output wire        qmemdmmu_ci_o
);

`ifdef OR1200_NO_DMMU
    assign qmemdmmu_adr_o    = dcpu_adr_i;
    assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
    assign qmemdmmu_ci_o     = dcpu_adr_i[31];

    assign spr_dat_o = 32'h0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dcpu_tag_o <= 4'h0;
            dcpu_err_o <= 1'b0;
        end else begin
            dcpu_tag_o <= qmemdmmu_tag_i;
            dcpu_err_o <= qmemdmmu_err_i;
        end
    end

`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif

`else
    // Internal signals
    wire        dtlb_en;
    wire        dtlb_hit;
    wire [18:0] dtlb_ppn;
    wire        dtlb_ci;
    wire        dtlb_uwe;
    wire        dtlb_ure;
    wire        dtlb_swe;
    wire        dtlb_sre;
    wire [31:0] dtlb_dat_o;

    reg         dtlb_done;
    reg  [18:0] dcpu_vpn_r;

    wire        miss;
    wire        fault;

    // DTLB enable
    assign dtlb_en = dmmu_en & dcpu_cycstb_i;

    // DTLB done flag
    always @(posedge clk or posedge rst) begin
        if (rst)
            dtlb_done <= 1'b0;
        else if (dtlb_en)
            dtlb_done <= dcpu_cycstb_i;
        else
            dtlb_done <= 1'b0;
    end

    // VPN register (not used in final address mux, but kept per spec)
    always @(posedge clk) begin
        dcpu_vpn_r <= dcpu_adr_i[31:13];
    end

    // Instantiate the DTLB
    or1200_dmmu_tlb u_dtlb (
        .clk            (clk),
        .rst            (rst),
        .dtlb_en        (dtlb_en),
        .vaddr          (dcpu_adr_i),
        .dtlb_hit       (dtlb_hit),
        .dtlb_ppn       (dtlb_ppn),
        .dtlb_ci        (dtlb_ci),
        .dtlb_uwe       (dtlb_uwe),
        .dtlb_ure       (dtlb_ure),
        .dtlb_swe       (dtlb_swe),
        .dtlb_sre       (dtlb_sre),
        .spr_cs         (spr_cs),
        .spr_write      (spr_write),
        .spr_addr       (spr_addr),
        .spr_dat_i      (spr_dat_i),
        .spr_dat_o      (dtlb_dat_o),
`ifdef OR1200_BIST
        .mbist_si_i     (mbist_si_i),
        .mbist_so_o     (mbist_so_o),
        .mbist_ctrl_i   (mbist_ctrl_i),
`endif
        .dummy          ()
    );

`ifndef OR1200_BIST
    // If BIST not defined, provide dummy outputs for the unconnected ports
    // but the TLB instance must still be syntactically correct.
    // The generated code from the spec includes these only when BIST is defined.
    // We handle the conditional instantiation by providing the ports only when defined.
    // To keep the code clean, we assume the lower module has these ports only when BIST is defined.
    // Since we cannot remove ports from `or1200_dmmu_tlb` dynamically, we assume the module
    // definition handles it internally or the ports are always present but unused.
`endif

    // Miss detection
    assign miss = dtlb_done & ~dtlb_hit;

    // Fault detection
    wire user_load  = ~supv & ~dcpu_we_i;
    wire user_store = ~supv &  dcpu_we_i;
    wire supv_load  =  supv & ~dcpu_we_i;
    wire supv_store =  supv &  dcpu_we_i;

    wire perm_ok = (user_load  &  dtlb_ure) |
                   (user_store &  dtlb_uwe) |
                   (supv_load  &  dtlb_sre) |
                   (supv_store &  dtlb_swe);

    assign fault = dtlb_done & ~perm_ok;

    // Address output
    assign qmemdmmu_adr_o = dmmu_en ? {dtlb_ppn, dcpu_adr_i[12:0]} : dcpu_adr_i;

    // Cache inhibit output
    assign qmemdmmu_ci_o = dmmu_en ? (dtlb_done & dtlb_ci) : dcpu_adr_i[31];

    // Request gating
    wire req_suppress = miss | fault;
    wire dc_dis_dmmu_en = (~dc_en) & dmmu_en;

    assign qmemdmmu_cycstb_o = dcpu_cycstb_i & ~req_suppress &
                               (dc_dis_dmmu_en ? dtlb_done : 1'b1);

    // CPU error and tag outputs
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dcpu_err_o <= 1'b0;
            dcpu_tag_o <= 4'h0;
        end else begin
            dcpu_err_o <= miss | fault | qmemdmmu_err_i;

            if (miss)
                dcpu_tag_o <= `OR1200_DTAG_TE;
            else if (fault)
                dcpu_tag_o <= `OR1200_DTAG_PE;
            else
                dcpu_tag_o <= qmemdmmu_tag_i;
        end
    end

    // SPR read data
    assign spr_dat_o = spr_cs ? dtlb_dat_o : 32'h0;

`endif

endmodule
