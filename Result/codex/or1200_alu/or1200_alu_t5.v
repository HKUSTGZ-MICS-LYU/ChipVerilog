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
    output [31:0] result,
    output flagforw,
    output flag_we,
    output cyforw,
    output cy_we,
    input carry,
    input flag
);

reg [31:0] result;
reg flagforw;
reg flag_we;
reg cyforw;
reg cy_we;

wire [32:0] cy_sum_result_sum;
wire cy_sum;
wire [31:0] result_sum;
wire [31:0] result_and;
`ifdef OR1200_IMPL_ADDC
wire [32:0] cy_csum_result_csum;
wire cy_csum;
wire [31:0] result_csum;
`endif
wire [31:0] comp_a;
wire [31:0] comp_b;
reg flagcomp;
reg [31:0] shifted_rotated;
reg [31:0] result_cust5;
reg [31:0] result_ff1;
`ifdef OR1200_IMPL_ALU_COMP1
wire a_eq_b;
wire a_lt_b;
`endif

assign cy_sum_result_sum = a + b;
assign cy_sum = cy_sum_result_sum[32];
assign result_sum = cy_sum_result_sum[31:0];
assign result_and = a & b;
`ifdef OR1200_IMPL_ADDC
assign cy_csum_result_csum = a + b + {32'd0, carry};
assign cy_csum = cy_csum_result_csum[32];
assign result_csum = cy_csum_result_csum[31:0];
`endif
assign comp_a = {a[31] ^ comp_op[3], a[30:0]};
assign comp_b = {b[31] ^ comp_op[3], b[30:0]};

`ifdef OR1200_IMPL_ALU_COMP1
assign a_eq_b = (comp_a == comp_b);
assign a_lt_b = (comp_a < comp_b);

always @* begin
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = a_eq_b;
        `OR1200_COP_SFNE: flagcomp = !a_eq_b;
        `OR1200_COP_SFGT: flagcomp = !(a_eq_b | a_lt_b);
        `OR1200_COP_SFGE: flagcomp = !a_lt_b;
        `OR1200_COP_SFLT: flagcomp = a_lt_b;
        `OR1200_COP_SFLE: flagcomp = a_eq_b | a_lt_b;
`ifdef OR1200_CASE_DEFAULT
        default: flagcomp = 1'b0;
`endif
    endcase
end
`else
`ifdef OR1200_IMPL_ALU_COMP2
always @* begin
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
        `OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
        `OR1200_COP_SFGT: flagcomp = (comp_a > comp_b);
        `OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
        `OR1200_COP_SFLT: flagcomp = (comp_a < comp_b);
        `OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
`ifdef OR1200_CASE_DEFAULT
        default: flagcomp = 1'b0;
`endif
    endcase
end
`endif
`endif

always @* begin
    casex (shrot_op)
        `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
        `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
        `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
        default: shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
    endcase
end

always @* begin
    casex (cust5_op)
        5'h1: begin
            casex (cust5_limm[1:0])
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

always @* begin
    if (a[0])
        result_ff1 = 32'd1;
    else if (a[1])
        result_ff1 = 32'd2;
    else if (a[2])
        result_ff1 = 32'd3;
    else if (a[3])
        result_ff1 = 32'd4;
    else if (a[4])
        result_ff1 = 32'd5;
    else if (a[5])
        result_ff1 = 32'd6;
    else if (a[6])
        result_ff1 = 32'd7;
    else if (a[7])
        result_ff1 = 32'd8;
    else if (a[8])
        result_ff1 = 32'd9;
    else if (a[9])
        result_ff1 = 32'd10;
    else if (a[10])
        result_ff1 = 32'd11;
    else if (a[11])
        result_ff1 = 32'd12;
    else if (a[12])
        result_ff1 = 32'd13;
    else if (a[13])
        result_ff1 = 32'd14;
    else if (a[14])
        result_ff1 = 32'd15;
    else if (a[15])
        result_ff1 = 32'd16;
    else if (a[16])
        result_ff1 = 32'd17;
    else if (a[17])
        result_ff1 = 32'd18;
    else if (a[18])
        result_ff1 = 32'd19;
    else if (a[19])
        result_ff1 = 32'd20;
    else if (a[20])
        result_ff1 = 32'd21;
    else if (a[21])
        result_ff1 = 32'd22;
    else if (a[22])
        result_ff1 = 32'd23;
    else if (a[23])
        result_ff1 = 32'd24;
    else if (a[24])
        result_ff1 = 32'd25;
    else if (a[25])
        result_ff1 = 32'd26;
    else if (a[26])
        result_ff1 = 32'd27;
    else if (a[27])
        result_ff1 = 32'd28;
    else if (a[28])
        result_ff1 = 32'd29;
    else if (a[29])
        result_ff1 = 32'd30;
    else if (a[30])
        result_ff1 = 32'd31;
    else if (a[31])
        result_ff1 = 32'd32;
    else
        result_ff1 = 32'd0;
