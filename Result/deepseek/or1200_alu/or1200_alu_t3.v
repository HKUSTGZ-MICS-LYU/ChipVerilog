module or1200_alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] mult_mac_result,
    input         macrc_op,
    input  [3:0] alu_op,
    input  [1:0] shrot_op,
    input  [3:0] comp_op,
    input  [4:0] cust5_op,
    input  [5:0] cust5_limm,
    output [31:0] result,
    output        flagforw,
    output        flag_we,
    output        cyforw,
    output        cy_we,
    input         carry,
    input         flag
);

  // localparam definitions for opcode constants (from or1200_defines.v)
  localparam [3:0] OR1200_ALUOP_ADD   = 4'h0;
  localparam [3:0] OR1200_ALUOP_ADDC  = 4'h1;
  localparam [3:0] OR1200_ALUOP_SUB   = 4'h2;
  localparam [3:0] OR1200_ALUOP_AND   = 4'h3;
  localparam [3:0] OR1200_ALUOP_OR    = 4'h4;
  localparam [3:0] OR1200_ALUOP_XOR   = 4'h5;
  localparam [3:0] OR1200_ALUOP_IMM   = 4'h6;
  localparam [3:0] OR1200_ALUOP_SHROT = 4'h7;
  localparam [3:0] OR1200_ALUOP_CUST5 = 4'h8;
  localparam [3:0] OR1200_ALUOP_CMOV  = 4'h9;
  localparam [3:0] OR1200_ALUOP_MOVHI = 4'ha;
  localparam [3:0] OR1200_ALUOP_MUL   = 4'hb;
  localparam [3:0] OR1200_ALUOP_DIV   = 4'hc;
  localparam [3:0] OR1200_ALUOP_DIVU  = 4'hd;
  localparam [3:0] OR1200_ALUOP_COMP  = 4'he;

  localparam [1:0] OR1200_SHROTOP_SLL = 2'b00;
  localparam [1:0] OR1200_SHROTOP_SRL = 2'b01;
  localparam [1:0] OR1200_SHROTOP_ROR = 2'b10;

  localparam [3:0] OR1200_COP_SFEQ = 3'b000;
  localparam [3:0] OR1200_COP_SFNE = 3'b001;
  localparam [3:0] OR1200_COP_SFGT = 3'b010;
  localparam [3:0] OR1200_COP_SFGE = 3'b011;
  localparam [3:0] OR1200_COP_SFLT = 3'b100;
  localparam [3:0] OR1200_COP_SFLE = 3'b101;

  // Internal wires
  reg  [31:0] result_reg;
  reg         flagforw_reg;
  reg         flag_we_reg;
  reg         cyforw_reg;
  reg         cy_we_reg;

  // ADD / ADDC sums
  wire [32:0] cy_sum_result_sum;
  wire        cy_sum;
  wire [31:0] result_sum;
  assign cy_sum_result_sum = a + b;
  assign {cy_sum, result_sum} = cy_sum_result_sum;

`ifdef OR1200_IMPL_ADDC
  wire [32:0] cy_csum_result_csum;
  wire        cy_csum;
  wire [31:0] result_csum;
  assign cy_csum_result_csum = a + b + {32'd0, carry};
  assign {cy_csum, result_csum} = cy_csum_result_csum;
`endif

  // AND
  wire [31:0] result_and;
  assign result_and = a & b;

  // Compare
  wire [30:0] comp_a_lower, comp_b_lower;
  wire        comp_a_sign, comp_b_sign;
  assign comp_a_sign = a[31] ^ comp_op[3];
  assign comp_b_sign = b[31] ^ comp_op[3];
  assign comp_a_lower = a[30:0];
  assign comp_b_lower = b[30:0];

  wire [31:0] comp_a = {comp_a_sign, comp_a_lower};
  wire [31:0] comp_b = {comp_b_sign, comp_b_lower};

  reg flagcomp;
  reg a_eq_b;
  reg a_lt_b;
  reg comp_ge, comp_gt, comp_le, comp_lt, comp_eq, comp_ne;

  always @(*) begin
`ifdef OR1200_IMPL_ALU_COMP1
    // COMP1 implementation
    a_eq_b = (comp_a == comp_b);
    // unsigned compare for lt: (comp_a < comp_b)
    // For signed compare we already handled sign bit, so unsigned compare works
    a_lt_b = (comp_a < comp_b);
    casex (comp_op[2:0])
      OR1200_COP_SFEQ: flagcomp = a_eq_b;
      OR1200_COP_SFNE: flagcomp = ~a_eq_b;
      OR1200_COP_SFGT: flagcomp = ~a_lt_b & ~a_eq_b;
      OR1200_COP_SFGE: flagcomp = ~a_lt_b;
      OR1200_COP_SFLT: flagcomp = a_lt_b;
      OR1200_COP_SFLE: flagcomp = a_lt_b | a_eq_b;
      default: flagcomp = 1'b0;
    endcase
`elsif OR1200_IMPL_ALU_COMP2
    // COMP2 implementation
    casex (comp_op[2:0])
      OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
      OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
      OR1200_COP_SFGT: flagcomp = (comp_a > comp_b);
      OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
      OR1200_COP_SFLT: flagcomp = (comp_a < comp_b);
      OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
      default: flagcomp = 1'b0;
    endcase
