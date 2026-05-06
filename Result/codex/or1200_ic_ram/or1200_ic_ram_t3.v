// Generated from or1200_ic_ram/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_ic_ram(
    // Clock and reset
    input clk,
    input rst,

`ifdef OR1200_BIST
    // RAM BIST
    input mbist_si_i,
    output mbist_so_o,
    input [`OR1200_MBIST_CTRL_WIDTH - 1:0] mbist_ctrl_i,
`endif

    // Internal i/f
    input [10:0] addr,
    input en,
    input [3:0] we,
    input [31:0] datain,
    output [31:0] dataout
);

`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg [31:0] dataout_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign dataout = dataout_r;

reg [31:0] mem [0:2047];
always @(posedge clk) begin
    if (en) begin
        if (we[0]) mem[addr][7:0] <= datain[7:0];
        if (we[1]) mem[addr][15:8] <= datain[15:8];
        if (we[2]) mem[addr][23:16] <= datain[23:16];
        if (we[3]) mem[addr][31:24] <= datain[31:24];
        dataout_r <= mem[addr];
    end
end

always @* begin
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
