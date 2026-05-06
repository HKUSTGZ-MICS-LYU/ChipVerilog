`define OR1200_ALUOP_ADD    4'h0
`define OR1200_ALUOP_ADDC   4'h1
`define OR1200_ALUOP_SUB    4'h2
`define OR1200_ALUOP_AND    4'h3
`define OR1200_ALUOP_OR     4'h4
`define OR1200_ALUOP_XOR    4'h5
`define OR1200_ALUOP_IMM    4'h6
`define OR1200_ALUOP_SHROT  4'h7
`define OR1200_ALUOP_CUST5  4'h8
`define OR1200_ALUOP_CMOV   4'h9
`define OR1200_ALUOP_MOVHI  4'ha
`define OR1200_ALUOP_MUL    4'hb
`define OR1200_ALUOP_DIV    4'hc
`define OR1200_ALUOP_DIVU   4'hd
`define OR1200_ALUOP_COMP   4'he
`define OR1200_ALUOP_FF1    4'hf
`define OR1200_SHROTOP_SLL  2'h0
`define OR1200_SHROTOP_SRL  2'h1
`define OR1200_SHROTOP_ROR  2'h2
`define OR1200_COP_SFEQ     3'h0
`define OR1200_COP_SFNE     3'h1
`define OR1200_COP_SFGT     3'h2
`define OR1200_COP_SFGE     3'h3
`define OR1200_COP_SFLT     3'h4
`define OR1200_COP_SFLE     3'h5

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

    wire [31:0] result_sum;
    wire cy_sum;
    wire [32:0] cy_sum_result_sum;

    wire [31:0] result_csum;
    wire cy_csum;
    wire [32:0] cy_csum_result_csum;

    wire [31:0] result_and;

    wire [31:0] shifted_rotated;

    wire [31:0] result_cust5;

    wire flagcomp;
    wire [31:0] comp_a;
    wire [31:0] comp_b;

    reg [31:0] result_reg;
    reg flagforw_reg;
    reg flag_we_reg;
    reg cyforw_reg;
    reg cy_we_reg;

    assign result = result_reg;
    assign flagforw = flagforw_reg;
    assign flag_we = flag_we_reg;
    assign cyforw = cyforw_reg;
    assign cy_we = cy_we_reg;

    assign cy_sum_result_sum = a + b;
    assign result_sum = cy_sum_result_sum[31:0];
    assign cy_sum = cy_sum_result_sum[32];

    `ifdef OR1200_IMPL_ADDC
        assign cy_csum_result_csum = a + b + {32'd0, carry};
        assign result_csum = cy_csum_result_csum[31:0];
        assign cy_csum = cy_csum_result_csum[32];
    `else
        assign result_csum = 32'd0;
        assign cy_csum = 1'b0;
    `endif

    assign result_and = a & b;

    assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
    assign comp_b = {b[31] ^ comp_op[3], b[30:0]};

    `ifdef OR1200_IMPL_ALU_COMP1
        wire a_eq_b;
        wire a_lt_b;
        assign a_eq_b = (comp_a == comp_b);
        assign a_lt_b = (comp_a < comp_b);
        always @(comp_op[2:0] or a_eq_b or a_lt_b) begin
            casex (comp_op[2:0])
                `OR1200_COP_SFEQ:  flagcomp = a_eq_b;
                `OR1200_COP_SFNE:  flagcomp = !a_eq_b;
                `OR1200_COP_SFGT:  flagcomp = !a_lt_b && !a_eq_b;
                `OR1200_COP_SFGE:  flagcomp = !a_lt_b;
                `OR1200_COP_SFLT:  flagcomp = a_lt_b;
                `OR1200_COP_SFLE:  flagcomp = a_lt_b || a_eq_b;
                default:          flagcomp = 1'bx;
            endcase
        end
    `else
        `ifdef OR1200_IMPL_ALU_COMP2
            always @(comp_op[2:0] or comp_a or comp_b) begin
                casex (comp_op[2:0])
                    `OR1200_COP_SFEQ:  flagcomp = (comp_a == comp_b);
                    `OR1200_COP_SFNE:  flagcomp = (comp_a != comp_b);
                    `OR1200_COP_SFGT:  flagcomp = (comp_a > comp_b);
                    `OR1200_COP_SFGE:  flagcomp = (comp_a >= comp_b);
                    `OR1200_COP_SFLT:  flagcomp = (comp_a < comp_b);
                    `OR1200_COP_SFLE:  flagcomp = (comp_a <= comp_b);
                    default:          flagcomp = 1'bx;
                endcase
            end
        `endif
    `endif

    always @(shrot_op or a or b) begin
        casex (shrot_op)
            `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
            `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
            `ifdef OR1200_IMPL_ALU_ROTATE
                `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
            `endif
            default: shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
        endcase
    end

    always @(cust5_op or cust5_limm or a or b) begin
        casex (cust5_op)
            5'h1: begin
                case (cust5_limm[1:0])
                    2'd0: result_cust5 = {a[31:8], b[7:0]};
                    2'd1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                    2'd2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                    2'd3: result_cust5 = {b[7:0], a[23:0]};
                endcase
            end
            5'h2: result_cust5 = a | (1 << cust5_limm);
            5'h3: result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
            default: result_cust5 = a;
        endcase
    end

    always @(alu_op or result_sum or result_csum or a or b or result_and or shifted_rotated or result_cust5 or mult_mac_result or macrc_op or flag or flagcomp) begin
        flagforw_reg = 1'b0;
        flag_we_reg = 1'b0;
        cyforw_reg = 1'b0;
        cy_we_reg = 1'b0;

        casex (alu_op)
            `OR1200_ALUOP_ADD: begin
                result_reg = result_sum;
                `ifdef OR1200_IMPL_CY
                    cyforw_reg = cy_sum;
                    cy_we_reg = 1'b1;
                `endif
                `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
                    flagforw_reg = (result_sum == 32'd0);
                    flag_we_reg = 1'b1;
                `endif
            end
            `OR1200_ALUOP_ADDC: begin
                `ifdef OR1200_IMPL_ADDC
                    result_reg = result_csum;
                    `ifdef OR1200_IMPL_CY
                        cyforw_reg = cy_csum;
                        cy_we_reg = 1'b1;
                    `endif
                    `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
                        flagforw_reg = (result_csum == 32'd0);
                        flag_we_reg = 1'b1;
                    `endif
                `else
                    result_reg = 32'd0;
                `endif
            end
            `OR1200_ALUOP_SUB: result_reg = a - b;
            `OR1200_ALUOP_AND: begin
                result_reg = result_and;
                `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
                    flagforw_reg = (result_and == 32'd0);
                    flag_we_reg = 1'b1;
                `endif
            end
            `OR1200_ALUOP_OR:  result_reg = a | b;
            `OR1200_ALUOP_XOR: result_reg = a ^ b;
            `OR1200_ALUOP_IMM: result_reg = b;
            `OR1200_ALUOP_SHROT: result_reg = shifted_rotated;
            `OR1200_ALUOP_CUST5: result_reg = result_cust5;
            `OR1200_ALUOP_CMOV: result_reg = flag ? a : b;
            `OR1200_ALUOP_MOVHI: begin
                if (macrc_op)
                    result_reg = mult_mac_result;
                else
                    result_reg = b << 16;
            end
            `OR1200_ALUOP_MUL: begin
                `ifdef OR1200_MULT_IMPLEMENTED
                    result_reg = mult_mac_result;
                `else
                    result_reg = 32'd0;
                `endif
            end
            `OR1200_ALUOP_DIV,
            `OR1200_ALUOP_DIVU: begin
                `ifdef OR1200_MULT_IMPLEMENTED
                    `ifdef OR1200_IMPL_DIV
                        result_reg = mult_mac_result;
                    `else
                        result_reg = 32'd0;
                    `endif
                `else
                    result_reg = 32'd0;
                `endif
            end
            `OR1200_ALUOP_COMP: begin
                result_reg = 32'd0;
                flagforw_reg = flagcomp;
                flag_we_reg = 1'b1;
            end
            `OR1200_ALUOP_FF1: begin
                reg [5:0] i;
                reg [31:0] ff1_result;
                ff1_result = 32'd0;
                for (i = 0; i < 32; i = i + 1) begin
                    if (a[i] && (ff1_result == 32'd0)) begin
                        ff1_result = {27'd0, i} + 32'd1;
                    end
                end
                result_reg = ff1_result;
            end
            default: begin
                result_reg = 32'd0;
            end
        endcase
    end

endmodule
