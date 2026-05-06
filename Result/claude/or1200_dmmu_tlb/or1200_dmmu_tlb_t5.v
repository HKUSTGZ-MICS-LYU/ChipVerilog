// Generated from: Description/or1200_dmmu_tlb_description.txt
module or1200_dmmu_tlb(
    input         clk,
    input         rst,
    input         tlb_en,
    input  [31:0] vaddr,
    output        hit,
    output [31:13] ppn,
    output        uwe,
    output        ure,
    output        swe,
    output        sre,
    output        ci,
`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`include "or1200_defines.v"

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i;
  wire _unused_bist = |mbist_ctrl_i;
`endif

  // Index selection: SPR has priority when spr_cs asserted
  wire [5:0] tlb_index = spr_cs ? spr_addr[5:0] : vaddr[18:13];

  // Match RAM: {vpn[31:19], v}
  reg [13:0] mr_ram [0:63];
  reg [23:0] tr_ram [0:63];
  reg [13:0] mr_dout;
  reg [23:0] tr_dout;

  wire tlb_mr_en = tlb_en | (spr_cs & ~spr_addr[7]);
  wire tlb_tr_en = tlb_en | (spr_cs &  spr_addr[7]);
  wire tlb_mr_we = spr_cs & spr_write & ~spr_addr[7];
  wire tlb_tr_we = spr_cs & spr_write &  spr_addr[7];

  always @(posedge clk) begin
    if (tlb_mr_en) begin
      mr_dout <= mr_ram[tlb_index];
      if (tlb_mr_we) mr_ram[tlb_index] <= {spr_dat_i[31:19], spr_dat_i[0]};
    end
    if (tlb_tr_en) begin
      tr_dout <= tr_ram[tlb_index];
      if (tlb_tr_we) tr_ram[tlb_index] <= {spr_dat_i[31:13], spr_dat_i[9], spr_dat_i[8], spr_dat_i[7], spr_dat_i[6], spr_dat_i[1]};
    end
  end

  wire [12:0] vpn = mr_dout[13:1];
  wire v = mr_dout[0];

  assign ppn = tr_dout[23:5];
  assign swe = tr_dout[4];
  assign sre = tr_dout[3];
  assign uwe = tr_dout[2];
  assign ure = tr_dout[1];
  assign ci  = tr_dout[0];

  assign hit = (vpn == vaddr[31:19]) & v;

  reg [31:0] spr_dat_r;
  assign spr_dat_o = spr_dat_r;
  always @* begin
    spr_dat_r = 32'h0;
    if (spr_cs && !spr_write && !spr_addr[7]) begin
      // Match register readback
      spr_dat_r[31:19] = vpn;
      spr_dat_r[`OR1200_DTLB_INDXW-1:0] = tlb_index & {`OR1200_DTLB_INDXW{v}};
      spr_dat_r[0] = v;
    end else if (spr_cs && !spr_write && spr_addr[7]) begin
      // Translate register readback (ci at bit 1, bit0 hardwired 0)
      spr_dat_r[31:13] = ppn;
      spr_dat_r[9] = swe;
      spr_dat_r[8] = sre;
      spr_dat_r[7] = uwe;
      spr_dat_r[6] = ure;
      spr_dat_r[1] = ci;
      spr_dat_r[0] = 1'b0;
    end
  end

  wire _unused_rst = rst;
endmodule
