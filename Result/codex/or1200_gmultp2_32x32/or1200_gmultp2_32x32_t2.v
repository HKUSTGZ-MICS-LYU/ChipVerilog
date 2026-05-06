// Generated from or1200_gmultp2_32x32/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_gmultp2_32x32(
    input [31:0] X,
    input [31:0] Y,
    input CLK,
    input RST,
    output [63:0] P
);

reg [63:0] P_r;
assign P = P_r;

always @(posedge CLK or posedge RST) begin
    if (RST)
        P_r <= 64'd0;
    else
        P_r <= X * Y;
end

endmodule
