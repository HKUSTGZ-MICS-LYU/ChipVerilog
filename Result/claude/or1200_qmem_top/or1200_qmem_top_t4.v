module or1200_qmem_top(
    input clk,
    input rst,
    input enable,
    input [31:0] addr,
    output reg [63:0] data_out
);

    always @(posedge clk) begin
        if (rst) begin
            data_out <= 64'h0;
        end else begin
        end
    end

endmodule
