// Automatically generated OR1200 PIC module

`ifdef OR1200_PIC_IMPLEMENTED

module or1200_pic (
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

  // Internal variables
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

  wire picmr_sel;
  wire picsr_sel;
  wire [19:0] um_ints;

  // SPR address decode
  assign picmr_sel = spr_cs && (spr_addr[1:0] == 2'b00);
  assign picsr_sel = spr_cs && (spr_addr[1:0] == 2'b01);

  // Interrupt mask register
  `ifdef OR1200_PIC_PICMR
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        picmr[19] <= 1'b1;
        picmr[18:2] <= 17'b0;
      end else if (picmr_sel && spr_write) begin
        picmr[19:2] <= spr_dat_i[19:2];
      end
    end
  `endif

  // Unmasked interrupts
  assign um_ints = pic_int & {picmr, 2'b11};

  // Interrupt status register
  `ifdef OR1200_PIC_PICSR
    always @(posedge clk or posedge rst) begin
      if (rst) begin
        picsr <= 20'b0;
      end else if (picsr_sel && spr_write) begin
        picsr <= spr_dat_i[19:0] | um_ints;
      end else begin
        picsr <= picsr | um_ints;
      end
    end
  `endif

  // Interrupt request
  assign intr = |um_ints;
  assign pic_wakeup = intr;

  // SPR read data output
  reg [31:0] spr_dat_o;

  always @* begin
    `ifdef OR1200_PIC_READREGS
      if (spr_addr[1:0] == 2'b00) begin
        spr_dat_o[19:0] = {picmr, 2'b0};
      end else begin
        spr_dat_o[19:0] = picsr;
      end
    `else
      spr_dat_o[19:0] = picsr;
    `endif

    `ifdef OR1200_PIC_UNUSED_ZERO
      spr_dat_o[31:20] = 12'b0;
    `endif
  end

endmodule

`else

module or1200_pic (
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

  // Simple mode: only pic_int[1:0]
  assign intr = pic_int[1] | pic_int[0];
  assign pic_wakeup = intr;

  reg [31:0] spr_dat_o;

  always @* begin
    `ifdef OR1200_PIC_READREGS
      spr_dat_o[19:0] = 20'b0;
    `endif

    `ifdef OR1200_PIC_UNUSED_ZERO
      spr_dat_o[31:20] = 12'b0;
    `endif
  end

endmodule

`endif
