`define OR1200_PIC_OFS_PICMR 2'b00
`endif
`ifndef OR1200_PIC_OFS_PICSR
`define OR1200_PIC_OFS_PICSR 2'b01
`endif
`ifndef OR1200_PIC_INTS
`define OR1200_PIC_INTS 20
`endif

module or1200_pic (
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

// Internal signals
wire [19:0] um_ints;
wire picmr_sel, picsr_sel;

// Address decoding
assign picmr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
assign picsr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

`ifdef OR1200_PIC_IMPLEMENTED

    // PICMR register or wire
    `ifdef OR1200_PIC_PICMR
        reg [19:2] picmr;
        always @(posedge clk or posedge rst) begin
            if (rst)
                picmr <= {1'b1, {(`OR1200_PIC_INTS-3){1'b0}}};
            else if (picmr_sel & spr_write)
                picmr <= spr_dat_i[19:2];
        end
    `else
        wire [19:2] picmr = {(`OR1200_PIC_INTS-2){1'b1}};
    `endif

    // PICSR register or wire
    `ifdef OR1200_PIC_PICSR
        reg [19:0] picsr;
        always @(posedge clk or posedge rst) begin
            if (rst)
                picsr <= 20'b0;
            else if (picsr_sel & spr_write)
                picsr <= spr_dat_i[19:0] | um_ints;
            else
                picsr <= picsr | um_ints;
        end
    `else
        wire [19:0] picsr = pic_int;
    `endif

    // Unmasked interrupts
    assign um_ints = pic_int & {picmr, 2'b11};

    // Interrupt output and wakeup
    assign intr = |um_ints;
    assign pic_wakeup = intr;

    // SPR read data
    always @(*) begin
        // default assignment
        spr_dat_o = 32'b0;
        `ifdef OR1200_PIC_READREGS
            if (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR)
                spr_dat_o[19:0] = {picmr, 2'b0};
            else
                spr_dat_o[19:0] = picsr[19:0];
        `else
            spr_dat_o[19:0] = picsr[19:0];
        `endif
        `ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'b0;
        `endif
    end

`else // !OR1200_PIC_IMPLEMENTED

    // Non-implemented: no mask, no status register
    assign intr = pic_int[1] | pic_int[0];
    assign pic_wakeup = intr;

    // SPR read data (combinational)
    always @(*) begin
        spr_dat_o = 32'b0; // default to avoid latches, but spec only assigns when macro defined
        `ifdef OR1200_PIC_READREGS
            spr_dat_o[19:0] = 20'b0;
        `endif
        `ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'b0;
        `endif
    end

`endif // OR1200_PIC_IMPLEMENTED

endmodule
