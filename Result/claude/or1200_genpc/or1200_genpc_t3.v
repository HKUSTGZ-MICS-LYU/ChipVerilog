// Generated from: Description/or1200_genpc_description.txt
module or1200_genpc(
    input         clk,
    input         rst,

    output [31:0] icpu_adr_o,
    output        icpu_cycstb_o,
    output [3:0]  icpu_sel_o,
    output [3:0]  icpu_tag_o,
    input         icpu_rty_i,
    input  [31:0] icpu_adr_i,

    input  [2:0]  branch_op,
    input  [3:0]  except_type,
    input         except_prefix,
    input  [31:2] branch_addrofs,
    input  [31:0] lr_restor,
    input         flag,
    output        taken,
    input         except_start,
    input  [31:2] binsn_addr,
    input  [31:0] epcr,
    input  [31:0] spr_dat_i,
    input         spr_pc_we,
    input         genpc_refetch,
    input         genpc_freeze,
    input         genpc_stop_prefetch,
    input         no_more_dslot
);

`include "or1200_defines.v"

  reg [31:2] pcreg;
  reg [31:0] pc;
  reg taken_r;
  assign taken = taken_r;

  reg genpc_refetch_r;

  wire [31:0] pc_seq = {pcreg + 30'd1, 2'b00};
  wire [31:0] pc_j   = {branch_addrofs, 2'b00};
  wire [31:0] pc_bal = {binsn_addr + branch_addrofs, 2'b00};

  wire [31:0] pc_except =
      { (except_prefix ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P),
        except_type,
        `OR1200_EXCEPT_V };

  // Candidate next PC (combinational)
  always @* begin
    pc = pc_seq;
    taken_r = 1'b0;

    if (spr_pc_we) begin
      pc = spr_dat_i;
      taken_r = 1'b0; // per description: SPR PC write does not set taken
    end else if (except_start) begin
      pc = pc_except;
      taken_r = 1'b1;
    end else begin
      case (branch_op)
        `OR1200_BRANCHOP_NOP: begin
          pc = pc_seq;
          taken_r = 1'b0;
        end
        `OR1200_BRANCHOP_J: begin
          pc = pc_j;
          taken_r = 1'b1;
        end
        `OR1200_BRANCHOP_JR: begin
          pc = lr_restor;
          taken_r = 1'b1;
        end
        `OR1200_BRANCHOP_BAL: begin
          pc = pc_bal;
          taken_r = 1'b1;
        end
        `OR1200_BRANCHOP_BF: begin
          pc = flag ? pc_bal : pc_seq;
          taken_r = flag;
        end
        `OR1200_BRANCHOP_BNF: begin
          pc = (!flag) ? pc_bal : pc_seq;
          taken_r = !flag;
        end
        `OR1200_BRANCHOP_RFE: begin
          pc = epcr;
          taken_r = 1'b1;
        end
        default: begin
          pc = pc_seq;
          taken_r = 1'b0;
        end
      endcase
    end
  end

  // Instruction-side outputs
  assign icpu_cycstb_o = ~genpc_freeze;
  assign icpu_sel_o    = 4'b1111;
  assign icpu_tag_o    = `OR1200_ITAG_NI;

  wire resend_current =
      (~no_more_dslot) & (~except_start) & (~spr_pc_we) & (icpu_rty_i | genpc_refetch);

  assign icpu_adr_o = resend_current ? icpu_adr_i : pc;

  // pcreg update rules
  wire normal_advance = (~genpc_freeze) & (~icpu_rty_i) & (~genpc_refetch);
  wire force_update   = no_more_dslot | except_start;

  // Reset PC initialization: reset vector - 4, stored as word address
  wire [31:0] reset_vector =
      { (`OR1200_SR_EPH_DEF ? `OR1200_EXCEPT_EPH1_P : `OR1200_EXCEPT_EPH0_P),
        `OR1200_EXCEPT_RESET,
        `OR1200_EXCEPT_V };
  wire [31:0] reset_vector_m4 = reset_vector - 32'd4;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      pcreg <= reset_vector_m4[31:2];
      genpc_refetch_r <= 1'b0;
    end else begin
      // genpc_refetch_r is retained but not used in active logic
      genpc_refetch_r <= genpc_refetch;

      if (spr_pc_we) begin
        pcreg <= spr_dat_i[31:2];
      end else if (force_update) begin
        pcreg <= pc[31:2];
      end else if (normal_advance) begin
        pcreg <= pc[31:2];
      end
    end
  end
endmodule