`endif
  end

  // Shift / Rotate
  reg [31:0] shifted_rotated;
  always @(*) begin
    casex (shrot_op)
      OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
      OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
      OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
      default: shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
    endcase
  end

  // FF1
  reg [31:0] ff1_result;
  integer i;
  always @(*) begin
    ff1_result = 32'd0;
    for (i = 0; i < 32; i = i + 1) begin
      if (a[i]) begin
        ff1_result = i + 1;
        disable loop;
      end
    end
  end

  // Custom 5
  reg [31:0] result_cust5;
  always @(*) begin
    casex (cust5_op)
      5'h1: begin
        casex (cust5_limm[1:0])
          2'b00: result_cust5 = {a[31:8], b[7:0]};
          2'b01: result_cust5 = {a[31:16], b[7:0], a[7:0]};
          2'b10: result_cust5 = {a[31:24], b[7:0], a[15:0]};
          2'b11: result_cust5 = {b[7:0], a[23:0]};
          default: result_cust5 = a;
        endcase
      end
      5'h2: begin
        result_cust5 = a | (32'd1 << cust5_limm);
      end
      5'h3: begin
        result_cust5 = a & (32'hffffffff ^ (32'd1 << cust5_limm));
      end
      default: begin
        result_cust5 = a;
      end
    endcase
  end

  // Main result mux
  always @(*) begin
    casex (alu_op)
      OR1200_ALUOP_ADD: result_reg = result_sum;
`ifdef OR1200_IMPL_ADDC
      OR1200_ALUOP_ADDC: result_reg = result_csum;
`endif
      OR1200_ALUOP_SUB: result_reg = a - b;
      OR1200_ALUOP_AND: result_reg = result_and;
      OR1200_ALUOP_OR: result_reg = a | b;
      OR1200_ALUOP_XOR: result_reg = a ^ b;
      OR1200_ALUOP_IMM: result_reg = b;
      OR1200_ALUOP_SHROT: result_reg = shifted_rotated;
      OR1200_ALUOP_CUST5: result_reg = result_cust5;
      OR1200_ALUOP_CMOV: begin
        if (flag) result_reg = a;
        else result_reg = b;
      end
      OR1200_ALUOP_MOVHI: begin
        if (macrc_op) result_reg = mult_mac_result;
        else result_reg = {b[15:0], 16'd0};
      end
`ifdef OR1200_MULT_IMPLEMENTED
      OR1200_ALUOP_MUL: result_reg = mult_mac_result;
`ifdef OR1200_IMPL_DIV
      OR1200_ALUOP_DIV: result_reg = mult_mac_result;
      OR1200_ALUOP_DIVU: result_reg = mult_mac_result;
`endif
`endif
      // FF1 is not tied to any specific alu_op in the spec; it's used elsewhere.
      // If needed, could be mapped to an operation. Not specified, so we ignore.
      default: result_reg = 32'd0;
    endcase
  end

  // Flag and carry write enables and values
  always @(*) begin
    flagforw_reg = 1'b0;
    flag_we_reg = 1'b0;
    cyforw_reg = 1'b0;
    cy_we_reg = 1'b0;

    casex (alu_op)
      OR1200_ALUOP_COMP: begin
        flagforw_reg = flagcomp;
        flag_we_reg = 1'b1;
      end
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
      OR1200_ALUOP_ADD: begin
        flagforw_reg = (result_sum == 32'd0);
        flag_we_reg = 1'b1;
      end
`ifdef OR1200_IMPL_ADDC
      OR1200_ALUOP_ADDC: begin
        flagforw_reg = (result_csum == 32'd0);
        flag_we_reg = 1'b1;
      end
`endif
      OR1200_ALUOP_AND: begin
        flagforw_reg = (result_and == 32'd0);
        flag_we_reg = 1'b1;
      end
`endif
      default: begin
        // flagforw and flag_we remain zero
      end
    endcase

`ifdef OR1200_IMPL_CY
    casex (alu_op)
      OR1200_ALUOP_ADD: begin
        cyforw_reg = cy_sum;
        cy_we_reg = 1'b1;
      end
`ifdef OR1200_IMPL_ADDC
      OR1200_ALUOP_ADDC: begin
        cyforw_reg = cy_csum;
        cy_we_reg = 1'b1;
      end
`endif
      default: begin
        // cyforw and cy_we remain zero
      end
    endcase
`endif
  end

  assign result = result_reg;
  assign flagforw = flagforw_reg;
  assign flag_we = flag_we_reg;
  assign cyforw = cyforw_reg;
  assign cy_we = cy_we_reg;

endmodule
