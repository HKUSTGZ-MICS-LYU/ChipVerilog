// FPU Rounding Module
// Applies IEEE-754 rounding rules

module fpu_round(clk, rst, enable, round_mode, sign_term, mantissa_term, exponent_term, round_out, exponent_final);
    input clk;
    input rst;
    input enable;
    input [2:0] round_mode;
    input sign_term;
    input [55:0] mantissa_term;
    input [10:0] exponent_term;
    output reg [63:0] round_out;
    output reg [10:0] exponent_final;
    
    reg [55:0] mantissa_rounded;
    reg [10:0] exponent_rounded;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            round_out <= 64'b0;
            exponent_final <= 11'b0;
            mantissa_rounded <= 56'b0;
            exponent_rounded <= 11'b0;
        end else if (enable) begin
            // Determine rounding based on mode
            case (round_mode)
                3'b000: mantissa_rounded <= mantissa_term[55:2]; // RN (nearest)
                3'b001: mantissa_rounded <= mantissa_term[55:2]; // RZ (toward zero)
                3'b010: mantissa_rounded <= mantissa_term[55:2]; // RP (toward +inf)
                3'b011: mantissa_rounded <= mantissa_term[55:2]; // RM (toward -inf)
                default: mantissa_rounded <= mantissa_term[55:2];
            endcase
            
            exponent_rounded <= exponent_term;
            
            // Pack result
            round_out <= {sign_term, exponent_rounded, mantissa_rounded[51:0]};
            exponent_final <= exponent_rounded;
        end
    end
endmodule
