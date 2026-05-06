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

wire [32:0] cy_sum_result_sum;
wire        cy_sum;
wire [31:0] result_sum;
wire [31:0] result_and;
wire [31:0] comp_a;
wire [31:0] comp_b;
wire [31:0] ff1_result;
reg  [31:0] shifted_rotated;
reg  [31:0] result_cust5;
reg  [31:0] result_r;
reg         flagforw_r;
reg         flag_we_r;
reg         flagcomp;

`ifdef OR1200_IMPL_CY
reg cyforw_r;
reg cy_we_r;
`endif

`ifdef OR1200_IMPL_ADDC
wire [32:0] cy_csum_result_csum;
wire        cy_csum;
wire [31:0] result_csum;
`endif

assign cy_sum_result_sum = a + b;
assign cy_sum = cy_sum_result_sum[32];
assign result_sum = cy_sum_result_sum[31:0];
assign result_and = a & b;
assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
assign comp_b = {b[31] ^ comp_op[3], b[30:0]};
assign ff1_result =
    a[0]  ? 32'd1  : a[1]  ? 32'd2  : a[2]  ? 32'd3  : a[3]  ? 32'd4  :
    a[4]  ? 32'd5  : a[5]  ? 32'd6  : a[6]  ? 32'd7  : a[7]  ? 32'd8  :
    a[8]  ? 32'd9  : a[9]  ? 32'd10 : a[10] ? 32'd11 : a[11] ? 32'd12 :
    a[12] ? 32'd13 : a[13] ? 32'd14 : a[14] ? 32'd15 : a[15] ? 32'd16 :
    a[16] ? 32'd17 : a[17] ? 32'd18 : a[18] ? 32'd19 : a[19] ? 32'd20 :
    a[20] ? 32'd21 : a[21] ? 32'd22 : a[22] ? 32'd23 : a[23] ? 32'd24 :
    a[24] ? 32'd25 : a[25] ? 32'd26 : a[26] ? 32'd27 : a[27] ? 32'd28 :
    a[28] ? 32'd29 : a[29] ? 32'd30 : a[30] ? 32'd31 : a[31] ? 32'd32 :
    32'd0;

`ifdef OR1200_IMPL_ADDC
assign cy_csum_result_csum = a + b + {32'd0, carry};
assign cy_csum = cy_csum_result_csum[32];
assign result_csum = cy_csum_result_csum[31:0];
`endif

always @(a or b or shrot_op) begin
    casex (shrot_op)
        `OR1200_SHROTOP_SLL:
            shifted_rotated = a << b[4:0];
        `OR1200_SHROTOP_SRL:
            shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
        `OR1200_SHROTOP_ROR:
            shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
        default:
            shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
    endcase
end

always @(a or b or cust5_op or cust5_limm) begin
    casex (cust5_op)
        5'h1:
            casex (cust5_limm[1:0])
                2'd0: result_cust5 = {a[31:8], b[7:0]};
                2'd1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                2'd2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                2'd3: result_cust5 = {b[7:0], a[23:0]};
`ifdef OR1200_CASE_DEFAULT
                default: result_cust5 = a;
`else
`ifdef OR1200_WARNINGS
                default: begin
                    result_cust5 = a;
                    $display("or1200_alu: wrong cust5_limm select");
                end
