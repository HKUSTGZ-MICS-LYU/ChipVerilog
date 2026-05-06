// Generated from: Description/or1200_rf_description.txt
module or1200_rf(
    input         clk,
    input         rst,

    // Write i/f
    input         supv,
    input         wb_freeze,
    input  [4:0]  addrw,
    input  [31:0] dataw,
    input         we,
    input         flushpipe,

    // Read i/f
    input         id_freeze,
    input  [4:0]  addra,
    input  [4:0]  addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input         rda,
    input         rdb,

    // Debug (SPR window)
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`include "or1200_defines.v"

  // Detect SPR access to RF window
  wire spr_valid = spr_cs & (spr_addr[10:5] == `OR1200_SPR_RF);

  // Arbitration for write port
  wire [4:0]  rf_addrw = (spr_valid & spr_write) ? spr_addr[4:0] : addrw;
  wire [31:0] rf_dataw = (spr_valid & spr_write) ? spr_dat_i     : dataw;

  // Arbitration for read port A (SPR reads reuse port A)
  wire [4:0] rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
  wire [4:0] rf_addrb = addrb;

  // Read enables (kept for semantic gating; storage below is always readable)
  wire rf_ena = (rda & ~id_freeze) | spr_valid;
  wire rf_enb = (rdb & ~id_freeze) | spr_valid;
  wire rf_wr_req = (spr_valid & spr_write) | (we & ~wb_freeze);

  // Write allow latch (suppresses writes after flush when WB not frozen)
  reg rf_we_allow;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rf_we_allow <= 1'b1;
    end else if (!wb_freeze) begin
      rf_we_allow <= ~flushpipe;
    end
  end

  // Final write enable; block writes to r0 when not supervisor
  wire rf_we = rf_wr_req & rf_we_allow & (supv | (|rf_addrw));

  // Generic register array implementation (portable across configurations)
  reg [31:0] rf_mem [0:31];
  integer i;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      for (i = 0; i < 32; i = i + 1) rf_mem[i] <= 32'd0;
    end else if (rf_we) begin
      rf_mem[rf_addrw] <= rf_dataw;
    end
  end

  wire [31:0] from_rfa = rf_mem[rf_addra];
  wire [31:0] from_rfb = rf_mem[rf_addrb];

  assign spr_dat_o = from_rfa;

  // Operand retention during ID freeze
  reg [32:0] dataa_saved;
  reg [32:0] datab_saved;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      dataa_saved <= 33'd0;
      datab_saved <= 33'd0;
    end else begin
      if (id_freeze) begin
        if (!dataa_saved[32]) dataa_saved <= {1'b1, from_rfa};
        if (!datab_saved[32]) datab_saved <= {1'b1, from_rfb};
      end else begin
        dataa_saved <= 33'd0;
        datab_saved <= 33'd0;
      end
    end
  end

  assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
  assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;

  // rf_ena/rf_enb are retained for interface completeness
  wire _unused = rf_ena ^ rf_enb;

endmodule

