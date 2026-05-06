`include "or1200_defines.v"

module or1200_pic(
    input                          clk,
    input                          rst,
    input                          spr_cs,
    input                          spr_write,
    input      [31:0]              spr_addr,
    input      [31:0]              spr_dat_i,
    output     [31:0]              spr_dat_o,
    output                         pic_wakeup,
    output                         intr,
    input      [`OR1200_PIC_INTS-1:0] pic_int
);

`ifdef OR1200_PIC_IMPLEMENTED
reg [`OR1200_PIC_INTS-3:0] picmr;
reg [`OR1200_PIC_INTS-1:0] picsr;
wire picmr_sel = spr_cs && (spr_addr[`OR1200_PICOFS_BITS] == `OR1200_PIC_OFS_PICMR);
wire picsr_sel = spr_cs && (spr_addr[`OR1200_PICOFS_BITS] == `OR1200_PIC_OFS_PICSR);
wire [`OR1200_PIC_INTS-1:0] um_ints = pic_int & {picmr, 2'b11};

always @(posedge clk or posedge rst) begin
    if (rst)
        picmr <= {{1'b1}, {(`OR1200_PIC_INTS-4){1'b0}}};
    else if (picmr_sel && spr_write)
        picmr <= spr_dat_i[`OR1200_PIC_INTS-1:2];
end

always @(posedge clk or posedge rst) begin
    if (rst)
        picsr <= {`OR1200_PIC_INTS{1'b0}};
    else if (picsr_sel && spr_write)
        picsr <= spr_dat_i[`OR1200_PIC_INTS-1:0];
    else
        picsr <= picsr | um_ints;
end

assign intr = |um_ints;
assign pic_wakeup = intr;
assign spr_dat_o = picmr_sel ? {{(32-`OR1200_PIC_INTS){1'b0}}, picmr, 2'b00}
                            : {{(32-`OR1200_PIC_INTS){1'b0}}, picsr};
`else
assign intr = |pic_int[1:0];
assign pic_wakeup = intr;
assign spr_dat_o = 32'b0;
`endif

endmodule
