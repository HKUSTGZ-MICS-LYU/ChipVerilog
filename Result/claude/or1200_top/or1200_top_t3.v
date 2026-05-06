module or1200_top(
    input clk,
    input rst,
    output [31:0] icpu_adr_o,
    output icpu_cycstb_o,
    output [3:0] icpu_sel_o,
    input [31:0] icpu_dat_i,
    input icpu_ack_i,
    output [31:0] dcpu_adr_o,
    output dcpu_cycstb_o,
    output dcpu_we_o,
    output [3:0] dcpu_sel_o,
    output [31:0] dcpu_dat_o,
    input [31:0] dcpu_dat_i,
    input dcpu_ack_i
);

    wire ic_en, dc_en;
    wire [31:0] pc;

    assign ic_en = 1'b1;
    assign dc_en = 1'b1;
    assign icpu_adr_o = pc;
    assign icpu_cycstb_o = 1'b1;
    assign icpu_sel_o = 4'b1111;
    assign dcpu_adr_o = 32'b0;
    assign dcpu_cycstb_o = 1'b0;
    assign dcpu_we_o = 1'b0;
    assign dcpu_sel_o = 4'b0;
    assign dcpu_dat_o = 32'b0;

endmodule
