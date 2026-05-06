module or1200_wb_biu (
    clk,
    rst,
    clmode,
    wb_clk_i,
    wb_rst_i,
    wb_ack_i,
    wb_err_i,
    wb_rty_i,
    wb_dat_i,
    wb_cyc_o,
    wb_adr_o,
    wb_stb_o,
    wb_we_o,
    wb_sel_o,
    wb_dat_o,
`ifdef OR1200_WB_CAB
    wb_cab_o,
`endif
`ifdef OR1200_WB_B3
    wb_cti_o,
    wb_bte_o,
`endif
    biu_dat_i,
    biu_adr_i,
    biu_cyc_i,
    biu_stb_i,
    biu_we_i,
    biu_sel_i,
    biu_cab_i,
    biu_dat_o,
    biu_ack_o,
    biu_err_o
);

  input clk;
  input rst;
  input [1:0] clmode;

  input wb_clk_i;
  input wb_rst_i;
  input wb_ack_i;
  input wb_err_i;
  input wb_rty_i;
  input [31:0] wb_dat_i;

  output wb_cyc_o;
  output [31:0] wb_adr_o;
  output wb_stb_o;
  output wb_we_o;
  output [3:0] wb_sel_o;
  output [31:0] wb_dat_o;

`ifdef OR1200_WB_CAB
  output wb_cab_o;
`endif

`ifdef OR1200_WB_B3
  output [2:0] wb_cti_o;
  output [1:0] wb_bte_o;
`endif

  input [31:0] biu_dat_i;
  input [31:0] biu_adr_i;
  input biu_cyc_i;
  input biu_stb_i;
  input biu_we_i;
  input [3:0] biu_sel_i;
  input biu_cab_i;

  output [31:0] biu_dat_o;
  output biu_ack_o;
  output biu_err_o;

  wire [31:0] biu_dat_o;
  wire biu_ack_o;
  wire biu_err_o;

  wire wb_cyc_o;
  wire [31:0] wb_adr_o;
  wire wb_stb_o;
  wire wb_we_o;
  wire [3:0] wb_sel_o;
  wire [31:0] wb_dat_o;

`ifdef OR1200_WB_CAB
  wire wb_cab_o;
`endif

`ifdef OR1200_WB_B3
  wire [2:0] wb_cti_o;
  wire [1:0] wb_bte_o;
`endif

  // ------------------------------------------------------------
  // RISC clock domain: valid_div
  // ------------------------------------------------------------
  reg [1:0] valid_div;
  always @(posedge clk or posedge rst) begin
    if (rst) valid_div <= 2'b00;
    else valid_div <= valid_div + 2'b01;
  end

  // ------------------------------------------------------------
  // Wishbone clock domain: retry counter
  // ------------------------------------------------------------
`ifdef OR1200_WB_RETRY
  reg [3:0] retry_cntr;
  wire retry;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) retry_cntr <= 4'h0;
    else if (wb_rty_i) retry_cntr <= 4'hF;
    else if (|retry_cntr) retry_cntr <= retry_cntr - 4'h1;
  end
  assign retry = wb_rty_i | (|retry_cntr);
`else
  wire retry;
  assign retry = 1'b0;
`endif

  // ------------------------------------------------------------
  // Abort logic
  // ------------------------------------------------------------
  wire aborted;
  reg  aborted_r;

  // The current wb_stb_o is needed for abort detection. Pre-declare a wire used
  // both for output and for abort detection.
  wire wb_stb_o_int;

  assign aborted = wb_stb_o_int & ~(biu_cyc_i & biu_stb_i) & ~wb_ack_i & ~wb_err_i;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) aborted_r <= 1'b0;
    else if (wb_ack_i | wb_err_i) aborted_r <= 1'b0;
    else if (aborted) aborted_r <= 1'b0;
    else if (aborted) aborted_r <= 1'b1;
  end

  // ------------------------------------------------------------
  // Wishbone output generation
  // ------------------------------------------------------------
`ifdef OR1200_REGISTERED_OUTPUTS

  // Registered output path
  reg        wb_cyc_o_reg;
  reg [31:0] wb_adr_o_reg;
  reg        wb_stb_o_reg;
  reg        wb_we_o_reg;
  reg  [3:0] wb_sel_o_reg;
  reg [31:0] wb_dat_o_reg;
