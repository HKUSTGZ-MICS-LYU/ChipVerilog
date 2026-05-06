`timescale 1ns / 1ns

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

// ------------------------------------------------------------------
// Local parameter definitions (matching original OR1200 RTL constants)
// ------------------------------------------------------------------
localparam OR1200_ALUOP_ADD   = 4'b0000;
localparam OR1200_ALUOP_ADDC  = 4'b0001;
localparam OR1200_ALUOP_SUB   = 4'b0010;
localparam OR1200_ALUOP_AND   = 4'b0011;
localparam OR1200_ALUOP_OR    = 4'b0100;
localparam OR1200_ALUOP_XOR   = 4'b0101;
localparam OR1200_ALUOP_IMM   = 4'b0110;
localparam OR1200_ALUOP_SHROT = 4'b0111;
localparam OR1200_ALUOP_CUST5 = 4'b1000;
localparam OR1200_ALUOP_CMOV  = 4'b1001;
localparam OR1200_ALUOP_MOVHI = 4'b1010;
localparam OR1200_ALUOP_MUL   = 4'b1011;
localparam OR1200_ALUOP_DIV   = 4'b1100;
localparam OR1200_ALUOP_DIVU  = 4'b1101;
localparam OR1200_ALUOP_FF1   = 4'b1110;
localparam OR1200_ALUOP_COMP  = 4'b1111;

localparam OR1200_SHROTOP_SLL = 2'b00;
localparam OR1200_SHROTOP_SRL = 2'b01;
localparam OR1200_SHROTOP_ROR = 2'b10;
// 2'b11 default --> arithmetic right shift

localparam OR1200_COP_SFEQ   = 3'b000;
localparam OR1200_COP_SFNE   = 3'b001;
localparam OR1200_COP_SFGT   = 3'b010;
localparam OR1200_COP_SFGE   = 3'b011;
localparam OR1200_COP_SFLT   = 3'b100;
localparam OR1200_COP_SFLE   = 3'b101;

// ------------------------------------------------------------------
// Internal wires / regs
// ------------------------------------------------------------------
wire [32:0] cy_sum_result_sum;    // {cy, result_sum}
wire [32:0] cy_csum_result_csum;  // {cy_csum, result_csum}
wire [31:0] result_sum;
wire [31:0] result_csum;
wire [31:0] result_and;
wire [31:0] shifted_rotated;
wire [31:0] result_cust5;
wire        flagcomp;
wire [31:0] ff1_result;

// ------------------------------------------------------------------
// ADD sum
// ------------------------------------------------------------------
assign cy_sum_result_sum = a + b;
assign result_sum = cy_sum_result_sum[31:0];
wire cy_sum = cy_sum_result_sum[32];

// ------------------------------------------------------------------
// ADDC sum (only if OR1200_IMPL_ADDC is defined)
// ------------------------------------------------------------------
`ifdef OR1200_IMPL_ADDC
assign cy_csum_result_csum = a + b + {31'd0, carry};
assign result_csum = cy_csum_result_csum[31:0];
wire cy_csum = cy_csum_result_csum[32];
`else
assign result_csum = 32'd0;
wire cy_csum = 1'b0;
`endif

// ------------------------------------------------------------------
// AND result
// ------------------------------------------------------------------
assign result_and = a & b;

// ------------------------------------------------------------------
// FF1 (first one from LSB)
// ------------------------------------------------------------------
integer i;
reg [31:0] ff1_result_reg;
always @(*) begin
    ff1_result_reg = 32'd0;
    for (i = 0; i < 32; i = i + 1) begin
        if (a[i]) begin
            ff1_result_reg = i + 1;
            disable ff1_loop;
        end
    end
end
assign ff1_result = ff1_result_reg;

// ------------------------------------------------------------------
// Shift / Rotate
// ------------------------------------------------------------------
reg [31:0] shifted_rotated_reg;
always @(*) begin
    casex (shrot_op)
        OR1200_SHROTOP_SLL: shifted_rotated_reg = a << b[4:0];
        OR1200_SHROTOP_SRL: shifted_rotated_reg = a >> b[4:0];
        `ifdef OR1200_IMPL_ALU_ROTATE
        OR1200_SHROTOP_ROR: shifted_rotated_reg = (a << (6'd32 - {1'b0, b[4:0]})) | (a >> b[4:0]);
        `endif
        default: shifted_rotated_reg = ({32{a[31]}} << (6'd32 - {1'b0, b[4:0]})) | a >> b[4:0];
    endcase
