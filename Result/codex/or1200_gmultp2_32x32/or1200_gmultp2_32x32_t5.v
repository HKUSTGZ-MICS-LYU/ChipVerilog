module or1200_gmultp2_32x32(
    input [31:0] X,
    input [31:0] Y,
    input CLK,
    input RST,
    output [63:0] P
);
reg signed [63:0] p0, p1;
always @(posedge CLK) p0 <= $signed(X) * $signed(Y);
always @(posedge CLK or posedge RST) begin
    if (RST) p1 <= 64'h0;
    else p1 <= p0;
end
assign P = p1;
endmodule
