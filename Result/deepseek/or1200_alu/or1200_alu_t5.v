module or1200_alu(
    input [31:0] a,
    input [31:0] b,
    input [31:0] mult_mac_result,
    input macrc_op,
    input [3:0] alu_op,
    input [1:0] shrot_op,
    input [3:0] comp_op,
    input [4:0] cust5_op,
    input [5:0] cust5_limm,
    output reg [31:0] result,
    output reg flagforw,
    output reg flag_we,
    output reg cyforw,
    output reg cy_we,
    input carry,
    input flag
);

// -------------------------------------------------------------------
// Local parameter definitions for operation codes and sub‑opcodes
// -------------------------------------------------------------------
localparam [3:0] OR1200_ALUOP_ADD   = 4'd0;
localparam [3:0] OR1200_ALUOP_ADDC  = 4'd1;
localparam [3:0] OR1200_ALUOP_SUB   = 4'd2;
localparam [3:0] OR1200_ALUOP_AND   = 4'd3;
localparam [3:0] OR1200_ALUOP_OR    = 4'd4;
localparam [3:0] OR1200_ALUOP_XOR   = 4'd5;
localparam [3:0] OR1200_ALUOP_IMM   = 4'd6;
localparam [3:0] OR1200_ALUOP_SHROT = 4'd7;
localparam [3:0] OR1200_ALUOP_COMP  = 4'd8;
localparam [3:0] OR1200_ALUOP_CMOV  = 4'd9;
localparam [3:0] OR1200_ALUOP_MOVHI = 4'd10;
localparam [3:0] OR1200_ALUOP_MUL   = 4'd11;
localparam [3:0] OR1200_ALUOP_DIV   = 4'd12;
localparam [3:0] OR1200_ALUOP_DIVU  = 4'd13;
localparam [3:0] OR1200_ALUOP_FF1   = 4'd14;
localparam [3:0] OR1200_ALUOP_CUST5 = 4'd15;

localparam [1:0] OR1200_SHROTOP_SLL = 2'd0;
localparam [1:0] OR1200_SHROTOP_SRL = 2'd1;
localparam [1:0] OR1200_SHROTOP_ROR = 2'd2;   // only when rotate implemented
localparam [1:0] OR1200_SHROTOP_SRA = 2'd3;   // default (arithmetic right shift)

localparam [3:0] OR1200_COP_SFEQ = 3'd0;
localparam [3:0] OR1200_COP_SFNE = 3'd1;
localparam [3:0] OR1200_COP_SFGT = 3'd2;
localparam [3:0] OR1200_COP_SFGE = 3'd3;
localparam [3:0] OR1200_COP_SFLT = 3'd4;
localparam [3:0] OR1200_COP_SFLE = 3'd5;

// -------------------------------------------------------------------
// Internal wires
// -------------------------------------------------------------------
wire [32:0] sum33;
wire [31:0] result_sum;
wire        cy_sum;

wire [32:0] csum33;
wire [31:0] result_csum;
wire        cy_csum;

wire [31:0] result_and;
wire [31:0] result_or;
wire [31:0] result_xor;
wire [31:0] result_sub;
wire [31:0] result_imm;
wire [31:0] result_movhi;
wire [31:0] result_mul;
wire [31:0] result_div;
wire [31:0] result_divu;
wire [31:0] result_ff1;
wire [31:0] result_cust5;

wire [31:0] comp_a, comp_b;
wire        flagcomp;
wire        a_eq_b, a_lt_b;

wire [4:0] shamt;
wire [31:0] shift_left;
wire [31:0] shift_right_log;
wire [31:0] shift_right_arith;
wire [31:0] rot_right;
reg  [31:0] shifted_rotated;

// -------------------------------------------------------------------
// ADD: 33‑bit sum, cy_sum and result_sum
// -------------------------------------------------------------------
assign sum33 = a + b;
assign cy_sum = sum33[32];
assign result_sum = sum33[31:0];

// -------------------------------------------------------------------
// ADDC: 33‑bit sum with carry (optional)
// -------------------------------------------------------------------
`ifdef OR1200_IMPL_ADDC
  assign csum33 = a + b + {31'd0, carry};
  assign cy_csum = csum33[32];
  assign result_csum = csum33[31:0];
`endif

