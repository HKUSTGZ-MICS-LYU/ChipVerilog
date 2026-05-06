module or1200_freeze(
    input clk,
    input rst,
    input dcpu_rty_i,
    input icpu_rty_i,
    input multicycle,
    input mac_busy,
    input du_stall,
    output reg genpc_freeze,
    output reg if_freeze,
    output reg id_freeze,
    output reg ex_freeze,
    output reg wb_freeze
);

    reg stall_condition;
    
    assign stall_condition = dcpu_rty_i | icpu_rty_i | multicycle | mac_busy | du_stall;

    always @(posedge clk) begin
        if (rst) begin
            genpc_freeze <= 1'b0;
            if_freeze <= 1'b0;
            id_freeze <= 1'b0;
            ex_freeze <= 1'b0;
            wb_freeze <= 1'b0;
        end
        else begin
            if (stall_condition) begin
                genpc_freeze <= 1'b1;
                if_freeze <= 1'b1;
                id_freeze <= 1'b1;
                ex_freeze <= 1'b1;
                wb_freeze <= 1'b1;
            end
            else begin
                genpc_freeze <= 1'b0;
                if_freeze <= 1'b0;
                id_freeze <= 1'b0;
                ex_freeze <= 1'b0;
                wb_freeze <= 1'b0;
            end
        end
    end

endmodule
