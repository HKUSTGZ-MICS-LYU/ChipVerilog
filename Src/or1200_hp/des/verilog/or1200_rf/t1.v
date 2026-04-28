`include "timescale.v"
`include "or1200_defines.v"

module or1200_rf(
    clk, rst,
    supv, wb_freeze, addrw, dataw, we, flushpipe,
    id_freeze, addra, addrb, dataa, datab, rda, rdb,
    spr_cs, spr_write, spr_addr, spr_dat_i, spr_dat_o
);

input         clk, rst;
input         supv, wb_freeze;
input  [4:0]  addrw;
input  [31:0] dataw;
input         we, flushpipe;
input         id_freeze;
input  [4:0]  addra, addrb;
output [31:0] dataa, datab;
input         rda, rdb;
input         spr_cs, spr_write;
input  [31:0] spr_addr, spr_dat_i;
output [31:0] spr_dat_o;

wire [31:0] from_rfa, from_rfb;
reg  [32:0] dataa_saved, datab_saved;
reg         rf_we_allow;

// SPR valid: address targets GPR range
wire spr_valid = spr_cs & (spr_addr[10:5] == `OR1200_SPR_RF);

// Write path mux: SPR write overrides normal write-back
wire [4:0]  rf_addrw = spr_valid & spr_write ? spr_addr[4:0] : addrw;
wire [31:0] rf_dataw = spr_valid & spr_write ? spr_dat_i     : dataw;

// Write enable: (SPR write or normal WB when not frozen) & allow & addr-0 protection
wire rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze)) &
              rf_we_allow &
              (supv | (|rf_addrw));

// Read port A address: SPR read uses spr_addr, else normal addra
wire [4:0] rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
wire [4:0] rf_addrb = addrb;

// Read enables
wire rf_ena = (rda & ~id_freeze) | spr_valid;
wire rf_enb = (rdb & ~id_freeze) | spr_valid;

// SPR read data comes from port A
assign spr_dat_o = from_rfa;

// rf_we_allow: set after reset, updated to ~flushpipe when wb_freeze=0
always @(posedge clk or posedge rst) begin
    if (rst)
        rf_we_allow <= 1'b1;
    else if (!wb_freeze)
        rf_we_allow <= ~flushpipe;
end

// Operand save during id_freeze
always @(posedge clk or posedge rst) begin
    if (rst) begin
        dataa_saved <= 33'h0;
        datab_saved <= 33'h0;
    end else begin
        if (id_freeze & ~dataa_saved[32])
            dataa_saved <= {1'b1, from_rfa};
        else if (~id_freeze)
            dataa_saved <= 33'h0;

        if (id_freeze & ~datab_saved[32])
            datab_saved <= {1'b1, from_rfb};
        else if (~id_freeze)
            datab_saved <= 33'h0;
    end
end

// Output selection
assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;

// Register-file implementation selection
`ifdef OR1200_RFRAM_TWOPORT

or1200_tpram_32x32 rf_a(
    .clk_a(clk), .rst_a(rst), .ce_a(rf_ena), .oe_a(1'b1),
    .addr_a(rf_addra), .do_a(from_rfa),
    .clk_b(clk), .rst_b(rst), .ce_b(rf_we), .we_b(rf_we),
    .addr_b(rf_addrw), .di_b(rf_dataw)
);

or1200_tpram_32x32 rf_b(
    .clk_a(clk), .rst_a(rst), .ce_a(rf_enb), .oe_a(1'b1),
    .addr_a(rf_addrb), .do_a(from_rfb),
    .clk_b(clk), .rst_b(rst), .ce_b(rf_we), .we_b(rf_we),
    .addr_b(rf_addrw), .di_b(rf_dataw)
);

`else
`ifdef OR1200_RFRAM_DUALPORT

or1200_dpram_32x32 rf_a(
    .clk_a(clk), .rst_a(rst), .ce_a(rf_ena), .oe_a(1'b1),
    .addr_a(rf_addra), .do_a(from_rfa),
    .clk_b(clk), .rst_b(rst), .ce_b(rf_we), .we_b(rf_we),
    .addr_b(rf_addrw), .di_b(rf_dataw)
);

or1200_dpram_32x32 rf_b(
    .clk_a(clk), .rst_a(rst), .ce_a(rf_enb), .oe_a(1'b1),
    .addr_a(rf_addrb), .do_a(from_rfb),
    .clk_b(clk), .rst_b(rst), .ce_b(rf_we), .we_b(rf_we),
    .addr_b(rf_addrw), .di_b(rf_dataw)
);

`else
`ifdef OR1200_RFRAM_GENERIC

or1200_rfram_generic rf(
    .clk(clk), .rst(rst),
    .ce_a(rf_ena), .addr_a(rf_addra), .do_a(from_rfa),
    .ce_b(rf_enb), .addr_b(rf_addrb), .do_b(from_rfb),
    .ce_w(rf_we),  .we_w(rf_we), .addr_w(rf_addrw), .di_w(rf_dataw)
);

`else
`ifdef OR1200_RAM_MODELS_VIRTEX

reg [4:0] rf_addra_reg, rf_addrb_reg;
wire [31:0] from_rfa_int, from_rfb_int;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_addra_reg <= 5'h0;
        rf_addrb_reg <= 5'h0;
    end else begin
        if (rf_ena) rf_addra_reg <= rf_addra;
        if (rf_enb) rf_addrb_reg <= rf_addrb;
    end
end

// Force address-0 reads to zero
assign from_rfa = (rf_addra_reg == 5'h00) ? 32'h0 : from_rfa_int;
assign from_rfb = (rf_addrb_reg == 5'h00) ? 32'h0 : from_rfb_int;

rf_sub rf_a(
    .clka(clk), .ena(rf_ena), .addra(rf_addra), .dina(32'h0),
    .clkb(clk), .enb(rf_we),  .web(rf_we), .addrb(rf_addrw), .dinb(rf_dataw),
    .douta(from_rfa_int)
);

rf_sub rf_b(
    .clka(clk), .ena(rf_enb), .addra(rf_addrb), .dina(32'h0),
    .clkb(clk), .enb(rf_we),  .web(rf_we), .addrb(rf_addrw), .dinb(rf_dataw),
    .douta(from_rfb_int)
);

`else

initial begin
    $display("Define RFRAM type.");
    $finish;
end

`endif
`endif
`endif
`endif

endmodule