module or1200_mult_mac(
    input clk,
    input rst,
    input [31:0] a,
    input [31:0] b,
    input [3:0] mac_op,
    input mac_stall,
    output reg [31:0] result,
    output reg overflow
);

    reg [63:0] accumulator;
    wire [63:0] product = {{32{a[31]}}, a} * {{32{b[31]}}, b};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            accumulator <= 64'b0;
            result <= 32'b0;
            overflow <= 1'b0;
        end else if (!mac_stall) begin
            case (mac_op)
                4'b0000: accumulator <= product;
                4'b0001: accumulator <= accumulator + product;
                4'b0010: accumulator <= accumulator - product;
                default: accumulator <= accumulator;
            endcase
            result <= accumulator[31:0];
            overflow <= accumulator[63:32] != {32{accumulator[31]}};
        end
    end

endmodule
