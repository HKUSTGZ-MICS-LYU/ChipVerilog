// Generated from: Description/or1200_sprs_description.txt
module or1200_sprs(
    input         clk,
    input         rst,

    // Internal CPU interface
    input         flagforw,
    input         flag_we,
    output        flag,
    input         cyforw,
    input         cy_we,
    output        carry,
    input  [31:0] addrbase,
    input  [15:0] addrofs,
    input  [31:0] dat_i,
    input  [3:0]  alu_op,
    input  [2:0]  branch_op,
    input  [31:0] epcr,
    input  [31:0] eear,
    input  [15:0] esr,
    input         except_started,
    output [31:0] to_wbmux,
    output        epcr_we,
    output        eear_we,
    output        esr_we,
    output        pc_we,
    output        sr_we,
    output [15:0] to_sr,
    output [15:0] sr,
    input  [31:0] spr_dat_cfgr,
    input  [31:0] spr_dat_rf,
    input  [31:0] spr_dat_npc,
    input  [31:0] spr_dat_ppc,
    input  [31:0] spr_dat_mac,

    // From/to other RISC units
    input  [31:0] spr_dat_pic,
    input  [31:0] spr_dat_tt,
    input  [31:0] spr_dat_pm,
    input  [31:0] spr_dat_dmmu,
    input  [31:0] spr_dat_immu,
    input  [31:0] spr_dat_du,
    output [31:0] spr_addr,
    output [31:0] spr_dat_o,
    output [31:0] spr_cs,
    output        spr_we,

    input  [31:0] du_addr,
    input  [31:0] du_dat_du,
    input         du_read,
    input         du_write,
    output [31:0] du_dat_cpu
);

