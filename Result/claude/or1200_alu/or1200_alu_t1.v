`include "or1200_defines.v"

module or1200_alu
  #(parameter width = `OR1200_OPERAND_WIDTH)
(
    input [width-1:0] a,
    input [width-1:0] b,
    input [width-1:0] mult_mac_result,
    input macrc_op,
    input [`OR1200_ALUOP_WIDTH-1:0] alu_op,
    input [`OR1200_SHROTOP_WIDTH-1:0] shrot_op,
    input [`OR1200_COMPOP_WIDTH-1:0] comp_op,
    input [4:0] cust5_op,
    input [5:0] cust5_limm,
    output [width-1:0] result,
    output flagforw,
    output flag_we,
    output cyforw,
    output cy_we,
    input carry,
    input flag
);

wire [width:0] cy_sum_result_sum;
wire cy_sum;
wire [width-1:0] result_sum;
wire [width-1:0] result_and;
reg [width-1:0] shifted_rotated;
wire [width-1:0] comp_a;
wire [width-1:0] comp_b;
reg flagcomp;
reg [width-1:0] result_ff1;
reg [width-1:0] result_cust5;
wire a_eq_b;
wire a_lt_b;
reg [width-1:0] result_r;
reg flagforw_r;
reg flag_we_r;

`ifdef OR1200_IMPL_CY
reg cyforw_r;
reg cy_we_r;
`endif

`ifdef OR1200_IMPL_ADDC
wire [width:0] cy_csum_result_csum;
wire cy_csum;
wire [width-1:0] result_csum;
`endif

assign cy_sum_result_sum = a + b;
assign cy_sum = cy_sum_result_sum[width];
assign result_sum = cy_sum_result_sum[width-1:0];
assign result_and = a & b;

`ifdef OR1200_IMPL_ADDC
assign cy_csum_result_csum = a + b + {{width{1'b0}}, carry};
assign cy_csum = cy_csum_result_csum[width];
assign result_csum = cy_csum_result_csum[width-1:0];
`endif

assign comp_a = {a[width-1] ^ comp_op[3], a[width-2:0]};
assign comp_b = {b[width-1] ^ comp_op[3], b[width-2:0]};

`ifdef OR1200_IMPL_ALU_COMP1
assign a_eq_b = (comp_a == comp_b);
assign a_lt_b = (comp_a < comp_b);
`elsif OR1200_IMPL_ALU_COMP2
assign a_eq_b = (comp_a == comp_b);
assign a_lt_b = (comp_a < comp_b);
`else
assign a_eq_b = 1'b0;
assign a_lt_b = 1'b0;
`endif

always @(*) begin
    casex (a)
        32'b???????????????????????????????1: result_ff1 = 32'd1;
        32'b??????????????????????????????10: result_ff1 = 32'd2;
        32'b?????????????????????????????100: result_ff1 = 32'd3;
        32'b????????????????????????????1000: result_ff1 = 32'd4;
        32'b???????????????????????????10000: result_ff1 = 32'd5;
        32'b??????????????????????????100000: result_ff1 = 32'd6;
        32'b?????????????????????????1000000: result_ff1 = 32'd7;
        32'b????????????????????????10000000: result_ff1 = 32'd8;
        32'b???????????????????????100000000: result_ff1 = 32'd9;
        32'b??????????????????????1000000000: result_ff1 = 32'd10;
        32'b?????????????????????10000000000: result_ff1 = 32'd11;
        32'b????????????????????100000000000: result_ff1 = 32'd12;
        32'b???????????????????1000000000000: result_ff1 = 32'd13;
        32'b??????????????????10000000000000: result_ff1 = 32'd14;
        32'b?????????????????100000000000000: result_ff1 = 32'd15;
        32'b????????????????1000000000000000: result_ff1 = 32'd16;
        32'b???????????????10000000000000000: result_ff1 = 32'd17;
        32'b??????????????100000000000000000: result_ff1 = 32'd18;
        32'b?????????????1000000000000000000: result_ff1 = 32'd19;
        32'b????????????10000000000000000000: result_ff1 = 32'd20;
        32'b???????????100000000000000000000: result_ff1 = 32'd21;
        32'b??????????1000000000000000000000: result_ff1 = 32'd22;
        32'b?????????10000000000000000000000: result_ff1 = 32'd23;
        32'b????????100000000000000000000000: result_ff1 = 32'd24;
        32'b???????1000000000000000000000000: result_ff1 = 32'd25;
        32'b??????10000000000000000000000000: result_ff1 = 32'd26;
        32'b?????100000000000000000000000000: result_ff1 = 32'd27;
        32'b????1000000000000000000000000000: result_ff1 = 32'd28;
        32'b???10000000000000000000000000000: result_ff1 = 32'd29;
        32'b??100000000000000000000000000000: result_ff1 = 32'd30;
        32'b?1000000000000000000000000000000: result_ff1 = 32'd31;
        32'b10000000000000000000000000000000: result_ff1 = 32'd32;
`ifdef OR1200_CASE_DEFAULT
        default: result_ff1 = 32'd0;
`endif
    endcase
end

always @(*) begin
    result_cust5 = a;
    casex (cust5_op)
        5'h1: begin
            casex (cust5_limm[1:0])
                2'd0: result_cust5 = {a[31:8], b[7:0]};
                2'd1: result_cust5 = {a[31:16], b[7:0], a[7:0]};
                2'd2: result_cust5 = {a[31:24], b[7:0], a[15:0]};
                2'd3: result_cust5 = {b[7:0], a[23:0]};
`ifdef OR1200_CASE_DEFAULT
                default: result_cust5 = a;
`endif
            endcase
        end
        5'h2: result_cust5 = a | (32'd1 << cust5_limm);
        5'h3: result_cust5 = a & (32'hffff_ffff ^ (32'd1 << cust5_limm));
        default: result_cust5 = a;
    endcase
end

always @(*) begin
    casex (shrot_op)
        `OR1200_SHROTOP_SLL: shifted_rotated = a << b[4:0];
        `OR1200_SHROTOP_SRL: shifted_rotated = a >> b[4:0];
`ifdef OR1200_IMPL_ALU_ROTATE
        `OR1200_SHROTOP_ROR: shifted_rotated = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
`endif
        default: shifted_rotated = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
    endcase
end

always @(*) begin
    flagcomp = 1'b0;
`ifdef OR1200_IMPL_ALU_COMP1
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = a_eq_b;
        `OR1200_COP_SFNE: flagcomp = !a_eq_b;
        `OR1200_COP_SFGT: flagcomp = !a_eq_b & !a_lt_b;
        `OR1200_COP_SFGE: flagcomp = !a_lt_b;
        `OR1200_COP_SFLT: flagcomp = a_lt_b;
        `OR1200_COP_SFLE: flagcomp = a_eq_b | a_lt_b;
        default: flagcomp = 1'b0;
    endcase
`elsif OR1200_IMPL_ALU_COMP2
    casex (comp_op[2:0])
        `OR1200_COP_SFEQ: flagcomp = (comp_a == comp_b);
        `OR1200_COP_SFNE: flagcomp = (comp_a != comp_b);
        `OR1200_COP_SFGT: flagcomp = (comp_a > comp_b);
        `OR1200_COP_SFGE: flagcomp = (comp_a >= comp_b);
        `OR1200_COP_SFLT: flagcomp = (comp_a < comp_b);
        `OR1200_COP_SFLE: flagcomp = (comp_a <= comp_b);
        default: flagcomp = 1'b0;
    endcase
`endif
end

always @(*) begin
`ifdef OR1200_CASE_DEFAULT
    casex (alu_op)
`else
    casex (alu_op)
`endif
        `OR1200_ALUOP_ADD: result_r = result_sum;
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: result_r = result_csum;
`endif
        `OR1200_ALUOP_SUB: result_r = a - b;
        `OR1200_ALUOP_OR: result_r = a | b;
        `OR1200_ALUOP_XOR: result_r = a ^ b;
        `OR1200_ALUOP_IMM: result_r = b;
        `OR1200_ALUOP_MOVHI: result_r = macrc_op ? mult_mac_result : b << 16;
        `OR1200_ALUOP_SHROT: result_r = shifted_rotated;
        `OR1200_ALUOP_CUST5: result_r = result_cust5;
        `OR1200_ALUOP_CMOV: result_r = flag ? a : b;
        `OR1200_ALUOP_FF1: result_r = result_ff1;
`ifdef OR1200_MULT_IMPLEMENTED
        `OR1200_ALUOP_MUL: result_r = mult_mac_result;
`ifdef OR1200_IMPL_DIV
        `OR1200_ALUOP_DIV: result_r = mult_mac_result;
        `OR1200_ALUOP_DIVU: result_r = mult_mac_result;
`endif
`endif
`ifdef OR1200_CASE_DEFAULT
        default: result_r = result_and;
`else
        `OR1200_ALUOP_COMP,
        `OR1200_ALUOP_AND: result_r = result_and;
`endif
    endcase
end

assign result = result_r;

always @(*) begin
    flagforw_r = 1'b0;
    flag_we_r = 1'b0;
    casex (alu_op)
        `OR1200_ALUOP_COMP: begin
            flagforw_r = flagcomp;
            flag_we_r = 1'b1;
        end
`ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        `OR1200_ALUOP_ADD: begin
            flagforw_r = (result_sum == {width{1'b0}});
            flag_we_r = 1'b1;
        end
`ifdef OR1200_IMPL_ADDC
        `OR1200_ALUOP_ADDC: begin
            flagforw_r = (result_csum == {width{1'b0}});
            flag_we_r = 1'b1;
        end
`endif
        `OR1200_ALUOP_AND: begin
            flagforw_r = (result_and == {width{1'b0}});
            flag_we_r = 1'b1;
        end
`endif
`ifdef OR1200_CASE_DEFAULT
        default: begin
            flagforw_r = 1'b0;
            flag_we_r = 1'b0;
        end
`endif
    endcase
end

assign flagforw = flagforw_r;
assign flag_we = flag_we_r;

`ifdef OR1200_IMPL_CY
always @(*) begin
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
`ifdef OR1200_CASE_DEFAULT
        default: begin
            cyforw_r = 1'b0;
            cy_we_r = 1'b0;
        end
`endif
    endcase
end

assign cyforw = cyforw_r;
assign cy_we = cy_we_r;
`else
assign cyforw = 1'b0;
assign cy_we = 1'b0;
`endif

`ifdef OR1200_WARNINGS
always @(alu_op) begin
    if (^alu_op === 1'bx)
        $display("WARNING: or1200_alu alu_op is unknown");
end
`endif

endmodule
