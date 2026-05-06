`ifndef OR1200_SPR_RF
`define OR1200_SPR_RF 6'd0
`endif

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
assign rf_addrw = (spr_valid & spr_write) ? spr_addr[4:0] : addrw;
assign rf_dataw = (spr_valid & spr_write) ? spr_dat_i : dataw;
assign rf_ena = (rda & ~id_freeze) | spr_valid;
assign rf_enb = (rdb & ~id_freeze) | spr_valid;
assign rf_we = (((spr_valid & spr_write) | (we & ~wb_freeze)) & rf_we_allow) & (supv | (|rf_addrw));

assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
assign spr_dat_o = from_rfa;

always @(posedge clk or posedge rst) begin
    if (rst)
        rf_we_allow <= 1'b1;
    else if (!wb_freeze)
        rf_we_allow <= ~flushpipe;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dataa_saved <= 33'b0;
        datab_saved <= 33'b0;
    end
    else if (!id_freeze) begin
        dataa_saved <= 33'b0;
        datab_saved <= 33'b0;
    end
    else begin
        if (!dataa_saved[32])
            dataa_saved <= {1'b1, from_rfa};
        if (!datab_saved[32])
            datab_saved <= {1'b1, from_rfb};
    end
end

`ifdef OR1200_RFRAM_TWOPORT
reg [31:0] rf_mem [0:31];

always @(posedge clk) begin
    if (rf_we)
        rf_mem[rf_addrw] <= rf_dataw;
end

assign from_rfa = rf_mem[rf_addra];
assign from_rfb = rf_mem[addrb];
assign from_rfa_int = 32'h00000000;
assign from_rfb_int = 32'h00000000;

`elsif OR1200_RFRAM_DUALPORT
reg [31:0] rf_mem [0:31];

always @(posedge clk) begin
    if (rf_we)
        rf_mem[rf_addrw] <= rf_dataw;
end

assign from_rfa = rf_mem[rf_addra];
assign from_rfb = rf_mem[addrb];
assign from_rfa_int = 32'h00000000;
assign from_rfb_int = 32'h00000000;

`elsif OR1200_RFRAM_GENERIC
reg [31:0] rf_mem [0:31];

always @(posedge clk) begin
    if (rf_we)
        rf_mem[rf_addrw] <= rf_dataw;
end

assign from_rfa = rf_mem[rf_addra];
assign from_rfb = rf_mem[addrb];
assign from_rfa_int = 32'h00000000;
assign from_rfb_int = 32'h00000000;

`elsif OR1200_RAM_MODELS_VIRTEX
reg [31:0] rf_mem [0:31];

always @(posedge clk) begin
    if (rf_we)
        rf_mem[rf_addrw] <= rf_dataw;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rf_addra_reg <= 5'b00000;
        rf_addrb_reg <= 5'b00000;
    end
    else begin
        if (rf_ena)
            rf_addra_reg <= rf_addra;
        if (rf_enb)
            rf_addrb_reg <= addrb;
    end
end

assign from_rfa_int = rf_mem[rf_addra_reg];
assign from_rfb_int = rf_mem[rf_addrb_reg];
assign from_rfa = (rf_addra_reg == 5'h00) ? 32'h00000000 : from_rfa_int;
assign from_rfb = (rf_addrb_reg == 5'h00) ? 32'h00000000 : from_rfb_int;

`else
assign from_rfa = 32'h00000000;
assign from_rfb = 32'h00000000;
assign from_rfa_int = 32'h00000000;
assign from_rfb_int = 32'h00000000;

always @(posedge clk) begin
    $display("Define RFRAM type.");
    $finish;
end
`endif

endmodule
