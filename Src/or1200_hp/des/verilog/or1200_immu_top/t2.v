`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_immu_top (
    input         clk,
    input         rst,

    // CPU i/f
    input         ic_en,
    input         immu_en,
    input         supv,
    input  [31:0] icpu_adr_i,
    input         icpu_cycstb_i,
    output [31:0] icpu_adr_o,
    output [3:0]  icpu_tag_o,
    output        icpu_rty_o,
    output        icpu_err_o,

    // SPR access
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

`ifdef OR1200_BIST
    input                                mbist_si_i,
    output                               mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH-1:0] mbist_ctrl_i,
`endif

    // QMEM i/f
    input         qmemimmu_rty_i,
    input         qmemimmu_err_i,
    input  [3:0]  qmemimmu_tag_i,
    output [31:0] qmemimmu_adr_o,
    output        qmemimmu_cycstb_o,
    output        qmemimmu_ci_o
);

`ifdef OR1200_NO_IMMU

    //--------------------------------------------------------------------------
    // Bypass: no IMMU
    //--------------------------------------------------------------------------
    assign icpu_adr_o       = icpu_adr_i;
    assign icpu_tag_o       = qmemimmu_tag_i;
    assign icpu_rty_o       = qmemimmu_rty_i;
    assign icpu_err_o       = qmemimmu_err_i;
    assign spr_dat_o        = 32'h0;
    assign qmemimmu_adr_o   = icpu_adr_i;
    assign qmemimmu_cycstb_o= icpu_cycstb_i;
    assign qmemimmu_ci_o    = `OR1200_IMMU_CI;
`ifdef OR1200_BIST
    assign mbist_so_o       = mbist_si_i;
`endif

`else

    //--------------------------------------------------------------------------
    // Internal wires / registers
    //--------------------------------------------------------------------------
    wire        itlb_spr_access;
    wire [31:13] itlb_ppn;
    wire        itlb_hit;
    wire        itlb_uxe;
    wire        itlb_sxe;
    wire [31:0] itlb_dat_o;
    wire        itlb_en;
    wire        itlb_ci;
    wire        itlb_done;
    wire        fault;
    wire        miss;
    wire        page_cross;

    reg  [31:0] icpu_adr_o_r;
    reg  [31:13] icpu_vpn_r;
    reg          itlb_en_r;
    reg          dis_spr_access;

    //--------------------------------------------------------------------------
    // Registered CPU-side address output (init to 0x100 after reset)
    //--------------------------------------------------------------------------
    assign icpu_adr_o = icpu_adr_o_r;

    always @(posedge clk or posedge rst) begin
        if (rst)
            icpu_adr_o_r <= 32'h0000_0100;
        else
            icpu_adr_o_r <= icpu_adr_i;
    end

    //--------------------------------------------------------------------------
    // VPN register: latch current VPN each cycle
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            icpu_vpn_r <= 19'h0;
        else
            icpu_vpn_r <= icpu_adr_i[31:13];
    end

    //--------------------------------------------------------------------------
    // page_cross: VPN changed since last cycle
    //--------------------------------------------------------------------------
    assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);

    //--------------------------------------------------------------------------
    // itlb_en: ITLB lookup enable (immu_en & cycstb)
    //--------------------------------------------------------------------------
    assign itlb_en = immu_en & icpu_cycstb_i & ~dis_spr_access;

    //--------------------------------------------------------------------------
    // itlb_en_r: one-cycle delayed itlb_en
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            itlb_en_r <= 1'b0;
        else
            itlb_en_r <= itlb_en;
    end

    //--------------------------------------------------------------------------
    // itlb_done: delayed lookup result is usable (no page cross)
    //--------------------------------------------------------------------------
    assign itlb_done = itlb_en_r & ~page_cross & ~dis_spr_access;

    //--------------------------------------------------------------------------
    // dis_spr_access: gate SPR access window
    //--------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            dis_spr_access <= 1'b0;
        else if (~qmemimmu_rty_i)
            dis_spr_access <= 1'b0;
        else if (spr_cs)
            dis_spr_access <= 1'b1;
    end

    assign itlb_spr_access = spr_cs & ~dis_spr_access;

    //--------------------------------------------------------------------------
    // Miss and fault detection (only when itlb_done)
    //--------------------------------------------------------------------------
    assign miss  = itlb_done & ~itlb_hit;
    assign fault = itlb_done & itlb_hit &
                   ( (~supv & ~itlb_uxe) |   // user mode, no user execute
                     ( supv & ~itlb_sxe) );  // supv mode, no supv execute

    //--------------------------------------------------------------------------
    // CPU-side error and tag
    //--------------------------------------------------------------------------
    assign icpu_err_o = miss | fault | qmemimmu_err_i;
    assign icpu_tag_o = miss  ? `OR1200_ITAG_TE :
                        fault ? `OR1200_ITAG_PE :
                                qmemimmu_tag_i;

    //--------------------------------------------------------------------------
    // CPU-side retry
    //--------------------------------------------------------------------------
    assign icpu_rty_o = qmemimmu_rty_i | (spr_cs & ~dis_spr_access);

    //--------------------------------------------------------------------------
    // Downstream address
    //--------------------------------------------------------------------------
    assign qmemimmu_adr_o = itlb_done ?
                            {itlb_ppn, icpu_adr_i[12:0]} :
                            {icpu_vpn_r, icpu_adr_i[12:0]};

    //--------------------------------------------------------------------------
    // Downstream request
    //--------------------------------------------------------------------------
    assign qmemimmu_cycstb_o = immu_en ?
        (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross) :
        (icpu_cycstb_i & ~page_cross);

    //--------------------------------------------------------------------------
    // Downstream cache-inhibit: fixed constant per spec
    //--------------------------------------------------------------------------
    assign qmemimmu_ci_o = `OR1200_IMMU_CI;

    //--------------------------------------------------------------------------
    // SPR read data
    //--------------------------------------------------------------------------
    assign spr_dat_o = spr_cs ? itlb_dat_o : 32'h0;

    //--------------------------------------------------------------------------
    // or1200_immu_tlb instantiation
    //--------------------------------------------------------------------------
    or1200_immu_tlb or1200_immu_tlb (
        .clk       (clk),
        .rst       (rst),
        .tlb_en    (itlb_en),
        .vaddr     (icpu_adr_i),
        .hit       (itlb_hit),
        .ppn       (itlb_ppn),
        .uxe       (itlb_uxe),
        .sxe       (itlb_sxe),
        .ci        (itlb_ci),
`ifdef OR1200_BIST
        .mbist_si_i   (mbist_si_i),
        .mbist_so_o   (mbist_so_o),
        .mbist_ctrl_i (mbist_ctrl_i),
`endif
        .spr_cs    (itlb_spr_access),
        .spr_write (spr_write),
        .spr_addr  (spr_addr),
        .spr_dat_i (spr_dat_i),
        .spr_dat_o (itlb_dat_o)
    );

`endif  // OR1200_NO_IMMU

endmodule