`timescale 1ns / 1ps

module or1200_du(
    input clk,
    input rst,
    input enable
);

    always @(posedge clk) begin
        if (rst) begin
        end else if (enable) begin
        end
    end

endmodule
