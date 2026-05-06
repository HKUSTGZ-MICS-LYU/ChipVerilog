module signed_shifter #(
  parameter XY_BITS = 15,
  parameter ITERATION_BITS = 4
) (
  input  wire [ITERATION_BITS-1:0] i,
  input  wire signed [XY_BITS:0]   D,
  output reg  signed [XY_BITS:0]   Q
);

  integer j;

  always @* begin
    Q = D;
    for (j = 0; j < i; j = j + 1) begin
      Q = {D[XY_BITS], Q[XY_BITS:1]};
    end
  end

endmodule
