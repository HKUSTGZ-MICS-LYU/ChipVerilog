// Generated from or1200_tt/description.txt only.
// Behavioral, synthesizable approximation based on the provided description.
module or1200_tt(
    // RISC Internal Interface
    input clk,
    input rst,
    input du_stall,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o,
    output intr
);

reg [31:0] spr_dat_o_r;
reg intr_r;
assign spr_dat_o = spr_dat_o_r;
assign intr = intr_r;

reg [31:0] ttmr_reg;
reg [31:0] ttcr_reg;
wire match = (ttcr_reg[27:0] == ttmr_reg[27:0]);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ttmr_reg <= 32'd0;
        ttcr_reg <= 32'd0;
    end else begin
        if (spr_cs && spr_write) begin
            if (spr_addr[0])
                ttcr_reg <= spr_dat_i;
            else
                ttmr_reg <= spr_dat_i;
        end else if (!du_stall) begin
            ttcr_reg <= ttcr_reg + 1'b1;
            if (match)
                ttmr_reg[28] <= 1'b1;
        end
    end
end

always @* begin
    spr_dat_o_r = spr_addr[0] ? ttcr_reg : ttmr_reg;
    intr_r = ttmr_reg[28];
end

endmodule
