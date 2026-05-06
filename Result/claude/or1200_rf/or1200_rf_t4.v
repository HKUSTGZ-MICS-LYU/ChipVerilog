module or1200_rf(
    input clk,
    input rst,
    input [4:0] addr_a,
    input [4:0] addr_b,
    input [4:0] addr_w,
    input we,
    input [31:0] dat_w,
    output [31:0] dat_a,
    output [31:0] dat_b
);

    reg [31:0] rf [0:31];

    assign dat_a = rf[addr_a];
    assign dat_b = rf[addr_b];

    always @(posedge clk) begin
        if (we) begin
            rf[addr_w] <= dat_w;
        end
    end

endmodule
