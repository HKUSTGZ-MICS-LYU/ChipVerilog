module or1200_if(
    input clk,
    input rst,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    input icpu_rty_i,
    input icpu_err_i,
    input if_freeze,
    output [31:0] if_insn,
    output [31:0] if_pc
);

    reg [31:0] if_insn_reg;
    reg [31:0] if_pc_reg;
    reg [31:0] pc;

    assign if_insn = if_insn_reg;
    assign if_pc = if_pc_reg;

    always @(posedge clk) begin
        if (rst) begin
            if_insn_reg <= 32'h15000000;
            if_pc_reg <= 32'b0;
            pc <= 32'b0;
        end
        else if (!if_freeze) begin
            if (icpu_ack_i) begin
                if_insn_reg <= icpu_dat_i;
                if_pc_reg <= pc;
                pc <= pc + 32'd4;
            end
        end
    end

endmodule
