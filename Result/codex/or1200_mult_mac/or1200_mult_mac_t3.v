// Generated from or1200_mult_mac/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_mult_mac(
    // Clock and reset
    input clk,
    input rst,

    // Multiplier/MAC interface
    input ex_freeze,
    input id_macrc_op,
    input macrc_op,
    input [31:0] a,
    input [31:0] b,
    input [1:0] mac_op,
    input [3:0] alu_op,
    output [31:0] result,
    output mac_stall_r,

    // SPR interface
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);

reg [31:0] result_r;
reg mac_stall_r_r;
reg [31:0] spr_dat_o_r;
assign result = result_r;
assign mac_stall_r = mac_stall_r_r;
assign spr_dat_o = spr_dat_o_r;

reg [63:0] mul_prod_r_reg;
reg [63:0] mac_r_reg;
reg [1:0] mac_op_r1;
reg [1:0] mac_op_r2;
reg [1:0] mac_op_r3;
reg [5:0] div_cntr;
reg div_free;
wire [63:0] mul_prod = a * b;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        mul_prod_r_reg <= 64'd0;
        mac_r_reg <= 64'd0;
        mac_op_r1 <= 2'd0;
        mac_op_r2 <= 2'd0;
        mac_op_r3 <= 2'd0;
        div_cntr <= 6'd0;
        div_free <= 1'b1;
        mac_stall_r_r <= 1'b0;
    end else begin
        mul_prod_r_reg <= mul_prod;
        mac_op_r1 <= mac_op;
        mac_op_r2 <= mac_op_r1;
        mac_op_r3 <= mac_op_r2;
        if (spr_cs && spr_write) begin
            if (spr_addr[0])
                mac_r_reg[31:0] <= spr_dat_i;
            else
                mac_r_reg[63:32] <= spr_dat_i;
        end else begin
            if (mac_op_r3 == 2'b01)
                mac_r_reg <= mac_r_reg + mul_prod_r_reg;
            else if (mac_op_r3 == 2'b10)
                mac_r_reg <= mac_r_reg - mul_prod_r_reg;
        end
        if ((alu_op == 4'hd) && div_free) begin
            div_free <= 1'b0;
            div_cntr <= 6'd32;
        end else if (div_cntr != 0) begin
            div_cntr <= div_cntr - 1'b1;
            if (div_cntr == 1)
                div_free <= 1'b1;
        end
        mac_stall_r_r <= id_macrc_op && !ex_freeze && (mac_op != 0);
    end
end

always @* begin
    case (alu_op)
        4'hd: result_r = (b != 0) ? (a / b) : 32'd0;
        4'hb: result_r = mul_prod_r_reg[31:0];
        default: result_r = macrc_op ? mac_r_reg[31:0] : mul_prod_r_reg[31:0];
    endcase
    spr_dat_o_r = spr_addr[0] ? mac_r_reg[31:0] : mac_r_reg[63:32];
end

endmodule
