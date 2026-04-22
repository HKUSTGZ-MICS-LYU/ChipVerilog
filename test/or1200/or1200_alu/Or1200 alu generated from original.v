`include "timescale.v"
`include "or1200_defines.v"

// Generated from ORIGINAL description.txt
// Key issues in original:
// - "contains no clock or reset registers" (misleading but functionally OK)
// - "macrc_op has priority over the MOVHI path" (vague)
// - "extending the adder by one bit" (vague implementation hint)
// - three irrelevant switched-off sentences (no impact on generation)
// - flagcomp described as "Flagcomp" (no semantic help)
// - cy_sum_result_sum described as "Carry sum result sum" (no structural hint)
// Because of the vague adder description, a naive implementation might write:
//   assign {cy_sum, result_sum} = a + b;  // direct concatenation
// instead of the explicit 33-bit wire style

module or1200_alu(
    a, b, mult_mac_result, macrc_op,
    alu_op, shrot_op, comp_op,
    cust5_op, cust5_limm,
    result, flagforw, flag_we,
    cyforw, cy_we, carry, flag
);

input  [31:0] a;
input  [31:0] b;
input  [31:0] mult_mac_result;
input         macrc_op;
input  [3:0]  alu_op;
input  [1:0]  shrot_op;
input  [3:0]  comp_op;
input  [4:0]  cust5_op;
input  [5:0]  cust5_limm;
output [31:0] result;
output        flagforw;
output        flag_we;
output        cyforw;
output        cy_we;
input         carry;
input         flag;

reg  [31:0] result;
reg  [31:0] shifted_rotated;
reg  [31:0] result_cust5;
reg         flagforw;
reg         flagcomp;   // described only as "Flagcomp" — no clear semantic
reg         flag_we;
reg         cy_we;
wire [31:0] comp_a;
wire [31:0] comp_b;
wire        a_eq_b;
wire        a_lt_b;
wire [31:0] result_sum;
wire [31:0] result_csum;
wire        cy_csum;
wire [31:0] result_and;
wire        cy_sum;
reg         cyforw;

// From original: "extending the adder by one bit" — vague, could generate either style
// A reader might write the simpler concatenation form:
assign {cy_sum, result_sum} = a + b;  // ← naive interpretation of "extending by one bit"
`ifdef OR1200_IMPL_ADDC
assign {cy_csum, result_csum} = a + b + {32'd0, carry};
`endif

assign comp_a  = {a[31] ^ comp_op[3], a[30:0]};
assign comp_b  = {b[31] ^ comp_op[3], b[30:0]};
`ifdef OR1200_IMPL_ALU_COMP1
assign a_eq_b  = (comp_a == comp_b);
assign a_lt_b  = (comp_a < comp_b);
`endif
assign result_and = a & b;

// Central ALU
always @(alu_op or a or b or result_sum or result_and or macrc_op or shifted_rotated or mult_mac_result) begin
    casex (alu_op)
        `OR1200_ALUOP_FF1: begin
            result = a[0] ? 1 : a[1] ? 2 : a[2] ? 3 : a[3] ? 4 :
                     a[4] ? 5 : a[5] ? 6 : a[6] ? 7 : a[7] ? 8 :
                     a[8] ? 9 : a[9] ? 10 : a[10] ? 11 : a[11] ? 12 :
                     a[12] ? 13 : a[13] ? 14 : a[14] ? 15 : a[15] ? 16 :
                     a[16] ? 17 : a[17] ? 18 : a[18] ? 19 : a[19] ? 20 :
                     a[20] ? 21 : a[21] ? 22 : a[22] ? 23 : a[23] ? 24 :
                     a[24] ? 25 : a[25] ? 26 : a[26] ? 27 : a[27] ? 28 :
                     a[28] ? 29 : a[29] ? 30 : a[30] ? 31 : a[31] ? 32 : 0;
        end
        `OR1200_ALUOP_CUST5: result = result_cust5;
        `OR1200_ALUOP_SHROT: result = shifted_rotated;
        `OR1200_ALUOP_ADD:   result = result_sum;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC:  result = result_csum;