// -------------------------------------------------------------------
// AND, OR, XOR, SUB, IMM (simple datapath)
// -------------------------------------------------------------------
assign result_and = a & b;
assign result_or  = a | b;
assign result_xor = a ^ b;
assign result_sub = a - b;
assign result_imm = b;

// -------------------------------------------------------------------
// MOVHI: b << 16 or mult_mac_result when macrc_op asserted
// -------------------------------------------------------------------
assign result_movhi = macrc_op ? mult_mac_result : (b << 16);

// -------------------------------------------------------------------
// MUL, DIV, DIVU: transparent pass of mult_mac_result
// -------------------------------------------------------------------
`ifdef OR1200_MULT_IMPLEMENTED
  assign result_mul = mult_mac_result;
  `ifdef OR1200_IMPL_DIV
    assign result_div  = mult_mac_result;
    assign result_divu = mult_mac_result;
  `else
    assign result_div  = 32'd0;
    assign result_divu = 32'd0;
  `endif
`else
  assign result_mul  = 32'd0;
  assign result_div  = 32'd0;
  assign result_divu = 32'd0;
`endif

// -------------------------------------------------------------------
// FF1: find first 1 from LSB
// -------------------------------------------------------------------
integer i;
reg [31:0] ff1_tmp;
always @* begin
  ff1_tmp = 32'd0;
  for (i = 0; i < 32; i = i + 1) begin
    if (a[i]) begin
      ff1_tmp = i + 1;
      i = 32; // break
    end
  end
end
assign result_ff1 = ff1_tmp;

// -------------------------------------------------------------------
// l.cust5 custom operations
// -------------------------------------------------------------------
wire [31:0] byte_ins;
wire [31:0] bit_set;
wire [31:0] bit_clear;

