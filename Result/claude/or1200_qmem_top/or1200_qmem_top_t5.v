// Generated from: Description/or1200_qmem_top_description.txt
module or1200_qmem_top(
    input         clk,
    input         rst,

`ifdef OR1200_BIST
    input         mbist_si_i,
    output        mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // QMEM and CPU/IMMU
    input  [31:0] qmemimmu_adr_i,
    input         qmemimmu_cycstb_i,
    input         qmemimmu_ci_i,
    input  [3:0]  qmemicpu_sel_i,
    input  [3:0]  qmemicpu_tag_i,
    output [31:0] qmemicpu_dat_o,
    output        qmemicpu_ack_o,
    output        qmemimmu_rty_o,
    output        qmemimmu_err_o,
    output [3:0]  qmemimmu_tag_o,

    // QMEM and IC
    output [31:0] icqmem_adr_o,
    output        icqmem_cycstb_o,
    output        icqmem_ci_o,
    output [3:0]  icqmem_sel_o,
    output [3:0]  icqmem_tag_o,
    input  [31:0] icqmem_dat_i,
    input         icqmem_ack_i,
    input         icqmem_rty_i,
    input         icqmem_err_i,
    input  [3:0]  icqmem_tag_i,

    // QMEM and CPU/DMMU
    input  [31:0] qmemdmmu_adr_i,
    input         qmemdmmu_cycstb_i,
    input         qmemdmmu_ci_i,
    input         qmemdcpu_we_i,
    input  [3:0]  qmemdcpu_sel_i,
    input  [3:0]  qmemdcpu_tag_i,
    input  [31:0] qmemdcpu_dat_i,
    output [31:0] qmemdcpu_dat_o,
    output        qmemdcpu_ack_o,
    output        qmemdcpu_rty_o,
    output        qmemdmmu_err_o,
    output [3:0]  qmemdmmu_tag_o,

    // QMEM and DC
    output [31:0] dcqmem_adr_o,
    output        dcqmem_cycstb_o,
    output        dcqmem_ci_o,
    output        dcqmem_we_o,
    output [3:0]  dcqmem_sel_o,
    output [3:0]  dcqmem_tag_o,
    output [31:0] dcqmem_dat_o,
    input  [31:0] dcqmem_dat_i,
    input         dcqmem_ack_i,
    input         dcqmem_rty_i,
    input         dcqmem_err_i,
    input  [3:0]  dcqmem_tag_i
);

`include "or1200_defines.v"

`ifdef OR1200_BIST
  assign mbist_so_o = mbist_si_i;
  wire _unused_bist = |mbist_ctrl_i;
`endif

`ifdef OR1200_QMEM_IMPLEMENTED

`ifdef OR1200_QMEM_IADDR
  wire iaddr_qmem_hit = ((qmemimmu_adr_i & `OR1200_QMEM_IMASK) == `OR1200_QMEM_IADDR);
`else
  wire iaddr_qmem_hit = 1'b0;
`endif

`ifdef OR1200_QMEM_DADDR
  wire daddr_qmem_hit = ((qmemdmmu_adr_i & `OR1200_QMEM_DMASK) == `OR1200_QMEM_DADDR);
`else
  wire daddr_qmem_hit = 1'b0;
`endif

  // Block cache path on hit
  assign icqmem_adr_o    = iaddr_qmem_hit ? 32'd0 : qmemimmu_adr_i;
  assign icqmem_cycstb_o = iaddr_qmem_hit ? 1'b0  : qmemimmu_cycstb_i;
  assign icqmem_ci_o     = iaddr_qmem_hit ? 1'b0  : qmemimmu_ci_i;
  assign icqmem_sel_o    = iaddr_qmem_hit ? 4'd0  : qmemicpu_sel_i;
  assign icqmem_tag_o    = iaddr_qmem_hit ? 4'd0  : qmemicpu_tag_i;

  assign dcqmem_adr_o    = daddr_qmem_hit ? 32'd0 : qmemdmmu_adr_i;
  assign dcqmem_cycstb_o = daddr_qmem_hit ? 1'b0  : qmemdmmu_cycstb_i;
  assign dcqmem_ci_o     = daddr_qmem_hit ? 1'b0  : qmemdmmu_ci_i;
  assign dcqmem_we_o     = daddr_qmem_hit ? 1'b0  : qmemdcpu_we_i;
  assign dcqmem_sel_o    = daddr_qmem_hit ? 4'd0  : qmemdcpu_sel_i;
  assign dcqmem_tag_o    = daddr_qmem_hit ? 4'd0  : qmemdcpu_tag_i;
  assign dcqmem_dat_o    = daddr_qmem_hit ? 32'd0 : qmemdcpu_dat_i;

  // Local single-port QMEM array: 2048 x 32 words addressed by [12:2]
  reg [31:0] qmem_ram [0:2047];
  wire [10:0] qmem_word_addr =
      (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdmmu_adr_i[12:2] :
                                            qmemimmu_adr_i[12:2];
  wire qmem_en = (qmemimmu_cycstb_i & iaddr_qmem_hit) | (qmemdmmu_cycstb_i & daddr_qmem_hit);
  wire qmem_we = (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i);

  wire [31:0] qmem_di = qmemdcpu_dat_i;
  reg  [31:0] qmem_do;

  // Simple byte select support (optional)
  wire [3:0] qmem_sel =
`ifdef OR1200_QMEM_BSEL
      (qmemdmmu_cycstb_i & daddr_qmem_hit) ? qmemdcpu_sel_i : qmemicpu_sel_i;
`else
      4'hf;
`endif

`ifdef OR1200_QMEM_ACK
  wire qmem_ack = 1'b1;
`else
  wire qmem_ack = 1'b1;
`endif

  integer ii;
  always @(posedge clk) begin
    if (qmem_en) begin
      qmem_do <= qmem_ram[qmem_word_addr];
      if (qmem_we) begin
        if (qmem_sel[3]) qmem_ram[qmem_word_addr][31:24] <= qmem_di[31:24];
        if (qmem_sel[2]) qmem_ram[qmem_word_addr][23:16] <= qmem_di[23:16];
        if (qmem_sel[1]) qmem_ram[qmem_word_addr][15:8]  <= qmem_di[15:8];
        if (qmem_sel[0]) qmem_ram[qmem_word_addr][7:0]   <= qmem_di[7:0];
      end
    end
  end

  // FSM/arbiter acks
  localparam [2:0] IDLE=3'd0, STORE=3'd1, LOAD=3'd2, FETCH=3'd3;
  reg [2:0] state;
  reg qmem_dack, qmem_iack;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      qmem_dack <= 1'b0;
      qmem_iack <= 1'b0;
    end else begin
      qmem_dack <= 1'b0;
      qmem_iack <= 1'b0;
      if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmemdcpu_we_i & qmem_ack) begin
        state <= STORE;
        qmem_dack <= 1'b1;
      end else if (qmemdmmu_cycstb_i & daddr_qmem_hit & qmem_ack) begin
        state <= LOAD;
        qmem_dack <= 1'b1;
      end else if (qmemimmu_cycstb_i & iaddr_qmem_hit & qmem_ack) begin
        state <= FETCH;
        qmem_iack <= 1'b1;
      end else begin
        state <= IDLE;
      end
    end
  end

  // Return paths
  assign qmemicpu_dat_o = qmem_iack ? qmem_do : icqmem_dat_i;
  assign qmemicpu_ack_o = qmem_iack ? 1'b1   : icqmem_ack_i;
  assign qmemimmu_rty_o = qmem_iack ? 1'b0   : icqmem_rty_i;
  assign qmemimmu_err_o = qmem_iack ? 1'b0   : icqmem_err_i;
  assign qmemimmu_tag_o = qmem_iack ? 4'd0   : icqmem_tag_i;

  assign qmemdcpu_dat_o = daddr_qmem_hit ? qmem_do : dcqmem_dat_i;
  assign qmemdcpu_ack_o = daddr_qmem_hit ? qmem_dack : dcqmem_ack_i;
  assign qmemdcpu_rty_o = daddr_qmem_hit ? ~qmem_dack : dcqmem_rty_i;
  assign qmemdmmu_err_o = daddr_qmem_hit ? 1'b0 : dcqmem_err_i;
  assign qmemdmmu_tag_o = daddr_qmem_hit ? 4'd0 : dcqmem_tag_i;

  wire _unused_state = |state;

`else
  // Pure pass-through when not implemented
  assign icqmem_adr_o    = qmemimmu_adr_i;
  assign icqmem_cycstb_o = qmemimmu_cycstb_i;
  assign icqmem_ci_o     = qmemimmu_ci_i;
  assign icqmem_sel_o    = qmemicpu_sel_i;
  assign icqmem_tag_o    = qmemicpu_tag_i;

  assign qmemicpu_dat_o  = icqmem_dat_i;
  assign qmemicpu_ack_o  = icqmem_ack_i;
  assign qmemimmu_rty_o  = icqmem_rty_i;
  assign qmemimmu_err_o  = icqmem_err_i;
  assign qmemimmu_tag_o  = icqmem_tag_i;

  assign dcqmem_adr_o    = qmemdmmu_adr_i;
  assign dcqmem_cycstb_o = qmemdmmu_cycstb_i;
  assign dcqmem_ci_o     = qmemdmmu_ci_i;
  assign dcqmem_we_o     = qmemdcpu_we_i;
  assign dcqmem_sel_o    = qmemdcpu_sel_i;
  assign dcqmem_tag_o    = qmemdcpu_tag_i;
  assign dcqmem_dat_o    = qmemdcpu_dat_i;

  assign qmemdcpu_dat_o  = dcqmem_dat_i;
  assign qmemdcpu_ack_o  = dcqmem_ack_i;
  assign qmemdcpu_rty_o  = dcqmem_rty_i;
  assign qmemdmmu_err_o  = dcqmem_err_i;
  assign qmemdmmu_tag_o  = dcqmem_tag_i;
`endif

endmodule
