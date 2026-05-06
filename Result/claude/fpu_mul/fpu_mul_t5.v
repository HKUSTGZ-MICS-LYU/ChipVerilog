// Generated from: Description/fpu_mul_description.txt
// This implementation keeps the described interfaces/timing style, but uses a direct
// 53x53 multiply to form the 106-bit product (synthesizable on most toolflows).
module fpu_mul (
    input         clk,
    input         rst,
    input         enable,
    input  [63:0] opa,
    input  [63:0] opb,
    output reg        sign,
    output     [55:0] product_7,
    output reg [11:0] exponent_5
);

  // Registered operand fields
  reg [51:0] mantissa_a, mantissa_b;
  reg [10:0] exponent_a, exponent_b;
  reg        a_is_norm, b_is_norm;
  reg        a_is_zero, b_is_zero;
  reg        in_zero;

  reg [52:0] mul_a, mul_b;

  // Product pipeline
  reg [105:0] product, product_1, product_2, product_3, product_4, product_5, product_6;
  reg         product_lsb;

  // Exponent pipeline
  reg [11:0] exponent_terms;
  reg [11:0] exponent_1, exponent_2, exponent_3, exponent_4;
  reg        exponent_et_zero;

  // Leading-one/zero based shift amount for product normalization
  reg [5:0] product_shift;
  reg [5:0] product_shift_2;

  // A simple leading-one position detector for product[105:52] region
  // product_shift indicates how many left shifts are needed to bring the leading 1 to bit 105.
  // If already normalized (product[105]==1), shift is 0.
  integer k;
  always @* begin
    product_shift = 6'd0;
    if (product[105]) begin
      product_shift = 6'd0;
    end else begin
      product_shift = 6'd53;
      for (k = 104; k >= 52; k = k - 1) begin
        if (product[k] && (product_shift == 6'd53)) begin
          product_shift = (7'd105 - {1'b0, k[5:0]});
        end
      end
    end
  end

  // Combinational output bundle
  assign product_7 = {1'b0, product_6[105:52], product_lsb};

  always @(posedge clk) begin
    if (rst) begin
      sign <= 1'b0;
      mantissa_a <= 52'd0; mantissa_b <= 52'd0;
      exponent_a <= 11'd0; exponent_b <= 11'd0;
      a_is_norm <= 1'b0; b_is_norm <= 1'b0;
      a_is_zero <= 1'b0; b_is_zero <= 1'b0;
      in_zero <= 1'b0;
      mul_a <= 53'd0; mul_b <= 53'd0;

      exponent_terms <= 12'd0;
      exponent_1 <= 12'd0; exponent_2 <= 12'd0; exponent_3 <= 12'd0; exponent_4 <= 12'd0;
      exponent_5 <= 12'd0;
      exponent_et_zero <= 1'b0;
      product <= 106'd0; product_1 <= 106'd0; product_2 <= 106'd0; product_3 <= 106'd0;
      product_4 <= 106'd0; product_5 <= 106'd0; product_6 <= 106'd0;
      product_lsb <= 1'b0;
      product_shift_2 <= 6'd0;
    end else if (enable) begin
      // Sign is produced directly from current operands (as in description warning)
      sign <= opa[63] ^ opb[63];

      exponent_a <= opa[62:52];
      exponent_b <= opb[62:52];
      mantissa_a <= opa[51:0];
      mantissa_b <= opb[51:0];

      a_is_norm <= (opa[62:52] != 11'd0);
      b_is_norm <= (opb[62:52] != 11'd0);
      a_is_zero <= (opa[62:0] == 63'd0);
      b_is_zero <= (opb[62:0] == 63'd0);
      in_zero   <= a_is_zero | b_is_zero;

      mul_a <= {a_is_norm, mantissa_a};
      mul_b <= {b_is_norm, mantissa_b};

      product <= mul_a * mul_b;

      // Exponent terms and bias correction (using 1022 per description)
      exponent_terms <= exponent_a + exponent_b + (~a_is_norm) + (~b_is_norm);
      // Candidate exponent: exponent_terms - 1022 (clamped for zero inputs later)
      exponent_1 <= (exponent_terms > 12'd1021) ? (exponent_terms - 12'd1022) : 12'd0;

      // Pipeline product and exponent
      product_1 <= product;
      product_shift_2 <= product_shift;
      exponent_2 <= exponent_1;

      // Normalize: shift left by product_shift_2 if exponent allows, else produce denorm-like shift
      if (exponent_2 > {6'd0, product_shift_2}) begin
        product_2 <= product_1 << product_shift_2;
        exponent_3 <= exponent_2 - {6'd0, product_shift_2};
      end else begin
        // Not enough exponent headroom; shift left only by exponent_2 (push toward denorm)
        product_2 <= product_1 << exponent_2[5:0];
        exponent_3 <= 12'd0;
      end

      product_3 <= product_2;
      exponent_4 <= exponent_3;

      exponent_et_zero <= (exponent_4 == 12'd0);
      if (exponent_et_zero) begin
        product_4 <= (product_3 >> 1);
      end else begin
        product_4 <= product_3;
      end

      // Sticky (simplified): OR-reduce discarded low bits below bit 52
      product_lsb <= |product_4[51:0];

      product_5 <= product_4;
      product_6 <= product_5;

      exponent_5 <= in_zero ? 12'd0 : exponent_4;
    end
  end
endmodule

