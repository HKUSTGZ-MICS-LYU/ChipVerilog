`include "timescale.v"
`include "or1200_defines.v"

module or1200_pic(
    clk, rst,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o,
    pic_wakeup, intr,
    pic_int
);

input         clk, rst;
input         spr_cs, spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;
output        pic_wakeup, intr;
input  [19:0] pic_int;

`ifdef OR1200_PIC_IMPLEMENTED

// PICMR: programmable mask or fixed all-ones
`ifdef OR1200_PIC_PICMR
reg  [19:2] picmr;
`else
wire [19:2] picmr = {`OR1200_PIC_INTS-2{1'b1}};
`endif

// PICSR: latch or direct
`ifdef OR1200_PIC_PICSR
reg  [19:0] picsr;
`else
wire [19:0] picsr = pic_int;
`endif

// Write selects
wire picmr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
wire picsr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

// Unmasked interrupts: lowest two bits always unmasked
wire [19:0] um_ints = pic_int & {picmr, 2'b11};

// intr and wakeup
assign intr       = |um_ints;
assign pic_wakeup = intr;

// PICMR register
`ifdef OR1200_PIC_PICMR
always @(posedge clk or posedge rst) begin
    if (rst)
        picmr <= #1 {1'b1, {`OR1200_PIC_INTS-3{1'b0}}};
    else if (picmr_sel & spr_write)
        picmr <= #1 spr_dat_i[19:2];
end
`endif

// PICSR register
`ifdef OR1200_PIC_PICSR
always @(posedge clk or posedge rst) begin
    if (rst)
        picsr <= #1 20'h0;
    else if (picsr_sel & spr_write)
        picsr <= #1 spr_dat_i[19:0] | um_ints;
    else
        picsr <= #1 picsr | um_ints;
end
`endif

// SPR read data (combinational)
reg [31:0] spr_dat_o;
always @(spr_addr or picmr or picsr) begin
    case (spr_addr[1:0])
`ifdef OR1200_PIC_READREGS
        `OR1200_PIC_OFS_PICMR: begin
            spr_dat_o[19:0] = {picmr, 2'b00};
`ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'h0;
`endif
        end
`endif
        default: begin
            spr_dat_o[19:0] = picsr[19:0];
`ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'h0;
`endif
        end
    endcase
end

`else // !OR1200_PIC_IMPLEMENTED

assign intr       = pic_int[1] | pic_int[0];
assign pic_wakeup = intr;

reg [31:0] spr_dat_o;
always @(spr_addr) begin
    spr_dat_o = 32'h0;
`ifdef OR1200_PIC_READREGS
    spr_dat_o[19:0] = 20'h0;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_o[31:20] = 12'h0;
`endif
end

`endif // OR1200_PIC_IMPLEMENTED

endmodule