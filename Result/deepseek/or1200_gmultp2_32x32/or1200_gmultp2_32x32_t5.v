module or1200_gmultp2_32x32 (
  input [31:0] X,
  input [31:0] Y,
  input CLK,
  input RST,
  output reg [63:0] P
);

`ifdef OR1200_GENERIC_MULTP2_32X32

  integer xi, yi;
  reg [63:0] p0;
  reg [63:0] p1;

  // Capture X and Y into signed integers for multiplication
  always @(X) xi = X;
  always @(Y) yi = Y;

  // First pipeline stage: compute product on CLK rising edge
  always @(posedge CLK) begin
    p0 <= xi * yi;
  end

  // Second pipeline stage: transfer p0 to p1, with asynchronous reset
  always @(posedge CLK or posedge RST) begin
    if (RST)
      p1 <= 64'b0;
    else
      p1 <= p0;
  end

  // Output is continuously driven by p1
  always @(p1) P = p1;

`else
  // If the macro is not defined, output zero as a default
  assign P = 64'b0;
`endif

endmodule
