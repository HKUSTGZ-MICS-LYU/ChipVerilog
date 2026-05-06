module or1200_iwb_biu(
    input clk,
    input rst,
    input [31:0] cyc_i,
    input [31:0] stb_i,
    input [31:0] ack_o,
    output reg dat_i,
    output reg [63:0] dat_o
);

    always @(posedge clk) begin
        if (rst) begin
            dat_i <= 64'h0;
            dat_o <= 64'h0;
        end else begin
        end
    end

endmodule
