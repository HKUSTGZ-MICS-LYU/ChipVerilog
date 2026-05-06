module or1200_mult_mac(
    input clk,
    input rst,
    input [31:0] a,
    input [31:0] b,
    input [1:0] mac_op,
    input mac_enable,
    output reg [31:0] result,
    output reg mac_stall
);

    reg [63:0] mac_acc;
    reg [63:0] product_temp;

    always @(posedge clk) begin
        if (rst) begin
            mac_acc <= 64'b0;
            product_temp <= 64'b0;
            result <= 32'b0;
            mac_stall <= 1'b0;
        end
        else if (mac_enable) begin
            case (mac_op)
                2'b00: begin
                    product_temp <= a * b;
                    mac_acc <= 64'b0;
                    result <= 32'b0;
                    mac_stall <= 1'b0;
                end
                2'b01: begin
                    product_temp <= a * b;
                    mac_acc <= mac_acc + product_temp;
                    result <= mac_acc[31:0];
                    mac_stall <= 1'b0;
                end
                2'b10: begin
                    mac_acc <= mac_acc - product_temp;
                    result <= mac_acc[31:0];
                    mac_stall <= 1'b0;
                end
                2'b11: begin
                    result <= mac_acc[31:0];
                    mac_stall <= 1'b0;
                end
            endcase
        end
    end

endmodule
