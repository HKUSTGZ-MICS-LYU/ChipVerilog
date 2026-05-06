//////////////////////////////////////////////////////////////////////
////                                                              ////
////  OR1200 ALU                                                  ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

`include "timescale.v"
`include "or1200_defines.v"

module or1200_alu(
    a, b, mult_mac_result, macrc_op,
    alu_op, shrot_op, comp_op,
    cust5_op, cust5_limm,
    result, flagforw, flag_we,
    cyforw, cy_we, carry, flag
);

//
// I/O
//
input  [31:0] a;
input  [31:0] b;
input  [31:0] mult_mac_result;
input         macrc_op;
input  [3:0]  alu_op;
input  [1:0]  shrot_op;
input  [3:0]  comp_op;
input  [4:0]  cust5_op;
input  [5:0]  cust5_limm;
input         carry;
input         flag;

output [31:0] result;
output        flagforw;
output        flag_we;
output        cyforw;
output        cy_we;

//
// Internal signals
//
reg  [31:0] result;
reg         flagforw;
reg         flag_we;
reg         cyforw;
reg         cy_we;

wire [31:0] result_sum;
wire [31:0] result_and;
wire [31:0] result_or;
wire [31:0] result_xor;
wire [31:0] shifted_rotated;
reg  [31:0] result_cust5;
reg  [31:0] result_ff1;

wire [32:0] cy_sum_result_sum;
wire        cy_sum;

`ifdef OR1200_IMPL_ADDC
wire [32:0] cy_csum_result_csum;
wire        cy_csum;
wire [31:0] result_csum;
`endif

wire [31:0] comp_a;
wire [31:0] comp_b;
reg         flagcomp;

`ifdef OR1200_IMPL_ALU_COMP1
wire        a_eq_b;
wire        a_lt_b;
`endif

//
// Basic operations
//
assign cy_sum_result_sum = a + b;
assign cy_sum = cy_sum_result_sum[32];
assign result_sum = cy_sum_result_sum[31:0];

`ifdef OR1200_IMPL_ADDC
assign cy_csum_result_csum = a + b + {32'd0, carry};
assign cy_csum = cy_csum_result_csum[32];
assign result_csum = cy_csum_result_csum[31:0];
`endif

assign result_and = a & b;
assign result_or  = a | b;
assign result_xor = a ^ b;

//
// Compare operands
//
assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
assign comp_b = {b[31] ^ comp_op[3], b[30:0]};

`ifdef OR1200_IMPL_ALU_COMP1
assign a_eq_b = comp_a == comp_b;
assign a_lt_b = comp_a < comp_b;
`endif

//
// Compare result
//
always @(*) begin
    case (comp_op)
        `OR1200_COP_SFEQ: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = a_eq_b;
`else
            flagcomp = comp_a == comp_b;
`endif
        end

        `OR1200_COP_SFNE: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = !a_eq_b;
`else
            flagcomp = comp_a != comp_b;
`endif
        end

        `OR1200_COP_SFGT: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = !(a_eq_b | a_lt_b);
`else
            flagcomp = comp_a > comp_b;
`endif
        end

        `OR1200_COP_SFGE: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = !a_lt_b;
`else
            flagcomp = comp_a >= comp_b;
`endif
        end

        `OR1200_COP_SFLT: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = a_lt_b;
`else
            flagcomp = comp_a < comp_b;
`endif
        end

        `OR1200_COP_SFLE: begin
`ifdef OR1200_IMPL_ALU_COMP1
            flagcomp = a_eq_b | a_lt_b;
`else
            flagcomp = comp_a <= comp_b;