`endif
`endif
            endcase
        5'h2:
            result_cust5 = a | (1 << cust5_limm);
        5'h3:
            result_cust5 = a & (32'hffffffff ^ (1 << cust5_limm));
        default:
            result_cust5 = a;
    endcase
end

`ifdef OR1200_IMPL_ALU_COMP1
wire a_eq_b;
wire a_lt_b;

assign a_eq_b = comp_a == comp_b;
assign a_lt_b = comp_a < comp_b;

always @(a_eq_b or a_lt_b or comp_op) begin
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ:
            flagcomp = a_eq_b;
        `OR1200_COP_SFNE:
            flagcomp = !a_eq_b;
        `OR1200_COP_SFGT:
            flagcomp = !(a_eq_b | a_lt_b);
        `OR1200_COP_SFGE:
            flagcomp = !a_lt_b;
        `OR1200_COP_SFLT:
            flagcomp = a_lt_b;
        `OR1200_COP_SFLE:
            flagcomp = a_eq_b | a_lt_b;
`ifdef OR1200_CASE_DEFAULT
        default:
            flagcomp = 1'b0;
`else
`ifdef OR1200_WARNINGS
        default: begin
            flagcomp = 1'b0;
            $display("or1200_alu: wrong compare opcode");
        end
`endif
`endif
    endcase
end
`elsif OR1200_IMPL_ALU_COMP2
always @(comp_a or comp_b or comp_op) begin
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ:
            flagcomp = comp_a == comp_b;
        `OR1200_COP_SFNE:
            flagcomp = comp_a != comp_b;
        `OR1200_COP_SFGT:
            flagcomp = comp_a > comp_b;
        `OR1200_COP_SFGE:
            flagcomp = comp_a >= comp_b;
        `OR1200_COP_SFLT:
            flagcomp = comp_a < comp_b;
        `OR1200_COP_SFLE:
            flagcomp = comp_a <= comp_b;
`ifdef OR1200_CASE_DEFAULT
        default:
            flagcomp = 1'b0;
`else
`ifdef OR1200_WARNINGS
        default: begin
            flagcomp = 1'b0;
            $display("or1200_alu: wrong compare opcode");
        end
`endif
`endif
    endcase
end
`else
always @(comp_op) begin
    flagcomp = 1'b0;
end
`endif

always @(alu_op or result_sum or a or b or macrc_op or mult_mac_result or shifted_rotated or result_cust5 or flag or ff1_result
`ifdef OR1200_IMPL_ADDC
    or result_csum
`endif
) begin
    casex (alu_op)
        `OR1200_ALUOP_ADD:
            result_r = result_sum;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC:
            result_r = result_csum;
`endif
        `OR1200_ALUOP_SUB:
            result_r = a - b;
        `OR1200_ALUOP_AND:
            result_r = a & b;
        `OR1200_ALUOP_OR:
            result_r = a | b;
        `OR1200_ALUOP_XOR:
            result_r = a ^ b;
        `OR1200_ALUOP_MOVHI:
            result_r = macrc_op ? mult_mac_result : b << 16;
        `OR1200_ALUOP_SHROT:
            result_r = shifted_rotated;
        `OR1200_ALUOP_COMP:
            result_r = 32'd0;
        `OR1200_ALUOP_IMM:
            result_r = b;
        `OR1200_ALUOP_CUST5:
            result_r = result_cust5;
        `OR1200_ALUOP_CMOV:
            result_r = flag ? a : b;
        `OR1200_ALUOP_FF1:
            result_r = ff1_result;
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_ALUOP_MUL:
            result_r = mult_mac_result;
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV:
            result_r = mult_mac_result;
        `OR1200_ALUOP_DIVU:
            result_r = mult_mac_result;
`endif
`endif
`ifdef OR1200_CASE_DEFAULT
        default:
            result_r = 32'h00000000;
`else
`ifdef OR1200_WARNINGS
        default: begin
            result_r = 32'h00000000;
            $display("or1200_alu: wrong alu opcode");
        end
`endif
`endif
    endcase
end

always @(alu_op or flagcomp or result_sum or result_and
`ifdef OR1200_IMPL_ADDC
    or result_csum
`endif
) begin
    flagforw_r = 1'b0;
    flag_we_r = 1'b0;

    casex (alu_op)
        `OR1200_ALUOP_COMP: begin
            flagforw_r = flagcomp;
            flag_we_r = 1'b1;
        end
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD: begin
            flagforw_r = ~|result_sum;
            flag_we_r = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            flagforw_r = ~|result_csum;
            flag_we_r = 1'b1;
        end
`endif
        `OR1200_ALUOP_AND: begin
            flagforw_r = ~|result_and;
            flag_we_r = 1'b1;
        end
`endif
    endcase
end

`ifdef OR1200_IMPL_CY
always @(alu_op or cy_sum
`ifdef OR1200_IMPL_ADDC
    or cy_csum
`endif
) begin
    cyforw_r = 1'b0;
    cy_we_r = 1'b0;

    casex (alu_op)
        `OR1200_ALUOP_ADD: begin
            cyforw_r = cy_sum;
            cy_we_r = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            cyforw_r = cy_csum;
            cy_we_r = 1'b1;
        end
`endif
    endcase
end
`endif

assign result = result_r;
assign flagforw = flagforw_r;
assign flag_we = flag_we_r;
`ifdef OR1200_IMPL_CY
assign cyforw = cyforw_r;
assign cy_we = cy_we_r;
`else
assign cyforw = 1'b0;
assign cy_we = 1'b0;
`endif

endmodule