// byte insertion based on cust5_limm[1:0]
assign byte_ins = (cust5_limm[1:0] == 2'd0) ? {a[31:8], b[7:0]} :
                  (cust5_limm[1:0] == 2'd1) ? {a[31:16], b[7:0], a[7:0]} :
                  (cust5_limm[1:0] == 2'd2) ? {a[31:24], b[7:0], a[15:0]} :
                  (cust5_limm[1:0] == 2'd3) ? {b[7:0], a[23:0]} : 32'd0;

assign bit_set   = a | (32'd1 << cust5_limm);
assign bit_clear = a & (32'hffffffff ^ (32'd1 << cust5_limm));

// cust5 final result (default: a)
assign result_cust5 = (cust5_op == 5'h1) ? byte_ins :
                      (cust5_op == 5'h2) ? bit_set :
                      (cust5_op == 5'h3) ? bit_clear :
                                           a;

// -------------------------------------------------------------------
// Shift / rotate combinational block
// -------------------------------------------------------------------
assign shamt = b[4:0];
assign shift_left       = a << shamt;
assign shift_right_log  = a >> shamt;
assign shift_right_arith= ({32{a[31]}} << (6'd32 - {1'b0, shamt})) | (a >> shamt);
assign rot_right        = (a << (6'd32 - {1'b0, shamt})) | (a >> shamt);

always @* begin
  casex (shrot_op)
    OR1200_SHROTOP_SLL: shifted_rotated = shift_left;
    OR1200_SHROTOP_SRL: shifted_rotated = shift_right_log;
    `ifdef OR1200_IMPL_ALU_ROTATE
      OR1200_SHROTOP_ROR: shifted_rotated = rot_right;
    `endif
    default: shifted_rotated = shift_right_arith;    // arithmetic right shift
  endcase
end

// -------------------------------------------------------------------
// Compare block (two implementations, selected by macro)
// -------------------------------------------------------------------
assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
assign comp_b = {b[31] ^ comp_op[3], b[30:0]};

`ifdef OR1200_IMPL_ALU_COMP1
  assign a_eq_b = (comp_a == comp_b);
  assign a_lt_b = (comp_a < comp_b);
  always @* begin
    casex (comp_op[2:0])
      OR1200_COP_SFEQ: flagcomp = a_eq_b;
      OR1200_COP_SFNE: flagcomp = ~a_eq_b;
      OR1200_COP_SFGT: flagcomp = ~a_eq_b & ~a_lt_b;
      OR1200_COP_SFGE: flagcomp = ~a_lt_b;
      OR1200_COP_SFLT: flagcomp = a_lt_b;
      OR1200_COP_SFLE: flagcomp = a_eq_b | a_lt_b;
      default: flagcomp = 1'b0;
    endcase
  end
`elsif OR1200_IMPL_ALU_COMP2
  always @* begin
    casex (comp_op[2:0])
      OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
      OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
      OR1200_COP_SFGT: flagcomp = (comp_a > comp_b);
      OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
      OR1200_COP_SFLT: flagcomp = (comp_a < comp_b);
      OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
      default: flagcomp = 1'b0;
    endcase
  end
`else
  // default behaviour if none defined: always 0
  assign flagcomp = 1'b0;
`endif

// -------------------------------------------------------------------
// Main result mux and flag/carry write enables
// -------------------------------------------------------------------
always @* begin
  // default assignments
  result   = 32'd0;
  flagforw = 1'b0;
  flag_we  = 1'b0;
  cyforw   = 1'b0;
  cy_we    = 1'b0;

  casex (alu_op)
    OR1200_ALUOP_ADD: begin
      result = result_sum;
      `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        flagforw = (result_sum == 32'd0);
        flag_we  = 1'b1;
      `endif
      `ifdef OR1200_IMPL_CY
        cyforw = cy_sum;
        cy_we  = 1'b1;
      `endif
    end

    OR1200_ALUOP_ADDC: begin
      `ifdef OR1200_IMPL_ADDC
        result = result_csum;
        `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
          flagforw = (result_csum == 32'd0);
          flag_we  = 1'b1;
        `endif
        `ifdef OR1200_IMPL_CY
          cyforw = cy_csum;
          cy_we  = 1'b1;
        `endif
      `else
        result = 32'd0;
      `endif
    end

    OR1200_ALUOP_SUB: begin
      result = result_sub;
    end

    OR1200_ALUOP_AND: begin
      result = result_and;
      `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        flagforw = (result_and == 32'd0);
        flag_we  = 1'b1;
      `endif
    end

    OR1200_ALUOP_OR: begin
      result = result_or;
    end

    OR1200_ALUOP_XOR: begin
      result = result_xor;
    end

    OR1200_ALUOP_IMM: begin
      result = result_imm;
    end

    OR1200_ALUOP_SHROT: begin
      result = shifted_rotated;
    end

    OR1200_ALUOP_COMP: begin
      result = 32'd0; // compare does not produce result
      flagforw = flagcomp;
      flag_we  = 1'b1;
    end

    OR1200_ALUOP_CMOV: begin
      result = flag ? a : b;
    end

    OR1200_ALUOP_MOVHI: begin
      result = result_movhi;
    end

    OR1200_ALUOP_MUL: begin
      `ifdef OR1200_MULT_IMPLEMENTED
        result = result_mul;
      `else
        result = 32'd0;
      `endif
    end

    OR1200_ALUOP_DIV: begin
      `ifdef OR1200_MULT_IMPLEMENTED
        `ifdef OR1200_IMPL_DIV
          result = result_div;
        `else
          result = 32'd0;
        `endif
      `else
        result = 32'd0;
      `endif
    end

    OR1200_ALUOP_DIVU: begin
      `ifdef OR1200_MULT_IMPLEMENTED
        `ifdef OR1200_IMPL_DIV
          result = result_divu;
        `else
          result = 32'd0;
        `endif
      `else
        result = 32'd0;
      `endif
    end

    OR1200_ALUOP_FF1: begin
      result = result_ff1;
    end

    OR1200_ALUOP_CUST5: begin
      result = result_cust5;
    end

`ifdef OR1200_CASE_DEFAULT
    default: begin
      result = 32'd0;
      `ifdef OR1200_WARNINGS
        // synthesis translate_off
        $display("or1200_alu: unknown alu_op %h", alu_op);
        // synthesis translate_on
      `endif
    end
`endif
  endcase
end

endmodule
