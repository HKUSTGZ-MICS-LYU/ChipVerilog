`include "or1200_defines.v"

module or1200_rf(
    input               clk,
    input               rst,
    input               supv,
    input               wb_freeze,
    input  [4:0]        addrw,
    input  [31:0]       dataw,
    input               we,
    input               flushpipe,
    input               id_freeze,
    input  [4:0]        addra,
    input  [4:0]        addrb,
    output [31:0]       dataa,
    output [31:0]       datab,
    input               rda,
    input               rdb,
    input               spr_cs,
    input               spr_write,
    input  [31:0]       spr_addr,
    input  [31:0]       spr_dat_i,
    output [31:0]       spr_dat_o
);

reg [31:0] rf[0:31];
reg        rf_we_allow;
reg [32:0] dataa_saved;
reg [32:0] datab_saved;

wire spr_valid = spr_cs && (spr_addr[`OR1200_SPR_GROUP_BITS] == `OR1200_SPR_GROUP_SYS) &&
                 (spr_addr[`OR1200_SPROFS_BITS] >= (`OR1200_SPR_RF << 5)) &&
                 (spr_addr[`OR1200_SPROFS_BITS] < ((`OR1200_SPR_RF << 5) + 32));
wire [4:0] rf_addrw = spr_valid && spr_write ? spr_addr[4:0] : addrw;
wire [31:0] rf_dataw = spr_valid && spr_write ? spr_dat_i : dataw;
wire rf_we = ((spr_valid && spr_write) || (we && !wb_freeze)) && rf_we_allow && (supv || (|rf_addrw));
wire [4:0] rf_addra = (spr_valid && !spr_write) ? spr_addr[4:0] : addra;
wire [4:0] rf_addrb = addrb;
wire rf_ena = spr_valid || (rda && !id_freeze);
wire rf_enb = spr_valid || (rdb && !id_freeze);
wire [31:0] from_rfa = (rf_addra == 5'd0) ? 32'b0 : rf[rf_addra];
wire [31:0] from_rfb = (rf_addrb == 5'd0) ? 32'b0 : rf[rf_addrb];

integer i;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'b0;
    end else if (rf_we) begin
        rf[rf_addrw] <= rf_dataw;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_we_allow <= 1'b1;
    else if (!wb_freeze)
        rf_we_allow <= ~flushpipe;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        dataa_saved <= 33'b0;
    else if (id_freeze && !dataa_saved[32] && rf_ena)
        dataa_saved <= {1'b1, from_rfa};
    else if (!id_freeze)
        dataa_saved <= 33'b0;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        datab_saved <= 33'b0;
    else if (id_freeze && !datab_saved[32] && rf_enb)
        datab_saved <= {1'b1, from_rfb};
    else if (!id_freeze)
        datab_saved <= 33'b0;
end

assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
assign spr_dat_o = from_rfa;

endmodule
