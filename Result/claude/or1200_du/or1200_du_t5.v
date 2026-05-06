// Generated from: Description/or1200_du_description.txt
module or1200_du(
    // RISC Internal Interface
    input         clk,
    input         rst,
    input         dcpu_cycstb_i,
    input         dcpu_we_i,
    input  [31:0] dcpu_adr_i,
    input  [31:0] dcpu_dat_lsu,
    input  [31:0] dcpu_dat_dc,
    input   icpu_cycstb_i,
    input         ex_freeze,
    input  [2:0]  branch_op,
    input  [31:0] ex_insn,
    input  [31:0] id_pc,
    input  [31:0] spr_dat_npc,
    input  [31:0] rf_dataw,
    output [13:0] du_dsr,
    output        du_stall,
    output [31:0] du_addr,
    input  [31:0] du_dat_i,
    output [31:0] du_dat_o,
    output        du_read,
    output        du_write,
    input  [12:0] du_except,
    output        du_hwbkpt,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,

    // External Debug Interface
    input         dbg_stall_i,
    input         dbg_ewt_i,
    output [3:0]  dbg_lss_o,
    output [1:0]  dbg_is_o,
    output [10:0] dbg_wp_o,
    output        dbg_bp_o,
    input         dbg_stb_i,
    input         dbg_we_i,
    input  [31:0] dbg_adr_i,
    input  [31:0] dbg_dat_i,
    output [31:0] dbg_dat_o,
    output        dbg_ack_o
);

`include "or1200_defines.v"

  // Basic external debug bridge
  assign du_stall = dbg_stall_i;
  assign du_addr  = dbg_adr_i;
  assign du_dat_o = dbg_dat_i;
  assign du_read  = dbg_stb_i & ~dbg_we_i;
  assign du_write = dbg_stb_i &  dbg_we_i;
  assign dbg_dat_o = du_dat_i;

  // 1-cycle delayed ack
  reg dbg_ack_r;
  always @(posedge clk or posedge rst) begin
    if (rst) dbg_ack_r <= 1'b0;
    else dbg_ack_r <= dbg_stb_i;
  end
  assign dbg_ack_o = dbg_ack_r;

  // Status outputs
`ifndef OR1200_DU_STATUS_UNIMPLEMENTED
  assign dbg_lss_o = {dcpu_cycstb_i, dcpu_we_i, 2'b00};
  assign dbg_is_o  = {icpu_cycstb_i[0], 1'b0};
`else
  assign dbg_lss_o = 4'b0000;
  reg is_tgl;
  always @(posedge clk or posedge rst) begin
    if (rst) is_tgl <= 1'b0;
    else if (icpu_cycstb_i[0]) is_tgl <= ~is_tgl;
  end
  assign dbg_is_o = {is_tgl, 1'b0};
`endif

  // Per description: dbg_wp_o forced zero in this implementation
  assign dbg_wp_o = 11'b000_0000_0000;

`ifdef OR1200_DU_IMPLEMENTED
  // Debug registers (minimal subset that matches described behavior)
  reg [13:0] dsr;
  reg [13:0] drr;
  reg [31:0] dmr1, dmr2;

  // Optional compare registers (implemented as regs; may be unused unless macros expect)
  reg [31:0] dvr [0:7];
  reg [7:0]  dcr [0:7];
  reg [31:0] dwcr0, dwcr1;

  assign du_dsr = dsr;

  // Decode exception stop vector from du_except (already masked by DSR per description)
  wire [13:0] except_stop = {1'b0, du_except};

  // Breakpoint register output
  reg dbg_bp_r;
  assign dbg_bp_o = dbg_bp_r;

  // Hardware watchpoint request (simplified: optional; default off)
`ifdef OR1200_DU_HWBKPTS
  // Very conservative: only use external watchpoint trigger as event
  assign du_hwbkpt = dbg_ewt_i;
`else
  assign du_hwbkpt = 1'b0;
`endif

  integer i;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      dsr <= 14'd0;
      drr <= 14'd0;
      dmr1 <= 32'd0;
      dmr2 <= 32'd0;
      dwcr0 <= 32'd0;
      dwcr1 <= 32'd0;
      dbg_bp_r <= 1'b0;
      for (i=0;i<8;i=i+1) begin
        dvr[i] <= 32'd0;
        dcr[i] <= 8'd0;
      end
    end else begin
      // Minimal SPR writes: accept any DU SPR write as DSR update,
      // and allow explicit DRR clear via write.
      if (spr_cs && spr_write) begin
        dsr <= spr_dat_i[13:0];
        drr <= spr_dat_i[13:0];
      end

      // DRR accumulates exception stop reasons when not explicitly written
      if (!(spr_cs && spr_write)) begin
        drr <= drr | except_stop;
      end

      // Breakpoint output update
      if (!ex_freeze) begin
        dbg_bp_r <= (|except_stop);
`ifdef OR1200_DU_STEPPING
        if (dmr1[`OR1200_DMR1_ST]) begin
          if (ex_insn != {`OR1200_OR32_NOP, 26'h041_0000}) dbg_bp_r <= 1'b1;
        end
`endif
`ifdef OR1200_DU_BT
        if (dmr1[`OR1200_DMR1_BT]) begin
          if (branch_op != `OR1200_BRANCHOP_NOP) dbg_bp_r <= 1'b1;
        end
`endif
      end else begin
        dbg_bp_r <= (|except_stop);
      end
    end
  end

`ifdef OR1200_DU_READREGS
  assign spr_dat_o = spr_cs ? {18'd0, dsr} : 32'd0;
`else
  assign spr_dat_o = 32'd0;
`endif

`else
  // Not implemented
  assign du_dsr = 14'd0;
  assign du_hwbkpt = 1'b0;
  assign dbg_bp_o = 1'b0;
  assign spr_dat_o = 32'd0;
`endif

  // Unused inputs (avoid lint warnings)
  wire _unused = |{dcpu_adr_i, dcpu_dat_lsu, dcpu_dat_dc, id_pc, spr_dat_npc, rf_dataw, dbg_ewt_i};

endmodule