`include "or1200_defines.v"

  // DU arbitration
  wire du_access = du_read | du_write;
  wire [3:0] sprs_op = du_write ? `OR1200_ALUOP_MTSR :
                       du_read  ? `OR1200_ALUOP_MFSR :
                                  alu_op;

  assign spr_addr  = du_access ? du_addr : (addrbase | {16'h0000, addrofs});
  assign spr_dat_o = (du_access & du_write) ? du_dat_du : dat_i;

  // du_dat_cpu behavior
  assign du_dat_cpu = du_write ? du_dat_du :
                      du_read  ? to_wbmux :
                                dat_i;

  wire write_spr = (sprs_op == `OR1200_ALUOP_MTSR);
  wire read_spr  = (sprs_op == `OR1200_ALUOP_MFSR);

  assign spr_we = du_write | write_spr;

  // One-hot group decode by spr_addr[15:11]
  wire [31:0] unqualified_cs = (32'h1 << spr_addr[15:11]);
  assign spr_cs = unqualified_cs & {32{read_spr | write_spr}};

  // System-group selects (spr_cs[0] must be asserted)
  wire sys_sel = spr_cs[0];

  wire cfgr_sel = sys_sel & (spr_addr[10:4] == 7'h00); // coarse region
  wire rf_sel   = sys_sel & (spr_addr[10:5] == `OR1200_SPR_RF);

  wire npc_sel  = sys_sel & (spr_addr[10:0] == `OR1200_SPR_NPC);
  wire sr_sel   = sys_sel & (spr_addr[10:0] == `OR1200_SPR_SR);
  wire ppc_sel  = sys_sel & (spr_addr[10:0] == `OR1200_SPR_PPC);
  wire epcr_sel = sys_sel & (spr_addr[10:0] == `OR1200_SPR_EPCR);
  wire eear_sel = sys_sel & (spr_addr[10:0] == `OR1200_SPR_EEAR);
  wire esr_sel  = sys_sel & (spr_addr[10:0] == `OR1200_SPR_ESR);

  assign pc_we   = write_spr & (npc_sel | ppc_sel);
  assign epcr_we = write_spr & epcr_sel;
  assign eear_we = write_spr & eear_sel;
  assign esr_we  = write_spr & esr_sel;

  // SR update enable combines multiple sources
  wire mtsr_to_sr = write_spr & sr_sel;
  wire rfe = (branch_op == `OR1200_BRANCHOP_RFE);
  assign sr_we = mtsr_to_sr | rfe | flag_we | cy_we;

  // Compose to_sr (does not include except_started handling)
  reg [15:0] to_sr_r;
  assign to_sr = to_sr_r;

  always @* begin
    // Default: hold current
    to_sr_r = sr;

    // [15:11]
    if (rfe) begin
      to_sr_r[15:11] = esr[15:11];
    end else if (mtsr_to_sr) begin
      to_sr_r[15] = 1'b1;
      to_sr_r[14:11] = spr_dat_o[14:11];
    end

    // CY bit [10]
    if (rfe) begin
      to_sr_r[10] = esr[10];
    end else if (cy_we) begin
      to_sr_r[10] = cyforw;
    end else if (mtsr_to_sr) begin
      to_sr_r[10] = spr_dat_o[10];
    end

    // FLAG bit [9]
    if (rfe) begin
      to_sr_r[9] = esr[9];
    end else if (flag_we) begin
      to_sr_r[9] = flagforw;
    end else if (mtsr_to_sr) begin
      to_sr_r[9] = spr_dat_o[9];
    end

    // [8:0]
    if (rfe) begin
      to_sr_r[8:0] = esr[8:0];
    end else if (mtsr_to_sr) begin
      to_sr_r[8:0] = spr_dat_o[8:0];
    end
  end

  // SR register with exception-entry priority
  reg [15:0] sr_r;
  assign sr = sr_r;
  assign flag  = sr_r[9];
  assign carry = sr_r[10];

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      // Implementation-defined reset SR: supervisor=1, EPH default, other bits 0; F=1 at LSB?
      sr_r <= {1'b1, {`OR1200_SR_WIDTH-2{1'b0}}, 1'b1};
    end else if (except_started) begin
      // On exception entry: set SM=1, clear TEE/IEE/DCE/ICE
      sr_r[0] <= 1'b1;
      sr_r[1] <= 1'b0;
      sr_r[2] <= 1'b0;
      sr_r[5] <= 1'b0;
      sr_r[6] <= 1'b0;
    end else if (sr_we) begin
      sr_r <= to_sr_r;
    end
  end

  // Read data muxing
  reg [31:0] sys_data;
  always @* begin
    sys_data = 32'h0000_0000;
    if (cfgr_sel) sys_data = spr_dat_cfgr;
    else if (rf_sel) sys_data = spr_dat_rf;
    else if (npc_sel) sys_data = spr_dat_npc;
    else if (ppc_sel) sys_data = spr_dat_ppc;
    else if (sr_sel)  sys_data = {16'h0000, sr_r};
    else if (epcr_sel) sys_data = epcr;
    else if (eear_sel) sys_data = eear;
    else if (esr_sel)  sys_data = {16'h0000, esr};
  end

  reg [31:0] to_wbmux_r;
  assign to_wbmux = to_wbmux_r;
  always @* begin
    if (write_spr) begin
      to_wbmux_r = 32'h0000_0000;
    end else if (read_spr) begin
      case (spr_addr[15:11])
        `OR1200_SPR_GROUP_TT:   to_wbmux_r = spr_dat_tt;
        `OR1200_SPR_GROUP_PIC:  to_wbmux_r = spr_dat_pic;
        `OR1200_SPR_GROUP_PM:   to_wbmux_r = spr_dat_pm;
        `OR1200_SPR_GROUP_DMMU: to_wbmux_r = spr_dat_dmmu;
        `OR1200_SPR_GROUP_IMMU: to_wbmux_r = spr_dat_immu;
        `OR1200_SPR_GROUP_MAC:  to_wbmux_r = spr_dat_mac;
        `OR1200_SPR_GROUP_DU:   to_wbmux_r = spr_dat_du;
        `OR1200_SPR_GROUP_SYS:  to_wbmux_r = sys_data;
        default:             to_wbmux_r = 32'h0000_0000;
      endcase
    end else begin
      to_wbmux_r = 32'h0000_0000;
    end
  end

endmodule
