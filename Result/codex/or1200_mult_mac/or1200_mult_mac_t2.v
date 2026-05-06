module or1200_mult_mac(
    input clk,
    input rst,
    input ex_freeze,
    input id_macrc_op,
    input macrc_op,
    input [31:0] a,
    input [31:0] b,
    input [1:0] mac_op,
    input [3:0] alu_op,
    output [31:0] result,
    output mac_stall_r,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

`ifdef OR1200_MULT_IMPLEMENTED
reg [31:0] result;
reg [63:0] mul_prod_r;
wire [63:0] mul_prod;
wire [31:0] x;
wire [31:0] y;
wire [31:0] x_pre;
wire [31:0] y_pre;
wire op_active;
`ifdef OR1200_IMPL_DIV
wire alu_op_div_divu;
wire alu_op_div;
wire [31:0] div_tmp;
reg div_free;
reg [5:0] div_cntr;
`endif
`else
wire [31:0] result;
wire [63:0] mul_prod_r;
wire [63:0] mul_prod;
`ifdef OR1200_IMPL_DIV
wire [5:0] div_cntr;
`endif
`endif

`ifdef OR1200_MAC_IMPLEMENTED
reg [1:0] mac_op_r1;
reg [1:0] mac_op_r2;
reg [1:0] mac_op_r3;
reg mac_stall_r;
reg [63:0] mac_r;
wire spr_maclo_we;
wire spr_machi_we;
`else
wire [1:0] mac_op_r1;
wire [1:0] mac_op_r2;
wire [1:0] mac_op_r3;
wire mac_stall_r;
wire [63:0] mac_r;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
`ifdef OR1200_IMPL_DIV
assign alu_op_div = (alu_op == `OR1200_ALUOP_DIV);
assign alu_op_div_divu = (alu_op == `OR1200_ALUOP_DIV) | (alu_op == `OR1200_ALUOP_DIVU);
assign x_pre = (alu_op_div & a[31]) ? (~a + 32'd1) : a;
assign y_pre = (alu_op_div & b[31]) ? (~b + 32'd1) : b;
assign div_tmp = mul_prod_r[63:32] - y;
assign op_active = alu_op_div_divu | (alu_op == `OR1200_ALUOP_MUL) | (|mac_op);
`else
assign x_pre = a;
assign y_pre = b;
assign op_active = (alu_op == `OR1200_ALUOP_MUL) | (|mac_op);
`endif

`ifdef OR1200_LOWPWR_MULT
assign x = op_active ? x_pre : 32'b0;
assign y = op_active ? y_pre : 32'b0;
`else
assign x = x_pre;
assign y = y_pre;
`endif

`ifdef OR1200_ASIC_MULTP2_32X32
or1200_amultp2_32x32 mult_mac_mul (x, y, mul_prod);
`else
or1200_gmultp2_32x32 mult_mac_mul (x, y, mul_prod);
`endif

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
`ifdef OR1200_IMPL_DIV
        div_free <= 1'b1;
        div_cntr <= 6'd0;
`endif
    end else begin
`ifdef OR1200_IMPL_DIV
        if (div_cntr != 6'd0) begin
            if (div_tmp[31]) begin
                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
            end else begin
                mul_prod_r <= {div_tmp[30:0], mul_prod_r[31:0], 1'b1};
            end
            div_cntr <= div_cntr - 6'd1;
        end else if (alu_op_div_divu & div_free) begin
            mul_prod_r <= {31'b0, x[31:0], 1'b0};
            div_cntr <= 6'd32;
            div_free <= 1'b0;
        end else if (div_free | !ex_freeze) begin
            mul_prod_r <= mul_prod;
            div_free <= 1'b1;
        end
`else
        mul_prod_r <= mul_prod;
`endif
    end
end

always @* begin
`ifdef OR1200_IMPL_DIV
    if (alu_op == `OR1200_ALUOP_DIV) begin
        result = (a[31] ^ b[31]) ? (~mul_prod_r[31:0] + 32'd1) : mul_prod_r[31:0];
    end else if (alu_op == `OR1200_ALUOP_DIVU) begin
        result = mul_prod_r[31:0];
    end else
`endif
    if (alu_op == `OR1200_ALUOP_MUL) begin
        result = mul_prod_r[31:0];
    end else begin
        result = mac_r[31:0];
    end
end
`else
assign result = 32'b0;
assign mul_prod_r = 64'b0;
assign mul_prod = 64'b0;
`ifdef OR1200_IMPL_DIV
assign div_cntr = 6'd0;
`endif
`endif

`ifdef OR1200_MAC_IMPLEMENTED
assign spr_maclo_we = spr_cs & spr_write & spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & !spr_addr[0];
assign spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_op_r1 <= 2'b00;
        mac_op_r2 <= 2'b00;
        mac_op_r3 <= 2'b00;
    end else begin
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_r <= 64'b0;
    end else begin
`ifdef OR1200_MAC_SPR_WE
        if (spr_maclo_we) begin
            mac_r[31:0] <= spr_dat_i;
        end else if (spr_machi_we) begin
            mac_r[63:32] <= spr_dat_i;
        end else begin
`endif
            if (mac_op_r3 == `OR1200_MACOP_MAC) begin
                mac_r <= mac_r + mul_prod_r;
            end else if (mac_op_r3 == `OR1200_MACOP_MSB) begin
                mac_r <= mac_r - mul_prod_r;
            end else if (macrc_op & !ex_freeze) begin
                mac_r <= 64'b0;
            end
`ifdef OR1200_MAC_SPR_WE
        end
`endif
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_stall_r <= 1'b0;
    end else begin
        mac_stall_r <= (|mac_op) |
                       (id_macrc_op & ((|mac_op_r1) | (|mac_op_r2)))
`ifdef OR1200_IMPL_DIV
                       | (div_cntr != 6'd0)
`endif
                       ;
    end
end
`else
assign mac_op_r1 = 2'b00;
assign mac_op_r2 = 2'b00;
assign mac_op_r3 = 2'b00;
assign mac_stall_r = 1'b0;
assign mac_r = 64'b0;
assign spr_dat_o = 32'b0;
`endif

endmodule