end

always @* begin
    casex (alu_op)
        `OR1200_ALUOP_ADD: result = result_sum;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: result = result_csum;
`endif
        `OR1200_ALUOP_SUB: result = a - b;
        `OR1200_ALUOP_AND: result = result_and;
        `OR1200_ALUOP_OR: result = a | b;
        `OR1200_ALUOP_XOR: result = a ^ b;
        `OR1200_ALUOP_IMM: result = b;
        `OR1200_ALUOP_MOVHI: begin
            if (macrc_op)
                result = mult_mac_result;
            else
                result = b << 16;
        end
        `OR1200_ALUOP_SHROT: result = shifted_rotated;
        `OR1200_ALUOP_COMP: result = 32'd0;
        `OR1200_ALUOP_FF1: result = result_ff1;
        `OR1200_ALUOP_CUST5: result = result_cust5;
        `OR1200_ALUOP_CMOV: begin
            if (flag)
                result = a;
            else
                result = b;
        end
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_ALUOP_MUL: result = mult_mac_result;
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV: result = mult_mac_result;
        `OR1200_ALUOP_DIVU: result = mult_mac_result;
`endif
`endif
`ifdef OR1200_CASE_DEFAULT
        default: result = 32'd0;
`endif
    endcase
end

always @* begin
    flagforw = 1'b0;
    flag_we = 1'b0;

    casex (alu_op)
        `OR1200_ALUOP_COMP: begin
            flagforw = flagcomp;
            flag_we = 1'b1;
        end
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD: begin
            flagforw = (result_sum == 32'b0);
            flag_we = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            flagforw = (result_csum == 32'b0);
            flag_we = 1'b1;
        end
`endif
        `OR1200_ALUOP_AND: begin
            flagforw = (result_and == 32'b0);
            flag_we = 1'b1;
        end
`endif
`ifdef OR1200_CASE_DEFAULT
        default: begin
            flagforw = 1'b0;
            flag_we = 1'b0;
        end
`endif
    endcase
end

always @* begin
    cyforw = 1'b0;
    cy_we = 1'b0;
`ifdef OR1200_IMPL_CY
    casex (alu_op)
        `OR1200_ALUOP_ADD: begin
            cyforw = cy_sum;
            cy_we = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            cyforw = cy_csum;
            cy_we = 1'b1;
        end
`endif
`ifdef OR1200_CASE_DEFAULT
        default: begin
            cyforw = 1'b0;
            cy_we = 1'b0;
        end
`endif
    endcase
`endif
end

`ifdef OR1200_WARNINGS
// synopsys translate_off
always @(alu_op or shrot_op or comp_op or cust5_op or cust5_limm or macrc_op) begin
    if (^alu_op === 1'bx)
        $display("%t: WARNING: or1200_alu alu_op contains unknown bits.", $time);
    if (^shrot_op === 1'bx)
        $display("%t: WARNING: or1200_alu shrot_op contains unknown bits.", $time);
    if (^comp_op === 1'bx)
        $display("%t: WARNING: or1200_alu comp_op contains unknown bits.", $time);
    if (^cust5_op === 1'bx)
        $display("%t: WARNING: or1200_alu cust5_op contains unknown bits.", $time);
    if (^cust5_limm === 1'bx)
        $display("%t: WARNING: or1200_alu cust5_limm contains unknown bits.", $time);
    if (macrc_op === 1'bx)
        $display("%t: WARNING: or1200_alu macrc_op is unknown.", $time);
end
// synopsys translate_on
`endif

endmodule
