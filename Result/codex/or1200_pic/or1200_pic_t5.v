module or1200_pic(
    input         clk,
    input         rst,
    input         spr_cs,
    input         spr_write,
    input  [31:0] spr_addr,
    input  [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output        pic_wakeup,
    output        intr,
    input  [19:0] pic_int
);

wire picmr_sel;
wire picsr_sel;
wire [19:0] um_ints;

assign picmr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
assign picsr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

`ifdef OR1200_PIC_IMPLEMENTED

`ifdef OR1200_PIC_PICMR
reg [19:2] picmr;

always @(posedge clk or posedge rst)
begin
    if (rst)
        picmr <= 18'h20000;
    else if (picmr_sel & spr_write)
        picmr <= spr_dat_i[19:2];
end
`else
wire [19:2] picmr;
assign picmr = {18{1'b1}};
`endif

assign um_ints = pic_int & {picmr, 2'b11};
assign intr = |um_ints;
assign pic_wakeup = intr;

`ifdef OR1200_PIC_PICSR
reg [19:0] picsr;

always @(posedge clk or posedge rst)
begin
    if (rst)
        picsr <= 20'b0;
    else if (picsr_sel & spr_write)
        picsr <= spr_dat_i[19:0] | um_ints;
    else
        picsr <= picsr | um_ints;
end
`else
wire [19:0] picsr;
assign picsr = pic_int;
`endif

reg [31:0] spr_dat_o_r;
assign spr_dat_o = spr_dat_o_r;

always @*
begin
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o_r = 32'b0;
`else
    spr_dat_o_r = 32'bx;
`endif
`ifdef OR1200_PIC_READREGS
    if (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR)
        spr_dat_o_r[19:0] = {picmr, 2'b00};
    else
        spr_dat_o_r[19:0] = picsr;
`else
    spr_dat_o_r[19:0] = picsr;
`endif
end

`else

assign intr = pic_int[1] | pic_int[0];
assign pic_wakeup = intr;

reg [31:0] spr_dat_o_r;
assign spr_dat_o = spr_dat_o_r;

always @*
begin
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o_r = 32'b0;
`else
    spr_dat_o_r = 32'bx;
`endif
`ifdef OR1200_PIC_READREGS
    spr_dat_o_r[19:0] = 20'b0;
`endif
end

`endif

endmodule
