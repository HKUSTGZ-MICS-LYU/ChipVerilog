module or1200_freeze(
    input clk,
    input rst,
    input ic_busy,
    input dc_busy,
    input [31:0] dcpu_adr_o,
    input dcpu_cycstb_o,
    output reg if_freeze,
    output reg id_freeze,
    output reg ex_freeze,
    output reg wb_freeze
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_freeze <= 1'b0;
            id_freeze <= 1'b0;
            ex_freeze <= 1'b0;
            wb_freeze <= 1'b0;
        end else begin
            if_freeze <= ic_busy;
            id_freeze <= ic_busy | dc_busy;
            ex_freeze <= dc_busy;
            wb_freeze <= dc_busy;
        end
    end

endmodule
