`include "or1200_defines.v"

module or1200_wbmux(
    input               clk,
    input               rst,
    input               wb_freeze,
    input  [2:0]        rfwb_op,
    input  [31:0]       muxin_a,
    input  [31:0]       muxin_b,
    input  [31:0]       muxin_c,
    input  [31:0]       muxin_d,
    output [31:0]       muxout,
    output reg [31:0]   muxreg,
    output reg          muxreg_valid
);

reg [31:0] muxout_r;
assign muxout = muxout_r;

always @* begin
    case (rfwb_op[`OR1200_RFWBOP_WIDTH-1:1])
        2'b00: muxout_r = muxin_a;
        2'b01: muxout_r = muxin_b;
        2'b10: muxout_r = muxin_c;
        2'b11: muxout_r = muxin_d + 32'd8;
        default: muxout_r = 32'b0;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        muxreg       <= 32'b0;
        muxreg_valid <= 1'b0;
    end else if (!wb_freeze) begin
        muxreg       <= muxout;
        muxreg_valid <= rfwb_op[0];
    end
end

endmodule
