module or1200_immu_top (
    // Rst and clk
    input clk,
    input rst,

    // CPU i/f
    input ic_en,
    input immu_en,
    input supv,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    output [31:0] icpu_adr_o,
    output [3:0] icpu_tag_o,
    output icpu_rty_o,
    output icpu_err_o,

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

    // QMEM i/f
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    output [31:0] qmemimmu_adr_o,
    output qmemimmu_cycstb_o,
    output qmemimmu_ci_o
);

  // ---------------------------------------------------------------
  //  Constants
  // ---------------------------------------------------------------
  localparam [3:0] TAG_TLB_MISS   = 4'b0001;
  localparam [3:0] TAG_PAGE_FAULT = 4'b0010;
  localparam [3:0] TAG_DEFAULT    = 4'b0000;
  localparam CI_CONST             = 1'b0;  // Architecturally defined cache-inhibit constant

  // ---------------------------------------------------------------
  //  Internal wires and regs
  // ---------------------------------------------------------------
  wire [31:0] itlb_dat_o;
  wire [31:13] itlb_ppn;
  wire itlb_hit;
  wire itlb_uxe;
  wire itlb_sxe;
  wire itlb_ci;

  reg [31:0] icpu_adr_o;
  reg [31:13] icpu_vpn_r;
  reg itlb_en_r;
  reg dis_spr_access;

  wire itlb_spr_access;
  wire itlb_en;
  wire itlb_done;
  wire miss;
  wire fault;
  wire page_cross;

  // ---------------------------------------------------------------
  //  Registered CPU address output
  // ---------------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      icpu_adr_o <= 32'h0000_0100;
    end else begin
      icpu_adr_o <= icpu_adr_i;
    end
  end

  // ---------------------------------------------------------------
  //  Registered VPN
  // ---------------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      icpu_vpn_r <= 19'b0;
    end else begin
      icpu_vpn_r <= icpu_adr_i[31:13];
    end
  end

  // ---------------------------------------------------------------
  //  Page cross detection
  // ---------------------------------------------------------------
  assign page_cross = (icpu_adr_i[31:13] != icpu_vpn_r);

  // ---------------------------------------------------------------
  //  ITLB enable generation
  // ---------------------------------------------------------------
  assign itlb_en = immu_en & icpu_cycstb_i;

  // ---------------------------------------------------------------
  //  Registered ITLB enable (delayed by one cycle)
  // ---------------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      itlb_en_r <= 1'b0;
    end else begin
      // Suppress during SPR access
      itlb_en_r <= itlb_en & ~dis_spr_access;
    end
  end

  // ---------------------------------------------------------------
  //  ITLB lookup done condition
  // ---------------------------------------------------------------
  assign itlb_done = itlb_en_r & ~page_cross;

  // ---------------------------------------------------------------
  //  TLB miss and page fault detection
  // ---------------------------------------------------------------
  assign miss  = itlb_done & ~itlb_hit;
  assign fault = itlb_done & itlb_hit &
                 (( supv & ~itlb_sxe) |
                  (~supv & ~itlb_uxe));

  // ---------------------------------------------------------------
  //  Downstream address generation
  // ---------------------------------------------------------------
  assign qmemimmu_adr_o = itlb_done ?
                          {itlb_ppn, icpu_adr_i[12:0]} :
                          {icpu_vpn_r, icpu_adr_i[12:0]};

  // ---------------------------------------------------------------
  //  Downstream cycle/strobe generation
  // ---------------------------------------------------------------
  assign qmemimmu_cycstb_o = immu_en ?
                             (icpu_cycstb_i & itlb_done & ~miss & ~fault & ~page_cross) :
                             (icpu_cycstb_i & ~page_cross);

  // ---------------------------------------------------------------
  //  Downstream cache-inhibit output (fixed constant)
  // ---------------------------------------------------------------
  assign qmemimmu_ci_o = CI_CONST;

  // ---------------------------------------------------------------
  //  CPU tag / error / retry multiplexing
  // ---------------------------------------------------------------
  assign icpu_tag_o = miss  ? TAG_TLB_MISS   :
                      fault ? TAG_PAGE_FAULT :
                              qmemimmu_tag_i;

  assign icpu_err_o = miss | fault | qmemimmu_err_i;

  assign icpu_rty_o = qmemimmu_rty_i | dis_spr_access;

  // ---------------------------------------------------------------
  //  SPR access control
  // ---------------------------------------------------------------
  assign itlb_spr_access = spr_cs & ~dis_spr_access;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      dis_spr_access <= 1'b0;
    end else if (~icpu_rty_o) begin  // retry released
      dis_spr_access <= 1'b0;
    end else if (itlb_spr_access) begin
      dis_spr_access <= 1'b1;
    end
  end

  // ---------------------------------------------------------------
  //  SPR read data
  // ---------------------------------------------------------------
  assign spr_dat_o = (spr_cs & ~spr_write) ? itlb_dat_o : 32'b0;

  // ---------------------------------------------------------------
  //  ITLB instantiation (normal IMMU build)
  // ---------------------------------------------------------------
  or1200_immu_itlb u_immu_itlb (
      .clk      (clk),
      .rst      (rst),
      .en       (itlb_en_r),
      .vpn      (icpu_adr_i[31:13]),
      .hit      (itlb_hit),
      .ppn      (itlb_ppn),
      .uxe      (itlb_uxe),
      .sxe      (itlb_sxe),
      .ci       (itlb_ci),
      .spr_cs   (itlb_spr_access),
      .spr_write(spr_write),
      .spr_addr (spr_addr),
      .spr_dat_i(spr_dat_i),
      .spr_dat_o(itlb_dat_o)
`ifdef OR1200_BIST
      ,
      .mbist_si_i  (mbist_si_i),
      .mbist_so_o  (mbist_so_o),
      .mbist_ctrl_i(mbist_ctrl_i)
`endif
  );

