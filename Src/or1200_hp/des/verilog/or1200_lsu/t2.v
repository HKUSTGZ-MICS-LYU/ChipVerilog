`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_lsu (
    // Internal i/f
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

    // External i/f to DC
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

    //--------------------------------------------------------------------------
    // Effective address
    //--------------------------------------------------------------------------
    assign dcpu_adr_o = addrbase + addrofs;

    wire [1:0] mem2reg_addr = dcpu_adr_o[1:0];

    //--------------------------------------------------------------------------
    // Address alignment exception
    //--------------------------------------------------------------------------
    reg except_align_r;

    always @(*) begin
        case (lsu_op)
            // Halfword: addr[0] must be 0
            `OR1200_LSUOP_SH,
            `OR1200_LSUOP_LHZ,
            `OR1200_LSUOP_LHS:  except_align_r = dcpu_adr_o[0];
            // Word: addr[1:0] must be 00
            `OR1200_LSUOP_SW,
            `OR1200_LSUOP_LWZ,
            `OR1200_LSUOP_LWS:  except_align_r = |dcpu_adr_o[1:0];
            // Byte: no alignment required
            default:             except_align_r = 1'b0;
        endcase
    end

    assign except_align = except_align_r;

    //--------------------------------------------------------------------------
    // LSU stall / unstall
    //--------------------------------------------------------------------------
    assign lsu_unstall = dcpu_ack_i;
    assign lsu_stall   = dcpu_rty_i & dcpu_cycstb_o;

    //--------------------------------------------------------------------------
    // dcpu_cycstb_o: issue request only when op valid and no blocking
    //--------------------------------------------------------------------------
    assign dcpu_cycstb_o = |lsu_op & ~du_stall & ~lsu_unstall & ~except_align;

    //--------------------------------------------------------------------------
    // dcpu_we_o: store when lsu_op[3]=1
    //--------------------------------------------------------------------------
    assign dcpu_we_o = lsu_op[3];

    //--------------------------------------------------------------------------
    // dcpu_tag_o
    //--------------------------------------------------------------------------
    assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

    //--------------------------------------------------------------------------
    // dcpu_sel_o: byte-lane select
    //--------------------------------------------------------------------------
    reg [3:0] dcpu_sel_o_r;

    always @(*) begin
        case (lsu_op)
            // Byte accesses
            `OR1200_LSUOP_SB,
            `OR1200_LSUOP_LBZ,
            `OR1200_LSUOP_LBS: begin
                case (dcpu_adr_o[1:0])
                    2'b00: dcpu_sel_o_r = 4'b1000;
                    2'b01: dcpu_sel_o_r = 4'b0100;
                    2'b10: dcpu_sel_o_r = 4'b0010;
                    2'b11: dcpu_sel_o_r = 4'b0001;
                endcase
            end
            // Halfword accesses
            `OR1200_LSUOP_SH,
            `OR1200_LSUOP_LHZ,
            `OR1200_LSUOP_LHS: begin
                case (dcpu_adr_o[1:0])
                    2'b00: dcpu_sel_o_r = 4'b1100;
                    2'b10: dcpu_sel_o_r = 4'b0011;
                    default: dcpu_sel_o_r = 4'b0000;  // misaligned
                endcase
            end
            // Word accesses
            `OR1200_LSUOP_SW,
            `OR1200_LSUOP_LWZ,
            `OR1200_LSUOP_LWS: begin
                case (dcpu_adr_o[1:0])
                    2'b00: dcpu_sel_o_r = 4'b1111;
                    default: dcpu_sel_o_r = 4'b0000;  // misaligned
                endcase
            end
            default: dcpu_sel_o_r = 4'b0000;
        endcase
    end

    assign dcpu_sel_o = dcpu_sel_o_r;

    //--------------------------------------------------------------------------
    // Exception classification from data-side error
    //--------------------------------------------------------------------------
    assign except_dtlbmiss  = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
    assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
    assign except_dbuserr   = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);

    //--------------------------------------------------------------------------
    // or1200_mem2reg: load data alignment
    //--------------------------------------------------------------------------
    or1200_mem2reg or1200_mem2reg (
        .addr    (mem2reg_addr),
        .lsu_op  (lsu_op),
        .memout  (dcpu_dat_i),
        .regout  (lsu_dataout)
    );

    //--------------------------------------------------------------------------
    // or1200_reg2mem: store data alignment
    //--------------------------------------------------------------------------
    or1200_reg2mem or1200_reg2mem (
        .addr    (mem2reg_addr),
        .lsu_op  (lsu_op),
        .regin   (lsu_datain),
        .memout  (dcpu_dat_o)
    );

endmodule