`ifdef OR1200_WB_CAB
  reg wb_cab_o_reg;
`endif

  wire new_req;
  assign new_req = biu_cyc_i & biu_stb_i & ~wb_ack_i & ~aborted;

  // wb_adr_o
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_adr_o_reg <= 32'h0;
    else if (new_req & ~wb_stb_o_reg) wb_adr_o_reg <= biu_adr_i;
  end

  // wb_dat_o
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_dat_o_reg <= 32'h0;
    else if (new_req) wb_dat_o_reg <= biu_dat_i;
  end

  // wb_sel_o
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_sel_o_reg <= 4'h0;
    else wb_sel_o_reg <= biu_sel_i;
  end

  // wb_we_o
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_we_o_reg <= 1'b0;
    else if (new_req) wb_we_o_reg <= biu_we_i;
    else if (aborted & ~wb_ack_i) wb_we_o_reg <= wb_we_o_reg;
  end

  // wb_stb_o
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_stb_o_reg <= 1'b0;
    else if (new_req & ~retry) wb_stb_o_reg <= 1'b1;
    else if (wb_ack_i) wb_stb_o_reg <= 1'b0;
    else if (aborted & ~wb_ack_i) wb_stb_o_reg <= wb_stb_o_reg;
    else if (~(biu_cyc_i & biu_stb_i) & ~aborted) wb_stb_o_reg <= 1'b0;
  end

  // wb_cyc_o
`ifdef OR1200_NO_BURSTS
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_cyc_o_reg <= 1'b0;
    else if (new_req & ~retry) wb_cyc_o_reg <= 1'b1;
    else if (wb_ack_i & ~(biu_cyc_i & biu_stb_i)) wb_cyc_o_reg <= 1'b0;
    else if (aborted & ~wb_ack_i) wb_cyc_o_reg <= wb_cyc_o_reg;
    else if (~(biu_cyc_i & biu_stb_i) & ~aborted) wb_cyc_o_reg <= 1'b0;
  end
`else
  // bursts allowed
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_cyc_o_reg <= 1'b0;
    else if (new_req & ~retry) wb_cyc_o_reg <= 1'b1;
    else if (wb_ack_i & ~(biu_cyc_i & biu_stb_i)) wb_cyc_o_reg <= 1'b0;
    else if (aborted & ~wb_ack_i) wb_cyc_o_reg <= wb_cyc_o_reg;
    else if (~(biu_cyc_i | biu_cab_i) & ~aborted) wb_cyc_o_reg <= 1'b0;
  end
`endif

`ifdef OR1200_WB_CAB
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_cab_o_reg <= 1'b0;
    else wb_cab_o_reg <= biu_cab_i;
  end
  assign wb_cab_o = wb_cab_o_reg;
`endif

  assign wb_cyc_o = wb_cyc_o_reg;
  assign wb_adr_o = wb_adr_o_reg;
  assign wb_stb_o_int = wb_stb_o_reg;
  assign wb_stb_o = wb_stb_o_reg;
  assign wb_we_o  = wb_we_o_reg;
  assign wb_sel_o = wb_sel_o_reg;
  assign wb_dat_o = wb_dat_o_reg;

`else

  // Combinational output path
  assign wb_adr_o = biu_adr_i;
  assign wb_dat_o = biu_dat_i;
  assign wb_sel_o = biu_sel_i;
  assign wb_we_o  = biu_cyc_i & biu_stb_i & biu_we_i;
  assign wb_stb_o_int = biu_cyc_i & biu_stb_i;
  assign wb_stb_o = wb_stb_o_int;

