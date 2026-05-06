module or1200_mult_mac(
  input clk,
  input rst,
  input ex_freeze,
  input id_macrc_op,
  input macrc_op,
  input [31:0] a,
  input [31:0] b,
  input [1:0] mac_op,
  input [3:0] alu_op,
  output [31:0] result,
  output mac_stall_r,
  input spr_cs,
  input spr_write,
  input [31:0] spr_addr,
  input [31:0] spr_dat_i,
  output [31:0] spr_dat_o
);

`ifdef OR1200_MULT_IMPLEMENTED
  reg [63:0] mul_prod_r;
  wire [63:0] mul_prod;
`else
  wire [63:0] mul_prod;
  wire [63:0] mul_prod_r;
`endif

`ifdef OR1200_MAC_IMPLEMENTED
  reg [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
  reg [63:0] mac_r;
  reg mac_stall_r;
`else
  wire [1:0] mac_op_r1, mac_op_r2, mac_op_r3;
  wire [63:0] mac_r;
  wire mac_stall_r;
`endif

  wire [31:0] x, y;
  wire spr_maclo_we, spr_machi_we;
  wire alu_op_div_divu, alu_op_div;
  reg div_free;
  wire [31:0] div_tmp;
  reg [5:0] div_cntr;

  assign alu_op_div = (alu_op == 4'b0011); // Signed DIV
  assign alu_op_div_divu = (alu_op == 4'b0011) || (alu_op == 4'b0100); // DIV or DIVU

  // Operand preprocessing
  assign x = (alu_op_div && a[31]) ? (~a + 1) : a;
  assign y = (alu_op_div && b[31]) ? (~b + 1) : b;

`ifdef OR1200_LOWPWR_MULT
  wire lowpwr_active = alu_op_div_divu || (alu_op == 4'b0101) || (|mac_op);
  wire [31:0] x_lp = lowpwr_active ? x : 32'b0;
  wire [31:0] y_lp = lowpwr_active ? y : 32'b0;
`else
  wire [31:0] x_lp = x;
  wire [31:0] y_lp = y;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
  `ifdef OR1200_ASIC_MULTP2_32X32
    or1200_amultp2_32x32 mult(.x(x_lp), .y(y_lp), .p(mul_prod));
  `else
    or1200_gmultp2_32x32 mult(.x(x_lp), .y(y_lp), .p(mul_prod));
  `endif
`else
  assign mul_prod = 64'b0;
  assign mul_prod_r = 64'b0;
`endif

`ifdef OR1200_IMPL_DIV
  assign div_tmp = mul_prod_r[63:32] - y_lp;

  always @(posedge rst or posedge clk) begin
    if (rst) begin
      `ifdef OR1200_MULT_IMPLEMENTED
        mul_prod_r <= 64'b0;
      `endif
      div_free <= 1'b1;
      div_cntr <= 6'b0;
    end else begin
      if (div_cntr > 0) begin
        if (div_tmp[31])
          mul_prod_r <= {mul_prod_r[62:0], 1'b0};
        else
          mul_prod_r <= {div_tmp[30:0], mul_prod_r[30:0], 1'b1};
        div_cntr <= div_cntr - 1;
        div_free <= 1'b0;
      end else if (alu_op_div_divu && div_free) begin
        mul_prod_r <= {31'b0, x_lp, 1'b0};
        div_cntr <= 6'd32;
        div_free <= 1'b0;
      end else if (!ex_freeze || div_free) begin
        `ifdef OR1200_MULT_IMPLEMENTED
          mul_prod_r <= mul_prod;
        `endif
        div_free <= 1'b1;
      end
    end
  end
`else
  always @(posedge rst or posedge clk) begin
    if (rst) begin
      `ifdef OR1200_MULT_IMPLEMENTED
        mul_prod_r <= 64'b0;
      `endif
      div_free <= 1'b1;
      div_cntr <= 6'b0;
    end else begin
      if (!ex_freeze || div_free) begin
        `ifdef OR1200_MULT_IMPLEMENTED
          mul_prod_r <= mul_prod;
        `endif
        div_free <= 1'b1;
      end
    end
  end
`endif

  wire [31:0] div_result = alu_op_div ? 
    ((a[31] ^ b[31]) ? (~mul_prod_r[31:0] + 1) : mul_prod_r[31:0]) : mul_prod_r[31:0];

  assign result = (alu_op_div_divu) ? div_result :
                  (alu_op == 4'b0101) ? mul_prod_r[31:0] :
                  mac_r[31:0];

`ifdef OR1200_MAC_IMPLEMENTED
  assign spr_maclo_we = spr_cs && spr_write && spr_addr[0];
  assign spr_machi_we = spr_cs && spr_write && !spr_addr[0];

  assign spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];

  always @(posedge rst or posedge clk) begin
    if (rst) begin
      mac_op_r1 <= 2'b0;
      mac_op_r2 <= 2'b0;
      mac_op_r3 <= 2'b0;
      mac_r <= 64'b0;
      mac_stall_r <= 1'b0;
    end else begin
      mac_op_r1 <= mac_op;
      mac_op_r2 <= mac_op_r1;
      mac_op_r3 <= mac_op_r2;

      `ifdef OR1200_MAC_SPR_WE
        if (spr_maclo_we)
          mac_r[31:0] <= spr_dat_i;
        else if (spr_machi_we)
          mac_r[63:32] <= spr_dat_i;
        else if (mac_op_r3 == 2'b01) // MAC
          mac_r <= mac_r + mul_prod_r;
        else if (mac_op_r3 == 2'b10) // MSB
          mac_r <= mac_r - mul_prod_r;
        else if (macrc_op && !ex_freeze)
          mac_r <= 64'b0;
      `else
        if (mac_op_r3 == 2'b01) // MAC
          mac_r <= mac_r + mul_prod_r;
        else if (mac_op_r3 == 2'b10) // MSB
          mac_r <= mac_r - mul_prod_r;
        else if (macrc_op && !ex_freeze)
          mac_r <= 64'b0;
      `endif

      mac_stall_r <= (|mac_op) || 
                     ((|mac_op_r1 || |mac_op_r2) && id_macrc_op) ||
                     `ifdef OR1200_IMPL_DIV
                       (div_cntr != 0);
                     `else
                       1'b0;
                     `endif
    end
  end
`else
  assign mac_op_r1 = 2'b0;
  assign mac_op_r2 = 2'b0;
  assign mac_op_r3 = 2'b0;
  assign mac_r = 64'b0;
  assign mac_stall_r = 1'b0;
  assign spr_dat_o = 32'b0;
`endif

endmodule
