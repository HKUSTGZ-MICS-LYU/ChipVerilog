`timescale 1ns/1ps

`ifndef OR1200_ALUOP_MUL
`define OR1200_ALUOP_MUL  4'd0
`endif
`ifndef OR1200_ALUOP_DIV
`define OR1200_ALUOP_DIV  4'd1
`endif
`ifndef OR1200_ALUOP_DIVU
`define OR1200_ALUOP_DIVU 4'd2
`endif

`ifndef OR1200_MACOP_NOP
`define OR1200_MACOP_NOP 2'b00
`endif
`ifndef OR1200_MACOP_MAC
`define OR1200_MACOP_MAC 2'b01
`endif
`ifndef OR1200_MACOP_MSB
`define OR1200_MACOP_MSB 2'b10
`endif

module or1200_mult_mac(
    input         clk,
    input         rst,
    input         ex_freeze,
    input         id_macrc_op,
    input         macrc_op,
    input  [31:0] a,
    input  [31:0] b,
    input  [1:0]  mac_op,
    input  [3:0]  alu_op,
    output [31:0] result,
    output        mac_stall_r,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

wire alu_op_mul;
wire alu_op_div;
wire alu_op_divu;
wire alu_op_div_divu;
wire [31:0] x;
wire [31:0] y;
wire spr_maclo_we;
wire spr_machi_we;
reg  [31:0] result_r;

assign alu_op_mul      = (alu_op == `OR1200_ALUOP_MUL);
assign alu_op_div      = (alu_op == `OR1200_ALUOP_DIV);
assign alu_op_divu     = (alu_op == `OR1200_ALUOP_DIVU);
assign alu_op_div_divu = alu_op_div | alu_op_divu;

`ifdef OR1200_LOWPWR_MULT
wire mult_active;
assign mult_active = alu_op_div_divu | alu_op_mul | (|mac_op);
assign x = mult_active ? ((alu_op_div && a[31]) ? (~a + 32'd1) : a) : 32'b0;
assign y = mult_active ? ((alu_op_div && b[31]) ? (~b + 32'd1) : b) : 32'b0;
`else
assign x = (alu_op_div && a[31]) ? (~a + 32'd1) : a;
assign y = (alu_op_div && b[31]) ? (~b + 32'd1) : b;
`endif

assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];
assign result       = result_r;

`ifdef OR1200_MULT_IMPLEMENTED
wire [63:0] mul_prod;
reg  [63:0] mul_prod_r;
assign mul_prod = {32'b0, x} * {32'b0, y};
`ifdef OR1200_IMPL_DIV
reg        div_free;
reg  [5:0] div_cntr;
wire [31:0] div_tmp;
assign div_tmp = mul_prod_r[63:32] - y;
wire div_busy;
assign div_busy = |div_cntr;
`else
wire div_busy;
assign div_busy = 1'b0;
`endif
`else
wire [63:0] mul_prod;
wire [63:0] mul_prod_r;
wire        div_busy;
assign mul_prod  = 64'b0;
assign mul_prod_r = 64'b0;
assign div_busy  = 1'b0;
`endif

`ifdef OR1200_MAC_IMPLEMENTED
reg  [1:0] mac_op_r1;
reg  [1:0] mac_op_r2;
reg  [1:0] mac_op_r3;
reg        mac_stall_r_r;
reg  [63:0] mac_r;
assign mac_stall_r = mac_stall_r_r;
assign spr_dat_o   = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
`else
wire [1:0] mac_op_r1;
wire [1:0] mac_op_r2;
wire [1:0] mac_op_r3;
wire [63:0] mac_r;
assign mac_op_r1   = 2'b00;
assign mac_op_r2   = 2'b00;
assign mac_op_r3   = 2'b00;
assign mac_r       = 64'b0;
assign mac_stall_r = 1'b0;
assign spr_dat_o   = 32'b0;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
`ifdef OR1200_IMPL_DIV
        div_free   <= 1'b1;
        div_cntr   <= 6'b0;
`endif
    end
    else begin
`ifdef OR1200_IMPL_DIV
        if (div_cntr != 6'b0) begin
            if (div_tmp[31])
                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
            else
                mul_prod_r <= {div_tmp[30:0], mul_prod_r[31:0], 1'b1};
            div_cntr <= div_cntr - 6'd1;
        end
        else if (alu_op_div_divu && div_free) begin
            mul_prod_r <= {31'b0, x, 1'b0};
            div_cntr   <= 6'd32;
            div_free   <= 1'b0;
        end
        else if (div_free || !ex_freeze) begin
            mul_prod_r <= mul_prod;
            div_free   <= 1'b1;
        end
`else
        mul_prod_r <= mul_prod;
`endif
    end
end
`endif

`ifdef OR1200_MAC_IMPLEMENTED
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_op_r1 <= 2'b00;
        mac_op_r2 <= 2'b00;
        mac_op_r3 <= 2'b00;
    end
    else begin
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        mac_r <= 64'b0;
    else begin
`ifdef OR1200_MAC_SPR_WE
        if (spr_maclo_we)
            mac_r[31:0] <= spr_dat_i;
        else if (spr_machi_we)
            mac_r[63:32] <= spr_dat_i;
        else
`endif
        if (mac_op_r3 == `OR1200_MACOP_MAC)
            mac_r <= mac_r + mul_prod_r;
        else if (mac_op_r3 == `OR1200_MACOP_MSB)
            mac_r <= mac_r - mul_prod_r;
        else if (macrc_op && !ex_freeze)
            mac_r <= 64'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        mac_stall_r_r <= 1'b0;
    else
        mac_stall_r_r <= (|mac_op) |
                         (((|mac_op_r1) | (|mac_op_r2)) & id_macrc_op) |
                         div_busy;
end
`endif

always @* begin
`ifdef OR1200_MULT_IMPLEMENTED
    if (alu_op_div)
        result_r = (a[31] ^ b[31]) ? (~mul_prod_r[31:0] + 32'd1) : mul_prod_r[31:0];
    else if (alu_op_divu)
        result_r = mul_prod_r[31:0];
    else if (alu_op_mul)
        result_r = mul_prod_r[31:0];
    else
        result_r = mac_r[31:0];
`else
    result_r = 32'b0;
`endif
end

endmodule
