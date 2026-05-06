`ifndef OR1200_ALUOP_DIV
`define OR1200_ALUOP_DIV 4'd10
`endif
`ifndef OR1200_ALUOP_DIVU
`define OR1200_ALUOP_DIVU 4'd11
`endif
`ifndef OR1200_ALUOP_MUL
`define OR1200_ALUOP_MUL 4'd12
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

reg [31:0] result;
reg        mac_stall_r;
reg [31:0] spr_dat_o;
reg [63:0] mul_prod_r;
reg [1:0]  mac_op_r1;
reg [1:0]  mac_op_r2;
reg [1:0]  mac_op_r3;
reg [63:0] mac_r;
reg        div_free;
reg [5:0]  div_cntr;

wire       alu_op_div;
wire       alu_op_div_divu;
wire       alu_op_mul;
wire       datapath_active;
wire [31:0] x;
wire [31:0] y;
wire [63:0] mul_prod;
wire       spr_maclo_we;
wire       spr_machi_we;
wire [31:0] div_tmp;

assign alu_op_div      = (alu_op == `OR1200_ALUOP_DIV);
assign alu_op_div_divu = (alu_op == `OR1200_ALUOP_DIV) || (alu_op == `OR1200_ALUOP_DIVU);
assign alu_op_mul      = (alu_op == `OR1200_ALUOP_MUL);
assign datapath_active = alu_op_div_divu || alu_op_mul || (|mac_op);

`ifdef OR1200_LOWPWR_MULT
assign x = datapath_active ? ((alu_op_div && a[31]) ? (~a + 32'd1) : a) : 32'b0;
assign y = datapath_active ? ((alu_op_div && b[31]) ? (~b + 32'd1) : b) : 32'b0;
`else
assign x = (alu_op_div && a[31]) ? (~a + 32'd1) : a;
assign y = (alu_op_div && b[31]) ? (~b + 32'd1) : b;
`endif

`ifdef OR1200_MULT_IMPLEMENTED
assign mul_prod = x * y;
`else
assign mul_prod = 64'b0;
`endif

assign spr_maclo_we = spr_cs & spr_write &  spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & ~spr_addr[0];
assign div_tmp      = mul_prod_r[63:32] - y;

always @* begin
`ifdef OR1200_MULT_IMPLEMENTED
    if (alu_op_div) begin
        if (a[31] ^ b[31])
            result = ~mul_prod_r[31:0] + 32'd1;
        else
            result = mul_prod_r[31:0];
    end
    else if (alu_op == `OR1200_ALUOP_DIVU)
        result = mul_prod_r[31:0];
    else if (alu_op_mul)
        result = mul_prod_r[31:0];
`ifdef OR1200_MAC_IMPLEMENTED
    else
        result = mac_r[31:0];
`else
    else
        result = 32'b0;
`endif
`else
    result = 32'b0;
`endif
end

always @* begin
`ifdef OR1200_MAC_IMPLEMENTED
    spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
`else
    spr_dat_o = 32'b0;
`endif
end

always @(posedge clk or posedge rst) begin
`ifdef OR1200_MULT_IMPLEMENTED
    if (rst) begin
        mul_prod_r <= 64'b0;
        div_free   <= 1'b1;
        div_cntr   <= 6'd0;
    end
    else begin
`ifdef OR1200_IMPL_DIV
        if (div_cntr != 6'd0) begin
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
        div_free   <= 1'b1;
        div_cntr   <= 6'd0;
`endif
    end
`else
    if (rst) begin
        mul_prod_r <= 64'b0;
        div_free   <= 1'b1;
        div_cntr   <= 6'd0;
    end
    else begin
        mul_prod_r <= 64'b0;
        div_free   <= 1'b1;
        div_cntr   <= 6'd0;
    end
`endif
end

always @(posedge clk or posedge rst) begin
`ifdef OR1200_MAC_IMPLEMENTED
    if (rst) begin
        mac_op_r1 <= `OR1200_MACOP_NOP;
        mac_op_r2 <= `OR1200_MACOP_NOP;
        mac_op_r3 <= `OR1200_MACOP_NOP;
    end
    else begin
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;
    end
`else
    if (rst) begin
        mac_op_r1 <= `OR1200_MACOP_NOP;
        mac_op_r2 <= `OR1200_MACOP_NOP;
        mac_op_r3 <= `OR1200_MACOP_NOP;
    end
    else begin
        mac_op_r1 <= `OR1200_MACOP_NOP;
        mac_op_r2 <= `OR1200_MACOP_NOP;
        mac_op_r3 <= `OR1200_MACOP_NOP;
    end
`endif
end

always @(posedge clk or posedge rst) begin
`ifdef OR1200_MAC_IMPLEMENTED
    if (rst) begin
        mac_r <= 64'b0;
    end
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
`else
    if (rst)
        mac_r <= 64'b0;
    else
        mac_r <= 64'b0;
`endif
end

always @(posedge clk or posedge rst) begin
`ifdef OR1200_MAC_IMPLEMENTED
    if (rst)
        mac_stall_r <= 1'b0;
    else
        mac_stall_r <= (|mac_op) || (((|mac_op_r1) || (|mac_op_r2)) && id_macrc_op)
`ifdef OR1200_IMPL_DIV
                        || (div_cntr != 6'd0)
`endif
                        ;
`else
    if (rst)
        mac_stall_r <= 1'b0;
    else
        mac_stall_r <= 1'b0;
`endif
end

endmodule
