module or1200_lsu #(
    parameter [3:0] OR1200_LSUOP_NOP = 4'b0000,
    parameter [3:0] OR1200_LSUOP_LBZ = 4'b0001,
    parameter [3:0] OR1200_LSUOP_LBS = 4'b0010,
    parameter [3:0] OR1200_LSUOP_LHZ = 4'b0011,
    parameter [3:0] OR1200_LSUOP_LHS = 4'b0100,
    parameter [3:0] OR1200_LSUOP_LWZ = 4'b0101,
    parameter [3:0] OR1200_LSUOP_LWS = 4'b0110,
    parameter [3:0] OR1200_LSUOP_SB  = 4'b1000,
    parameter [3:0] OR1200_LSUOP_SH  = 4'b1001,
    parameter [3:0] OR1200_LSUOP_SW  = 4'b1010,
    parameter [3:0] OR1200_DTAG_IDLE = 4'b0000,
    parameter [3:0] OR1200_DTAG_ND   = 4'b0001,
    parameter [3:0] OR1200_DTAG_TE   = 4'b0010,
    parameter [3:0] OR1200_DTAG_PE   = 4'b0100,
    parameter [3:0] OR1200_DTAG_BE   = 4'b1000
)(
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
    output [3:0] dcpu_sel_o,
    output [3:0] dcpu_tag_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i,
    input dcpu_rty_i,
    input dcpu_err_i,
    input [3:0] dcpu_tag_i
);

reg [3:0] dcpu_sel_o;
wire [1:0] mem2reg_addr;
wire halfword_op;
wire word_op;

assign dcpu_adr_o = addrbase + addrofs;
assign mem2reg_addr = dcpu_adr_o[1:0];

assign halfword_op = (lsu_op == OR1200_LSUOP_SH) |
                     (lsu_op == OR1200_LSUOP_LHZ) |
                     (lsu_op == OR1200_LSUOP_LHS);
assign word_op = (lsu_op == OR1200_LSUOP_SW) |
                 (lsu_op == OR1200_LSUOP_LWZ) |
                 (lsu_op == OR1200_LSUOP_LWS);

assign except_align = (halfword_op & mem2reg_addr[0]) |
                      (word_op & (mem2reg_addr != 2'b00));

assign lsu_unstall = dcpu_ack_i;
assign dcpu_cycstb_o = (|lsu_op) & ~du_stall & ~lsu_unstall & ~except_align;
assign lsu_stall = dcpu_rty_i & dcpu_cycstb_o;
assign dcpu_we_o = lsu_op[3];
assign dcpu_tag_o = dcpu_cycstb_o ? OR1200_DTAG_ND : OR1200_DTAG_IDLE;

assign except_dtlbmiss = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_TE);
assign except_dmmufault = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_PE);
assign except_dbuserr = dcpu_err_i & (dcpu_tag_i == OR1200_DTAG_BE);

always @* begin
    dcpu_sel_o = 4'b0000;
    case (lsu_op)
        OR1200_LSUOP_SB,
        OR1200_LSUOP_LBZ,
        OR1200_LSUOP_LBS: begin
            case (mem2reg_addr)
                2'b00: dcpu_sel_o = 4'b1000;
                2'b01: dcpu_sel_o = 4'b0100;
                2'b10: dcpu_sel_o = 4'b0010;
                2'b11: dcpu_sel_o = 4'b0001;
            endcase
        end
        OR1200_LSUOP_SH,
        OR1200_LSUOP_LHZ,
        OR1200_LSUOP_LHS: begin
            case (mem2reg_addr)
                2'b00: dcpu_sel_o = 4'b1100;
                2'b10: dcpu_sel_o = 4'b0011;
                default: dcpu_sel_o = 4'b0000;
            endcase
        end
        OR1200_LSUOP_SW,
        OR1200_LSUOP_LWZ,
        OR1200_LSUOP_LWS: begin
            case (mem2reg_addr)
                2'b00: dcpu_sel_o = 4'b1111;
                default: dcpu_sel_o = 4'b0000;
            endcase
        end
        default: dcpu_sel_o = 4'b0000;
    endcase
end

