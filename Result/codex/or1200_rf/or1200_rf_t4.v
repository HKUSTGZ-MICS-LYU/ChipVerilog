`include "or1200_defines.v"

module or1200_rf(
    input clk,
    input rst,
    input supv,
    input wb_freeze,
    input [4:0] addrw,
    input [31:0] dataw,
    input we,
    input flushpipe,
    input id_freeze,
    input [4:0] addra,
    input [4:0] addrb,
    output [31:0] dataa,
    output [31:0] datab,
    input rda,
    input rdb,
    input spr_cs,
    input spr_write,
    input [31:0] spr_addr,
    input [31:0] spr_dat_i,
    output [31:0] spr_dat_o
);
reg [31:0] rf[0:31];
reg [32:0] dataa_saved, datab_saved;
reg rf_we_allow;

wire spr_valid = spr_cs && (spr_addr[10:5] == `OR1200_SPR_RF);
wire [4:0] rf_addra = (spr_valid && !spr_write) ? spr_addr[4:0] : addra;
wire [4:0] rf_addrb = addrb;
wire [4:0] rf_addrw = (spr_valid && spr_write) ? spr_addr[4:0] : addrw;
wire [31:0] rf_dataw = (spr_valid && spr_write) ? spr_dat_i : dataw;
wire rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze)) & rf_we_allow & (supv | (|rf_addrw));

wire [31:0] from_rfa = (rf_addra == 5'd0) ? 32'b0 : rf[rf_addra];
wire [31:0] from_rfb = (rf_addrb == 5'd0) ? 32'b0 : rf[rf_addrb];

assign spr_dat_o = from_rfa;
assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;

integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_we_allow <= 1'b1;
        dataa_saved <= 33'b0;
        datab_saved <= 33'b0;
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'b0;
    end else begin
        if (!wb_freeze)
            rf_we_allow <= ~flushpipe;

        if (rf_we)
            rf[rf_addrw] <= rf_dataw;

        if (id_freeze) begin
            if (!dataa_saved[32] && (rda || spr_valid))
                dataa_saved <= {1'b1, from_rfa};
            if (!datab_saved[32] && rdb)
                datab_saved <= {1'b1, from_rfb};
        end else begin
            dataa_saved <= 33'b0;
            datab_saved <= 33'b0;
        end
    end
end

endmodule