`endif
        `OR1200_ALUOP_SUB:   result = a - b;
        `OR1200_ALUOP_XOR:   result = a ^ b;
        `OR1200_ALUOP_OR:    result = a | b;
        `OR1200_ALUOP_IMM:   result = b;
        `OR1200_ALUOP_MOVHI: begin
            // original: "macrc_op has priority" — correct but vague
            if (macrc_op) result = mult_mac_result;
            else          result = b << 16;
        end
`ifdef OR1200_MULT_IMPLEMENTED
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV,
        `OR1200_ALUOP_DIVU,
`endif
        `OR1200_ALUOP_MUL:   result = mult_mac_result;
`endif
        `OR1200_ALUOP_CMOV:  result = flag ? a : b;
        default:             result = result_and;
    endcase
end

// l.cust5
always @(cust5_op or cust5_limm or a or b) begin
    casex (cust5_op)
        5'h1: begin
            casex (cust5_limm[1:0])
                2'h0: result_cust5 = {a[31:8],  b[7:0]};
                2'h1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                2'h2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                2'h3: result_cust5 = {b[7:0],   a[23:0]};
            endcase
        end
        5'h2: result_cust5 = a | (1 << cust5_limm);
        5'h3: result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
        default: result_cust5 = a;
    endcase
end

// flagforw
always @(alu_op or result_sum or result_and or flagcomp) begin
    casex (alu_op)
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD:  flagforw = (result_sum == 32'h0);
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: flagforw = (result_csum == 32'h0);
`endif
        `OR1200_ALUOP_AND:  flagforw = (result_and == 32'h0);
`endif
        `OR1200_ALUOP_COMP: flagforw = flagcomp;
        default:            flagforw = 1'b0;
    endcase
end

// flag_we
always @(alu_op or result_sum or result_and or flagcomp) begin
    casex (alu_op)
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD:  flag_we = 1'b1;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: flag_we = 1'b1;
`endif
        `OR1200_ALUOP_AND:  flag_we = 1'b1;
`endif
        `OR1200_ALUOP_COMP: flag_we = 1'b1;
        default:            flag_we = 1'b0;
    endcase
end

// cyforw
always @(alu_op or cy_sum
`ifdef OR1200_IMPL_ADDC
    or cy_csum
`endif
    ) begin
    casex (alu_op)
`ifdef OR1200_IMPL_CY
        `OR1200_ALUOP_ADD:  cyforw = cy_sum;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: cyforw = cy_csum;
`endif
`endif
        default: cyforw = 1'b0;
    endcase
end

// cy_we
always @(alu_op or cy_sum
`ifdef OR1200_IMPL_ADDC
    or cy_csum
`endif
    ) begin
    casex (alu_op)
`ifdef OR1200_IMPL_CY
        `OR1200_ALUOP_ADD:  cy_we = 1'b1;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: cy_we = 1'b1;
`endif
`endif
        default: cy_we = 1'b0;
    endcase
end

// shift/rotate
always @(shrot_op or a or b) begin
    case (shrot_op)
        `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
        `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
        `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32-{1'b0,b[4:0]})) | (a >> b[4:0]);
`endif
        default: shifted_rotated = ({32{a[31]}} << (6'd32-{1'b0,b[4:0]})) | a >> b[4:0];
    endcase
end

// compare
`ifdef OR1200_IMPL_ALU_COMP1
always @(comp_op or a_eq_b or a_lt_b) begin
    case (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = a_eq_b;
        `OR1200_COP_SFNE: flagcomp = ~a_eq_b;
        `OR1200_COP_SFGT: flagcomp = ~(a_eq_b | a_lt_b);
        `OR1200_COP_SFGE: flagcomp = ~a_lt_b;
        `OR1200_COP_SFLT: flagcomp = a_lt_b;
        `OR1200_COP_SFLE: flagcomp = a_eq_b | a_lt_b;
        default:          flagcomp = 1'b0;
    endcase
end
`endif
`ifdef OR1200_IMPL_ALU_COMP2
always @(comp_op or comp_a or comp_b) begin
    case (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
        `OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
        `OR1200_COP_SFGT: flagcomp = (comp_a >  comp_b);
        `OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
        `OR1200_COP_SFLT: flagcomp = (comp_a <  comp_b);
        `OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
        default:          flagcomp = 1'b0;
    endcase
end
`endif

endmodule
