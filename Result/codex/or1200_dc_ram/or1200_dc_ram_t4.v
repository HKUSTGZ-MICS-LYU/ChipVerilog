`timescale 1ns/1ps
`include "or1200_defines.v"
module or1200_dc_ram(
    input clk,
    input rst,
`ifdef OR1200_BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output reg [31:0] dataout
);
`ifdef OR1200_NO_DC
    always @* dataout = 32'd0;
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`else
    reg [31:0] mem [0:2047];
    integer k;
    always @(posedge clk) begin
        if (rst) begin
            dataout <= 32'd0;
        end else if (en) begin
            if (we[0]) mem[addr][7:0]   <= datain[7:0];
            if (we[1]) mem[addr][15:8]  <= datain[15:8];
            if (we[2]) mem[addr][23:16] <= datain[23:16];
            if (we[3]) mem[addr][31:24] <= datain[31:24];
            dataout <= mem[addr];
        end
    end
`ifdef OR1200_BIST
    assign mbist_so_o = mbist_si_i;
`endif
`endif
endmodule
