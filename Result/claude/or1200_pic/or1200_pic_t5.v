// Generated from: Description/or1200_pic_description.txt
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

`include "or1200_defines.v"

`ifdef OR1200_PIC_IMPLEMENTED
  // Selects for write
  wire picmr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
  wire picsr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

`ifdef OR1200_PIC_PICMR
  reg [19:2] picmr;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      picmr <= {1'b1, {`OR1200_PIC_INTS-3{1'b0}}};
    end else if (picmr_sel && spr_write) begin
      picmr <= spr_dat_i[19:2];
    end
  end
`else
  wire [19:2] picmr = {18{1'b1}};
`endif

  wire [19:0] um_ints = pic_int & {picmr, 2'b11};

`ifdef OR1200_PIC_PICSR
  reg [19:0] picsr;
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      picsr <= 20'd0;
    end else if (picsr_sel && spr_write) begin
      picsr <= spr_dat_i[19:0] | um_ints;
    end else begin
      picsr <= picsr | um_ints;
    end
  end
`else
  wire [19:0] picsr = pic_int;
`endif

  assign intr = |um_ints;
  assign pic_wakeup = intr;

  reg [31:0] spr_dat_r;
  assign spr_dat_o = spr_dat_r;
  always @* begin
    spr_dat_r = 32'h0;
`ifdef OR1200_PIC_READREGS
    if (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR) begin
      spr_dat_r[19:0] = {picmr, 2'b00};
    end else begin
      spr_dat_r[19:0] = picsr;
    end
`else
    spr_dat_r[19:0] = picsr;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_r[31:20] = 12'h000;
`endif
  end
`else
  assign intr = pic_int[1] | pic_int[0];
  assign pic_wakeup = intr;
`ifdef OR1200_PIC_READREGS
  reg [31:0] spr_dat_r;
  assign spr_dat_o = spr_dat_r;
  always @* begin
    spr_dat_r = 32'h0;
`ifdef OR1200_PIC_UNUSED_ZERO
    spr_dat_r = 32'h0;
`endif
  end
`endif
`endif

endmodule

