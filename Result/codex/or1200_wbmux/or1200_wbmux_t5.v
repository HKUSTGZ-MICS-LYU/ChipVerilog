module or1200_wbmux
  #(parameter width = `OR1200_OPERAND_WIDTH)
(
    input                        clk,
    input                        rst,
    input                        wb_freeze,
    input  [`OR1200_RFWBOP_WIDTH-1:0] rfwb_op,
    input  [width-1:0]           muxin_a,
    input  [width-1:0]           muxin_b,
    input  [width-1:0]           muxin_c,
    input  [width-1:0]           muxin_d,
    output reg [width-1:0]       muxout,
    output reg [width-1:0]       muxreg,
    output reg                   muxreg_valid
);

always @* begin
`ifdef OR1200_ADDITIONAL_SYNOPSYS_DIRECTIVES
    // synopsys infer_mux
`endif
    // synopsys parallel_case
    case (rfwb_op[`OR1200_RFWBOP_WIDTH-1:1])
        2'b00: muxout = muxin_a;
        2'b01: muxout = muxin_b;
        2'b10: muxout = muxin_c;
        2'b11: muxout = muxin_d + 32'h8;
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        muxreg <= #1 32'd0;
        muxreg_valid <= #1 1'b0;
    end
    else if (!wb_freeze) begin
        muxreg <= #1 muxout;
        muxreg_valid <= #1 rfwb_op[0];
    end
end

endmodule
