module or1200_gmultp2_32x32(
    input clk,
    input rst,
    input [31:0] a,
    input [31:0] b,
    input enable,
    output reg [63:0] product
);

    reg [31:0] a_reg;
    reg [31:0] b_reg;
    reg [63:0] product_temp;

    always @(posedge clk) begin
        if (rst) begin
            a_reg <= 32'b0;
            b_reg <= 32'b0;
            product <= 64'b0;
            product_temp <= 64'b0;
        end
        else if (enable) begin
            a_reg <= a;
            b_reg <= b;
            product_temp <= a_reg * b_reg;
            product <= product_temp;
        end
    end

endmodule
