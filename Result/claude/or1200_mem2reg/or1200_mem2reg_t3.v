module or1200_mem2reg(
    input clk,
    input rst,
    input enable,
    input [31:0] data_in,
    output reg [31:0] data_out
);

    reg [31:0] internal_reg;

    always @(posedge clk) begin
        if (rst) begin
            internal_reg <= 32'b0;
            data_out <= 32'b0;
        end else if (enable) begin
            internal_reg <= data_in;
            data_out <= internal_reg;
        end
    end

endmodule
