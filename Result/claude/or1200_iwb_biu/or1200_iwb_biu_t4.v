module or1200_iwb_biu(
    input clk,
    input rst,
    input [31:0] adr_i,
    input cycstb_i,
    input [3:0] sel_i,
    output reg [31:0] dat_o,
    output reg ack_o
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dat_o <= 32'b0;
            ack_o <= 1'b0;
        end else begin
            ack_o <= cycstb_i;
        end
    end

endmodule
