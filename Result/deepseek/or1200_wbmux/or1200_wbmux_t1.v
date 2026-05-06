// or1200_wbmux: Write-back stage data multiplexer and register
// Parameter width is OR1200_OPERAND_WIDTH, typically 32

module or1200_wbmux #(
    parameter width = 32
)(
    // Clock and reset
    input clk,
    input rst,

    // Internal i/f
    input wb_freeze,
    input [2:0] rfwb_op,
    input [width-1:0] muxin_a,
    input [width-1:0] muxin_b,
    input [width-1:0] muxin_c,
    input [width-1:0] muxin_d,
    output [width-1:0] muxout,
    output [width-1:0] muxreg,
    output muxreg_valid
);

    // Local parameter for RFWBOP width
    localparam RFWBOP_WIDTH = 3;

    // Internal signals
    reg [width-1:0] muxout;
    reg [width-1:0] muxreg;
    reg muxreg_valid;

    // Combinational write-back multiplexer
    always @* begin
        case (rfwb_op[RFWBOP_WIDTH-1:1])
            // synopsys parallel_case
            2'b00: muxout = muxin_a;
            2'b01: muxout = muxin_b;
            2'b10: muxout = muxin_c;
            2'b11: muxout = muxin_d + 32'h8;
        endcase
    end

    // Sequential register block with asynchronous reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            muxreg <= #1 32'd0;
            muxreg_valid <= #1 1'b0;
        end else if (!wb_freeze) begin
            muxreg <= #1 muxout;
            muxreg_valid <= #1 rfwb_op[0];
        end
    end

endmodule
