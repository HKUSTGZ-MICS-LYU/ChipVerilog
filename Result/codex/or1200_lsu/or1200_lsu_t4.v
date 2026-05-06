`include "or1200_defines.v"

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

wire [31:0] addr = addrbase + addrofs;
reg [3:0] sel;
wire lsu_valid = (lsu_op != `OR1200_LSUOP_NOP);
wire halfop = (lsu_op == `OR1200_LSUOP_LHZ) || (lsu_op == `OR1200_LSUOP_LHS) || (lsu_op == `OR1200_LSUOP_SH);
wire wordop = (lsu_op == `OR1200_LSUOP_LWZ) || (lsu_op == `OR1200_LSUOP_LWS) || (lsu_op == `OR1200_LSUOP_SW);

assign dcpu_adr_o = addr;
assign dcpu_we_o  = lsu_op[3];
assign except_align = (halfop && addr[0]) || (wordop && |addr[1:0]);
assign dcpu_cycstb_o = lsu_valid & ~du_stall & ~lsu_unstall & ~except_align;
assign lsu_unstall = dcpu_ack_i;
assign lsu_stall   = dcpu_rty_i & dcpu_cycstb_o;
assign except_dtlbmiss = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
assign except_dbuserr = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);
assign dcpu_tag_o = lsu_valid ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

always @* begin
    case (lsu_op)
        `OR1200_LSUOP_SB: begin
            case (addr[1:0])
                2'b00: sel = 4'b1000;
                2'b01: sel = 4'b0100;
                2'b10: sel = 4'b0010;
                2'b11: sel = 4'b0001;
                default: sel = 4'b0000;
            endcase
        end
        `OR1200_LSUOP_SH: begin
            case (addr[1:0])
                2'b00: sel = 4'b1100;
                2'b10: sel = 4'b0011;
                default: sel = 4'b0000;
            endcase
        end
        `OR1200_LSUOP_SW,
        `OR1200_LSUOP_LWZ,
        `OR1200_LSUOP_LWS: begin
            if (addr[1:0] == 2'b00)
                sel = 4'b1111;
            else
                sel = 4'b0000;
        end
        default: begin
            case (addr[1:0])
                2'b00: sel = 4'b1000;
                2'b01: sel = 4'b0100;
                2'b10: sel = 4'b0010;
                2'b11: sel = 4'b0001;
                default: sel = 4'b0000;
            endcase
        end
    endcase
end

assign dcpu_sel_o = sel;

or1200_mem2reg u_mem2reg(
    .addr(addr[1:0]),
    .lsu_op(lsu_op),
    .memdata(dcpu_dat_i),
    .regdata(lsu_dataout)
);

or1200_reg2mem u_reg2mem(
    .addr(addr[1:0]),
    .lsu_op(lsu_op),
    .regdata(lsu_datain),
    .memdata(dcpu_dat_o)
);

endmodule
