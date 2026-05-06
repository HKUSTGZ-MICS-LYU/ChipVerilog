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
    output [31:0] result,
    output flagforw,
    output flag_we,
    output cyforw,
    output cy_we,
    input carry,
    input flag
);

  // ADD datapath
  wire [32:0] cy_sum_result_sum;
  assign cy_sum_result_sum = a + b;
  wire [31:0] result_sum;
  wire cy_sum;
  assign result_sum = cy_sum_result_sum[31:0];
  assign cy_sum = cy_sum_result_sum[32];

  // ADDC datapath
`ifdef OR1200_IMPL_ADDC
  wire [32:0] cy_csum_result_csum;
  assign cy_csum_result_csum = a + b + {32'd0, carry};
  wire [31:0] result_csum;
  wire cy_csum;
  assign result_csum = cy_csum_result_csum[31:0];
  assign cy_csum = cy_csum_result_csum[32];
`else
  wire [31:0] result_csum = 32'd0;
  wire cy_csum = 1'b0;
`endif

  // AND datapath
  wire [31:0] result_and;
  assign result_and = a & b;

  // FF1 operation
  wire [31:0] result_ff1;
  assign result_ff1 = a[0]  ? 32'd1 :
                      a[1]  ? 32'd2 :
                      a[2]  ? 32'd3 :
                      a[3]  ? 32'd4 :
                      a[4]  ? 32'd5 :
                      a[5]  ? 32'd6 :
                      a[6]  ? 32'd7 :
                      a[7]  ? 32'd8 :
                      a[8]  ? 32'd9 :
                      a[9]  ? 32'd10 :
                      a[10] ? 32'd11 :
                      a[11] ? 32'd12 :
                      a[12] ? 32'd13 :
                      a[13] ? 32'd14 :
                      a[14] ? 32'd15 :
                      a[15] ? 32'd16 :
                      a[16] ? 32'd17 :
                      a[17] ? 32'd18 :
                      a[18] ? 32'd19 :
                      a[19] ? 32'd20 :
                      a[20] ? 32'd21 :
                      a[21] ? 32'd22 :
                      a[22] ? 32'd23 :
                      a[23] ? 32'd24 :
                      a[24] ? 32'd25 :
                      a[25] ? 32'd26 :
                      a[26] ? 32'd27 :
                      a[27] ? 32'd28 :
                      a[28] ? 32'd29 :
                      a[29] ? 32'd30 :
                      a[30] ? 32'd31 :
                      a[31] ? 32'd32 :
                              32'd0 ;

  // Shift/Rotate block
  wire [31:0] shifted_rotated;
  reg [31:0] shifted_rotated_reg;
  always @*
    casex (shrot_op)
      2'b00: shifted_rotated_reg = a << b[4:0]; // SLL
      2'b01: shifted_rotated_reg = a >> b[4:0]; // SRL
`ifdef OR1200_IMPL_ALU_ROTATE
      2'b10: shifted_rotated_reg = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]); // ROR
`endif
      default: shifted_rotated_reg = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0]; // SRA
    endcase
  assign shifted_rotated = shifted_rotated_reg;

  // Compare block
  wire [31:0] comp_a, comp_b;
  assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
  assign comp_b = {b[31] ^ comp_op[3], b[30:0]};

  wire a_eq_b;
  wire a_lt_b;
  wire flagcomp;
`ifdef OR1200_IMPL_ALU_COMP1
  assign a_eq_b = (comp_a == comp_b);
  assign a_lt_b = (comp_a < comp_b);
`else
`ifdef OR1200_IMPL_ALU_COMP2
  assign a_eq_b = (comp_a == comp_b);
  assign a_lt_b = (comp_a < comp_b);
