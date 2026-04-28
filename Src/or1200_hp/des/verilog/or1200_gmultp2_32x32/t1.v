`include "timescale.v"
`include "or1200_defines.v"

`ifdef OR1200_GENERIC_MULTP2_32X32

module or1200_gmultp2_32x32(
    input  [31:0] X,
    input  [31:0] Y,
    input         CLK,
    input         RST,
    output [63:0] P
);

reg [63:0] p0;
reg [63:0] p1;

integer xi;
integer yi;

assign P = p1;

always @(X or Y) begin
    xi = X;
    yi = Y;
end

// Stage 1: compute product
always @(posedge CLK) begin
    p0 <= xi * yi;
end

// Stage 2: pipeline with async reset
always @(posedge CLK or posedge RST) begin
    if (RST)
        p1 <= 64'h0;
    else
        p1 <= p0;
end

endmodule

`endif