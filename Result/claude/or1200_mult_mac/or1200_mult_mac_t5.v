// Generated from: Description/or1200_mult_mac_description.txt
module or1200_mult_mac(
    input         clk,
    input         rst,
    input         ex_freeze,
    input         id_macrc_op,
    input         macrc_op,
    input  [31:0] a,
    input  [31:0] b,
    input  [1:0]  mac_op,
    input  [3:0]  alu_op,
    output [31:0] result,
    output        mac_stall_r,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`include "or1200_defines.v"

`ifdef OR1200_MULT_IMPLEMENTED
  // Division op decode (when implemented)
`ifdef OR1200_IMPL_DIV
  wire alu_op_div      = (alu_op == `OR1200_ALUOP_DIV);
  wire alu_op_divu     = (alu_op == `OR1200_ALUOP_DIVU);
  wire alu_op_div_divu = alu_op_div | alu_op_divu;
`else
  wire alu_op_div      = 1'b0;
  wire alu_op_divu     = 1'b0;
  wire alu_op_div_divu = 1'b0;
`endif

  // Mult/MAC op activity
  wire alu_op_mul = (alu_op == `OR1200_ALUOP_MUL);
  wire mac_active = |mac_op;

  // Preprocess operands for signed division abs()
  wire [31:0] a_abs = (alu_op_div && a[31]) ? (~a + 32'd1) : a;
  wire [31:0] b_abs = (alu_op_div && b[31]) ? (~b + 32'd1) : b;

  // Low-power gating (optional)
`ifdef OR1200_LOWPWR_MULT
  wire [31:0] x = (alu_op_div_divu | alu_op_mul | mac_active) ? a_abs : 32'd0;
  wire [31:0] y = (alu_op_div_divu | alu_op_mul | mac_active) ? b_abs : 32'd0;
`else
  wire [31:0] x = a_abs;
  wire [31:0] y = b_abs;
`endif

  // Multiplier instance selection
  wire [63:0] mul_prod;
`ifdef OR1200_ASIC_MULTP2_32X32
  or1200_amultp2_32x32 u_mult(.X(x), .Y(y), .CLK(clk), .RST(rst), .P(mul_prod));
`else
  or1200_gmultp2_32x32 u_mult(.X(x), .Y(y), .CLK(clk), .RST(rst), .P(mul_prod));
`endif

  reg [63:0] mul_prod_r;

`ifdef OR1200_IMPL_DIV
  reg        div_free;
  reg [5:0]  div_cntr;
  wire [31:0] div_tmp = mul_prod_r[63:32] - y;
`endif

  // MAC pipeline and accumulator
`ifdef OR1200_MAC_IMPLEMENTED
  reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
  reg [63:0] mac_r;
  reg mac_stall_rr;
  assign mac_stall_r = mac_stall_rr;

  wire spr_maclo_we = spr_cs & spr_write & spr_addr[0];
  wire spr_machi_we = spr_cs & spr_write & ~spr_addr[0];

  assign spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
`else
  assign mac_stall_r = 1'b0;
  assign spr_dat_o   = 32'd0;
`endif

  // mul_prod_r / divider working register
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      mul_prod_r <= 64'd0;
`ifdef OR1200_IMPL_DIV
      div_free <= 1'b1;
      div_cntr <= 6'd0;
`endif
    end else begin
`ifdef OR1200_IMPL_DIV
      if (div_cntr != 6'd0) begin
        // Iteration
        if (div_tmp[31]) begin
          mul_prod_r <= {mul_prod_r[62:0], 1'b0};
        end else begin
          mul_prod_r <= {div_tmp, mul_prod_r[31:0], 1'b1};
        end
        div_cntr <= div_cntr - 6'd1;
        div_free <= 1'b0;
      end else if (alu_op_div_divu && div_free) begin
        // Start new divide
        mul_prod_r <= {31'b0, x, 1'b0};
        div_cntr <= 6'd32;
        div_free <= 1'b0;
      end else if (div_free || !ex_freeze) begin
        mul_prod_r <= mul_prod;
        div_free <= 1'b1;
      end
`else
      if (!ex_freeze) begin
        mul_prod_r <= mul_prod;
      end
`endif
    end
  end

`ifdef OR1200_MAC_IMPLEMENTED
  // MAC op pipeline
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      mac_op_r1 <= 2'b00;
      mac_op_r2 <= 2'b00;
      mac_op_r3 <= 2'b00;
    end else begin
      mac_op_r1 <= mac_op;
      mac_op_r2 <= mac_op_r1;
      mac_op_r3 <= mac_op_r2;
    end
  end

  // MAC accumulator update priority
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      mac_r <= 64'd0;
    end else begin
`ifdef OR1200_MAC_SPR_WE
      if (spr_maclo_we) mac_r[31:0] <= spr_dat_i;
      if (spr_machi_we) mac_r[63:32] <= spr_dat_i;
      if (spr_maclo_we || spr_machi_we) begin
        // keep other half as is
      end else
`endif
      if (mac_op_r3 == `OR1200_MACOP_MAC) begin
        mac_r <= mac_r + mul_prod_r;
      end else if (mac_op_r3 == `OR1200_MACOP_MSB) begin
        mac_r <= mac_r - mul_prod_r;
      end else if (macrc_op && !ex_freeze) begin
        mac_r <= 64'd0;
      end
    end
  end

  // Stall generation (inside MAC implementation branch, as described)
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      mac_stall_rr <= 1'b0;
    end else begin
`ifdef OR1200_IMPL_DIV
      mac_stall_rr <= (|mac_op) | ((|mac_op_r1 | |mac_op_r2) & id_macrc_op) | (div_cntr != 6'd0);
`else
      mac_stall_rr <= (|mac_op) | ((|mac_op_r1 | |mac_op_r2) & id_macrc_op);
`endif
    end
  end
`endif

  // Result selection
  reg [31:0] result_r;
  assign result = result_r;
  always @* begin
    result_r = 32'd0;
`ifdef OR1200_IMPL_DIV
    if (alu_op_div) begin
      result_r = (a[31] ^ b[31]) ? (~mul_prod_r[31:0] + 32'd1) : mul_prod_r[31:0];
    end else if (alu_op_divu) begin
      result_r = mul_prod_r[31:0];
    end else
`endif
    if (alu_op_mul) begin
      result_r = mul_prod_r[31:0];
    end else begin
`ifdef OR1200_MAC_IMPLEMENTED
      result_r = mac_r[31:0];
`else
      result_r = 32'd0;
`endif
    end
  end

`else
  assign result = 32'd0;
  assign mac_stall_r = 1'b0;
  assign spr_dat_o = 32'd0;
`endif

endmodule
