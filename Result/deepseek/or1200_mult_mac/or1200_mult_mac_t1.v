module or1200_mult_mac (
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
    localparam OR1200_MULT_IMPLEMENTED = 1;
    localparam OR1200_IMPL_DIV = 1;
    localparam OR1200_MAC_IMPLEMENTED = 1;
    localparam OR1200_MAC_SPR_WE = 1;
    localparam OR1200_LOWPWR_MULT = 0;
    localparam OR1200_ASIC_MULTP2_32X32 = 0;

    wire [31:0] x;
    wire [31:0] y;
    wire [63:0] mul_prod;
    reg [63:0] mul_prod_r;
    reg [31:0] result;
    reg [1:0] mac_op_r1;
    reg [1:0] mac_op_r2;
    reg [1:0] mac_op_r3;
    reg [63:0] mac_r;
    reg mac_stall_r;
    wire spr_maclo_we;
    wire spr_machi_we;
    wire alu_op_div;
    wire alu_op_div_divu;
    reg div_free;
    wire [31:0] div_tmp;
    reg [5:0] div_cntr;
    reg [31:0] spr_dat_o;

    assign alu_op_div = (alu_op == 4'b1000);
    assign alu_op_div_divu = (alu_op == 4'b1000) || (alu_op == 4'b1001);

    assign x = (OR1200_IMPL_DIV && alu_op_div && a[31]) ? (~a + 1) :
               (OR1200_LOWPWR_MULT && !alu_op_div_divu && (mac_op == 2'b00) && (alu_op != 4'b0110)) ? 32'b0 : a;
    assign y = (OR1200_IMPL_DIV && alu_op_div && b[31]) ? (~b + 1) :
               (OR1200_LOWPWR_MULT && !alu_op_div_divu && (mac_op == 2'b00) && (alu_op != 4'b0110)) ? 32'b0 : b;

    generate
        if (OR1200_MULT_IMPLEMENTED) begin
            if (OR1200_ASIC_MULTP2_32X32) begin
                or1200_amultp2_32x32 u_mult (.x(x), .y(y), .product(mul_prod));
            end else begin
                or1200_gmultp2_32x32 u_mult (.x(x), .y(y), .product(mul_prod));
            end
        end else begin
            assign mul_prod = 64'b0;
        end
    endgenerate

    assign div_tmp = mul_prod_r[63:32] - y;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mul_prod_r <= 64'b0;
            div_free <= 1'b1;
            if (OR1200_IMPL_DIV) div_cntr <= 6'b0;
        end else begin
            if (OR1200_IMPL_DIV && div_cntr != 0) begin
                mul_prod_r <= div_tmp[31] ? {mul_prod_r[62:0], 1'b0} : {div_tmp[31:0], mul_prod_r[31:0], 1'b1};
                div_cntr <= div_cntr - 1;
            end else if (OR1200_IMPL_DIV && alu_op_div_divu && div_free) begin
                mul_prod_r <= {31'b0, x[31:0], 1'b0};
                div_cntr <= 6'd32;
                div_free <= 1'b0;
            end else if (OR1200_MULT_IMPLEMENTED && (div_free || !ex_freeze)) begin
                mul_prod_r <= mul_prod;
                div_free <= 1'b1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_op_r1 <= 2'b0;
            mac_op_r2 <= 2'b0;
            mac_op_r3 <= 2'b0;
        end else if (!ex_freeze) begin
            mac_op_r1 <= mac_op;
            mac_op_r2 <= mac_op_r1;
            mac_op_r3 <= mac_op_r2;
        end
    end

    assign spr_maclo_we = spr_cs && spr_write && spr_addr[0];
    assign spr_machi_we = spr_cs && spr_write && !spr_addr[0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_r <= 64'b0;
        end else if (OR1200_MAC_SPR_WE && spr_maclo_we) begin
            mac_r[31:0] <= spr_dat_i;
        end else if (OR1200_MAC_SPR_WE && spr_machi_we) begin
            mac_r[63:32] <= spr_dat_i;
        end else if (mac_op_r3 == 2'b01) begin
            mac_r <= mac_r + mul_prod_r;
        end else if (mac_op_r3 == 2'b10) begin
            mac_r <= mac_r - mul_prod_r;
        end else if (macrc_op && !ex_freeze) begin
            mac_r <= 64'b0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_stall_r <= 1'b0;
        end else begin
            if (OR1200_MAC_IMPLEMENTED) begin
                mac_stall_r <= (|mac_op) || ((|mac_op_r1) && id_macrc_op) || ((|mac_op_r2) && id_macrc_op) || (OR1200_IMPL_DIV && div_cntr != 0);
            end else begin
                mac_stall_r <= 1'b0;
            end
        end
    end

    always @(*) begin
        if (alu_op_div) begin
            if (OR1200_IMPL_DIV && (a[31] ^ b[31]))
                result = ~mul_prod_r[31:0] + 1;
            else
                result = mul_prod_r[31:0];
        end else if (alu_op_div_divu) begin
            result = mul_prod_r[31:0];
        end else if (alu_op == 4'b0110) begin
            result = mul_prod_r[31:0];
        end else begin
            result = mac_r[31:0];
        end
    end

    always @(*) begin
        if (OR1200_MAC_IMPLEMENTED) begin
            if (spr_cs && !spr_write) begin
                spr_dat_o = spr_addr[0] ? mac_r[31:0] : mac_r[63:32];
            end else begin
                spr_dat_o = 32'b0;
            end
        end else begin
            spr_dat_o = 32'b0;
        end
    end
endmodule
