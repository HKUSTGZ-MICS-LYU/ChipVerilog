module or1200_pic(
    input clk,
    input rst,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output reg [31:0] spr_dat_o,
    output pic_wakeup,
    output intr,
    input [19:0] pic_int
);

`ifdef OR1200_PIC_IMPLEMENTED
wire picmr_sel;
wire picsr_sel;
wire [19:0] um_ints;

`ifdef OR1200_PIC_PICMR
reg [19:2] picmr;
`else
wire [19:2] picmr;
assign picmr = {18{1'b1}};
`endif

`ifdef OR1200_PIC_PICSR
reg [19:0] picsr;
`else
wire [19:0] picsr;
assign picsr = pic_int;
`endif

assign picmr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
assign picsr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);
assign um_ints = pic_int & {picmr, 2'b11};
assign intr = |um_ints;

`ifdef OR1200_PIC_PICMR
always @(posedge clk or posedge rst) begin
    if (rst)
        picmr <= {1'b1, 17'b0};
    else if (picmr_sel && spr_write)
        picmr <= spr_dat_i[19:2];
end
`endif

`ifdef OR1200_PIC_PICSR
always @(posedge clk or posedge rst) begin
    if (rst)
        picsr <= 20'b0;
    else if (picsr_sel && spr_write)
        picsr <= spr_dat_i[19:0] | um_ints;
    else
        picsr <= picsr | um_ints;
end
`endif

always @* begin
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o[31:20] = 12'b0;
`else
    spr_dat_o[31:20] = 12'bx;
`endif
`ifdef OR1200_PIC_READREGS
    case (spr_addr[1:0])
        `OR1200_PIC_OFS_PICMR: spr_dat_o[19:0] = {picmr, 2'b00};
        default: spr_dat_o[19:0] = picsr;
    endcase
`else
    spr_dat_o[19:0] = picsr;
`endif
end

`else
assign intr = pic_int[1] | pic_int[0];

always @* begin
`ifdef OR1200_PIC_READREGS
    spr_dat_o[19:0] = 20'b0;
`else
    spr_dat_o[19:0] = 20'bx;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o[31:20] = 12'b0;
`else
    spr_dat_o[31:20] = 12'bx;
`endif
end
`endif

assign pic_wakeup = intr;

endmodule
