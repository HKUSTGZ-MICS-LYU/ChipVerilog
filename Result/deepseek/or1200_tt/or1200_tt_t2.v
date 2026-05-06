// OpenRISC 1200 Tick Timer implementation
`timescale 1ns / 1ps

module or1200_tt (
    input clk,
    input rst,
    input du_stall,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output intr
);

  // Parameter definitions for TTMR bit fields and TT offsets
  parameter OR1200_TT_TTMR_IP = 28;
  parameter OR1200_TT_TTMR_IE = 29;
  parameter OR1200_TT_TTMR_M  = 30;  // TTMR mode field width is 2 bits (30:31)
  parameter OR1200_TT_TTMR_TP = 0;   // TTMR threshold field (lower 28 bits)

  // Offsets and address bits
  parameter OR1200_TT_OFS_TTMR = 32'h0;   // Example offset for TTMR
  parameter OR1200_TT_OFS_TTCR = 32'h4;   // Example offset for TTCR
  parameter OR1200_TTOFS_BITS = 31:2;     // Bits used for offset comparison

  // Internal signals
  wire [31:0] ttmr;
  wire [31:0] ttcr;
  wire ttmr_sel;
  wire ttcr_sel;
  wire match;
  wire restart;
  wire stop;

  // Address decoding for SPR access
  assign ttmr_sel = spr_cs && (spr_addr[OR1200_TTOFS_BITS] == OR1200_TT_OFS_TTMR[OR1200_TTOFS_BITS]);
  assign ttcr_sel = spr_cs && (spr_addr[OR1200_TTOFS_BITS] == OR1200_TT_OFS_TTCR[OR1200_TTOFS_BITS]);

  // Match logic: compare TTMR threshold with TTCR[27:0]
  assign match = (ttmr[OR1200_TT_TTMR_TP +: 28] == ttcr[27:0]);

  // Restart logic: restart when match and mode is 2'b01
  assign restart = match && (ttmr[OR1200_TT_TTMR_M +: 2] == 2'b01);

  // Stop logic: stop when (match and mode 2'b10) or mode 2'b00 or du_stall
  assign stop = (match && (ttmr[OR1200_TT_TTMR_M +: 2] == 2'b10)) ||
                (ttmr[OR1200_TT_TTMR_M +: 2] == 2'b00) ||
                du_stall;

  // Conditional generation based on OR1200_TT_IMPLEMENTED
  `ifdef OR1200_TT_IMPLEMENTED

    // TTMR register implementation
    `ifdef OR1200_TT_TTMR
      reg [31:0] ttmr_reg;
      assign ttmr = ttmr_reg;

      always @(posedge clk or posedge rst) begin
        if (rst) begin
          ttmr_reg <= 32'b0;
        end else if (ttmr_sel && spr_write) begin
          ttmr_reg <= spr_dat_i;
        end else if (ttmr_reg[OR1200_TT_TTMR_IE]) begin
          // Hardware update of IP only when IE is set
          ttmr_reg[OR1200_TT_TTMR_IP] <= ttmr_reg[OR1200_TT_TTMR_IP] | (match & ttmr_reg[OR1200_TT_TTMR_IE]);
        end
      end
    `else
      // TTMR not implemented, tie to default value {2'b11, 30'b0}
      assign ttmr = {2'b11, 30'b0};
    `endif

    // TTCR register implementation
    `ifdef OR1200_TT_TTCR
      reg [31:0] ttcr_reg;
      assign ttcr = ttcr_reg;

      always @(posedge clk or posedge rst) begin
        if (rst) begin
          ttcr_reg <= 32'b0;
        end else if (restart) begin
          ttcr_reg <= 32'b0;
        end else if (ttcr_sel && spr_write) begin
          ttcr_reg <= spr_dat_i;
        end else if (!stop) begin
          ttcr_reg <= ttcr_reg + 1;
        end
        // else hold when stop is asserted
      end
    `else
      // TTCR not implemented, tie to 32'b0
      assign ttcr = 32'b0;
    `endif

    // Interrupt output: directly driven by IP bit of TTMR
    assign intr = ttmr[OR1200_TT_TTMR_IP];

    // SPR read data generation
    `ifdef OR1200_TT_READREGS
      reg [31:0] spr_dat_o_reg;
      assign spr_dat_o = spr_dat_o_reg;

      always @(*) begin
        if (spr_addr[OR1200_TTOFS_BITS] == OR1200_TT_OFS_TTMR[OR1200_TTOFS_BITS])
          spr_dat_o_reg = ttmr;
        else
          spr_dat_o_reg = ttcr;
      end
    `else
      // If TT_READREGS not defined, spr_dat_o not driven here (external handling)
      // Per spec, if OR1200_TT_READREGS is defined, it's used; else in non-implemented branch
      // In implemented branch without READREGS, we tie to 0 to avoid latch
      assign spr_dat_o = 32'b0;
    `endif

  `else
    // OR1200_TT_IMPLEMENTED not defined
    assign intr = 1'b0;

    `ifdef OR1200_TT_READREGS
      assign spr_dat_o = 32'b0;
    `else
      // No assignment to spr_dat_o in this branch, but to avoid latch, tie to 0
      assign spr_dat_o = 32'b0;
    `endif

    // Tie off internal signals to avoid dangling wires
    assign ttmr = 32'b0;
    assign ttcr = 32'b0;
  `endif

endmodule
