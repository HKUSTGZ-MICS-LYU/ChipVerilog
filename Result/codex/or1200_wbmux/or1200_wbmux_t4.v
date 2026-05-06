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
    output reg [31:0]   muxout,
    output reg [31:0]   muxreg,
    output reg          muxreg_valid
);

always @* begin
    case (rfwb_op[2:1])
        2'b00: muxout = muxin_a;
        2'b01: muxout = muxin_b;
        2'b10: muxout = muxin_c;
        default: muxout = muxin_d + 32'd8;
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
