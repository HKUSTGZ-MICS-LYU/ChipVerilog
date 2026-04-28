`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_wbmux (
    input         clk,
    input         rst,

    input         wb_freeze,
    input  [2:0]  rfwb_op,
    input  [31:0] muxin_a,
    input  [31:0] muxin_b,
    input  [31:0] muxin_c,
    input  [31:0] muxin_d,
    output [31:0] muxout,
    output [31:0] muxreg,
    output        muxreg_valid
);

    //--------------------------------------------------------------------------
    // Combinational write-back data selection
    // Selector: rfwb_op[OR1200_RFWBOP_WIDTH-1:1] = rfwb_op[2:1]
    // rfwb_op[0] is the valid bit, not used for data selection
    //--------------------------------------------------------------------------
    reg [31:0] muxout_r;

    // synopsys parallel_case
`ifdef OR1200_ADDITIONAL_SYNOPSYS_DIRECTIVES
    // synopsys infer_mux
`endif
    always @(*) begin
        case (rfwb_op[`OR1200_RFWBOP_WIDTH-1:1])
            2'b00: muxout_r = muxin_a;
            2'b01: muxout_r = muxin_b;
            2'b10: muxout_r = muxin_c;
            2'b11: muxout_r = muxin_d + 32'h8;
        endcase
    end

    assign muxout = muxout_r;

    //--------------------------------------------------------------------------
    // Registered write-back outputs
    // Reset: async active-high, clears muxreg and muxreg_valid
    // wb_freeze: hold both registers (do not update)
    // Normal: latch muxout → muxreg, rfwb_op[0] → muxreg_valid
    //--------------------------------------------------------------------------
    reg [31:0] muxreg_r;
    reg        muxreg_valid_r;

    assign muxreg       = muxreg_r;
    assign muxreg_valid = muxreg_valid_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            muxreg_r       <= #1 32'd0;
            muxreg_valid_r <= #1 1'b0;
        end else if (!wb_freeze) begin
            muxreg_r       <= #1 muxout_r;
            muxreg_valid_r <= #1 rfwb_op[0];
        end
        // wb_freeze: both registers hold previous values (no assignment)
    end

endmodule