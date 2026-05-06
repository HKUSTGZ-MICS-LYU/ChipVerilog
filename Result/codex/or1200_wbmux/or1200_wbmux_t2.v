// Generated from or1200_wbmux/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_wbmux(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
    input wb_freeze,
    input [2:0] rfwb_op,
    input [31:0] muxin_a,
    input [31:0] muxin_b,
    input [31:0] muxin_c,
    input [31:0] muxin_d,
    output [31:0] muxout,
    output [31:0] muxreg,
    output muxreg_valid
);

reg [31:0] muxout_r;
reg [31:0] muxreg_r;
reg muxreg_valid_r;
assign muxout = muxout_r;
assign muxreg = muxreg_r;
assign muxreg_valid = muxreg_valid_r;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        muxreg_r <= 32'd0;
        muxreg_valid_r <= 1'b0;
    end else if (!wb_freeze) begin
        case (rfwb_op[1:0])
            2'b00: muxreg_r <= muxin_a;
            2'b01: muxreg_r <= muxin_b;
            2'b10: muxreg_r <= muxin_c;
            default: muxreg_r <= muxin_d;
        endcase
        muxreg_valid_r <= rfwb_op[0];
    end
end

always @* begin
    muxout_r = muxreg_valid_r ? muxreg_r : 32'd0;
end

endmodule
