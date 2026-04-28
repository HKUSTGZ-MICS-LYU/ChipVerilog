`include "timescale.v"
`include "or1200_defines.v"

module or1200_mem2reg(
    addr,
    lsu_op,
    memdata,
    regdata
);

input  [1:0]  addr;
input  [3:0]  lsu_op;
input  [31:0] memdata;
output [31:0] regdata;

reg [7:0]  regdata_hh;
reg [7:0]  regdata_hl;
reg [7:0]  regdata_lh;
reg [7:0]  regdata_ll;
reg [31:0] regdata;

// Select target byte according to addr[1:0]
// addr=00 -> byte in memdata[31:24] (MSB)
// addr=01 -> byte in memdata[23:16]
// addr=10 -> byte in memdata[15:8]
// addr=11 -> byte in memdata[7:0] (LSB)
wire [7:0] byte_sel =
    (addr == 2'b00) ? memdata[31:24] :
    (addr == 2'b01) ? memdata[23:16] :
    (addr == 2'b10) ? memdata[15:8]  :
                      memdata[7:0];

// Select target halfword according to addr[1]
// addr[1]=0 -> upper halfword memdata[31:16]
// addr[1]=1 -> lower halfword memdata[15:0]
wire [15:0] hword_sel =
    (addr[1] == 1'b0) ? memdata[31:16] : memdata[15:0];

always @(lsu_op or addr or memdata or byte_sel or hword_sel) begin
    case (lsu_op)

        // Unsigned byte load
        `OR1200_LSUOP_LBZ: begin
            regdata_hh = 8'h00;
            regdata_hl = 8'h00;
            regdata_lh = 8'h00;
            regdata_ll = byte_sel;
        end

        // Signed byte load
        `OR1200_LSUOP_LBS: begin
            regdata_hh = {8{byte_sel[7]}};
            regdata_hl = {8{byte_sel[7]}};
            regdata_lh = {8{byte_sel[7]}};
            regdata_ll = byte_sel;
        end

        // Unsigned halfword load
        `OR1200_LSUOP_LHZ: begin
            regdata_hh = 8'h00;
            regdata_hl = 8'h00;
            regdata_lh = hword_sel[15:8];
            regdata_ll = hword_sel[7:0];
        end

        // Signed halfword load
        `OR1200_LSUOP_LHS: begin
            regdata_hh = {8{hword_sel[15]}};
            regdata_hl = {8{hword_sel[15]}};
            regdata_lh = hword_sel[15:8];
            regdata_ll = hword_sel[7:0];
        end

        // Word load
        `OR1200_LSUOP_LWZ,
        `OR1200_LSUOP_LWS: begin
            regdata_hh = memdata[31:24];
            regdata_hl = memdata[23:16];
            regdata_lh = memdata[15:8];
            regdata_ll = memdata[7:0];
        end

        default: begin
            regdata_hh = 8'h00;
            regdata_hl = 8'h00;
            regdata_lh = 8'h00;
            regdata_ll = 8'h00;
        end

    endcase

    regdata = {regdata_hh, regdata_hl, regdata_lh, regdata_ll};
end

endmodule