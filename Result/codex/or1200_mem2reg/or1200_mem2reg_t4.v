`include "or1200_defines.v"

module or1200_mem2reg(
    input  [1:0]  addr,
    input  [3:0]  lsu_op,
    input  [31:0] memdata,
    output [31:0] regdata
);

reg [31:0] aligned;
reg [31:0] regdata_r;

always @* begin
    case (addr)
        2'b00: aligned = memdata;
        2'b01: aligned = {memdata[23:0], 8'b0};
        2'b10: aligned = {memdata[15:0], 16'b0};
        2'b11: aligned = {memdata[7:0], 24'b0};
        default: aligned = memdata;
    endcase
end

always @* begin
    case (lsu_op)
        `OR1200_LSUOP_LBZ: regdata_r = {24'b0, aligned[31:24]};
        `OR1200_LSUOP_LBS: regdata_r = {{24{aligned[31]}}, aligned[31:24]};
        `OR1200_LSUOP_LHZ: regdata_r = {16'b0, aligned[31:16]};
        `OR1200_LSUOP_LHS: regdata_r = {{16{aligned[31]}}, aligned[31:16]};
        default:           regdata_r = aligned;
    endcase
end

assign regdata = regdata_r;

endmodule
