// Generated from: Description/or1200_lsu_description.txt
module or1200_lsu(
    input  [31:0] addrbase,
    input  [31:0] addrofs,
    input  [3:0]  lsu_op,
    input  [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output        lsu_stall,
    output        lsu_unstall,
    input         du_stall,
    output        except_align,
    output        except_dtlbmiss,
    output        except_dmmufault,
    output        except_dbuserr,

    output [31:0] dcpu_adr_o,
    output        dcpu_cycstb_o,
    output        dcpu_we_o,
    output [3:0]  dcpu_sel_o,
    output [3:0]  dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input  [31:0] dcpu_dat_i,
    input         dcpu_ack_i,
    input         dcpu_rty_i,
    input         dcpu_err_i,
    input  [3:0]  dcpu_tag_i
);

`include "or1200_defines.v"

  assign dcpu_adr_o = addrbase + addrofs;
  wire [1:0] mem2reg_addr = dcpu_adr_o[1:0];

  // write enable from op[3]
  assign dcpu_we_o = lsu_op[3];

  // alignment check
  reg align_err;
  always @* begin
    align_err = 1'b0;
    case (lsu_op)
      `OR1200_LSUOP_SH,
      `OR1200_LSUOP_LHZ,
      `OR1200_LSUOP_LHS: begin
        if (dcpu_adr_o[0]) align_err = 1'b1;
      end
      `OR1200_LSUOP_SW,
      `OR1200_LSUOP_LWZ,
      `OR1200_LSUOP_LWS: begin
        if (dcpu_adr_o[1:0] != 2'b00) align_err = 1'b1;
      end
      default: align_err = 1'b0;
    endcase
  end
  assign except_align = align_err;

  // request gating
  assign lsu_unstall = dcpu_ack_i;
  assign dcpu_cycstb_o = (|lsu_op) & ~du_stall & ~lsu_unstall & ~except_align;

  // tag output
  assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

  // byte select
  reg [3:0] sel_r;
  always @* begin
    sel_r = 4'b0000;
    case (lsu_op)
      `OR1200_LSUOP_SB, `OR1200_LSUOP_LBZ, `OR1200_LSUOP_LBS: begin
        case (dcpu_adr_o[1:0])
          2'b00: sel_r = 4'b1000;
          2'b01: sel_r = 4'b0100;
          2'b10: sel_r = 4'b0010;
          2'b11: sel_r = 4'b0001;
        endcase
      end
      `OR1200_LSUOP_SH, `OR1200_LSUOP_LHZ, `OR1200_LSUOP_LHS: begin
        case (dcpu_adr_o[1:0])
          2'b00: sel_r = 4'b1100;
          2'b10: sel_r = 4'b0011;
          default: sel_r = 4'b0000;
        endcase
      end
      `OR1200_LSUOP_SW, `OR1200_LSUOP_LWZ, `OR1200_LSUOP_LWS: begin
        sel_r = (dcpu_adr_o[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
      end
      default: sel_r = 4'b0000;
    endcase
  end
  assign dcpu_sel_o = sel_r;

  // stall/unstall
  assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;

  // exception decode from downstream
  assign except_dtlbmiss  = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
  assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
  assign except_dbuserr   = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);

  // data align submodules
  or1200_mem2reg u_mem2reg(
      .addr(mem2reg_addr),
      .lsu_op(lsu_op),
      .memdata(dcpu_dat_i),
      .regdata(lsu_dataout)
  );

  or1200_reg2mem u_reg2mem(
      .addr(mem2reg_addr),
      .lsu_op(lsu_op),
      .regdata(lsu_datain),
      .memdata(dcpu_dat_o)
  );

endmodule
