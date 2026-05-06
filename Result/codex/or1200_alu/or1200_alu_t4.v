`timescale 1ns/1ps
`include "or1200_defines.v"
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
    wire [32:0] sum  = {1'b0,a} + {1'b0,b};
    wire [32:0] csum = {1'b0,a} + {1'b0,b} + carry;
    wire [32:0] diff = {1'b0,a} - {1'b0,b};
    wire signed_cmp = comp_op[3];
    wire [31:0] ca = signed_cmp ? {~a[31],a[30:0]} : a;
    wire [31:0] cb = signed_cmp ? {~b[31],b[30:0]} : b;
    reg cmp;
    integer i;
    reg [31:0] ff1;
    reg [31:0] shrot_res;
    reg [31:0] cust5_res;
    always @(*) begin
        case (comp_op[2:0])
            `OR1200_COP_SFEQ: cmp = (a == b);
            `OR1200_COP_SFNE: cmp = (a != b);
            `OR1200_COP_SFGT: cmp = (ca >  cb);
            `OR1200_COP_SFGE: cmp = (ca >= cb);
            `OR1200_COP_SFLT: cmp = (ca <  cb);
            `OR1200_COP_SFLE: cmp = (ca <= cb);
            default: cmp = 1'b0;
        endcase
        case (shrot_op)
            `OR1200_SHROTOP_SLL: shrot_res = a << b[4:0];
            `OR1200_SHROTOP_SRL: shrot_res = a >> b[4:0];
            `OR1200_SHROTOP_ROR: shrot_res = (a >> b[4:0]) | (a << (6'd32 - {1'b0,b[4:0]}));
            default: shrot_res = $signed(a) >>> b[4:0];
        endcase
        ff1 = 0;
        for (i=31; i>=0; i=i-1) if (a[i]) ff1 = i + 1;
        cust5_res = a;
        case (cust5_op[4:3])
            2'b00: begin
                cust5_res = a;
                case (cust5_limm[1:0])
                    2'd0: cust5_res[7:0]   = b[7:0];
                    2'd1: cust5_res[15:8]  = b[7:0];
                    2'd2: cust5_res[23:16] = b[7:0];
                    2'd3: cust5_res[31:24] = b[7:0];
                endcase
            end
            2'b01: cust5_res = a |  (32'd1 << cust5_limm[4:0]);
            2'b10: cust5_res = a & ~(32'd1 << cust5_limm[4:0]);
            default: cust5_res = a;
        endcase
        result = 32'd0; flagforw = 1'b0; flag_we = 1'b0; cyforw = 1'b0; cy_we = 1'b0;
        case (alu_op)
            `OR1200_ALUOP_ADD:  begin result = sum[31:0];  cyforw = sum[32];  cy_we = 1'b1; end
            `OR1200_ALUOP_ADDC: begin result = csum[31:0]; cyforw = csum[32]; cy_we = 1'b1; end
            `OR1200_ALUOP_SUB:  begin result = diff[31:0]; cyforw = diff[32]; end
            `OR1200_ALUOP_AND:  result = a & b;
            `OR1200_ALUOP_OR:   result = a | b;
            `OR1200_ALUOP_XOR:  result = a ^ b;
            `OR1200_ALUOP_MUL,
            `OR1200_ALUOP_DIV,
            `OR1200_ALUOP_DIVU: result = mult_mac_result;
            `OR1200_ALUOP_SHROT: result = shrot_res;
            `OR1200_ALUOP_IMM:   result = b;
            `OR1200_ALUOP_MOVHI: result = macrc_op ? mult_mac_result : {b[15:0],16'd0};
            `OR1200_ALUOP_COMP: begin result = {31'd0,cmp}; flagforw = cmp; flag_we = 1'b1; end
            `OR1200_ALUOP_CMOV: result = flag ? a : b;
            `OR1200_ALUOP_FF1:  result = ff1;
            `OR1200_ALUOP_CUST5: result = cust5_res;
            default: result = 32'd0;
        endcase
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        if (alu_op == `OR1200_ALUOP_ADD || alu_op == `OR1200_ALUOP_ADDC || alu_op == `OR1200_ALUOP_AND) begin
            flagforw = (result == 0); flag_we = 1'b1;
        end
`endif
`ifndef OR1200_IMPL_ADDC
        cyforw = 1'b0; cy_we = 1'b0;
`endif
    end
endmodule
