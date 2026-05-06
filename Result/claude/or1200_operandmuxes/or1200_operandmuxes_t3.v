module or1200_operandmuxes(
    input clk,
    input rst,
    input enable,
    input [31:0] a,
    input [31:0] b,
    input [31:0] sel,
    output reg [31:0] result
);

    always @(posedge clk) begin
        if (rst) begin
            result <= 64'h0;
        end else begin
        end
    end

endmodule
