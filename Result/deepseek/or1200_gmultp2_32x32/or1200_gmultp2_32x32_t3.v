module or1200_gmultp2_32x32 (
    input  [31:0] X,
    input  [31:0] Y,
    input         CLK,
    input         RST,
    output [63:0] P
);

    integer xi, yi;
    reg [63:0] p0, p1;

    // Convert inputs to signed integers
    always @*
    begin
        xi = $signed(X);
        yi = $signed(Y);
    end

    // First pipeline stage: capture product into p0
    always @(posedge CLK)
    begin
        p0 <= xi * yi;
    end

    // Second pipeline stage: transfer p0 to p1 with asynchronous reset
    always @(posedge CLK or posedge RST)
    begin
        if (RST)
            p1 <= 64'd0;
        else
            p1 <= p0;
    end

    // Output
    assign P = p1;

endmodule
`endif
