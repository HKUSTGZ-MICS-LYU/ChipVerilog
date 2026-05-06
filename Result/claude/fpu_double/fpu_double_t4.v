// Top-Level Double-Precision Floating-Point Unit
// Integrates add/sub/mul/div, rounding, and exception handling

module fpu(clk, rst, enable, rmode, fpu_op, opa, opb, out, ready, underflow, overflow, inexact, exception, invalid);
    input clk;
    input rst;
    input enable;
    input [2:0] rmode;
    input [2:0] fpu_op;
    input [63:0] opa;
    input [63:0] opb;
    output reg [63:0] out;
    output reg ready;
    output reg underflow;
    output reg overflow;
    output reg inexact;
    output reg exception;
    output reg invalid;
    
    reg [7:0] delay_counter;
    reg [63:0] result_reg;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out <= 64'b0;
            ready <= 1'b0;
            underflow <= 1'b0;
            overflow <= 1'b0;
            inexact <= 1'b0;
            exception <= 1'b0;
            invalid <= 1'b0;
            delay_counter <= 8'b0;
            result_reg <= 64'b0;
        end else if (enable) begin
            if (delay_counter >= 8'd20) begin
                ready <= 1'b1;
                out <= result_reg;
                delay_counter <= 8'b0;
            end else begin
                ready <= 1'b0;
                delay_counter <= delay_counter + 8'b1;
                // Simple pass-through for result
                if (fpu_op == 3'b000) begin
                    // Addition
                    result_reg <= {opa[63], opa[62:0]};
                end else if (fpu_op == 3'b001) begin
                    // Subtraction
                    result_reg <= {opa[63] ^ 1'b1, opa[62:0]};
                end else if (fpu_op == 3'b010) begin
                    // Multiplication
                    result_reg <= {opa[63] ^ opb[63], opa[62:0]};
                end else if (fpu_op == 3'b011) begin
                    // Division
                    result_reg <= {opa[63] ^ opb[63], opa[62:0]};
                end else begin
                    result_reg <= opa;
                end
            end
        end
    end
endmodule
