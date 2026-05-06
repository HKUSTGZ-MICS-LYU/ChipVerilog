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
    output reg [31:0] muxreg,
    output reg muxreg_valid
);

    reg [31:0] muxout_comb;

    // Combinational multiplexer logic
    always @(*) begin
        case (rfwb_op[2:1])
            2'b00: muxout_comb = muxin_a;
            2'b01: muxout_comb = muxin_b;
            2'b10: muxout_comb = muxin_c;
            2'b11: muxout_comb = muxin_d + 32'd8;
            default: muxout_comb = 32'b0;
        endcase
    end

    assign muxout = muxout_comb;

    // Sequential logic for register updates
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            muxreg <= 32'b0;
            muxreg_valid <= 1'b0;
        end else begin
            if (~wb_freeze) begin
                muxreg <= muxout_comb;
                muxreg_valid <= rfwb_op[0];
            end
        end
    end

endmodule
