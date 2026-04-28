`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

//
// OR1200 ALU opcodes
//
`define OR1200_ALUOP_ADD    4'd0
`define OR1200_ALUOP_ADDC   4'd1
`define OR1200_ALUOP_SUB    4'd2
`define OR1200_ALUOP_AND    4'd3
`define OR1200_ALUOP_OR     4'd4
`define OR1200_ALUOP_XOR    4'd5
`define OR1200_ALUOP_IMM    4'd6
`define OR1200_ALUOP_SHROT  4'd7
`define OR1200_ALUOP_COMP   4'd8
`define OR1200_ALUOP_MOVHI  4'd9
`define OR1200_ALUOP_MUL    4'd10
`define OR1200_ALUOP_CUST5  4'd11
`define OR1200_ALUOP_DIV    4'd12
`define OR1200_ALUOP_DIVU   4'd13
`define OR1200_ALUOP_CMOV   4'd14
`define OR1200_ALUOP_FF1    4'd15

//
// Shift/rotate sub-opcodes
//
`define OR1200_SHROTOP_SLL  2'd0
`define OR1200_SHROTOP_SRL  2'd1
`define OR1200_SHROTOP_ROR  2'd2
`define OR1200_SHROTOP_SRA  2'd3

//
// Compare sub-opcodes
//
`define OR1200_COP_SFEQ     3'd0
`define OR1200_COP_SFNE     3'd1
`define OR1200_COP_SFGT     3'd2
`define OR1200_COP_SFGE     3'd3
`define OR1200_COP_SFLT     3'd4
`define OR1200_COP_SFLE     3'd5

//
// Feature enables (define to include)
//
`define OR1200_IMPL_ADDC
`define OR1200_IMPL_CY
`define OR1200_IMPL_ALU_ROTATE
`define OR1200_MULT_IMPLEMENTED
`define OR1200_IMPL_DIV
`define OR1200_IMPL_ALU_COMP1
// `define OR1200_IMPL_ALU_COMP2
`define OR1200_ADDITIONAL_FLAG_MODIFIERS
// `define OR1200_CASE_DEFAULT
// `define OR1200_WARNINGS

module or1200_alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [31:0] mult_mac_result,
    input         macrc_op,
    input  [3:0]  alu_op,
    input  [1:0]  shrot_op,
    input  [3:0]  comp_op,
    input  [4:0]  cust5_op,
    input  [5:0]  cust5_limm,
    output [31:0] result,
    output        flagforw,
    output        flag_we,
    output        cyforw,
    output        cy_we,
    input         carry,
    input         flag
);

    //--------------------------------------------------------------------------
    // 33-bit ADD datapath
    //--------------------------------------------------------------------------
    wire [32:0] cy_sum_result_sum  = {1'b0, a} + {1'b0, b};
    wire        cy_sum             = cy_sum_result_sum[32];
    wire [31:0] result_sum         = cy_sum_result_sum[31:0];

`ifdef OR1200_IMPL_ADDC
    wire [32:0] cy_csum_result_csum = {1'b0, a} + {1'b0, b} + {32'd0, carry};
    wire        cy_csum              = cy_csum_result_csum[32];
    wire [31:0] result_csum          = cy_csum_result_csum[31:0];
`endif

    //--------------------------------------------------------------------------
    // AND datapath
    //--------------------------------------------------------------------------
    wire [31:0] result_and = a & b;

    //--------------------------------------------------------------------------
    // Shift / Rotate
    //--------------------------------------------------------------------------
    reg [31:0] shifted_rotated;
    always @(*) begin
        casex (shrot_op)
            `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
            `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
            `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
            default:             shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
        endcase
    end

    //--------------------------------------------------------------------------
    // Compare
    //--------------------------------------------------------------------------
    wire [31:0] comp_a = {a[31] ^ comp_op[3], a[30:0]};
    wire [31:0] comp_b = {b[31] ^ comp_op[3], b[30:0]};

    reg flagcomp;

`ifdef OR1200_IMPL_ALU_COMP1
    wire a_eq_b = (comp_a == comp_b);
    wire a_lt_b = (comp_a <  comp_b);

    always @(*) begin
        casex (comp_op[2:0])
            `OR1200_COP_SFEQ: flagcomp = a_eq_b;
            `OR1200_COP_SFNE: flagcomp = ~a_eq_b;
            `OR1200_COP_SFGT: flagcomp = ~a_lt_b & ~a_eq_b;
            `OR1200_COP_SFGE: flagcomp = ~a_lt_b;
            `OR1200_COP_SFLT: flagcomp =  a_lt_b;
            `OR1200_COP_SFLE: flagcomp =  a_lt_b | a_eq_b;
            default:          flagcomp = 1'b0;
        endcase
    end
