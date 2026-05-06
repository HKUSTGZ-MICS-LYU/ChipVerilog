module or1200_rf(
    clk,
    rst,
    supv,
    wb_freeze,
    addrw,
    dataw,
    we,
    flushpipe,
    id_freeze,
    addra,
    addrb,
    dataa,
    datab,
    rda,
    rdb,
    spr_cs,
    spr_write,
    spr_addr,
    spr_dat_i,
    spr_dat_o
);

input clk;
input rst;
input supv;
input wb_freeze;
input [4:0] addrw;
input [31:0] dataw;
input we;
input flushpipe;
input id_freeze;
input [4:0] addra;
input [4:0] addrb;
output [31:0] dataa;
output [31:0] datab;
input rda;
input rdb;
input spr_cs;
input spr_write;
input [31:0] spr_addr;
input [31:0] spr_dat_i;
output [31:0] spr_dat_o;

wire [31:0] from_rfa;
wire [31:0] from_rfb;
reg [32:0] dataa_saved;
reg [32:0] datab_saved;
wire [4:0] rf_addra;
wire [4:0] rf_addrw;
wire [31:0] rf_dataw;
wire rf_we;
wire spr_valid;
wire rf_ena;
wire rf_enb;
reg rf_we_allow;
wire [31:0] from_rfa_int;
wire [31:0] from_rfb_int;
reg [4:0] rf_addra_reg;
reg [4:0] rf_addrb_reg;

assign spr_valid = spr_cs & (spr_addr[10:5] == `OR1200_SPR_RF);
assign rf_addra = (spr_valid & !spr_write) ? spr_addr[4:0] : addra;
assign rf_addrw = spr_valid ? spr_addr[4:0] : addrw;
assign rf_dataw = spr_valid ? spr_dat_i : dataw;
assign rf_ena = (rda & !id_freeze) | spr_valid;
assign rf_enb = (rdb & !id_freeze) | spr_valid;
assign rf_we = ((spr_valid & spr_write) | (we & !wb_freeze)) & rf_we_allow & (supv | (|rf_addrw));

assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
assign spr_dat_o = from_rfa;

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_we_allow <= 1'b1;
    else if (!wb_freeze)
        rf_we_allow <= !flushpipe;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        dataa_saved <= 33'h000000000;
    else if (!id_freeze)
        dataa_saved <= 33'h000000000;
    else if (!dataa_saved[32])
        dataa_saved <= {1'b1, from_rfa};
end

always @(posedge clk or posedge rst) begin
    if (rst)
        datab_saved <= 33'h000000000;
    else if (!id_freeze)
        datab_saved <= 33'h000000000;
    else if (!datab_saved[32])
        datab_saved <= {1'b1, from_rfb};
end

`ifdef OR1200_RAM_MODELS_VIRTEX
always @(posedge clk or posedge rst) begin
    if (rst)
        rf_addra_reg <= 5'h00;
    else
        rf_addra_reg <= rf_addra;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_addrb_reg <= 5'h00;
    else
        rf_addrb_reg <= addrb;
end

rf_sub rfa(
    .clk(clk),
    .rst(rst),
    .ce_a(rf_ena),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_a(rf_addra),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_a(from_rfa_int)
);

rf_sub rfb(
    .clk(clk),
    .rst(rst),
    .ce_a(rf_enb),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_a(addrb),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_a(from_rfb_int)
);

assign from_rfa = (rf_addra_reg == 5'h00) ? 32'h00000000 : from_rfa_int;
assign from_rfb = (rf_addrb_reg == 5'h00) ? 32'h00000000 : from_rfb_int;
`elsif OR1200_RFRAM_TWOPORT
or1200_tpram_32x32 rfa(
    .clk_a(clk),
    .ce_a(rf_ena),
    .oe_a(1'b1),
    .addr_a(rf_addra),
    .do_a(from_rfa),
    .clk_b(clk),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_b()
);

or1200_tpram_32x32 rfb(
    .clk_a(clk),
    .ce_a(rf_enb),
    .oe_a(1'b1),
    .addr_a(addrb),
    .do_a(from_rfb),
    .clk_b(clk),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_b()
);
`elsif OR1200_RFRAM_DUALPORT
or1200_dpram_32x32 rfa(
    .clk_a(clk),
    .ce_a(rf_ena),
    .oe_a(1'b1),
    .addr_a(rf_addra),
    .do_a(from_rfa),
    .clk_b(clk),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_b()
);

or1200_dpram_32x32 rfb(
    .clk_a(clk),
    .ce_a(rf_enb),
    .oe_a(1'b1),
    .addr_a(addrb),
    .do_a(from_rfb),
    .clk_b(clk),
    .ce_b(rf_we),
    .we_b(rf_we),
    .addr_b(rf_addrw),
    .di_b(rf_dataw),
    .do_b()
);
`elsif OR1200_RFRAM_GENERIC
or1200_rfram_generic rf_generic(
    .clk(clk),
    .rst(rst),
    .ce_a(rf_ena),
    .ce_b(rf_enb),
    .addr_a(rf_addra),
    .addr_b(addrb),
    .do_a(from_rfa),
    .do_b(from_rfb),
    .we(rf_we),
    .addr_w(rf_addrw),
    .di_w(rf_dataw)
);
`else
assign from_rfa = 32'h00000000;
assign from_rfb = 32'h00000000;
initial begin
    $display("Define RFRAM type.");
    $finish;
end
`endif

endmodule
