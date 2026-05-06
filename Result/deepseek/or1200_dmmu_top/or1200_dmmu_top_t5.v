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

// Constants for exception tags
localparam [3:0] DTAG_TE = 4'b0010; // TLB miss
localparam [3:0] DTAG_PE = 4'b0001; // page fault

`ifdef OR1200_NO_DMMU

// Bypass path
assign qmemdmmu_adr_o = dcpu_adr_i;
assign qmemdmmu_cycstb_o = dcpu_cycstb_i;
assign dcpu_tag_o = qmemdmmu_tag_i;
assign dcpu_err_o = qmemdmmu_err_i;
assign spr_dat_o = 32'b0;
assign qmemdmmu_ci_o = dcpu_adr_i[31];
`ifdef OR1200_BIST
assign mbist_so_o = mbist_si_i;
`endif

`else // OR1200_NO_DMMU not defined

// Internal wires to DTLB
wire dtlb_hit;
wire [31:0] dtlb_ppn; // Physical page number
wire dtlb_uwe, dtlb_ure, dtlb_swe, dtlb_sre;
wire dtlb_ci;
wire [31:0] dtlb_dat_o;

// DTLB enable
wire dtlb_en = dmmu_en & dcpu_cycstb_i;

// dtlb_done register
reg dtlb_done;
always @(posedge clk or posedge rst) begin
    if (rst)
        dtlb_done <= 1'b0;
    else if (dtlb_en)
        dtlb_done <= dcpu_cycstb_i;
    else
        dtlb_done <= 1'b0;
end

// dcpu_vpn_r register (not used in output but kept for consistency)
reg [18:0] dcpu_vpn_r; // bits [31:13] of address
always @(posedge clk or posedge rst) begin
    if (rst)
        dcpu_vpn_r <= 19'd0;
    else
        dcpu_vpn_r <= dcpu_adr_i[31:13];
end

// TLB miss
wire miss = dtlb_done & ~dtlb_hit;

// Permission fault detection
wire load = ~dcpu_we_i;
wire store = dcpu_we_i;
wire supervisor = supv;
wire user = ~supv;

wire fault = dtlb_done & (
    (supervisor & load  & ~dtlb_sre) |
    (supervisor & store & ~dtlb_swe) |
    (user       & load  & ~dtlb_ure) |
    (user       & store & ~dtlb_uwe)
);

// CPU error and tag
assign dcpu_err_o = miss | fault | qmemdmmu_err_i;

assign dcpu_tag_o = miss ? DTAG_TE :
                    (fault ? DTAG_PE : qmemdmmu_tag_i);

// Downstream address
assign qmemdmmu_adr_o = dmmu_en ? {dtlb_ppn, dcpu_adr_i[12:0]} : dcpu_adr_i;

// Downstream request: miss or fault suppress; also wait for dtlb_done when cache disabled and DMMU enabled
wire cache_disabled_and_mmu_en = ~dc_en & dmmu_en;
wire request_forward = dcpu_cycstb_i & ~miss & ~fault & (cache_disabled_and_mmu_en ? dtlb_done : 1'b1);
assign qmemdmmu_cycstb_o = request_forward;

// Cache inhibit output
assign qmemdmmu_ci_o = dmmu_en ? (dtlb_done ? dtlb_ci : 1'b0) : dcpu_adr_i[31];

// SPR read data
assign spr_dat_o = spr_cs ? dtlb_dat_o : 32'b0;

// Instantiate DTLB submodule
or1200_dmmu_tlb #(
    .OR1200_BIST(`OR1200_BIST)
) dmmu_tlb_inst (
    .clk(clk),
    .rst(rst),
    .dtlb_en(dtlb_en),
    .dtlb_spr_access(spr_cs),
    .spr_write(spr_write),
    .spr_addr(spr_addr),
    .spr_dat_i(spr_dat_i),
    .dtlb_dat_o(dtlb_dat_o),
    .dtlb_hit(dtlb_hit),
    .dtlb_ppn(dtlb_ppn),
    .dtlb_uwe(dtlb_uwe),
    .dtlb_ure(dtlb_ure),
    .dtlb_swe(dtlb_swe),
    .dtlb_sre(dtlb_sre),
    .dtlb_ci(dtlb_ci)
`ifdef OR1200_BIST
    ,
    .mbist_si_i(mbist_si_i),
    .mbist_so_o(mbist_so_o),
    .mbist_ctrl_i(mbist_ctrl_i)
`endif
);

`endif // OR1200_NO_DMMU

endmodule
