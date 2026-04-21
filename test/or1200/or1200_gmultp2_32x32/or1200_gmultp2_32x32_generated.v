`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

`ifdef OR1200_GENERIC_MULTP2_32X32

module or1200_gmultp2_32x32 (
    X,
    Y,
    CLK,
    RST,
    P
);

input  [31:0] X;
input  [31:0] Y;
input         CLK;
input         RST;
output [63:0] P;

reg    [63:0] p0;
reg    [63:0] p1;
integer       xi;
integer       yi;

// Convert 32-bit inputs into signed Verilog integer operands.
always @(*) begin
    xi = X;
end

always @(*) begin
    yi = Y;
end

// Stage 1: multiply every cycle.
always @(posedge CLK) begin
    p0 <= xi * yi;
end

// Stage 2: registered output, asynchronously reset.
always @(posedge CLK or posedge RST) begin
    if (RST)
        p1 <= 64'b0;
    else
        p1 <= p0;
end

assign P = p1;

endmodule

`endif