end
assign shifted_rotated = shifted_rotated_reg;

// ------------------------------------------------------------------
// Compare
// ------------------------------------------------------------------
`ifdef OR1200_IMPL_ALU_COMP1
reg a_eq_b, a_lt_b;
reg flagcomp_reg;
always @(*) begin
    a_eq_b = (comp_a == comp_b);
    a_lt_b = (comp_a < comp_b);
    casex (comp_op[2:0])
        OR1200_COP_SFEQ: flagcomp_reg = a_eq_b;
        OR1200_COP_SFNE: flagcomp_reg = !a_eq_b;
        OR1200_COP_SFGT: flagcomp_reg = !a_eq_b & !a_lt_b;
        OR1200_COP_SFGE: flagcomp_reg = !a_lt_b;
        OR1200_COP_SFLT: flagcomp_reg = a_lt_b;
        OR1200_COP_SFLE: flagcomp_reg = a_eq_b | a_lt_b;
        default: flagcomp_reg = 1'b0;
    endcase
end
assign flagcomp = flagcomp_reg;
`endif

`ifdef OR1200_IMPL_ALU_COMP2
wire [31:0] comp_a = {a[31] ^ comp_op[3], a[30:0]};
wire [31:0] comp_b = {b[31] ^ comp_op[3], b[30:0]};
wire comp_eq = (comp_a == comp_b);
wire comp_lt = (comp_a < comp_b);
reg flagcomp_reg;
always @(*) begin
    casex (comp_op[2:0])
        OR1200_COP_SFEQ: flagcomp_reg = comp_eq;
        OR1200_COP_SFNE: flagcomp_reg = !comp_eq;
        OR1200_COP_SFGT: flagcomp_reg = !comp_eq & !comp_lt;
        OR1200_COP_SFGE: flagcomp_reg = !comp_lt;
        OR1200_COP_SFLT: flagcomp_reg = comp_lt;
        OR1200_COP_SFLE: flagcomp_reg = comp_eq | comp_lt;
        default: flagcomp_reg = 1'b0;
    endcase
end
assign flagcomp = flagcomp_reg;
`endif

