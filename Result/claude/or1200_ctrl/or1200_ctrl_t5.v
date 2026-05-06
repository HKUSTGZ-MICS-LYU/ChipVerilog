module or1200_ctrl(
    input clk,
    input rst,
    input [31:0] if_insn,
    input [31:0] instruction,
    input id_freeze,
    input ex_freeze,
    input wb_freeze,
    input branch_taken,
    input flushpipe,
    input du_hwbkpt,
    input wbforw_valid,
    output reg [31:0] ctrl_signals
);

    always @(posedge clk) begin
        if (rst) begin
            ctrl_signals <= 32'b0;
        end else begin
            if (id_freeze)
                ctrl_signals <= ctrl_signals;
            else if (flushpipe | du_hwbkpt)
                ctrl_signals <= 32'b0;
            else
                ctrl_signals <= 32'b0;
        end
    end

endmodule
