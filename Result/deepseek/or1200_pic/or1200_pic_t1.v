// or1200_pic: Programmable Interrupt Controller for OR1200
// Verilog-2001 implementation

module or1200_pic (
    input           clk,
    input           rst,
    input           spr_cs,
    input           spr_write,
    input  [31:0]   spr_addr,
    input  [31:0]   spr_dat_i,
    output reg [31:0] spr_dat_o,
    output          pic_wakeup,
    output          intr,
    input  [19:0]   pic_int
);

`ifdef OR1200_PIC_IMPLEMENTED

    // Internal signals
    wire [19:0] um_ints;
    wire       picmr_sel;
    wire       picsr_sel;

    // PICMR mask register or fixed mask
`ifdef OR1200_PIC_PICMR
    reg [19:2] picmr;
`else
    wire [19:2] picmr = {18{1'b1}};
`endif

    // PICSR status register or direct input
`ifdef OR1200_PIC_PICSR
    reg [19:0] picsr;
`else
    wire [19:0] picsr = pic_int;
`endif

    // Write select decode
    assign picmr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
    assign picsr_sel = spr_cs && (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

    // Unmasked interrupt vector: bits 1:0 always unmasked
    assign um_ints = pic_int & {picmr, 2'b11};

    // Interrupt request and wakeup
    assign intr       = |um_ints;
    assign pic_wakeup = intr;

    // Sequential update of PICMR
`ifdef OR1200_PIC_PICMR
    always @(posedge clk or posedge rst) begin
        if (rst)
            picmr <= {1'b1, {(20-3){1'b0}}}; // picmr[19]=1, picmr[18:2]=0
        else if (picmr_sel && spr_write)
            picmr <= spr_dat_i[19:2];
    end
`endif

    // Sequential update of PICSR
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

    // SPR read data generation (combinational)
    always @* begin
`ifdef OR1200_PIC_READREGS
        if (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR)
            spr_dat_o[19:0] = {picmr, 2'b0};
        else
            spr_dat_o[19:0] = picsr;
`else
        spr_dat_o[19:0] = picsr;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
        spr_dat_o[31:20] = 12'b0;
`endif
    end

`else // !OR1200_PIC_IMPLEMENTED

    // Non-implemented mode: only pic_int[1:0] contribute
    assign intr       = pic_int[1] | pic_int[0];
    assign pic_wakeup = intr;

    // SPR read data
    always @* begin
`ifdef OR1200_PIC_READREGS
        spr_dat_o[19:0] = 20'b0;
`else
        spr_dat_o[19:0] = 20'b0;
`endif
`ifdef OR1200_PIC_UNUSED_ZERO
        spr_dat_o[31:20] = 12'b0;
`endif
    end

`endif // OR1200_PIC_IMPLEMENTED

endmodule