// ------------------------------------------------------------------
// CUST5 custom operations
// ------------------------------------------------------------------
reg [31:0] result_cust5_reg;
always @(*) begin
    casex (cust5_op)
        5'h01: begin
            case (cust5_limm[1:0])
                2'b00: result_cust5_reg = {a[31:8], b[7:0]};
                2'b01: result_cust5_reg = {a[31:16], b[7:0], a[7:0]};
                2'b10: result_cust5_reg = {a[31:24], b[7:0], a[15:0]};
                2'b11: result_cust5_reg = {b[7:0], a[23:0]};
                default: result_cust5_reg = a; // should not happen
            endcase
        end
        5'h02: result_cust5_reg = a | (32'd1 << cust5_limm);
        5'h03: result_cust5_reg = a & (32'hFFFFFFFF ^ (32'd1 << cust5_limm));
        default: result_cust5_reg = a;
    endcase
end
assign result_cust5 = result_cust5_reg;

// ------------------------------------------------------------------
// Main result mux (combinational, using casex)
// ------------------------------------------------------------------
reg [31:0] result_reg;
always @(*) begin
    casex (alu_op)
        OR1200_ALUOP_ADD:   result_reg = result_sum;
        `ifdef OR1200_IMPL_ADDC
        OR1200_ALUOP_ADDC:  result_reg = result_csum;
        `endif
        OR1200_ALUOP_SUB:   result_reg = a - b;
        OR1200_ALUOP_AND:   result_reg = result_and;
        OR1200_ALUOP_OR:    result_reg = a | b;
        OR1200_ALUOP_XOR:   result_reg = a ^ b;
        OR1200_ALUOP_IMM:   result_reg = b;
        OR1200_ALUOP_SHROT: result_reg = shifted_rotated;
        OR1200_ALUOP_CUST5: result_reg = result_cust5;
        OR1200_ALUOP_CMOV:  result_reg = flag ? a : b;
        OR1200_ALUOP_MOVHI: begin
            if (macrc_op)
                result_reg = mult_mac_result;
            else
                result_reg = b << 16;
        end
        `ifdef OR1200_MULT_IMPLEMENTED
        OR1200_ALUOP_MUL:   result_reg = mult_mac_result;
        `endif
        `ifdef OR1200_MULT_IMPLEMENTED
        `ifdef OR1200_IMPL_DIV
        OR1200_ALUOP_DIV:   result_reg = mult_mac_result;
        OR1200_ALUOP_DIVU:  result_reg = mult_mac_result;
        `endif
        `endif
        OR1200_ALUOP_FF1:   result_reg = ff1_result;
        OR1200_ALUOP_COMP:  result_reg = {31'd0, flagcomp};
        `ifdef OR1200_CASE_DEFAULT
        default:            result_reg = {32{1'bx}};
        `endif
    endcase
end
assign result = result_reg;

// ------------------------------------------------------------------
// Flag forwarding (flagforw, flag_we)
// ------------------------------------------------------------------
reg flagforw_reg;
reg flag_we_reg;
always @(*) begin
    flagforw_reg = 1'b0;
    flag_we_reg  = 1'b0;

    casex (alu_op)
        OR1200_ALUOP_COMP: begin
            flagforw_reg = flagcomp;
            flag_we_reg  = 1'b1;
        end
        `ifdef OR1200_ADDITIONAL_FLAG_MODIFIERS
        OR1200_ALUOP_ADD: begin
            flagforw_reg = (result_sum == 32'd0);
            flag_we_reg  = 1'b1;
        end
        `ifdef OR1200_IMPL_ADDC
        OR1200_ALUOP_ADDC: begin
            flagforw_reg = (result_csum == 32'd0);
            flag_we_reg  = 1'b1;
        end
        `endif
        OR1200_ALUOP_AND: begin
            flagforw_reg = (result_and == 32'd0);
            flag_we_reg  = 1'b1;
        end
        `endif
        `ifdef OR1200_CASE_DEFAULT
        default: begin
            flagforw_reg = 1'b0;
            flag_we_reg  = 1'b0;
        end
        `endif
    endcase
end
assign flagforw = flagforw_reg;
assign flag_we  = flag_we_reg;

// ------------------------------------------------------------------
// Carry forwarding (cyforw, cy_we)
// ------------------------------------------------------------------
reg cyforw_reg;
reg cy_we_reg;
always @(*) begin
    cyforw_reg = 1'b0;
    cy_we_reg  = 1'b0;

    `ifdef OR1200_IMPL_CY
    casex (alu_op)
        OR1200_ALUOP_ADD: begin
            cyforw_reg = cy_sum;
            cy_we_reg  = 1'b1;
        end
        `ifdef OR1200_IMPL_ADDC
        OR1200_ALUOP_ADDC: begin
            cyforw_reg = cy_csum;
            cy_we_reg  = 1'b1;
        end
        `endif
        `ifdef OR1200_CASE_DEFAULT
        default: begin
            cyforw_reg = 1'b0;
            cy_we_reg  = 1'b0;
        end
        `endif
    endcase
    `endif
end
assign cyforw = cyforw_reg;
assign cy_we  = cy_we_reg;

endmodule
