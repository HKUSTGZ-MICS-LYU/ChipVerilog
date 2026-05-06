module or1200_top (
    input clk,
    input rst,
    input enable,
    output reg ready
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ready <= 1'b0;
        end else begin
            ready <= enable;
        end
    end

endmodule
