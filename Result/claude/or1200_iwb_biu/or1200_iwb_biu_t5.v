// Generated from: Description/or1200_iwb_biu_description.txt
module or1200_iwb_biu(
    // RISC clock, reset and clock control
    input         clk,
    input         rst,
    input  [1:0]  clmode,

    // WISHBONE interface
    input         wb_clk_i,
    input         wb_rst_i,
    input         wb_ack_i,
    input         wb_err_i,
    input         wb_rty_i,
    input  [31:0] wb_dat_i,
    output        wb_cyc_o,
    output [31:0] wb_adr_o,
    output        wb_stb_o,
    output        wb_we_o,
    output [3:0]  wb_sel_o,
    output [31:0] wb_dat_o,
`ifdef OR1200_WB_CAB
    output        wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    output [2:0]  wb_cti_o,
    output [1:0]  wb_bte_o,
`endif

    // Internal RISC bus
    input  [31:0] biu_dat_i,
    input  [31:0] biu_adr_i,
    input         biu_cyc_i,
    input         biu_stb_i,
    input         biu_we_i,
    input  [3:0]  biu_sel_i,
    input         biu_cab_i,
    output [31:0] biu_dat_o,
    output        biu_ack_o,
    output        biu_err_o
);

`include "or1200_defines.v"

  // RISC clock domain: divider and repeated access ack pulse
  reg [1:0] valid_div;
  reg repeated_access_ack;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      valid_div <= 2'b00;
      repeated_access_ack <= 1'b0;
    end else begin
      valid_div <= valid_div + 2'b01;
      repeated_access_ack <= 1'b0;
      if (repeated_access && biu_cyc_i && biu_stb_i) begin
        repeated_access_ack <= 1'b1;
      end
    end
  end

  wire req_i = biu_cyc_i & biu_stb_i;

  // WB clock domain state
  reg previous_complete;
  reg aborted_r;
  reg [31:0] wb_dat_r; // saved last read data

`ifdef OR1200_WB_RETRY
  reg [3:0] retry_cntr;
  wire retry = wb_rty_i | (|retry_cntr);
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) retry_cntr <= 4'd0;
    else if (wb_rty_i) retry_cntr <= 4'hf;
    else if (|retry_cntr) retry_cntr <= retry_cntr - 4'd1;
  end
`else
  wire retry = 1'b0;
`endif

`ifdef OR1200_REGISTERED_OUTPUTS
  reg        wb_cyc_r, wb_stb_r, wb_we_r;
  reg [31:0] wb_adr_r, wb_dat_r_out;
  reg [3:0]  wb_sel_r;
`ifdef OR1200_WB_CAB
  reg wb_cab_r;
`endif
`ifdef OR1200_WB_B3
  reg [2:0] wb_cti_r;
  reg [1:0] burst_len;
`endif

  wire aborted = wb_stb_r & ~req_i & ~(wb_ack_i | wb_err_i);

  // repeated access compare uses registered wb_adr_o and previous_complete
  wire same_addr = (wb_adr_r == biu_adr_i);
  wire repeated_access = previous_complete & same_addr;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      wb_cyc_r <= 1'b0;
      wb_stb_r <= 1'b0;
      wb_we_r  <= 1'b0;
      wb_adr_r <= 32'd0;
      wb_dat_r_out <= 32'd0;
      wb_sel_r <= 4'd0;
`ifdef OR1200_WB_CAB
      wb_cab_r <= 1'b0;
`endif
`ifdef OR1200_WB_B3
      wb_cti_r <= 3'b000;
      burst_len <= 2'b11;
`endif
    end else begin
      // Issue transaction unless suppressed
      if (aborted & ~wb_ack_i) begin
        wb_cyc_r <= 1'b1;
        wb_stb_r <= 1'b1;
        wb_we_r  <= wb_we_r;
      end else if (req_i & ~wb_ack_i & ~retry & ~repeated_access) begin
`ifdef OR1200_NO_BURSTS
        wb_cyc_r <= 1'b1;
`else
        wb_cyc_r <= biu_cyc_i | (biu_cab_i & ~retry);
`endif
        wb_stb_r <= 1'b1;
        wb_we_r  <= biu_we_i;
      end else begin
        wb_cyc_r <= 1'b0;
        wb_stb_r <= 1'b0;
        wb_we_r  <= 1'b0;
      end

      if (req_i & ~wb_ack_i & ~aborted & ~wb_stb_r) begin
        wb_adr_r <= biu_adr_i;
      end

      if (req_i & ~wb_ack_i & ~aborted) begin
        wb_dat_r_out <= biu_dat_i;
      end

      wb_sel_r <= biu_sel_i;

`ifdef OR1200_WB_CAB
      wb_cab_r <= biu_cab_i;
`endif