`else
`ifdef OR1200_IMPL_ALU_COMP2
    always @(*) begin
        casex (comp_op[2:0])
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
`endif

    //--------------------------------------------------------------------------
    // FF1 — find first 1 from LSB
    //--------------------------------------------------------------------------
    reg [31:0] result_ff1;
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
            default:                              result_ff1 = 32'd0;
        endcase
    end

    //--------------------------------------------------------------------------
    // l.cust5 custom instructions
    //--------------------------------------------------------------------------
    reg [31:0] result_cust5;
    always @(*) begin
        casex (cust5_op)
            5'h1: begin
                casex (cust5_limm[1:0])
                    2'd0: result_cust5 = {a[31:8],  b[7:0]};
                    2'd1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                    2'd2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                    2'd3: result_cust5 = {b[7:0],   a[23:0]};
                endcase
            end
            5'h2:    result_cust5 = a | (1 << cust5_limm);
            5'h3:    result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
            default: result_cust5 = a;
        endcase
    end

    //--------------------------------------------------------------------------
    // Main result mux
    //--------------------------------------------------------------------------
    reg [31:0] result_r;
    always @(*) begin
        casex (alu_op)
            `OR1200_ALUOP_ADD:   result_r = result_sum;
`ifdef OR1200_IMPL_ADDC
            `OR1200_ALUOP_ADDC:  result_r = result_csum;
`endif
            `OR1200_ALUOP_SUB:   result_r = a - b;
            `OR1200_ALUOP_AND:   result_r = result_and;
            `OR1200_ALUOP_OR:    result_r = a | b;
            `OR1200_ALUOP_XOR:   result_r = a ^ b;
            `OR1200_ALUOP_IMM:   result_r = b;
            `OR1200_ALUOP_SHROT: result_r = shifted_rotated;
            `OR1200_ALUOP_COMP:  result_r = 32'd0;
            `OR1200_ALUOP_MOVHI: result_r = macrc_op ? mult_mac_result : b << 16;
`ifdef OR1200_MULT_IMPLEMENTED
            `OR1200_ALUOP_MUL:   result_r = mult_mac_result;
`ifdef OR1200_IMPL_DIV
            `OR1200_ALUOP_DIV:   result_r = mult_mac_result;
            `OR1200_ALUOP_DIVU:  result_r = mult_mac_result;
`endif
`endif
            `OR1200_ALUOP_CUST5: result_r = result_cust5;
            `OR1200_ALUOP_CMOV:  result_r = flag ? a : b;
            `OR1200_ALUOP_FF1:   result_r = result_ff1;
`ifdef OR1200_CASE_DEFAULT
            default:             result_r = 32'd0;
`endif
        endcase
    end

    assign result = result_r;

    //--------------------------------------------------------------------------
    // Flag forwarding
    //--------------------------------------------------------------------------
    reg flagforw_r;
    reg flag_we_r;

    always @(*) begin
        casex (alu_op)
            `OR1200_ALUOP_COMP: begin
                flagforw_r = flagcomp;
                flag_we_r  = 1'b1;
            end
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
            `OR1200_ALUOP_ADD: begin
                flagforw_r = ~|result_sum;
                flag_we_r  = 1'b1;
            end
`ifdef OR1200_IMPL_ADDC
            `OR1200_ALUOP_ADDC: begin
                flagforw_r = ~|result_csum;
                flag_we_r  = 1'b1;
            end
`endif
            `OR1200_ALUOP_AND: begin
                flagforw_r = ~|result_and;
                flag_we_r  = 1'b1;
            end
`endif
            default: begin
                flagforw_r = 1'b0;
                flag_we_r  = 1'b0;
            end
        endcase
    end

    assign flagforw = flagforw_r;
    assign flag_we  = flag_we_r;

    //--------------------------------------------------------------------------
    // Carry forwarding
    //--------------------------------------------------------------------------
    reg cyforw_r;
    reg cy_we_r;

    always @(*) begin
`ifdef OR1200_IMPL_CY
        casex (alu_op)
            `OR1200_ALUOP_ADD: begin
                cyforw_r = cy_sum;
                cy_we_r  = 1'b1;
            end
`ifdef OR1200_IMPL_ADDC
            `OR1200_ALUOP_ADDC: begin
                cyforw_r = cy_csum;
                cy_we_r  = 1'b1;
            end
`endif
            default: begin
                cyforw_r = 1'b0;
                cy_we_r  = 1'b0;
            end
        endcase
`else
        cyforw_r = 1'b0;
        cy_we_r  = 1'b0;
`endif
    end

    assign cyforw = cyforw_r;
    assign cy_we  = cy_we_r;

endmodule
EOF