`endif
        end

        default: begin
            flagcomp = 1'b0;
        end
    endcase
end

//
// Shift / rotate
//
assign shifted_rotated =
    (shrot_op == `OR1200_SHROTOP_SLL) ? 
        a << b[4:0] :
    (shrot_op == `OR1200_SHROTOP_SRL) ?
        a >> b[4:0] :
`ifdef OR1200_IMPL_ALU_ROTATE
    (shrot_op == `OR1200_SHROTOP_ROR) ?
        (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]) :
`endif
        ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];

//
// CUST5
//
always @(*) begin
    casex (cust5_op)
        5'h1: begin
            case (cust5_limm[1:0])
                2'h0: result_cust5 = {a[31:8], b[7:0]};
                2'h1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                2'h2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                2'h3: result_cust5 = {b[7:0], a[23:0]};
            endcase
        end

        5'h2: begin
            result_cust5 = a | (1 << cust5_limm);
        end

        5'h3: begin
            result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
        end

        default: begin
            result_cust5 = a;
        end
    endcase
end

//
// FF1
//
always @(*) begin
    casex (a)
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1: result_ff1 = 32'd1;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10: result_ff1 = 32'd2;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100: result_ff1 = 32'd3;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000: result_ff1 = 32'd4;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxxx10000: result_ff1 = 32'd5;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxxx100000: result_ff1 = 32'd6;
        32'bxxxxxxxxxxxxxxxxxxxxxxxxx1000000: result_ff1 = 32'd7;
        32'bxxxxxxxxxxxxxxxxxxxxxxxx10000000: result_ff1 = 32'd8;
        32'bxxxxxxxxxxxxxxxxxxxxxxx100000000: result_ff1 = 32'd9;
        32'bxxxxxxxxxxxxxxxxxxxxxx1000000000: result_ff1 = 32'd10;
        32'bxxxxxxxxxxxxxxxxxxxxx10000000000: result_ff1 = 32'd11;
        32'bxxxxxxxxxxxxxxxxxxxx100000000000: result_ff1 = 32'd12;
        32'bxxxxxxxxxxxxxxxxxxx1000000000000: result_ff1 = 32'd13;
        32'bxxxxxxxxxxxxxxxxxx10000000000000: result_ff1 = 32'd14;
        32'bxxxxxxxxxxxxxxxxx100000000000000: result_ff1 = 32'd15;
        32'bxxxxxxxxxxxxxxxx1000000000000000: result_ff1 = 32'd16;
        32'bxxxxxxxxxxxxxxx10000000000000000: result_ff1 = 32'd17;
        32'bxxxxxxxxxxxxxx100000000000000000: result_ff1 = 32'd18;
        32'bxxxxxxxxxxxxx1000000000000000000: result_ff1 = 32'd19;
        32'bxxxxxxxxxxxx10000000000000000000: result_ff1 = 32'd20;
        32'bxxxxxxxxxxx100000000000000000000: result_ff1 = 32'd21;
        32'bxxxxxxxxxx1000000000000000000000: result_ff1 = 32'd22;
        32'bxxxxxxxxx10000000000000000000000: result_ff1 = 32'd23;
        32'bxxxxxxxx100000000000000000000000: result_ff1 = 32'd24;
        32'bxxxxxxx1000000000000000000000000: result_ff1 = 32'd25;
        32'bxxxxxx10000000000000000000000000: result_ff1 = 32'd26;
        32'bxxxxx100000000000000000000000000: result_ff1 = 32'd27;
        32'bxxxx1000000000000000000000000000: result_ff1 = 32'd28;
        32'bxxx10000000000000000000000000000: result_ff1 = 32'd29;
        32'bxx100000000000000000000000000000: result_ff1 = 32'd30;
        32'bx1000000000000000000000000000000: result_ff1 = 32'd31;
        32'b10000000000000000000000000000000: result_ff1 = 32'd32;
        default:                             result_ff1 = 32'd0;
    endcase
end

//
// Result mux
//
always @(*) begin
    casex (alu_op)
        `OR1200_ALUOP_ADD: begin
            result = result_sum;
        end

`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            result = result_csum;
        end
`endif

        `OR1200_ALUOP_SUB: begin
            result = a - b;
        end

`ifndef OR1200_CASE_DEFAULT
        `OR1200_ALUOP_COMP,
        `OR1200_ALUOP_AND: begin
            result = result_and;
        end
`endif

        `OR1200_ALUOP_OR: begin
            result = result_or;
        end

        `OR1200_ALUOP_XOR: begin
            result = result_xor;
        end

        `OR1200_ALUOP_IMM: begin
            result = b;
        end

        `OR1200_ALUOP_MOVHI: begin
            if (macrc_op)
                result = mult_mac_result;
            else
                result = b << 16;
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

        `OR1200_ALUOP_CMOV: begin
            result = flag ? a : b;
        end

        `OR1200_ALUOP_SHROT: begin
            result = shifted_rotated;
        end

        `OR1200_ALUOP_CUST5: begin
            result = result_cust5;
        end

        `OR1200_ALUOP_FF1: begin
            result = result_ff1;
        end

`ifdef OR1200_CASE_DEFAULT
        default: begin
            result = result_and;
        end
`endif
    endcase
end

//
// Flag generation
//
always @(*) begin
    flagforw = 1'b0;
    flag_we  = 1'b0;

    casex (alu_op)
        `OR1200_ALUOP_COMP: begin
            flagforw = flagcomp;
            flag_we  = 1'b1;
        end

`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD: begin
            flagforw = result_sum == 32'd0;
            flag_we  = 1'b1;
        end

`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            flagforw = result_csum == 32'd0;
            flag_we  = 1'b1;
        end
`endif

        `OR1200_ALUOP_AND: begin
            flagforw = result_and == 32'd0;
            flag_we  = 1'b1;
        end
`endif

        default: begin
            flagforw = 1'b0;
            flag_we  = 1'b0;
        end
    endcase
end

//
// Carry generation
//
always @(*) begin
    cyforw = 1'b0;
    cy_we  = 1'b0;

`ifdef OR1200_IMPL_CY
    casex (alu_op)
        `OR1200_ALUOP_ADD: begin
            cyforw = cy_sum;
            cy_we  = 1'b1;
        end

`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            cyforw = cy_csum;
            cy_we  = 1'b1;
        end
`endif

        default: begin
            cyforw = 1'b0;
            cy_we  = 1'b0;
        end
    endcase
`endif
end

`ifdef OR1200_WARNINGS
// synopsys translate_off
always @(*) begin
    case (alu_op)
        `OR1200_ALUOP_ADD,
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC,
`endif
        `OR1200_ALUOP_SUB,
        `OR1200_ALUOP_AND,
        `OR1200_ALUOP_OR,
        `OR1200_ALUOP_XOR,
        `OR1200_ALUOP_IMM,
        `OR1200_ALUOP_MOVHI,
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_ALUOP_MUL,
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV,
        `OR1200_ALUOP_DIVU,
`endif
`endif
        `OR1200_ALUOP_CMOV,
        `OR1200_ALUOP_SHROT,
        `OR1200_ALUOP_CUST5,
        `OR1200_ALUOP_FF1,
        `OR1200_ALUOP_COMP: begin
        end

        default: begin
            $display("%t: WARNING: Illegal ALU operation: %h", $time, alu_op);
        end
    endcase
end
// synopsys translate_on
`endif

endmodule