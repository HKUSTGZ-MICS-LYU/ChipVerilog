module fpu_exceptions(
    input clk,
    input rst,
    input enable,
    input [63:0] input_result,
    input exception_input,
    output reg [63:0] final_result,
    output reg exception_output
);

    reg [63:0] result_reg;
    reg exception_reg;

    always @(posedge clk) begin
        if (rst) begin
            final_result <= 64'b0;
            exception_output <= 1'b0;
            result_reg <= 64'b0;
            exception_reg <= 1'b0;
        end else if (enable) begin
            result_reg <= input_result;
            exception_reg <= exception_input;
            
            if (input_result[62:52] == 11'h7FF) begin
                if (|input_result[51:0]) begin
                    final_result <= {input_result[63], 11'h7FF, 52'h0};
                    exception_output <= 1'b1;
                end else begin
                    final_result <= input_result;
                    exception_output <= 1'b0;
                end
            end else begin
                final_result <= result_reg;
                exception_output <= exception_reg;
            end
        end
    end

endmodule