or1200_mem2reg #(
    .OR1200_LSUOP_LBZ(OR1200_LSUOP_LBZ),
    .OR1200_LSUOP_LBS(OR1200_LSUOP_LBS),
    .OR1200_LSUOP_LHZ(OR1200_LSUOP_LHZ),
    .OR1200_LSUOP_LHS(OR1200_LSUOP_LHS),
    .OR1200_LSUOP_LWZ(OR1200_LSUOP_LWZ),
    .OR1200_LSUOP_LWS(OR1200_LSUOP_LWS)
) u_mem2reg (
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .memdata(dcpu_dat_i),
    .regdata(lsu_dataout)
);

or1200_reg2mem #(
    .OR1200_LSUOP_SB(OR1200_LSUOP_SB),
    .OR1200_LSUOP_SH(OR1200_LSUOP_SH),
    .OR1200_LSUOP_SW(OR1200_LSUOP_SW)
) u_reg2mem (
    .addr(mem2reg_addr),
    .lsu_op(lsu_op),
    .regdata(lsu_datain),
    .memdata(dcpu_dat_o)
);

endmodule

module or1200_mem2reg #(
    parameter [3:0] OR1200_LSUOP_LBZ = 4'b0001,
    parameter [3:0] OR1200_LSUOP_LBS = 4'b0010,
    parameter [3:0] OR1200_LSUOP_LHZ = 4'b0011,
    parameter [3:0] OR1200_LSUOP_LHS = 4'b0100,
    parameter [3:0] OR1200_LSUOP_LWZ = 4'b0101,
    parameter [3:0] OR1200_LSUOP_LWS = 4'b0110
)(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] memdata,
    output reg [31:0] regdata
);

always @* begin
    regdata = 32'b0;
    case (lsu_op)
        OR1200_LSUOP_LBZ: begin
            case (addr)
                2'b00: regdata = {24'b0, memdata[31:24]};
                2'b01: regdata = {24'b0, memdata[23:16]};
                2'b10: regdata = {24'b0, memdata[15:8]};
                2'b11: regdata = {24'b0, memdata[7:0]};
            endcase
        end
        OR1200_LSUOP_LBS: begin
            case (addr)
                2'b00: regdata = {{24{memdata[31]}}, memdata[31:24]};
                2'b01: regdata = {{24{memdata[23]}}, memdata[23:16]};
                2'b10: regdata = {{24{memdata[15]}}, memdata[15:8]};
                2'b11: regdata = {{24{memdata[7]}}, memdata[7:0]};
            endcase
        end
        OR1200_LSUOP_LHZ: begin
            case (addr)
                2'b00: regdata = {16'b0, memdata[31:16]};
                2'b10: regdata = {16'b0, memdata[15:0]};
                default: regdata = 32'b0;
            endcase
        end
        OR1200_LSUOP_LHS: begin
            case (addr)
                2'b00: regdata = {{16{memdata[31]}}, memdata[31:16]};
                2'b10: regdata = {{16{memdata[15]}}, memdata[15:0]};
                default: regdata = 32'b0;
            endcase
        end
        OR1200_LSUOP_LWZ,
        OR1200_LSUOP_LWS: regdata = memdata;
        default: regdata = 32'b0;
    endcase
end

endmodule

module or1200_reg2mem #(
    parameter [3:0] OR1200_LSUOP_SB = 4'b1000,
    parameter [3:0] OR1200_LSUOP_SH = 4'b1001,
    parameter [3:0] OR1200_LSUOP_SW = 4'b1010
)(
    input [1:0] addr,
    input [3:0] lsu_op,
    input [31:0] regdata,
    output reg [31:0] memdata
);

always @* begin
    memdata = 32'b0;
    case (lsu_op)
        OR1200_LSUOP_SB: begin
            case (addr)
                2'b00: memdata = {regdata[7:0], 24'b0};
                2'b01: memdata = {8'b0, regdata[7:0], 16'b0};
                2'b10: memdata = {16'b0, regdata[7:0], 8'b0};
                2'b11: memdata = {24'b0, regdata[7:0]};
            endcase
        end
        OR1200_LSUOP_SH: begin
            case (addr)
                2'b00: memdata = {regdata[15:0], 16'b0};
                2'b10: memdata = {16'b0, regdata[15:0]};
                default: memdata = 32'b0;
            endcase
        end
        OR1200_LSUOP_SW: memdata = regdata;
        default: memdata = 32'b0;
    endcase
end

endmodule
