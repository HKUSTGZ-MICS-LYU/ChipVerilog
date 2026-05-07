module fpu_double (
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

reg [63:0] opa_reg;
reg [63:0] opb_reg;
reg [2:0] fpu_op_reg;
reg [1:0] rmode_reg;
reg enable_reg;
reg enable_reg_1;
reg enable_reg_2;
reg enable_reg_3;
reg op_enable;
reg [6:0] count_cycles;
reg [6:0] count_ready;
reg ready_0;
reg ready_1;
reg [55:0] mantissa_round;
reg [11:0] exponent_round;
reg sign_round;
reg add_enable;
reg sub_enable;
reg mul_enable;
reg div_enable;
reg [55:0] addsub_out;
reg addsub_sign;
reg [11:0] exp_addsub;
reg underflow_0;
reg overflow_0;
reg inexact_0;
reg exception_0;
reg invalid_0;

wire [11:0] exponent_post_round;
wire [63:0] out_round;
wire [63:0] out_except;
wire except_enable;
wire count_busy = (count_ready <= count_cycles);
wire add_enable_0 = (fpu_op_reg == 3'b000) & !(opa_reg[63] ^ opb_reg[63]);
wire add_enable_1 = (fpu_op_reg == 3'b001) & (opa_reg[63] ^ opb_reg[63]);
wire sub_enable_0 = (fpu_op_reg == 3'b000) & (opa_reg[63] ^ opb_reg[63]);
wire sub_enable_1 = (fpu_op_reg == 3'b001) & !(opa_reg[63] ^ opb_reg[63]);
wire [55:0] sum_out;
wire [55:0] diff_out;
wire [55:0] mul_out;
wire [55:0] div_out;
wire [10:0] exp_add_out;
wire [10:0] exp_sub_out;
wire [11:0] exp_mul_out;
wire [11:0] exp_div_out;
wire add_sign;
wire sub_sign;
wire mul_sign;
wire div_sign;

fpu_add fpu_add_inst(
    .clk(clk), .rst(rst), .enable(add_enable),
    .opa(opa_reg), .opb(opb_reg),
    .sign(add_sign), .sum_2(sum_out), .exponent_2(exp_add_out)
);

fpu_sub fpu_sub_inst(
    .clk(clk), .rst(rst), .enable(sub_enable),
    .opa(opa_reg), .opb(opb_reg), .fpu_op(fpu_op_reg),
    .sign(sub_sign), .diff_2(diff_out), .exponent_2(exp_sub_out)
);

fpu_mul fpu_mul_inst(
    .clk(clk), .rst(rst), .enable(mul_enable),
    .opa(opa_reg), .opb(opb_reg),
    .sign(mul_sign), .product_7(mul_out), .exponent_5(exp_mul_out)
);

fpu_div fpu_div_inst(
    .clk(clk), .rst(rst), .enable(div_enable),
    .opa(opa_reg), .opb(opb_reg),
    .sign(div_sign), .mantissa_7(div_out), .exponent_out(exp_div_out)
);

fpu_round fpu_round_inst(
    .clk(clk), .rst(rst), .enable(1),
    .round_mode(rmode_reg),
    .sign_term(sign_round), .mantissa_term(mantissa_round), .exponent_term(exponent_round),
    .round_out(out_round), .exponent_final(exponent_post_round)
);

fpu_exceptions fpu_exceptions_inst(
    .clk(clk), .rst(rst), .enable(1),
    .rmode(rmode_reg),
    .opa(opa_reg), .opb(opb_reg),
    .in_except(out_round), .exponent_in(exponent_post_round), .mantissa_in(mantissa_round[1:0]),
    .fpu_op(fpu_op_reg),
    .out(out_except), .ex_enable(except_enable),
    .underflow(underflow_0), .overflow(overflow_0), .inexact(inexact_0),
    .exception(exception_0), .invalid(invalid_0)
);

always @(posedge clk) begin
    if (rst) begin
        opa_reg <= 0;
        opb_reg <= 0;
        fpu_op_reg <= 0;
        rmode_reg <= 0;
        enable_reg <= 0;
        enable_reg_1 <= 0;
        enable_reg_2 <= 0;
        enable_reg_3 <= 0;
        op_enable <= 0;
        count_cycles <= 0;
        count_ready <= 0;
        ready_0 <= 0;
        ready_1 <= 0;
        ready <= 0;
        out <= 0;
        add_enable <= 0;
        sub_enable <= 0;
        mul_enable <= 0;
        div_enable <= 0;
        underflow <= 0;
        overflow <= 0;
        inexact <= 0;
        exception <= 0;
        invalid <= 0;
    end else begin
        enable_reg <= enable;
        enable_reg_1 <= enable_reg & !enable;
        enable_reg_2 <= enable_reg_1;
        enable_reg_3 <= enable_reg_2 | enable_reg_1;
        
        if (enable_reg_1) begin
            opa_reg <= opa;
            opb_reg <= opb;
            fpu_op_reg <= fpu_op;
            rmode_reg <= rmode;
            count_ready <= 0;
        end
        
        if (!count_busy)
            count_ready <= count_ready;
        else
            count_ready <= count_ready + 1;
        
        ready_0 <= !count_busy;
        ready_1 <= ready_0;
        ready <= ready_1;
        
        if (ready_1) begin
            out <= except_enable ? out_except : out_round;
            underflow <= underflow_0;
            overflow <= overflow_0;
            inexact <= inexact_0;
            exception <= exception_0;
            invalid <= invalid_0;
        end
        
        add_enable <= add_enable_0 | add_enable_1;
        sub_enable <= sub_enable_0 | sub_enable_1;
        mul_enable <= (fpu_op_reg == 3'b010);
        div_enable <= (fpu_op_reg == 3'b011) & enable_reg_3;
        
        case(fpu_op_reg)
            3'b000: begin
                addsub_out <= sum_out;
                exp_addsub <= {1'b0, exp_add_out};
                addsub_sign <= add_sign;
            end
            3'b001: begin
                addsub_out <= diff_out;
                exp_addsub <= {1'b0, exp_sub_out};
                addsub_sign <= sub_sign;
            end
            3'b010: begin
                addsub_out <= mul_out;
                exp_addsub <= exp_mul_out;
                addsub_sign <= mul_sign;
            end
            3'b011: begin
                addsub_out <= div_out;
                exp_addsub <= exp_div_out;
                addsub_sign <= div_sign;
            end
        endcase
        
        mantissa_round <= addsub_out;
        exponent_round <= exp_addsub;
        sign_round <= addsub_sign;
        
        case(fpu_op_reg)
            3'b000: count_cycles <= 7'd20;
            3'b001: count_cycles <= 7'd21;
            3'b010: count_cycles <= 7'd24;
            3'b011: count_cycles <= 7'd71;
            default: count_cycles <= 7'd20;
        endcase
    end
end

endmodule

