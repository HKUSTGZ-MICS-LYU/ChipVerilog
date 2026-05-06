`ifndef OR1200_LSUOP_NOP
`define OR1200_LSUOP_NOP 4'b0000
`define OR1200_LSUOP_LBZ 4'b0001
`define OR1200_LSUOP_LBS 4'b0010
`define OR1200_LSUOP_LHZ 4'b0011
`define OR1200_LSUOP_LHS 4'b0100
`define OR1200_LSUOP_LWZ 4'b0101
`define OR1200_LSUOP_LWS 4'b0110
`define OR1200_LSUOP_SB  4'b1001
`define OR1200_LSUOP_SH  4'b1010
`define OR1200_LSUOP_SW  4'b1011
`endif

`ifndef OR1200_DTAG_IDLE
`define OR1200_DTAG_IDLE 4'b0000
`define OR1200_DTAG_ND   4'b0001
`define OR1200_DTAG_TE   4'b0010
`define OR1200_DTAG_PE   4'b0011
`define OR1200_DTAG_BE   4'b0100
`endif

module or1200_lsu(
    input [31:0] addrbase,
    input [31:0] addrofs,
    input [3:0] lsu_op,
    input [31:0] lsu_datain,
    output [31:0] lsu_dataout,
    output lsu_stall,
    output lsu_unstall,
    input du_stall,
    output except_align,
    output except_dtlbmiss,
    output except_dmmufault,
    output except_dbuserr,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output reg [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i
);

wire [1:0] mem2reg_addr;
wire halfword_access;
wire word_access;

assign dcpu_adr_o = addrbase + addrofs;
assign mem2reg_addr = dcpu_adr_o[1:0];

assign halfword_access =
    (lsu_op == `OR1200_LSUOP_SH)  |
    (lsu_op == `OR1200_LSUOP_LHZ) |
    (lsu_op == `OR1200_LSUOP_LHS);

assign word_access =
    (lsu_op == `OR1200_LSUOP_SW)  |
    (lsu_op == `OR1200_LSUOP_LWZ) |
    (lsu_op == `OR1200_LSUOP_LWS);

assign except_align =
    (halfword_access & dcpu_adr_o[0]) |
    (word_access & (|dcpu_adr_o[1:0]));

assign lsu_unstall = dcpu_ack_i;
assign dcpu_cycstb_o = (|lsu_op) & ~du_stall & ~lsu_unstall & ~except_align;
assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;

assign dcpu_we_o = lsu_op[3];
assign dcpu_tag_o = dcpu_cycstb_o ? `OR1200_DTAG_ND : `OR1200_DTAG_IDLE;

assign except_dtlbmiss = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_TE);
assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_PE);
assign except_dbuserr = dcpu_err_i & (dcpu_tag_i == `OR1200_DTAG_BE);

always @* begin
    dcpu_sel_o = 4'b0000;
    case (lsu_op)
        `OR1200_LSUOP_SB,
        `OR1200_LSUOP_LBZ,
        `OR1200_LSUOP_LBS: begin
            case (dcpu_adr_o[1:0])
                2'b00: dcpu_sel_o = 4'b1000;
                2'b01: dcpu_sel_o = 4'b0100;
                2'b10: dcpu_sel_o = 4'b0010;
                2'b11: dcpu_sel_o = 4'b0001;
                default: dcpu_sel_o = 4'b0000;
            endcase
        end

        `OR1200_LSUOP_SH,
        `OR1200_LSUOP_LHZ,
        `OR1200_LSUOP_LHS: begin
            case (dcpu_adr_o[1:0])
                2'b00: dcpu_sel_o = 4'b1100;
                2'b10: dcpu_sel_o = 4'b0011;
                default: dcpu_sel_o = 4'b0000;
            endcase
        end

        `OR1200_LSUOP_SW,
        `OR1200_LSUOP_LWZ,
        `OR1200_LSUOP_LWS: begin
            if (dcpu_adr_o[1:0] == 2'b00)
                dcpu_sel_o = 4'b1111;
            else
                dcpu_sel_o = 4'b0000;
        end

        default: dcpu_sel_o = 4'b0000;
    endcase
end

or1200_mem2reg u_or1200_mem2reg (
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .memdata(dcpu_dat_i),
    .regdata(lsu_dataout)
);

or1200_reg2mem u_or1200_reg2mem (
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .regdata(lsu_datain),
    .memdata(dcpu_dat_o)
);

endmodule
