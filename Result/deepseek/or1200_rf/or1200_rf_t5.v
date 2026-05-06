module or1200_rf (
    input clk,
    input rst,
    input supv,
    input wb_freeze,
    input [4:0] addrw,
    input [31:0] dataw,
    input we,
    input flushpipe,
    input id_freeze,
    input [4:0] addra,
    input [4:0] addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input rda,
    input rdb,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

  localparam SPR_RF_BASE = 6'h00;

  wire [31:0] from_rfa;
  wire [31:0] from_rfb;
  reg [32:0] dataa_saved;
  reg [32:0] datab_saved;
  wire [4:0] rf_addra;
  wire [4:0] rf_addrw;
  wire [31:0] rf_dataw;
  wire rf_we;
  wire spr_valid;
  wire rf_ena;
  wire rf_enb;
  reg rf_we_allow;
  wire [31:0] from_rfa_int;
  wire [31:0] from_rfb_int;
  reg [4:0] rf_addra_reg;
  reg [4:0] rf_addrb_reg;

  assign spr_valid = spr_cs & (spr_addr[10:5] == SPR_RF_BASE);

  assign rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
  assign rf_addrw = (spr_valid & spr_write) ? spr_addr[4:0] : addrw;
  assign rf_dataw = (spr_valid & spr_write) ? spr_dat_i : dataw;

  assign rf_ena = (rda & ~id_freeze) | spr_valid;
  assign rf_enb = (rdb & ~id_freeze) | spr_valid;

  assign rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze)) & rf_we_allow & (supv | (|rf_addrw));

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      rf_we_allow <= 1'b1;
      dataa_saved <= 33'd0;
      datab_saved <= 33'd0;
    end else begin
      if (!wb_freeze) rf_we_allow <= ~flushpipe;
      if (id_freeze) begin
        if (!dataa_saved[32]) dataa_saved <= {1'b1, from_rfa};
        if (!datab_saved[32]) datab_saved <= {1'b1, from_rfb};
      end else begin
        dataa_saved <= 33'd0;
        datab_saved <= 33'd0;
      end
    end
  end

  generate
    ifdef OR1200_RFRAM_TWOPORT
      or1200_tpram_32x32 ram_a (.clk(clk), .we(rf_we), .en(rf_ena), .addr(rf_addra), .din(rf_dataw), .dout(from_rfa));
      or1200_tpram_32x32 ram_b (.clk(clk), .we(rf_we), .en(rf_enb), .addr(rf_addrb), .din(rf_dataw), .dout(from_rfb));
    elsif OR1200_RFRAM_DUALPORT
      or1200_dpram_32x32 ram_a (.clk(clk), .we(rf_we), .en(rf_ena), .addr(rf_addra), .din(rf_dataw), .dout(from_rfa));
      or1200_dpram_32x32 ram_b (.clk(clk), .we(rf_we), .en(rf_enb), .addr(rf_addrb), .din(rf_dataw), .dout(from_rfb));
    elsif OR1200_RFRAM_GENERIC
      or1200_rfram_generic rf_ram (.clk(clk), .rst(rst), .addra(rf_addra), .addrb(rf_addrb), .addrw(rf_addrw), .dataw(rf_dataw), .we(rf_we), .ena(rf_ena), .enb(rf_enb), .dataa(from_rfa), .datab(from_rfb));
    elsif OR1200_RAM_MODELS_VIRTEX
      always @(posedge clk or posedge rst) begin
        if (rst) begin
          rf_addra_reg <= 5'd0;
          rf_addrb_reg <= 5'd0;
        end else begin
          rf_addra_reg <= rf_addra;
          rf_addrb_reg <= rf_addrb;
        end
      end

      rf_sub ram_a (.clk(clk), .we(rf_we), .en(rf_ena), .addr(rf_addra_reg), .din(rf_dataw), .dout(from_rfa_int));
      rf_sub ram_b (.clk(clk), .we(rf_we), .en(rf_enb), .addr(rf_addrb_reg), .din(rf_dataw), .dout(from_rfb_int));

      assign from_rfa = (rf_addra_reg == 5'h00) ? 32'h00000000 : from_rfa_int;
      assign from_rfb = (rf_addrb_reg == 5'h00) ? 32'h00000000 : from_rfb_int;
    else
      initial begin
        $display("Define RFRAM type.");
        $finish;
      end
  endgenerate

  assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
  assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
  assign spr_dat_o = from_rfa;

endmodule
