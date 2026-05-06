module or1200_tt(
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

reg [31:0] ttmr;
reg [31:0] ttcr;
reg [31:0] spr_dat_o;

wire ttmr_sel;
wire ttcr_sel;
wire match;
wire restart;
wire stop;

assign ttmr_sel = (spr_cs && (spr_addr[31:0] == 32'h00000200));
assign ttcr_sel = (spr_cs && (spr_addr[31:0] == 32'h00000201));

assign match = (ttcr[27:0] == ttmr[27:0]);

assign restart = match && (ttmr[31:30] == 2'b01);

assign stop = (match && (ttmr[31:30] == 2'b10)) || 
              (ttmr[31:30] == 2'b00) || 
              du_stall;

assign intr = ttmr[28];

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        ttmr <= 32'h00000000;
        ttcr <= 32'h00000000;
    end else begin
        if (spr_cs && ttmr_sel && spr_write) begin
            ttmr <= spr_dat_i;
        end else if (ttmr[29]) begin
            ttmr[28] <= ttmr[28] | (match && ttmr[29]);
        end

        if (restart) begin
            ttcr <= 32'h00000000;
        end else if (spr_cs && ttcr_sel && spr_write) begin
            ttcr <= spr_dat_i;
        end else if (!stop) begin
            ttcr <= ttcr + 1;
        end
    end
end

always @(*) begin
    if (spr_cs) begin
        if (ttmr_sel) begin
            spr_dat_o = ttmr;
        end else if (ttcr_sel) begin
            spr_dat_o = ttcr;
        end else begin
            spr_dat_o = 32'h00000000;
        end
    end else begin
        spr_dat_o = 32'h00000000;
    end
end

endmodule