`ifdef OR1200_NO_BURSTS
  assign wb_cyc_o = biu_cyc_i & ~retry;
`else
  assign wb_cyc_o = biu_cyc_i | (biu_cab_i & ~retry);
`endif

`ifdef OR1200_WB_CAB
  assign wb_cab_o = biu_cab_i;
`endif

`endif

  // ------------------------------------------------------------
  // Long acknowledge / error generation
  // ------------------------------------------------------------
  wire long_ack_o;
  wire long_err_o;

`ifdef OR1200_REGISTERED_INPUTS

  reg long_ack_reg;
  reg long_err_reg;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) begin
      long_ack_reg <= 1'b0;
      long_err_reg <= 1'b0;
    end else begin
      long_ack_reg <= wb_ack_i & ~aborted;
      long_err_reg <= wb_err_i & ~aborted;
    end
  end

  assign long_ack_o = long_ack_reg;
  assign long_err_o = long_err_reg;

`else

  assign long_ack_o = wb_ack_i & ~aborted_r;
  assign long_err_o = wb_err_i & ~aborted_r;

`endif

  // ------------------------------------------------------------
  // Read data path
  // ------------------------------------------------------------
`ifdef OR1200_REGISTERED_INPUTS
  reg [31:0] biu_dat_o_reg;
  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) biu_dat_o_reg <= 32'h0;
    else if (wb_ack_i) biu_dat_o_reg <= wb_dat_i;
  end
  assign biu_dat_o = biu_dat_o_reg;
`else
  assign biu_dat_o = wb_dat_i;
`endif

  // ------------------------------------------------------------
  // Clock division gating for ack/err
  // ------------------------------------------------------------
  wire gated_ack;
  wire gated_err;

`ifdef OR1200_CLKDIV_2_SUPPORTED
  wire clkdiv2_gate;
  assign clkdiv2_gate = (clmode == 2'b01) ? valid_div[0] : 1'b1;
`else
  wire clkdiv2_gate;
  assign clkdiv2_gate = 1'b1;
`endif

`ifdef OR1200_CLKDIV_4_SUPPORTED
  wire clkdiv4_gate;
  assign clkdiv4_gate = (clmode == 2'b11) ? &valid_div : 1'b1;
`else
  wire clkdiv4_gate;
  assign clkdiv4_gate = 1'b1;
`endif

  assign gated_ack = long_ack_o & clkdiv2_gate & clkdiv4_gate;
  assign gated_err = long_err_o & clkdiv2_gate & clkdiv4_gate;

  assign biu_ack_o = gated_ack;
  assign biu_err_o = gated_err;

  // ------------------------------------------------------------
  // B3 burst support
  // ------------------------------------------------------------
`ifdef OR1200_WB_B3

  reg [1:0] burst_len;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) burst_len <= 2'b00;
    else if (~biu_cab_i) burst_len <= 2'b11;
    else if (biu_cab_i & (|burst_len) & wb_ack_i) burst_len <= burst_len - 2'b01;
  end

  assign wb_bte_o = 2'b01;

`ifdef OR1200_REGISTERED_OUTPUTS
  reg [2:0] wb_cti_o_reg;

  always @(posedge wb_clk_i or posedge wb_rst_i) begin
    if (wb_rst_i) wb_cti_o_reg <= 3'b000;
    else begin
`ifdef OR1200_NO_BURSTS
      wb_cti_o_reg <= 3'b111;
`else
      if (biu_cab_i & burst_len[1]) wb_cti_o_reg <= 3'b010;
      else if (biu_cab_i & wb_ack_i) wb_cti_o_reg <= 3'b111;
      else if (~biu_cab_i) wb_cti_o_reg <= 3'b000;
`endif
    end
  end

  assign wb_cti_o = wb_cti_o_reg;
`else
  // Unsupported !!!
  assign wb_cti_o = 3'b000;
`endif

`endif

endmodule
