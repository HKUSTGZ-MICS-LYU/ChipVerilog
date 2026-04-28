`include "timescale.v"
`include "or1200_defines.v"

module or1200_lsu(
    addrbase, addrofs, lsu_op, lsu_datain, lsu_dataout,
    lsu_stall, lsu_unstall, du_stall,
    except_align, except_dtlbmiss, except_dmmufault, except_dbuserr,
    dcpu_adr_o, dcpu_cycstb_o, dcpu_we_o, dcpu_sel_o, dcpu_tag_o,
    dcpu_dat_o, dcpu_dat_i, dcpu_ack_i, dcpu_rty_i, dcpu_err_i, dcpu_tag_i
);

input  [31:0] addrbase;
input  [31:0] addrofs;
input  [3:0]  lsu_op;
input  [31:0] lsu_datain;
output [31:0] lsu_dataout;
output        lsu_stall;
output        lsu_unstall;
input         du_stall;
output        except_align;
output        except_dtlbmiss;
output        except_dmmufault;
output        except_dbuserr;
output [31:0] dcpu_adr_o;
output        dcpu_cycstb_o;
output        dcpu_we_o;
output [3:0]  dcpu_sel_o;
output [3:0]  dcpu_tag_o;
output [31:0] dcpu_dat_o;
input  [31:0] dcpu_dat_i;
input         dcpu_ack_i;
input         dcpu_rty_i;
input         dcpu_err_i;
input  [3:0]  dcpu_tag_i;

// Effective address
assign dcpu_adr_o = addrbase + addrofs;

// Low two address bits for alignment and data mux
wire [1:0] mem2reg_addr = dcpu_adr_o[1:0];

// Write enable
assign dcpu_we_o = lsu_op[3];

// Alignment exception
assign except_align =
    ((lsu_op == `OR1200_LSUOP_SH)  | (lsu_op == `OR1200_LSUOP_LHZ) |
     (lsu_op == `OR1200_LSUOP_LHS)) ? dcpu_adr_o[0] :
    ((lsu_op == `OR1200_LSUOP_SW)  | (lsu_op == `OR1200_LSUOP_LWZ) |
     (lsu_op == `OR1200_LSUOP_LWS)) ? |dcpu_adr_o[1:0] :
    1'b0;

// Cycle/strobe: lsu_op nonzero and no blocking condition
assign dcpu_cycstb_o = |lsu_op & !du_stall & !lsu_unstall & !except_align;

// Access tag
assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

// Stall / unstall
assign lsu_stall   = dcpu_rty_i & dcpu_cycstb_o;
assign lsu_unstall = dcpu_ack_i;

// Error exception decode
assign except_dtlbmiss  = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
assign except_dbuserr   = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);

// Byte-select generation
reg [3:0] dcpu_sel_o;
always @(lsu_op or mem2reg_addr) begin
    casex ({lsu_op, mem2reg_addr})
        // Byte: SB, LBZ, LBS
        {`OR1200_LSUOP_SB,  2'b00}: dcpu_sel_o = 4'b1000;
        {`OR1200_LSUOP_SB,  2'b01}: dcpu_sel_o = 4'b0100;
        {`OR1200_LSUOP_SB,  2'b10}: dcpu_sel_o = 4'b0010;
        {`OR1200_LSUOP_SB,  2'b11}: dcpu_sel_o = 4'b0001;
        {`OR1200_LSUOP_LBZ, 2'b00}: dcpu_sel_o = 4'b1000;
        {`OR1200_LSUOP_LBZ, 2'b01}: dcpu_sel_o = 4'b0100;
        {`OR1200_LSUOP_LBZ, 2'b10}: dcpu_sel_o = 4'b0010;
        {`OR1200_LSUOP_LBZ, 2'b11}: dcpu_sel_o = 4'b0001;
        {`OR1200_LSUOP_LBS, 2'b00}: dcpu_sel_o = 4'b1000;
        {`OR1200_LSUOP_LBS, 2'b01}: dcpu_sel_o = 4'b0100;
        {`OR1200_LSUOP_LBS, 2'b10}: dcpu_sel_o = 4'b0010;
        {`OR1200_LSUOP_LBS, 2'b11}: dcpu_sel_o = 4'b0001;
        // Halfword: SH, LHZ, LHS
        {`OR1200_LSUOP_SH,  2'b00}: dcpu_sel_o = 4'b1100;
        {`OR1200_LSUOP_SH,  2'b10}: dcpu_sel_o = 4'b0011;
        {`OR1200_LSUOP_LHZ, 2'b00}: dcpu_sel_o = 4'b1100;
        {`OR1200_LSUOP_LHZ, 2'b10}: dcpu_sel_o = 4'b0011;
        {`OR1200_LSUOP_LHS, 2'b00}: dcpu_sel_o = 4'b1100;
        {`OR1200_LSUOP_LHS, 2'b10}: dcpu_sel_o = 4'b0011;
        // Word: SW, LWZ, LWS
        {`OR1200_LSUOP_SW,  2'b00}: dcpu_sel_o = 4'b1111;
        {`OR1200_LSUOP_LWZ, 2'b00}: dcpu_sel_o = 4'b1111;
        {`OR1200_LSUOP_LWS, 2'b00}: dcpu_sel_o = 4'b1111;
        default:                     dcpu_sel_o = 4'b0000;
    endcase
end

// or1200_mem2reg: load data alignment
or1200_mem2reg or1200_mem2reg(
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .memout(dcpu_dat_i),
    .regout(lsu_dataout)
);

// or1200_reg2mem: store data alignment
or1200_reg2mem or1200_reg2mem(
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .regin(lsu_datain),
    .memout(dcpu_dat_o)
);

endmodule