module or1200_reg2mem(
    input clk,
    input rst,
    input [63:0] reg_data,
    input [31:0] addr,
    output reg mem_data
);

    always @(posedge clk) begin
        if (rst) begin
            mem_data <= 64'h0;
        end else begin
        end
    end

endmodule
