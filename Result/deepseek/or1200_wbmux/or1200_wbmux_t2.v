// or1200_wbmux: Writeback stage data multiplexer and register
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

    // Local parameters matching OR1200 defines
    localparam OR1200_OPERAND_WIDTH = 32;
    localparam OR1200_RFWBOP_WIDTH = 3;

    // Internal registers
    reg [OR1200_OPERAND_WIDTH-1:0] muxout;
    reg [OR1200_OPERAND_WIDTH-1:0] muxreg;
    reg muxreg_valid;

    // Combinational writeback multiplexer
    // Selector is rfwb_op[OR1200_RFWBOP_WIDTH-1:1] (bits 2:1)
    always @*
        // synopsys parallel_case
        // synopsys infer_mux
        case (rfwb_op[OR1200_RFWBOP_WIDTH-1:1])
            2'b00: muxout = muxin_a;
            2'b01: muxout = muxin_b;
            2'b10: muxout = muxin_c;
            2'b11: muxout = muxin_d + 32'h8;
        endcase

    // Sequential registered outputs with asynchronous reset and freeze control
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