`ifdef OR1200_WB_B3
      assign wb_bte_o = 2'b01;
      if (!biu_cab_i) burst_len <= 2'b11;
      else if (biu_cab_i && (burst_len != 2'b00) && wb_ack_i) burst_len <= burst_len - 2'b01;
`ifdef OR1200_NO_BURSTS
      wb_cti_r <= 3'b111;
`else
      if (!biu_cab_i) wb_cti_r <= 3'b000;
      else if (biu_cab_i && burst_len[1]) wb_cti_r <= 3'b010;
      else if (biu_cab_i && wb_ack_i) wb_cti_r <= 3'b111;
`endif
`endif
    end
  end

  assign wb_cyc_o = wb_cyc_r;
  assign wb_stb_o = wb_stb_r;
  assign wb_we_o  = wb_we_r;
  assign wb_adr_o = wb_adr_r;
  assign wb_dat_o = wb_dat_r_out;
  assign wb_sel_o = wb_sel_r;
`ifdef OR1200_WB_CAB
  assign wb_cab_o = wb_cab_r;
`endif
`ifdef OR1200_WB_B3
  assign wb_cti_o = wb_cti_r;
  assign wb_bte_o = 2'b01;
`endif
`else
  // Non-registered outputs
  assign wb_adr_o = biu_adr_i;
  assign wb_dat_o = biu_dat_i;
  assign wb_sel_o = biu_sel_i;
  assign wb_we_o  = req_i & biu_we_i;
  assign wb_stb_o = req_i;
`ifdef OR1200_NO_BURSTS
  assign wb_cyc_o = biu_cyc_i & ~retry;
`else
  assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif
`ifdef OR1200_WB_CAB
  assign wb_cab_o = biu_cab_i;
`endif
`ifdef OR1200_WB_B3
  assign wb_cti_o = 3'b000;
  assign wb_bte_o = 2'b01;
`endif

  // repeated-access uses current wb_adr_o (biu_adr_i) in this mode
  wire same_addr = (wb_adr_o == biu_adr_i);
  wire repeated_access = previous_complete & same_addr;
  wire aborted = wb_stb_o & ~req_i & ~(wb_ack_i | wb_err_i);
`endif

  // previous_complete, aborted_r, wb_dat_r
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      previous_complete <= 1'b1;
      aborted_r <= 1'b0;
      wb_dat_r <= 32'd0;
    end else begin
      if (wb_ack_i & biu_cyc_i & biu_stb_i) begin
        previous_complete <= 1'b1;
        wb_dat_r <= wb_dat_i;
      end else if (req_i & ~wb_ack_i & ~aborted & ~wb_stb_o) begin
        previous_complete <= 1'b0;
      end

      if (wb_ack_i | wb_err_i) aborted_r <= 1'b0;
      else if (aborted) aborted_r <= 1'b1;
    end
  end

  // Input return path
`ifdef OR1200_REGISTERED_INPUTS
  reg [31:0] biu_dat_r_in;
  reg long_ack_r, long_err_r;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      biu_dat_r_in <= 32'd0;
      long_ack_r <= 1'b0;
      long_err_r <= 1'b0;
    end else begin
      if (wb_ack_i) biu_dat_r_in <= wb_dat_i;
      long_ack_r <= wb_ack_i & ~aborted;
      long_err_r <= wb_err_i & ~aborted;
    end
  end
  assign biu_dat_o = biu_dat_r_in;
  wire long_ack_o = long_ack_r;
  wire long_err_o = long_err_r;
`else
  wire long_ack_o = wb_ack_i;
  wire long_err_o = wb_err_i & ~aborted_r;
  assign biu_dat_o = repeated_access_ack ? wb_dat_r : wb_dat_i;
`endif

  // Ack/err generation (with repeated-access)
  wire ack_src = (repeated_access_ack | long_ack_o) & ~aborted_r;
  wire err_src = long_err_o;

`ifdef OR1200_CLKDIV_4_SUPPORTED
  wire ack_div4 = (clmode == 2'b11) ? (ack_src & (valid_div == 2'b00)) : ack_src;
  wire err_div4 = (clmode == 2'b11) ? (err_src & (valid_div == 2'b00)) : err_src;
`else
  wire ack_div4 = ack_src;
  wire err_div4 = err_src;
`endif

`ifdef OR1200_CLKDIV_2_SUPPORTED
  wire ack_div2 = (clmode == 2'b01) ? (ack_div4 & (valid_div[0] == 1'b0)) : ack_div4;
  wire err_div2 = (clmode == 2'b01) ? (err_div4 & (valid_div[0] == 1'b0)) : err_div4;
`else
  wire ack_div2 = ack_div4;
  wire err_div2 = err_div4;
`endif

  assign biu_ack_o = ack_div2;
  assign biu_err_o = err_div2;

endmodule
