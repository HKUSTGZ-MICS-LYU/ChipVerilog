module or1200_pic(
    input clk,
    input rst,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output pic_wakeup,
    output intr,
    input [19:0] pic_int
);

`ifdef OR1200_PIC_IMPLEMENTED

localparam PICMR_OFS = 2'b00;
localparam PICSR_OFS = 2'b01;

`ifdef OR1200_PIC_PICMR
reg [19:2] picmr;
`else
wire [19:2] picmr = {18{1'b1}};
`endif

`ifdef OR1200_PIC_PICSR
reg [19:0] picsr;
`else
wire [19:0] picsr = pic_int;
`endif

wire [19:0] um_ints;
wire picmr_sel;
wire picsr_sel;

assign um_ints = pic_int & {picmr, 2'b11};

assign picmr_sel = spr_cs & (spr_addr[1:0] == PICMR_OFS);
assign picsr_sel = spr_cs & (spr_addr[1:0] == PICSR_OFS);

`ifdef OR1200_PIC_PICMR
always @(posedge clk or posedge rst) begin
    if (rst) begin
        picmr <= {1'b1, {17{1'b0}}};
    end else if (picmr_sel & spr_write) begin
        picmr <= spr_dat_i[19:2];
    end
end
`endif

`ifdef OR1200_PIC_PICSR
always @(posedge clk or posedge rst) begin
    if (rst) begin
        picsr <= 20'h0;
    end else if (picsr_sel & spr_write) begin
        picsr <= spr_dat_i[19:0] | um_ints;
    end else begin
        picsr <= picsr | um_ints;
    end
end
`endif

reg [31:0] spr_dat_o_r;
always @(*) begin
    spr_dat_o_r = 32'h0;
`ifdef OR1200_PIC_READREGS
    case (spr_addr[1:0])
        PICMR_OFS: spr_dat_o_r[19:0] = {picmr, 2'b0};
        default: spr_dat_o_r[19:0] = picsr[19:0];
    endcase
`else
    spr_dat_o_r[19:0] = picsr[19:0];
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o_r[31:20] = 12'h0;
`endif
end

assign spr_dat_o = spr_dat_o_r;
assign intr = |um_ints;
assign pic_wakeup = intr;

`else // not OR1200_PIC_IMPLEMENTED

wire intr = pic_int[1] | pic_int[0];
assign pic_wakeup = intr;

reg [31:0] spr_dat_o_r;
always @(*) begin
    spr_dat_o_r = 32'h0;
`ifdef OR1200_PIC_READREGS
    spr_dat_o_r[19:0] = 20'h0;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o_r[31:20] = 12'h0;
`endif
end

assign spr_dat_o = spr_dat_o_r;

`endif

endmodule
