module i2c_master_top #(parameter ARST_LVL = 1'b0) (
  input wb_clk_i,
  input wb_rst_i,
  input arst_i,
  input [2:0] wb_adr_i,
  input [7:0] wb_dat_i,
  output reg [7:0] wb_dat_o,
  input wb_we_i,
  input wb_stb_i,
  input wb_cyc_i,
  output reg wb_ack_o,
  output reg wb_inta_o,
  input scl_pad_i,
  input sda_pad_i,
  output scl_pad_o,
  output scl_padoen_o,
  output sda_pad_o,
  output sda_padoen_o
);

  wire rst_i = arst_i ^ ARST_LVL;
  reg [15:0] prer;
  reg [7:0] ctr;
  reg [7:0] txr;
  reg [7:0] cr;
  reg rxack;
  reg tip;
  reg irq_flag;
  reg al;

  wire core_en = ctr[7];
  wire ien = ctr[6];
  wire wb_wacc = wb_we_i & wb_ack_o;

  wire done;
  wire irxack;
  wire [7:0] rxr_wire;
  wire i2c_busy;
  wire i2c_al_wire;

  wire iack_int = wb_wacc && (wb_adr_i == 3'b100) && core_en && wb_dat_i[0];

  i2c_master_byte_ctrl u_byte_ctrl (
    .clk(wb_clk_i),
    .nReset(rst_i),
    .ena(core_en),
    .clk_cnt(prer),
    .start(cr[7]),
    .stop(cr[6]),
    .read(cr[5]),
    .write(cr[4]),
    .ack_in(cr[3]),
    .din(txr),
    .cmd_ack(done),
    .al(),
    .irxack(irxack),
    .rxr(rxr_wire),
    .i2c_busy(i2c_busy),
    .i2c_al(i2c_al_wire),
    .scl_i(scl_pad_i),
    .sda_i(sda_pad_i),
    .scl_o(scl_pad_o),
    .scl_oen(scl_padoen_o),
    .sda_o(sda_pad_o),
    .sda_oen(sda_padoen_o)
  );

  always @(posedge wb_clk_i or negedge rst_i) begin
    if (!rst_i) begin
      prer <= 16'hffff;
      ctr <= 8'b0;
      txr <= 8'b0;
      cr <= 8'b0;
      al <= 1'b0;
      rxack <= 1'b0;
      tip <= 1'b0;
      irq_flag <= 1'b0;
      wb_ack_o <= 1'b0;
      wb_inta_o <= 1'b0;
      wb_dat_o <= 8'b0;
    end else if (wb_rst_i) begin
      prer <= 16'hffff;
      ctr <= 8'b0;
      txr <= 8'b0;
      cr <= 8'b0;
      al <= 1'b0;
      rxack <= 1'b0;
      tip <= 1'b0;
      irq_flag <= 1'b0;
      wb_ack_o <= 1'b0;
      wb_inta_o <= 1'b0;
      wb_dat_o <= 8'b0;
    end else begin
      wb_ack_o <= wb_cyc_i & wb_stb_i & ~wb_ack_o;

      if (done || i2c_al_wire) begin
        cr[7:4] <= 4'b0;
        cr[2:1] <= 2'b0;
        cr[0]   <= 1'b0;
      end else if (wb_wacc && (wb_adr_i == 3'b100) && core_en) begin
        cr <= wb_dat_i;
      end else begin
        cr <= cr;
      end

      if (iack_int)
        irq_flag <= 1'b0;
      else if (done || i2c_al_wire)
        irq_flag <= 1'b1;
      else
        irq_flag <= irq_flag;

      rxack <= irxack;
      tip   <= cr[5] | cr[4];
      al   <= i2c_al_wire | (al & ~cr[7]);
      wb_inta_o <= irq_flag & ien;

      case (wb_adr_i)
        3'b000: wb_dat_o <= prer[7:0];
        3'b001: wb_dat_o <= prer[15:8];
        3'b010: wb_dat_o <= ctr;
        3'b011: wb_dat_o <= rxr_wire;
        3'b100: wb_dat_o <= {rxack, i2c_busy, al, 3'b000, tip, irq_flag};
        3'b101: wb_dat_o <= txr;
        3'b110: wb_dat_o <= cr;
        3'b111: wb_dat_o <= 8'b0;
        default: wb_dat_o <= 8'b0;
      endcase
    end
  end

endmodule
