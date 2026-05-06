// FPU Exception Handling Module
// Generates IEEE-754 exception flags

module fpu_exceptions(clk, rst, enable, rmode, opa, opb, in_except, exponent_in, mantissa_in, fpu_op, out, ex_enable, underflow, overflow, inexact, exception, invalid);
    input clk;
    input rst;
    input enable;
    input [2:0] rmode;
    input [63:0] opa;
    input [63:0] opb;
    input in_except;
    input [10:0] exponent_in;
    input [55:0] mantissa_in;
    input [2:0] fpu_op;
    output reg [63:0] out;
    output reg ex_enable;
    output reg underflow;
    output reg overflow;
    output reg inexact;
    output reg exception;
    output reg invalid;
    
    wire opa_is_nan = (opa[62:52] == 11'h7FF) & (|opa[51:0]);
    wire opb_is_nan = (opb[62:52] == 11'h7FF) & (|opb[51:0]);
    wire opa_is_inf = (opa[62:52] == 11'h7FF) & ~(|opa[51:0]);
    wire opb_is_inf = (opb[62:52] == 11'h7FF) & ~(|opb[51:0]);
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out <= 64'b0;
            ex_enable <= 1'b0;
            underflow <= 1'b0;
            overflow <= 1'b0;
            inexact <= 1'b0;
            exception <= 1'b0;
            invalid <= 1'b0;
        end else if (enable) begin
            // Check for special cases
            if (opa_is_nan | opb_is_nan) begin
                out <= 64'hFFF8000000000000;
                invalid <= 1'b1;
                exception <= 1'b1;
            end else if (opa_is_inf & opb_is_inf) begin
                out <= {opa[63], 11'h7FF, 52'b0};
                invalid <= 1'b0;
                exception <= 1'b0;
            end else begin
                out <= {opa[63], exponent_in, mantissa_in[51:0]};
                invalid <= 1'b0;
                exception <= 1'b0;
            end
            
            underflow <= (exponent_in == 11'b0) & |mantissa_in;
            overflow <= (exponent_in == 11'h7FF) & |mantissa_in;
            inexact <= |mantissa_in[1:0];
            ex_enable <= 1'b1;
        end
    end
endmodule
