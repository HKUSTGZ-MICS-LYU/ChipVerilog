module or1200_gmultp2_32x32(
    input [31:0] X,
    input [31:0] Y,
    input CLK,
    input RST,
    output [63:0] P
);

    reg [63:0] p0;
    reg [63:0] p1;

    integer xi, yi;

    always @(*) begin
        xi = X;
        yi = Y;
    end

    always @(posedge CLK) begin
        p0 <= xi * yi;
    end

    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            p1 <= 64'd0;
        end else begin
            p1 <= p0;
        end
    end

    assign P = p1;

endmodule