`else
  assign a_eq_b = 1'b0;
  assign a_lt_b = 1'b0;
`endif
`endif

  assign flagcomp = (comp_op[2:0] == 3'b000) ? a_eq_b :                    // SFEQ
                    (comp_op[2:0] == 3'b001) ? ~a_eq_b :                   // SFNE
                    (comp_op[2:0] == 3'b010) ? (~a_eq_b & ~a_lt_b) :       // SFGT
                    (comp_op[2:0] == 3'b011) ? ~a_lt_b :                   // SFGE
                    (comp_op[2:0] == 3'b100) ? a_lt_b :                    // SFLT
                    (comp_op[2:0] == 3'b101) ? (a_lt_b | a_eq_b) :         // SFLE
                    1'b0;

  // Custom l.cust5 block
  wire [31:0] result_cust5;
  reg [31:0] result_cust5_reg;
  always @*
    casex (cust5_op)
      5'h1: case (cust5_limm[1:0])
              2'b00: result_cust5_reg = {a[31:8], b[7:0]};
              2'b01: result_cust5_reg = {a[31:16], b[7:0], a[7:0]};
              2'b10: result_cust5_reg = {a[31:24], b[7:0], a[15:0]};
              2'b11: result_cust5_reg = {b[7:0], a[23:0]};
            endcase
      5'h2: result_cust5_reg = a | (1 << cust5_limm);
      5'h3: result_cust5_reg = a & (32'hffffffff ^ (1 << cust5_limm));
      default: result_cust5_reg = a;
    endcase
  assign result_cust5 = result_cust5_reg;

  // Main result selection
  reg [31:0] result_reg;
  always @*
    casex (alu_op)
      4'b0000: result_reg = result_sum;                          // ADD
`ifdef OR1200_IMPL_ADDC
      4'b0001: result_reg = result_csum;                         // ADDC
`endif
      4'b0010: result_reg = a - b;                               // SUB
      4'b0011: result_reg = a & b;                               // AND
      4'b0100: result_reg = a | b;                               // OR
      4'b0101: result_reg = a ^ b;                               // XOR
      4'b0110: result_reg = b;                                   // IMM
      4'b0111: result_reg = shifted_rotated;                     // SHROT
      4'b1000: result_reg = result_cust5;                        // CUST5
      4'b1001: result_reg = flag ? a : b;                        // CMOV
      4'b1010: result_reg = macrc_op ? mult_mac_result : (b << 16); // MOVHI
`ifdef OR1200_MULT_IMPLEMENTED
      4'b1011: result_reg = mult_mac_result;                     // MUL
`endif
`ifdef OR1200_MULT_IMPLEMENTED
`ifdef OR1200_IMPL_DIV
      4'b1100: result_reg = mult_mac_result;                     // DIV
      4'b1101: result_reg = mult_mac_result;                     // DIVU
`endif
`endif
      4'b1110: result_reg = result_ff1;                          // FF1
      default: result_reg = 32'd0;
    endcase
  assign result = result_reg;

  // Flag forwarding logic
  reg flagforw_reg;
  reg flag_we_reg;
  always @*
    casex (alu_op)
      4'b1000, 4'b1001, 4'b1010, 4'b1011, 4'b1100, 4'b1101, 4'b1110:
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
      4'b0111: // SHROT
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
      4'b0110: // IMM
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
      4'b0101: // XOR
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
      4'b0100: // OR
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
      4'b0011: // AND
        begin
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
          flagforw_reg = (result_and == 32'd0);
          flag_we_reg = 1'b1;
`else
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
`endif
        end
      4'b0010: // SUB
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
`ifdef OR1200_IMPL_ADDC
      4'b0001: // ADDC
        begin
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
          flagforw_reg = (result_csum == 32'd0);
          flag_we_reg = 1'b1;
`else
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
`endif
        end
`endif
      4'b0000: // ADD
        begin
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
          flagforw_reg = (result_sum == 32'd0);
          flag_we_reg = 1'b1;
`else
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
`endif
        end
      default:
        begin
          flagforw_reg = 1'b0;
          flag_we_reg = 1'b0;
        end
    endcase
  assign flagforw = flag_we_reg ? flagforw_reg : 1'b0;
  assign flag_we = flag_we_reg;

  // Carry forwarding logic
  reg cyforw_reg;
  reg cy_we_reg;
  always @*
`ifdef OR1200_IMPL_CY
    casex (alu_op)
      4'b0000: // ADD
        begin
          cyforw_reg = cy_sum;
          cy_we_reg = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
      4'b0001: // ADDC
        begin
          cyforw_reg = cy_csum;
          cy_we_reg = 1'b1;
        end
`endif
      default:
        begin
          cyforw_reg = 1'b0;
          cy_we_reg = 1'b0;
        end
    endcase
`else
    begin
      cyforw_reg = 1'b0;
      cy_we_reg = 1'b0;
    end
`endif
  assign cyforw = cyforw_reg;
  assign cy_we = cy_we_reg;

endmodule
