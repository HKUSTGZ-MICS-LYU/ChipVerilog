module or1200_pic(
    // RISC Internal Interface
    input clk,
    input rst,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output pic_wakeup,
    output intr,

    // PIC Interface
    input [19:0] pic_int
);

    // Internal register declarations
    reg [19:2] picmr;
    reg [19:0] picsr;

    // Combinational logic for SPR address decoding
    wire picmr_sel = (spr_cs && (spr_addr[13:0] == 14'h0000));
    wire picsr_sel = (spr_cs && (spr_addr[13:0] == 14'h0002));

    // Unmasked interrupt vector: pic_int ANDed with the effective mask
    // {picmr, 2'b11} means the lowest 2 bits are always unmaskable
    wire [19:0] um_ints = pic_int & {picmr, 2'b11};

    // Interrupt output: high if any bit of um_ints is set
    assign intr = (|um_ints);

    // Wakeup output: same as intr
    assign pic_wakeup = intr;

    // SPR read data path (combinational)
    assign spr_dat_o = (picmr_sel) ? {picmr, 2'b00} : picsr;

    // Sequential logic: update PICMR and PICSR on rising edge of clk
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset values
            picmr <= 18'b010000000000000000;  // {1'b1, 17'b0}
            picsr <= 20'b00000000000000000000;
        end else begin
            // PICMR write by CPU
            if (spr_cs && spr_write && picmr_sel) begin
                picmr <= spr_dat_i[19:2];
            end

            // PICSR: accumulate unmasked interrupts and allow CPU writes
            if (spr_cs && spr_write && picsr_sel) begin
                picsr <= spr_dat_i[19:0] | um_ints;
            end else begin
                picsr <= picsr | um_ints;
            end
        end
    end

endmodule
