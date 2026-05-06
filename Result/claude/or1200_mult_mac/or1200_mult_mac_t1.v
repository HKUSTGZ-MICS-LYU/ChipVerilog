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

`ifdef OR1200_ALUOP_DIV
localparam [3:0] ALUOP_DIV = `OR1200_ALUOP_DIV;
`else
localparam [3:0] ALUOP_DIV = 4'h9;
`endif

`ifdef OR1200_ALUOP_DIVU
localparam [3:0] ALUOP_DIVU = `OR1200_ALUOP_DIVU;
`else
localparam [3:0] ALUOP_DIVU = 4'ha;
`endif

`ifdef OR1200_ALUOP_MUL
localparam [3:0] ALUOP_MUL = `OR1200_ALUOP_MUL;
`else
localparam [3:0] ALUOP_MUL = 4'hb;
`endif

`ifdef OR1200_MACOP_MAC
localparam [1:0] MACOP_MAC = `OR1200_MACOP_MAC;
`else
localparam [1:0] MACOP_MAC = 2'b01;
`endif

`ifdef OR1200_MACOP_MSB
localparam [1:0] MACOP_MSB = `OR1200_MACOP_MSB;
`else
localparam [1:0] MACOP_MSB = 2'b10;
`endif

wire alu_op_div;
wire alu_op_div_divu;
wire [31:0] x;
wire [31:0] y;
wire [31:0] a_div;
wire [31:0] b_div;

assign alu_op_div = (alu_op == ALUOP_DIV);
assign alu_op_div_divu = (alu_op == ALUOP_DIV) | (alu_op == ALUOP_DIVU);
assign a_div = (alu_op_div & a[31]) ? (~a + 32'd1) : a;
assign b_div = (alu_op_div & b[31]) ? (~b + 32'd1) : b;

`ifdef OR1200_LOWPWR_MULT
assign x = (alu_op_div_divu | (alu_op == ALUOP_MUL) | (|mac_op)) ? a_div : 32'b0;
assign y = (alu_op_div_divu | (alu_op == ALUOP_MUL) | (|mac_op)) ? b_div : 32'b0;
`else
assign x = a_div;
assign y = b_div;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
reg [63:0] mul_prod_r;
wire [63:0] mul_prod;
`ifdef OR1200_IMPL_DIV
reg div_free;
reg [5:0] div_cntr;
wire [31:0] div_tmp;
assign div_tmp = mul_prod_r[63:32] - y;
`endif
`else
wire [63:0] mul_prod_r;
wire [63:0] mul_prod;
assign mul_prod_r = 64'b0;
assign mul_prod = 64'b0;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
`ifdef OR1200_ASIC_MULTP2_32X32
or1200_amultp2_32x32 mul_i(x, y, mul_prod);
`else
or1200_gmultp2_32x32 mul_i(x, y, mul_prod);
`endif
`endif

`ifdef OR1200_MULT_IMPLEMENTED
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
`ifdef OR1200_IMPL_DIV
        div_free <= 1'b1;
        div_cntr <= 6'b0;
`endif
    end
    else begin
`ifdef OR1200_IMPL_DIV
        if (div_cntr != 6'b0) begin
            if (div_tmp[31])
                mul_prod_r <= {mul_prod_r[62:0], 1'b0};
            else
                mul_prod_r <= {div_tmp[30:0], mul_prod_r[30:0], 1'b1};
            div_cntr <= div_cntr - 6'd1;
        end
        else if (alu_op_div_divu & div_free) begin
            mul_prod_r <= {31'b0, x, 1'b0};
            div_cntr <= 6'd32;
            div_free <= 1'b0;
        end
        else if (div_free | !ex_freeze) begin
            mul_prod_r <= mul_prod;
            div_free <= 1'b1;
        end
`else
        mul_prod_r <= mul_prod;
`endif
    end
end
`endif

`ifdef OR1200_MAC_IMPLEMENTED
reg [1:0] mac_op_r1;
reg [1:0] mac_op_r2;
reg [1:0] mac_op_r3;
reg [63:0] mac_r;
reg mac_stall_r_reg;
wire spr_maclo_we;
wire spr_machi_we;
assign spr_maclo_we = spr_cs & spr_write & spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & !spr_addr[0];
assign spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
assign mac_stall_r = mac_stall_r_reg;
`else
wire [63:0] mac_r;
assign mac_r = 64'b0;
assign spr_dat_o = 32'b0;
assign mac_stall_r = 1'b0;
`endif

`ifdef OR1200_MAC_IMPLEMENTED
always @(posedge clk or posedge rst) begin
    if (rst) begin
        mac_op_r1 <= 2'b0;
        mac_op_r2 <= 2'b0;
        mac_op_r3 <= 2'b0;
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
        if (mac_op_r3 == MACOP_MAC)
            mac_r <= mac_r + mul_prod_r;
        else if (mac_op_r3 == MACOP_MSB)
            mac_r <= mac_r - mul_prod_r;
        else if (macrc_op & !ex_freeze)
            mac_r <= 64'b0;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        mac_stall_r_reg <= 1'b0;
    else begin
        mac_stall_r_reg <= (|mac_op) | (((|mac_op_r1) | (|mac_op_r2)) & id_macrc_op)
`ifdef OR1200_IMPL_DIV
                           | (div_cntr != 6'b0)
`endif
                           ;
    end
end
`endif

`ifdef OR1200_MULT_IMPLEMENTED
reg [31:0] result_r;
assign result = result_r;
always @* begin
    case (alu_op)
        ALUOP_DIV: begin
            if (a[31] ^ b[31])
                result_r = ~mul_prod_r[31:0] + 32'd1;
            else
                result_r = mul_prod_r[31:0];
        end
        ALUOP_DIVU: result_r = mul_prod_r[31:0];
        ALUOP_MUL: result_r = mul_prod_r[31:0];
        default: result_r = mac_r[31:0];
    endcase
end
`else
assign result = 32'b0;
`endif

endmodule
