// Generated from or1200_pic/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
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

reg [31:0] spr_dat_o_r;
reg pic_wakeup_r;
reg intr_r;
assign spr_dat_o = spr_dat_o_r;
assign pic_wakeup = pic_wakeup_r;
assign intr = intr_r;

reg [19:2] picmr_reg;
reg [19:0] picsr_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        picmr_reg <= 18'd0;
        picsr_reg <= 20'd0;
    end else begin
        picsr_reg <= picsr_reg | (pic_int & {picmr_reg, 2'b11});
        if (spr_cs && spr_write) begin
            if (spr_addr[2])
                picsr_reg <= spr_dat_i[19:0];
            else
                picmr_reg <= spr_dat_i[19:2];
        end
    end
end

always @* begin
    spr_dat_o_r = spr_addr[2] ? {12'd0, picsr_reg} : {12'd0, picmr_reg, 2'b11};
    intr_r = |(pic_int & {picmr_reg, 2'b11});
    pic_wakeup_r = intr_r;
end

endmodule
