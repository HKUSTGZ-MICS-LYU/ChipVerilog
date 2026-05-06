`ifndef OR1200_DTAG_IDLE
`define OR1200_DTAG_IDLE 4'b0000
`endif
`ifndef OR1200_DTAG_ND
`define OR1200_DTAG_ND   4'b0001
`endif
`ifndef OR1200_DTAG_TE
`define OR1200_DTAG_TE   4'b0010
`endif
`ifndef OR1200_DTAG_PE
`define OR1200_DTAG_PE   4'b0011
`endif
`ifndef OR1200_DTAG_BE
`define OR1200_DTAG_BE   4'b0100
`endif

`ifndef OR1200_LSUOP_NOP
`define OR1200_LSUOP_NOP 4'b0000
`endif
`ifndef OR1200_LSUOP_LBZ
`define OR1200_LSUOP_LBZ 4'b0001
`endif
`ifndef OR1200_LSUOP_LBS
`define OR1200_LSUOP_LBS 4'b0010
`endif
`ifndef OR1200_LSUOP_LHZ
`define OR1200_LSUOP_LHZ 4'b0011
`endif
`ifndef OR1200_LSUOP_LHS
`define OR1200_LSUOP_LHS 4'b0100
`endif
`ifndef OR1200_LSUOP_LWZ
`define OR1200_LSUOP_LWZ 4'b0101
`endif
`ifndef OR1200_LSUOP_LWS
`define OR1200_LSUOP_LWS 4'b0110
`endif
`ifndef OR1200_LSUOP_SB
`define OR1200_LSUOP_SB  4'b1001
`endif
`ifndef OR1200_LSUOP_SH
`define OR1200_LSUOP_SH  4'b1010
`endif
`ifndef OR1200_LSUOP_SW
`define OR1200_LSUOP_SW  4'b1011
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
wire halfword_op;
wire word_op;
wire valid_lsu_op;

assign dcpu_adr_o = addrbase + addrofs;
assign mem2reg_addr = dcpu_adr_o[1:0];
assign halfword_op = (lsu_op == `OR1200_LSUOP_SH) |
                     (lsu_op == `OR1200_LSUOP_LHZ) |
                     (lsu_op == `OR1200_LSUOP_LHS);
assign word_op = (lsu_op == `OR1200_LSUOP_SW) |
                 (lsu_op == `OR1200_LSUOP_LWZ) |
                 (lsu_op == `OR1200_LSUOP_LWS);
assign valid_lsu_op = |lsu_op;

assign except_align = (halfword_op & mem2reg_addr[0]) |
                      (word_op & (mem2reg_addr != 2'b00));

assign lsu_unstall = dcpu_ack_i;
assign dcpu_cycstb_o = valid_lsu_op & ~du_stall & ~lsu_unstall & ~except_align;
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
            case (mem2reg_addr)
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
            case (mem2reg_addr)
                2'b00: dcpu_sel_o = 4'b1100;
                2'b10: dcpu_sel_o = 4'b0011;
                default: dcpu_sel_o = 4'b0000;
            endcase
        end
        `OR1200_LSUOP_SW,
        `OR1200_LSUOP_LWZ,
        `OR1200_LSUOP_LWS: begin
            if (mem2reg_addr == 2'b00)
                dcpu_sel_o = 4'b1111;
            else
                dcpu_sel_o = 4'b0000;
        end
        default: dcpu_sel_o = 4'b0000;
    endcase
end

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

module or1200_mem2reg(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output reg [31:0] regdata
);

reg [7:0] selected_byte;
reg [15:0] selected_halfword;

always @* begin
    case (addr)
        2'b00: selected_byte = memdata[31:24];
        2'b01: selected_byte = memdata[23:16];
        2'b10: selected_byte = memdata[15:8];
        default: selected_byte = memdata[7:0];
    endcase
end

always @* begin
    case (addr)
        2'b00: selected_halfword = memdata[31:16];
        2'b10: selected_halfword = memdata[15:0];
        default: selected_halfword = 16'h0000;
    endcase
end

always @* begin
    regdata = 32'h0000_0000;
    case (lsu_op)
        `OR1200_LSUOP_LBZ: regdata = {24'h000000, selected_byte};
        `OR1200_LSUOP_LBS: regdata = {{24{selected_byte[7]}}, selected_byte};
        `OR1200_LSUOP_LHZ: regdata = {16'h0000, selected_halfword};
        `OR1200_LSUOP_LHS: regdata = {{16{selected_halfword[15]}}, selected_halfword};
        `OR1200_LSUOP_LWZ,
        `OR1200_LSUOP_LWS: regdata = memdata;
        default: regdata = 32'h0000_0000;
    endcase
end

endmodule

module or1200_reg2mem(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output reg [31:0] memdata
);

always @* begin
    memdata = 32'h0000_0000;
    case (lsu_op)
        `OR1200_LSUOP_SB: begin
            case (addr)
                2'b00: memdata = {regdata[7:0], 24'h000000};
                2'b01: memdata = {8'h00, regdata[7:0], 16'h0000};
                2'b10: memdata = {16'h0000, regdata[7:0], 8'h00};
                2'b11: memdata = {24'h000000, regdata[7:0]};
                default: memdata = 32'h0000_0000;
            endcase
        end
        `OR1200_LSUOP_SH: begin
            case (addr)
                2'b00: memdata = {regdata[15:0], 16'h0000};
                2'b10: memdata = {16'h0000, regdata[15:0]};
                default: memdata = 32'h0000_0000;
            endcase
        end
        `OR1200_LSUOP_SW: memdata = regdata;
        default: memdata = 32'h0000_0000;
    endcase
end

endmodule
