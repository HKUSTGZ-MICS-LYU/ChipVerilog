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

reg [63:0] mul_prod_r;
wire [63:0] mul_prod;
wire [31:0] x;
wire [31:0] y;

reg div_free;
reg [5:0] div_cntr;
wire [31:0] div_tmp;

wire alu_op_div_divu;
wire alu_op_div;

reg [1:0] mac_op_r1;
reg [1:0] mac_op_r2;
reg [1:0] mac_op_r3;
reg [63:0] mac_r;
reg mac_stall_r;

wire spr_maclo_we;
wire spr_machi_we;

reg [31:0] result;

assign alu_op_div_divu = (alu_op[3:0] == 4'h3) | (alu_op[3:0] == 4'h4);
assign alu_op_div = (alu_op[3:0] == 4'h3);

assign x = a;
assign y = b;

assign mul_prod = x * y;

assign div_tmp = mul_prod_r[63:32] - (y[31] ? ~y + 1 : y);

assign spr_maclo_we = spr_cs & spr_write & ~spr_addr[0];
assign spr_machi_we = spr_cs & spr_write & spr_addr[0];

assign spr_dat_o = spr_addr[0] ? mac_r[63:32] : mac_r[31:0];

always @(posedge clk) begin
    if (rst) begin
        mul_prod_r <= 64'b0;
        div_free <= 1'b1;
        div_cntr <= 6'b0;
        mac_op_r1 <= 2'b0;
        mac_op_r2 <= 2'b0;
        mac_op_r3 <= 2'b0;
        mac_r <= 64'b0;
        mac_stall_r <= 1'b0;
    end else begin
        if (div_cntr != 6'b0) begin
            div_cntr <= div_cntr - 1;
            if (div_tmp[63] == 0) begin
                mul_prod_r <= {div_tmp[62:0], mul_prod_r[30:0], 1'b1};
            end else begin
                mul_prod_r <= {mul_prod_r[62:0], mul_prod_r[30:0], 1'b0};
            end
        end else if (alu_op_div_divu & div_free) begin
            div_cntr <= 6'd32;
            mul_prod_r <= {31'b0, x, 1'b0};
            div_free <= 1'b0;
        end else if (div_free | ~ex_freeze) begin
            mul_prod_r <= mul_prod;
            div_free <= 1'b1;
        end
        
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;
        
        if (spr_maclo_we) begin
            mac_r[31:0] <= spr_dat_i;
        end else if (spr_machi_we) begin
            mac_r[63:32] <= spr_dat_i;
        end else if (mac_op_r3 == 2'b01) begin
            mac_r <= mac_r + mul_prod_r;
        end else if (mac_op_r3 == 2'b10) begin
            mac_r <= mac_r - mul_prod_r;
        end
        
        if (id_macrc_op | (mac_op_r3 != 2'b0)) begin
            mac_stall_r <= 1'b1;
        end else begin
            mac_stall_r <= 1'b0;
        end
    end
end

always @(*) begin
    if (alu_op_div_divu) begin
        if (alu_op_div & a[31] ^ b[31]) begin
            result = ~mul_prod_r[31:0] + 1;
        end else begin
            result = mul_prod_r[31:0];
        end
    end else if (alu_op[3:0] == 4'h2) begin
        result = mul_prod_r[31:0];
    end else begin
        result = mac_r[31:0];
    end
end

endmodule
