module or1200_gmultp2_32x32(
    input [31:0] X,
    input [31:0] Y,
    input CLK,
    input RST,
    output [63:0] P
);

reg [63:0] p0;
reg [63:0] p1;
integer xi;
integer yi;

always @(X)
    xi = X;

always @(Y)
    yi = Y;

always @(posedge CLK)
    p0 <= xi * yi;

always @(posedge CLK or posedge RST)
    if (RST)
        p1 <= 64'b0;
    else
        p1 <= p0;

assign P = p1;

endmodule
