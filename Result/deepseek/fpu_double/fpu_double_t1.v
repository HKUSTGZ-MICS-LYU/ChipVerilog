module fpu (
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

    // Internal registers for captured inputs
    reg [1:0] rmode_r;
    reg [2:0] fpu_op_r;
    reg [63:0] opa_r, opb_r;

    // Pipeline control
    reg enable_d;
    wire start;
    reg [2:0] cycle_count;
    parameter LATENCY = 3'd4; // Fixed latency (4 cycles)
    reg running;

    // Intermediate results from arithmetic datapaths
    wire add_sign, sub_sign, mul_sign, div_sign;
    wire [10:0] add_exp, sub_exp, mul_exp, div_exp;
    wire [51:0] add_man, sub_man, mul_man, div_man;

    // Selected intermediate result
    reg sign_i;
    reg [10:0] exp_i;
    reg [51:0] man_i;

    // Rounding outputs
    wire rnd_sign;
    wire [10:0] rnd_exp;
    wire [51:0] rnd_man;
    wire rnd_ovf, rnd_udf, rnd_inexact;

    // Exception handling outputs
    wire excp_out_valid;
    wire [63:0] excp_out;
    wire excp_underflow, excp_overflow, excp_inexact, excp_exception, excp_invalid;

    // Detect rising edge on enable
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enable_d <= 1'b0;
        end else begin
            enable_d <= enable;
        end
    end
    assign start = enable && !enable_d;

    // Input capture and operation control
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            opa_r <= 64'd0;
            opb_r <= 64'd0;
            fpu_op_r <= 3'b000;
            rmode_r <= 2'b00;
            running <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            if (start) begin
                opa_r <= opa;
                opb_r <= opb;
                fpu_op_r <= fpu_op;
                rmode_r <= rmode;
                running <= 1'b1;
                cycle_count <= 3'd0;
            end else if (running) begin
                if (cycle_count == LATENCY - 1) begin
                    running <= 1'b0;
                end else begin
                    cycle_count <= cycle_count + 1'b1;
                end
            end
        end
    end

    // Instantiate arithmetic datapaths
    // Addition
    fpu_add add_inst (
        .clk(clk),
        .rst(rst),
        .enable(running && fpu_op_r == 3'b000),
        .opa(opa_r),
        .opb(opb_r),
        .sign(add_sign),
        .exp(add_exp),
        .man(add_man)
    );

    // Subtraction
    fpu_sub sub_inst (
        .clk(clk),
        .rst(rst),
        .enable(running && fpu_op_r == 3'b001),
        .opa(opa_r),
        .opb(opb_r),
        .sign(sub_sign),
        .exp(sub_exp),
        .man(sub_man)
    );

    // Multiplication
    fpu_mul mul_inst (
        .clk(clk),
        .rst(rst),
        .enable(running && fpu_op_r == 3'b010),
        .opa(opa_r),
        .opb(opb_r),
        .sign(mul_sign),
        .exp(mul_exp),
        .man(mul_man)
    );

    // Division
    fpu_div div_inst (
        .clk(clk),
        .rst(rst),
        .enable(running && fpu_op_r == 3'b011),
        .opa(opa_r),
        .opb(opb_r),
        .sign(div_sign),
        .exp(div_exp),
        .man(div_man)
    );

    // Intermediate selection (registered to align with pipeline)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_i <= 1'b0;
            exp_i  <= 11'd0;
            man_i  <= 52'd0;
        end else begin
            case (fpu_op_r)
                3'b000: begin
                    sign_i <= add_sign;
                    exp_i  <= add_exp;
                    man_i  <= add_man;
                end
                3'b001: begin
                    sign_i <= sub_sign;
                    exp_i  <= sub_exp;
                    man_i  <= sub_man;
                end
                3'b010: begin
                    sign_i <= mul_sign;
                    exp_i  <= mul_exp;
                    man_i  <= mul_man;
                end
                3'b011: begin
                    sign_i <= div_sign;
                    exp_i  <= div_exp;
                    man_i  <= div_man;
                end
                default: begin
                    sign_i <= 1'b0;
                    exp_i  <= 11'd0;
                    man_i  <= 52'd0;
                end
            endcase
        end
    end

    // Rounding block
    fpu_round round_inst (
        .clk(clk),
        .rst(rst),
        .enable(running),
        .rmode(rmode_r),
        .sign(sign_i),
        .exp(exp_i),
        .man(man_i),
        .rnd_sign(rnd_sign),
        .rnd_exp(rnd_exp),
        .rnd_man(rnd_man),
        .ovf(rnd_ovf),
        .udf(rnd_udf),
        .inexact(rnd_inexact)
    );

    // Exception handling block
    fpu_exception exception_inst (
        .clk(clk),
        .rst(rst),
        .enable(running),
        .rmode(rmode_r),
        .fpu_op(fpu_op_r),
        .opa(opa_r),
        .opb(opb_r),
        .sign(rnd_sign),
        .exp(rnd_exp),
        .man(rnd_man),
        .ovf(rnd_ovf),
        .udf(rnd_udf),
        .inexact(rnd_inexact),
        .excp_out(excp_out),
        .excp_out_valid(excp_out_valid),
        .underflow(excp_underflow),
        .overflow(excp_overflow),
        .inexact(excp_inexact),
        .exception(excp_exception),
        .invalid(excp_invalid)
    );

    // Final output selection and ready/flag generation
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out       <= 64'd0;
            ready     <= 1'b0;
            underflow <= 1'b0;
            overflow  <= 1'b0;
            inexact   <= 1'b0;
            exception <= 1'b0;
            invalid   <= 1'b0;
        end else begin
            if (running && cycle_count == LATENCY - 1) begin
                ready <= 1'b1;
                if (excp_out_valid) begin
                    out <= excp_out;
                end else begin
                    out <= {rnd_sign, rnd_exp, rnd_man};
                end
                underflow <= excp_underflow;
                overflow  <= excp_overflow;
                inexact   <= excp_inexact;
                exception <= excp_exception;
                invalid   <= excp_invalid;
            end else begin
                ready <= 1'b0;
            end
        end
    end

endmodule


// Placeholder modules for arithmetic, rounding, and exception handling
// These must be implemented with actual IEEE-754 double-precision logic
module fpu_add (
    input clk, rst, enable,
    input [63:0] opa, opb,
    output reg sign,
    output reg [10:0] exp,
    output reg [51:0] man
);
    // Simplified: just pass operand A through
    always @(posedge clk) begin
        if (enable) begin
            sign <= opa[63];
            exp  <= opa[62:52];
            man  <= opa[51:0];
        end
    end
endmodule

module fpu_sub (
    input clk, rst, enable,
    input [63:0] opa, opb,
    output reg sign,
    output reg [10:0] exp,
    output reg [51:0] man
);
    // Simplified: just pass operand A through
    always @(posedge clk) begin
        if (enable) begin
            sign <= opa[63];
            exp  <= opa[62:52];
            man  <= opa[51:0];
        end
    end
endmodule

module fpu_mul (
    input clk, rst, enable,
    input [63:0] opa, opb,
    output reg sign,
    output reg [10:0] exp,
    output reg [51:0] man
);
    // Simplified: just pass operand A through
    always @(posedge clk) begin
        if (enable) begin
            sign <= opa[63];
            exp  <= opa[62:52];
            man  <= opa[51:0];
        end
    end
endmodule

module fpu_div (
    input clk, rst, enable,
    input [63:0] opa, opb,
    output reg sign,
    output reg [10:0] exp,
    output reg [51:0] man
);
    // Simplified: just pass operand A through
    always @(posedge clk) begin
        if (enable) begin
            sign <= opa[63];
            exp  <= opa[62:52];
            man  <= opa[51:0];
        end
    end
endmodule

module fpu_round (
    input clk, rst, enable,
    input [1:0] rmode,
    input sign,
    input [10:0] exp,
    input [51:0] man,
    output reg rnd_sign,
    output reg [10:0] rnd_exp,
    output reg [51:0] rnd_man,
    output reg ovf,
    output reg udf,
    output reg inexact
);
    // Simplified: pass through with no rounding
    always @(posedge clk) begin
        if (enable) begin
            rnd_sign <= sign;
            rnd_exp  <= exp;
            rnd_man  <= man;
            ovf      <= 1'b0;
            udf      <= 1'b0;
            inexact  <= 1'b0;
        end
    end
endmodule

module fpu_exception (
    input clk, rst, enable,
    input [1:0] rmode,
    input [2:0] fpu_op,
    input [63:0] opa, opb,
    input sign,
    input [10:0] exp,
    input [51:0] man,
    input ovf, udf, inexact,
    output reg [63:0] excp_out,
    output reg excp_out_valid,
    output reg underflow,
    output reg overflow,
    output reg exception,
    output reg invalid
);
    // Simplified: no special case detection
    always @(posedge clk) begin
        if (enable) begin
            excp_out_valid <= 1'b0;
            excp_out       <= 64'd0;
            underflow      <= udf;
            overflow       <= ovf;
            exception      <= ovf | udf | inexact;
            invalid        <= 1'b0;
        end
    end
endmodule
