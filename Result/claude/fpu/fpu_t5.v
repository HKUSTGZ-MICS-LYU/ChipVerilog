module fpu(
    input clk,
    input rst,
    input enable,
    input [1:0] rmode,
    input [2:0] fpu_op,
    input [63:0] opa,
    input [63:0] opb,
    output reg [63:0] out,
    output reg ready,
    output reg underflow,
    output reg overflow,
    output reg inexact,
    output reg exception,
    output reg invalid
);

    reg [63:0] opa_reg, opb_reg;
    reg [2:0] fpu_op_reg;
    reg [1:0] rmode_reg;
    reg enable_reg, enable_reg_1, enable_reg_2, enable_reg_3;
    reg [6:0] count_cycles, count_ready;
    reg ready_0, ready_1;
    
    wire [55:0] add_out, sub_out, mul_out, div_out;
    wire [10:0] exp_add_out, exp_sub_out;
    wire [11:0] exp_mul_out, exp_div_out;
    wire add_sign, sub_sign, mul_sign, div_sign;
    
    wire [55:0] addsub_out = (fpu_op_reg[0] ? sub_out : add_out);
    wire [11:0] exponent_round = (fpu_op_reg[0] ? {1'b0, exp_sub_out} : {1'b0, exp_add_out});
    wire addsub_sign = (fpu_op_reg[0] ? sub_sign : add_sign);
    
    wire [63:0] out_round;
    wire [63:0] out_except;
    wire [11:0] exponent_post_round;
    wire except_enable;
    wire underflow_0;
    wire overflow_0;
    wire inexact_0;
    wire exception_0;
    wire invalid_0;
    
    wire count_busy = (count_ready <= count_cycles);
    wire add_enable_0 = (fpu_op_reg == 3'b000) & !(opa_reg[63] ^ opb_reg[63]);
    wire sub_enable_0 = (fpu_op_reg == 3'b001) & !(opa_reg[63] ^ opb_reg[63]);
    wire mul_enable = (fpu_op_reg == 3'b010);
    wire div_enable = (fpu_op_reg == 3'b011);

    fpu_add add_inst (
        .clk(clk), .rst(rst), .enable(add_enable_0 | enable_reg_1),
        .opa(opa_reg), .opb(opb_reg),
        .sign(add_sign), .sum_2(add_out), .exponent_2(exp_add_out)
    );

    fpu_sub sub_inst (
        .clk(clk), .rst(rst), .enable(sub_enable_0 | enable_reg_1),
        .opa(opa_reg), .opb(opb_reg), .fpu_op(fpu_op_reg),
        .sign(sub_sign), .diff_2(sub_out), .exponent_2(exp_sub_out)
    );

    fpu_mul mul_inst (
        .clk(clk), .rst(rst), .enable(mul_enable),
        .opa(opa_reg), .opb(opb_reg),
        .sign(mul_sign), .product_7(mul_out), .exponent_5(exp_mul_out)
    );

    fpu_div div_inst (
        .clk(clk), .rst(rst), .enable(div_enable),
        .opa(opa_reg), .opb(opb_reg),
        .sign(div_sign), .mantissa_7(div_out), .exponent_out(exp_div_out)
    );

    fpu_round round_inst (
        .clk(clk), .rst(rst), .enable(1'b1),
        .round_mode(rmode_reg), .sign_term(addsub_sign),
        .mantissa_term(addsub_out), .exponent_term(exponent_round),
        .round_out(out_round), .exponent_final(exponent_post_round)
    );

    fpu_exceptions exc_inst (
        .clk(clk), .rst(rst), .enable(1'b1),
        .rmode(rmode_reg), .opa(opa_reg), .opb(opb_reg),
        .in_except(out_round),
        .exponent_in(exponent_post_round), .mantissa_in(addsub_out[1:0]),
        .fpu_op(fpu_op_reg),
        .out(out_except), .ex_enable(except_enable),
        .underflow(underflow_0), .overflow(overflow_0),
        .inexact(inexact_0), .exception(exception_0), .invalid(invalid_0)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            opa_reg <= 64'b0;
            opb_reg <= 64'b0;
            fpu_op_reg <= 3'b0;
            rmode_reg <= 2'b0;
            enable_reg <= 1'b0;
            enable_reg_1 <= 1'b0;
            enable_reg_2 <= 1'b0;
            enable_reg_3 <= 1'b0;
            count_cycles <= 7'b0;
            count_ready <= 7'd20;
            ready <= 1'b0;
            ready_0 <= 1'b0;
            ready_1 <= 1'b0;
            out <= 64'b0;
            underflow <= 1'b0;
            overflow <= 1'b0;
            inexact <= 1'b0;
            exception <= 1'b0;
            invalid <= 1'b0;
        end else begin
            enable_reg <= enable;
            enable_reg_1 <= enable_reg;
            enable_reg_2 <= enable_reg_1;
            enable_reg_3 <= enable_reg_2;
            
            if (enable_reg & !enable_reg_1) begin
                opa_reg <= opa;
                opb_reg <= opb;
                fpu_op_reg <= fpu_op;
                rmode_reg <= rmode;
                count_cycles <= 7'b0;
                
                case (fpu_op)
                    3'b000, 3'b001: count_ready <= 7'd20;
                    3'b010: count_ready <= 7'd24;
                    3'b011: count_ready <= 7'd71;
                    default: count_ready <= 7'd20;
                endcase
            end else if (!count_busy) begin
                count_cycles <= count_cycles + 1;
            end
            
            ready <= !count_busy;
            ready_0 <= ready;
            ready_1 <= ready_0;
            
            if (ready_1) begin
                out <= except_enable ? out_except : out_round;
                underflow <= underflow_0;
                overflow <= overflow_0;
                inexact <= inexact_0;
                exception <= exception_0;
                invalid <= invalid_0;
            end
        end
    end

endmodule
