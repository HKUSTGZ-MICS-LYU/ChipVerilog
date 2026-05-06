module or1200_lsu(
    input clk,
    input rst,
    input enable,
    input [31:0] addr,
    input [63:0] data_in,
    input [31:0] op,
    output reg [63:0] data_out,
    output reg ready
);

    always @(posedge clk) begin
        if (rst) begin
            data_out <= 64'h0;
            ready <= 1'b0;
        end else begin
        end
    end

endmodule
