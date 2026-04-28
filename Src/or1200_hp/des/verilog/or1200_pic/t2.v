`include "timescale.v"
// synopsys translate_on
`include "or1200_defines.v"

module or1200_pic (
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

`ifdef OR1200_PIC_IMPLEMENTED

    //--------------------------------------------------------------------------
    // PICMR: programmable interrupt mask register [19:2]
    // Bits [1:0] are not stored; they are hardwired to 1 in mask calculation.
    //--------------------------------------------------------------------------
`ifdef OR1200_PIC_PICMR
    reg [19:2] picmr;
`else
    wire [19:2] picmr = {18{1'b1}};   // fixed all-ones: all interrupts unmasked
`endif

    //--------------------------------------------------------------------------
    // PICSR: interrupt status register [19:0]
    //--------------------------------------------------------------------------
`ifdef OR1200_PIC_PICSR
    reg [19:0] picsr;
`else
    wire [19:0] picsr = pic_int;       // no latch: directly reflects pic_int
`endif

    //--------------------------------------------------------------------------
    // Write select decode (combinational)
    //--------------------------------------------------------------------------
    wire picmr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICMR);
    wire picsr_sel = spr_cs & (spr_addr[1:0] == `OR1200_PIC_OFS_PICSR);

    //--------------------------------------------------------------------------
    // Effective (unmasked) interrupt vector
    // Lowest two bits always unmasked: {picmr[19:2], 2'b11}
    //--------------------------------------------------------------------------
    wire [19:0] um_ints = pic_int & {picmr, 2'b11};

    //--------------------------------------------------------------------------
    // Interrupt request and wakeup
    //--------------------------------------------------------------------------
    assign intr      = |um_ints;
    assign pic_wakeup = intr;

    //--------------------------------------------------------------------------
    // PICMR register update
    //--------------------------------------------------------------------------
`ifdef OR1200_PIC_PICMR
    always @(posedge clk or posedge rst) begin
        if (rst)
            // Reset: bit[19]=1, bits[18:2]=0
            picmr <= {1'b1, {(`OR1200_PIC_INTS-3){1'b0}}};
        else if (picmr_sel & spr_write)
            picmr <= spr_dat_i[19:2];
    end
`endif

    //--------------------------------------------------------------------------
    // PICSR register update
    // On each cycle: picsr |= um_ints (latch active unmasked interrupts)
    // On SPR write:  picsr = spr_dat_i[19:0] | um_ints
    //--------------------------------------------------------------------------
`ifdef OR1200_PIC_PICSR
    always @(posedge clk or posedge rst) begin
        if (rst)
            picsr <= 20'h0;
        else if (picsr_sel & spr_write)
            picsr <= spr_dat_i[19:0] | um_ints;
        else
            picsr <= picsr | um_ints;
    end
`endif

    //--------------------------------------------------------------------------
    // SPR read data (combinational; does not check spr_cs per spec)
    //--------------------------------------------------------------------------
    reg [31:0] spr_dat_o_r;

    always @(*) begin
        spr_dat_o_r = 32'h0;
`ifdef OR1200_PIC_READREGS
        case (spr_addr[1:0])
            `OR1200_PIC_OFS_PICMR: begin
                // PICMR: return {picmr[19:2], 2'b0} in bits[19:0]
                // Bits[1:0] read as 0 (not stored in register)
                spr_dat_o_r[19:0] = {picmr, 2'b00};
`ifdef OR1200_PIC_UNUSED_ZERO
                spr_dat_o_r[31:20] = 12'h0;
`endif
            end
            default: begin
                spr_dat_o_r[19:0] = picsr[19:0];
`ifdef OR1200_PIC_UNUSED_ZERO
                spr_dat_o_r[31:20] = 12'h0;
`endif
            end
        endcase
`else
        // OR1200_PIC_READREGS not defined: return picsr only
        spr_dat_o_r[19:0] = picsr[19:0];
`ifdef OR1200_PIC_UNUSED_ZERO
        spr_dat_o_r[31:20] = 12'h0;
`endif
`endif
    end

    assign spr_dat_o = spr_dat_o_r;

`else   // OR1200_PIC_IMPLEMENTED not defined

    //--------------------------------------------------------------------------
    // Minimal mode: intr from lowest two interrupt inputs only
    //--------------------------------------------------------------------------
    assign intr       = pic_int[1] | pic_int[0];
    assign pic_wakeup = intr;

    // SPR read data in non-implemented mode
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

`endif  // OR1200_PIC_IMPLEMENTED

endmodule