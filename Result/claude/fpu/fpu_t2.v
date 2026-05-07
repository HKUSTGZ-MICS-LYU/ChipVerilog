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

    reg [63:0] opa_r;
    reg [63:0] opb_r;
    reg [1:0] rmode_r;
    reg [2:0] fpu_op_r;
    
    wire [55:0] sum_out;
    wire [10:0] exp_add_out;
    wire sign_add_out;
    
    wire [55:0] diff_out;
    wire [10:0] exp_sub_out;
    wire sign_sub_out;
    
    wire [55:0] mul_out;
    wire [11:0] exp_mul_out;
    wire sign_mul_out;
    
    wire [55:0] div_out;
    wire [11:0] exp_div_out;
    wire sign_div_out;
    
    reg [55:0] addsub_out;
    reg [10:0] exp_addsub_out;
    reg sign_addsub_out;
    
    reg [6:0] latency_counter;
    reg enable_reg_1;
    
    wire [63:0] rounded_result;
    wire [63:0] exception_result;
    wire [11:0] exponent_post_round;
    wire except_enable;
    wire underflow_0;
    wire overflow_0;
    wire inexact_0;
    wire exception_0;
    wire invalid_0;
    
    fpu_add add_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .opa(opa_r),
        .opb(opb_r),
        .sign(sign_add_out),
        .sum_2(sum_out),
        .exponent_2(exp_add_out)
    );
    
    fpu_sub sub_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .opa(opa_r),
        .opb(opb_r),
        .fpu_op(fpu_op_r),
        .sign(sign_sub_out),
        .diff_2(diff_out),
        .exponent_2(exp_sub_out)
    );
    
    fpu_mul mul_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .opa(opa_r),
        .opb(opb_r),
        .sign(sign_mul_out),
        .product_7(mul_out),
        .exponent_5(exp_mul_out)
    );
    
    fpu_div div_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .opa(opa_r),
        .opb(opb_r),
        .sign(sign_div_out),
        .mantissa_7(div_out),
        .exponent_out(exp_div_out)
    );
    
    fpu_round round_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .round_mode(rmode_r),
        .sign_term(sign_addsub_out),
        .mantissa_term(addsub_out),
        .exponent_term({1'b0, exp_addsub_out}),
        .round_out(rounded_result),
        .exponent_final(exponent_post_round)
    );
    
    fpu_exceptions except_inst(
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .rmode(rmode_r),
        .opa(opa_r),
        .opb(opb_r),
        .in_except(rounded_result),
        .exponent_in(exponent_post_round),
        .mantissa_in(addsub_out[1:0]),
        .fpu_op(fpu_op_r),
        .out(exception_result),
        .ex_enable(except_enable),
        .underflow(underflow_0),
        .overflow(overflow_0),
        .inexact(inexact_0),
        .exception(exception_0),
        .invalid(invalid_0)
    );

    always @(posedge clk) begin
        if (rst) begin
            opa_r <= 0;
            opb_r <= 0;
            rmode_r <= 0;
            fpu_op_r <= 0;
            out <= 0;
            ready <= 0;
            underflow <= 0;
            overflow <= 0;
            inexact <= 0;
            exception <= 0;
            invalid <= 0;
            latency_counter <= 0;
            enable_reg_1 <= 0;
            addsub_out <= 0;
            exp_addsub_out <= 0;
            sign_addsub_out <= 0;
        end else begin
            enable_reg_1 <= enable;
            
            if (enable) begin
                opa_r <= opa;
                opb_r <= opb;
                rmode_r <= rmode;
                fpu_op_r <= fpu_op;
                latency_counter <= 7'b0;
            end else if (latency_counter < 7'd71) begin
                latency_counter <= latency_counter + 1;
            end
            
            case (fpu_op_r)
                3'b000: begin
                    addsub_out <= sum_out;
                    exp_addsub_out <= exp_add_out;
                    sign_addsub_out <= sign_add_out;
                end
                3'b001: begin
                    addsub_out <= diff_out;
                    exp_addsub_out <= exp_sub_out;
                    sign_addsub_out <= sign_sub_out;
                end
                default: begin
                    addsub_out <= addsub_out;
                    exp_addsub_out <= exp_addsub_out;
                    sign_addsub_out <= sign_addsub_out;
                end
            endcase
            
            if ((fpu_op_r == 3'b000 && latency_counter == 7'd20) ||
                (fpu_op_r == 3'b001 && latency_counter == 7'd21) ||
                (fpu_op_r == 3'b010 && latency_counter == 7'd24) ||
                (fpu_op_r == 3'b011 && latency_counter == 7'd71)) begin
                ready <= 1;
                out <= except_enable ? exception_result : rounded_result;
                underflow <= underflow_0;
                overflow <= overflow_0;
                inexact <= inexact_0;
                exception <= exception_0;
                invalid <= invalid_0;
            end else begin
                ready <= 0;
            end
        end
    end

endmodule
