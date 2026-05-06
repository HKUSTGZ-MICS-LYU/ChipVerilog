// Generated from or1200_dc_tag/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_dc_tag(
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
    input [8:0] addr,
    input en,
    input we,
    input [19:0] datain,
    output tag_v,
    output [18:0] tag
);

`ifdef OR1200_BIST
reg mbist_so_o_r;
`endif
reg tag_v_r;
reg [18:0] tag_r;
`ifdef OR1200_BIST
assign mbist_so_o = mbist_so_o_r;
`endif
assign tag_v = tag_v_r;
assign tag = tag_r;

reg [18:0] tag_mem [0:511];
always @(posedge clk) begin
    if (en) begin
        if (we)
            tag_mem[addr] <= datain;
        {tag_r, tag_v_r} <= tag_mem[addr];
    end
end

always @* begin
`ifdef OR1200_BIST
    mbist_so_o_r = mbist_si_i;
`endif
end

endmodule
