`include "timescale.v"
`include "or1200_defines.v"

module or1200_alu(
    a, b, mult_mac_result, macrc_op,
    alu_op, shrot_op, comp_op, cust5_op, cust5_limm,
    result, flagforw, flag_we, cyforw, cy_we,
    carry, flag
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

// Internal wires
reg  [31:0] result;
reg         flagforw;
reg         flag_we;
reg         cyforw;
reg         cy_we;

// ADD / ADDC datapaths
wire [32:0] cy_sum_result_sum   = a + b;
wire        cy_sum              = cy_sum_result_sum[32];
wire [31:0] result_sum          = cy_sum_result_sum[31:0];
wire [31:0] result_and          = a & b;

`ifdef OR1200_IMPL_ADDC
wire [32:0] cy_csum_result_csum = a + b + {32'd0, carry};
wire        cy_csum             = cy_csum_result_csum[32];
wire [31:0] result_csum         = cy_csum_result_csum[31:0];
`endif

// Compare operands (sign-bit normalization)
wire [31:0] comp_a = {a[31] ^ comp_op[3], a[30:0]};
wire [31:0] comp_b = {b[31] ^ comp_op[3], b[30:0]};

// Compare result
reg flagcomp;
always @(comp_a or comp_b or comp_op) begin
`ifdef OR1200_IMPL_ALU_COMP1
    reg a_eq_b, a_lt_b;
    a_eq_b = (comp_a == comp_b);
    a_lt_b = (comp_a <  comp_b);
    case (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = a_eq_b;
        `OR1200_COP_SFNE: flagcomp = !a_eq_b;
        `OR1200_COP_SFGT: flagcomp = !a_lt_b & !a_eq_b;
        `OR1200_COP_SFGE: flagcomp = !a_lt_b;
        `OR1200_COP_SFLT: flagcomp = a_lt_b;
        `OR1200_COP_SFLE: flagcomp = a_lt_b | a_eq_b;
        default:          flagcomp = 1'b0;
    endcase
`else
`ifdef OR1200_IMPL_ALU_COMP2
    case (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
        `OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
        `OR1200_COP_SFGT: flagcomp = (comp_a >  comp_b);
        `OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
        `OR1200_COP_SFLT: flagcomp = (comp_a <  comp_b);
        `OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
        default:          flagcomp = 1'b0;
    endcase
`endif
`endif
end

// Shift/rotate
reg [31:0] shifted_rotated;
always @(a or b or shrot_op) begin
    case (shrot_op)
        `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
        `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
        `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
        default: shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
    endcase
end

// FF1
reg [31:0] result_ff1;
always @(a) begin
    casex (a)
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1: result_ff1 = 1;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10: result_ff1 = 2;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100: result_ff1 = 3;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000: result_ff1 = 4;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxx10000: result_ff1 = 5;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxx100000: result_ff1 = 6;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxx1000000: result_ff1 = 7;
        32'bxxxxxxxxxxxxxxxxxxxxxxxx10000000: result_ff1 = 8;
        32'bxxxxxxxxxxxxxxxxxxxxxxx100000000: result_ff1 = 9;
        32'bxxxxxxxxxxxxxxxxxxxxxx1000000000: result_ff1 = 10;
        32'bxxxxxxxxxxxxxxxxxxxxx10000000000: result_ff1 = 11;
        32'bxxxxxxxxxxxxxxxxxxxx100000000000: result_ff1 = 12;
        32'bxxxxxxxxxxxxxxxxxxx1000000000000: result_ff1 = 13;
        32'bxxxxxxxxxxxxxxxxxx10000000000000: result_ff1 = 14;
        32'bxxxxxxxxxxxxxxxxx100000000000000: result_ff1 = 15;
        32'bxxxxxxxxxxxxxxxx1000000000000000: result_ff1 = 16;
        32'bxxxxxxxxxxxxxxx10000000000000000: result_ff1 = 17;
        32'bxxxxxxxxxxxxxx100000000000000000: result_ff1 = 18;
        32'bxxxxxxxxxxxxx1000000000000000000: result_ff1 = 19;
        32'bxxxxxxxxxxxx10000000000000000000: result_ff1 = 20;
        32'bxxxxxxxxxxx100000000000000000000: result_ff1 = 21;
        32'bxxxxxxxxxx1000000000000000000000: result_ff1 = 22;
        32'bxxxxxxxxx10000000000000000000000: result_ff1 = 23;
        32'bxxxxxxxx100000000000000000000000: result_ff1 = 24;
        32'bxxxxxxx1000000000000000000000000: result_ff1 = 25;
        32'bxxxxxx10000000000000000000000000: result_ff1 = 26;
        32'bxxxxx100000000000000000000000000: result_ff1 = 27;
        32'bxxxx1000000000000000000000000000: result_ff1 = 28;
        32'bxxx10000000000000000000000000000: result_ff1 = 29;
        32'bxx100000000000000000000000000000: result_ff1 = 30;
        32'bx1000000000000000000000000000000: result_ff1 = 31;
        32'b10000000000000000000000000000000: result_ff1 = 32;
        default:                             result_ff1 = 0;
    endcase
end

// l.cust5
reg [31:0] result_cust5;
always @(a or b or cust5_op or cust5_limm) begin
    case (cust5_op)
        5'h1: begin
            case (cust5_limm[1:0])
                2'd0: result_cust5 = {a[31:8],  b[7:0]};
                2'd1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                2'd2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                2'd3: result_cust5 = {b[7:0],   a[23:0]};
            endcase
        end
        5'h2: result_cust5 = a | (1 << cust5_limm);
        5'h3: result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
        default: result_cust5 = a;
    endcase
end

// Main result mux and flag/carry generation
always @(alu_op or a or b or result_sum or result_and or
         shifted_rotated or result_ff1 or result_cust5 or
         mult_mac_result or macrc_op or flagcomp or flag or
`ifdef OR1200_IMPL_ADDC
         result_csum or cy_csum or
`endif
         cy_sum) begin

    result   = 32'd0;
    flagforw = 1'b0;
    flag_we  = 1'b0;
    cyforw   = 1'b0;
    cy_we    = 1'b0;

    casex (alu_op)
        `OR1200_ALUOP_ADD: begin
            result = result_sum;
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
            flagforw = !(|result_sum);
            flag_we  = 1'b1;
`endif
`ifdef OR1200_IMPL_CY
            cyforw = cy_sum;
            cy_we  = 1'b1;
`endif
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            result = result_csum;
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
            flagforw = !(|result_csum);
            flag_we  = 1'b1;
`endif
`ifdef OR1200_IMPL_CY
            cyforw = cy_csum;
            cy_we  = 1'b1;
`endif
        end
`endif
        `OR1200_ALUOP_SUB: begin
            result = a - b;
        end
        `OR1200_ALUOP_AND: begin
            result = result_and;
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
            flagforw = !(|result_and);
            flag_we  = 1'b1;
`endif
        end
        `OR1200_ALUOP_OR: begin
            result = a | b;
        end
        `OR1200_ALUOP_XOR: begin
            result = a ^ b;
        end
        `OR1200_ALUOP_IMM: begin
            result = b;
        end
        `OR1200_ALUOP_SHROT: begin
            result = shifted_rotated;
        end
        `OR1200_ALUOP_COMP: begin
            result   = 32'd0;
            flagforw = flagcomp;
            flag_we  = 1'b1;
        end
        `OR1200_ALUOP_MOVHI: begin
            result = macrc_op ? mult_mac_result : b << 16;
        end
        `OR1200_ALUOP_CUST5: begin
            result = result_cust5;
        end
        `OR1200_ALUOP_CMOV: begin
            result = flag ? a : b;
        end
        `OR1200_ALUOP_FF1: begin
            result = result_ff1;
        end
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_ALUOP_MUL: begin
            result = mult_mac_result;
        end
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV,
        `OR1200_ALUOP_DIVU: begin
            result = mult_mac_result;
        end
`endif
`endif
`ifdef OR1200_CASE_DEFAULT
        default: begin
`ifdef OR1200_WARNINGS
            // synthesis translate_off
            $display("%t: Unimplemented ALU op %b", $time, alu_op);
            // synthesis translate_on
`endif
            result = 32'd0;
        end
`endif
    endcase
end

endmodule