endmodule
module or1200_immu_itlb (
    input clk,
    input rst,
    input en,
    input [31:13] vpn,
    output hit,
    output [31:13] ppn,
    output uxe,
    output sxe,
    output ci,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
`ifdef OR1200_BIST
    ,
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i
`endif
);
  // Placeholder ITLB implementation.
  // In a real design this would contain CAM, RAM, and control logic.
  // For the purpose of this top-level integration, we provide stub behavior
  // that is sufficient for simulation of the surrounding logic.

  // Simple direct-mapped-like stub: one entry.
  reg        entry_v;
  reg [31:13] entry_vpn;
  reg [31:13] entry_ppn;
  reg        entry_uxe;
  reg        entry_sxe;
  reg        entry_ci;

  wire match;

  // Lookup
  assign match = entry_v && (entry_vpn == vpn);
  assign hit   = en && match;
  assign ppn   = entry_ppn;
  assign uxe   = entry_uxe;
  assign sxe   = entry_sxe;
  assign ci    = entry_ci;

  // SPR read
  assign spr_dat_o = spr_cs ? {entry_v, 11'b0, entry_vpn, entry_ppn, entry_uxe, entry_sxe, entry_ci, 3'b0} : 32'b0;

  // SPR write / reset
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      entry_v   <= 1'b0;
      entry_vpn <= 19'b0;
      entry_ppn <= 19'b0;
      entry_uxe <= 1'b0;
      entry_sxe <= 1'b0;
      entry_ci  <= 1'b0;
    end else if (spr_cs && spr_write) begin
      // Simple SPR write: unpack fields from spr_dat_i
      entry_v   <= spr_dat_i[31];
      entry_vpn <= spr_dat_i[30:12];
      entry_ppn <= spr_dat_i[11:0] ? 19'b0 : 19'b0; // placeholder
      // Real implementation would decode properly
      entry_uxe <= spr_dat_i[0];
      entry_sxe <= spr_dat_i[1];
      entry_ci  <= spr_dat_i[2];
    end
  end

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i; // bypass
`endif

endmodule
