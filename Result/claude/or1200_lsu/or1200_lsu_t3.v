module or1200_lsu(
    input clk,
    input rst,
    input [31:0] alu_result,
    input [31:0] write_data,
    input [3:0] lsu_op,
    input [3:0] lsu_sel,
    input lsu_stall,
    output reg [31:0] lsu_result,
    output reg lsu_ready
);

    reg [31:0] lsu_result_reg;
    reg lsu_ready_reg;

    always @(posedge clk) begin
        if (rst) begin
            lsu_result <= 32'b0;
            lsu_ready <= 1'b0;
            lsu_result_reg <= 32'b0;
            lsu_ready_reg <= 1'b0;
        end
        else if (!lsu_stall) begin
            case (lsu_op)
                4'b0001: begin
                    lsu_result <= write_data;
                    lsu_ready <= 1'b1;
                end
                4'b0010: begin
                    lsu_result <= write_data;
                    lsu_ready <= 1'b1;
                end
                default: begin
                    lsu_result <= 32'b0;
                    lsu_ready <= 1'b0;
                end
            endcase
        end
        else begin
            lsu_ready <= 1'b0;
        end
    end

endmodule
