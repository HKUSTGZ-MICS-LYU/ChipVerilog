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

// local parameters for SPR offsets
localparam [1:0] OR1200_PIC_OFS_PICMR = 2'b00;
localparam [1:0] OR1200_PIC_OFS_PICSR = 2'b01;

`ifdef OR1200_PIC_IMPLEMENTED

    // Internal signals
    `ifdef OR1200_PIC_PICMR
        reg [19:2] picmr;
    `else
        wire [19:2] picmr = {18{1'b1}};
    `endif

    `ifdef OR1200_PIC_PICSR
        reg [19:0] picsr;
    `else
        wire [19:0] picsr = pic_int[19:0];
    `endif

    wire picmr_sel;
    wire picsr_sel;
    wire [19:0] um_ints;
    reg [31:0] spr_dat_o;

    // Decode write selects
    assign picmr_sel = spr_cs && spr_write && (spr_addr[1:0] == OR1200_PIC_OFS_PICMR);
    assign picsr_sel = spr_cs && spr_write && (spr_addr[1:0] == OR1200_PIC_OFS_PICSR);

    // Unmasked interrupts
    assign um_ints = pic_int & {picmr, 2'b11};

    // Interrupt request and wakeup
    assign intr = |um_ints;
    assign pic_wakeup = intr;

    // PICMR register
    `ifdef OR1200_PIC_PICMR
        always @(posedge clk or posedge rst) begin
            if (rst)
                picmr <= {1'b1, {18{1'b0}}};
            else if (picmr_sel)
                picmr <= spr_dat_i[19:2];
        end
    `endif

    // PICSR register
    `ifdef OR1200_PIC_PICSR
        always @(posedge clk or posedge rst) begin
            if (rst)
                picsr <= 20'b0;
            else if (picsr_sel)
                picsr <= spr_dat_i[19:0] | um_ints;
            else
                picsr <= picsr | um_ints;
        end
    `endif

    // SPR read logic (combinational)
    always @(*) begin
        // Default value
        spr_dat_o = {12'b0, picsr};
        // Only override if PICMR readback is enabled
        `ifdef OR1200_PIC_READREGS
            if (spr_addr[1:0] == OR1200_PIC_OFS_PICMR)
                spr_dat_o = {12'b0, picmr, 2'b0};
        `endif
        `ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'b0;
        `endif
    end

`else // !OR1200_PIC_IMPLEMENTED

    reg [31:0] spr_dat_o;
    wire intr;
    wire pic_wakeup;

    // Simple interrupt generation from lowest two bits
    assign intr = pic_int[1] | pic_int[0];
    assign pic_wakeup = intr;

    // SPR read logic for non-implemented case
    always @(*) begin
        `ifdef OR1200_PIC_READREGS
            spr_dat_o = 32'b0;
        `else
            spr_dat_o = 32'b0; // avoid latches
        `endif
        `ifdef OR1200_PIC_UNUSED_ZERO
            spr_dat_o[31:20] = 12'b0;
        `endif
    end

`endif // OR1200_PIC_IMPLEMENTED

endmodule
