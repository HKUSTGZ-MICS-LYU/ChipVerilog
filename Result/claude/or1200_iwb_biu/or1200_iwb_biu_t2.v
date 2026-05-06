module or1200_iwb_biu(
    input clk,
    input rst,
    input [31:0] adr_i,
    input [31:0] dat_i,
    input cyc_i,
    input stb_i,
    input we_i,
    input [3:0] sel_i,
    input [3:0] tag_i,
    output [31:0] dat_o,
    output ack_o,
    output err_o,
    output rty_o
);

    reg [31:0] dat_o_reg;
    reg ack_o_reg;
    reg err_o_reg;
    
    assign dat_o = dat_o_reg;
    assign ack_o = ack_o_reg;
    assign err_o = err_o_reg;
    assign rty_o = !ack_o_reg & cyc_i;

    always @(posedge clk) begin
        if (rst) begin
            dat_o_reg <= 32'b0;
            ack_o_reg <= 1'b0;
            err_o_reg <= 1'b0;
        end
        else begin
            if (cyc_i & stb_i) begin
                ack_o_reg <= 1'b1;
                err_o_reg <= 1'b0;
            end
            else begin
                ack_o_reg <= 1'b0;
            end
        end
    end

endmodule
