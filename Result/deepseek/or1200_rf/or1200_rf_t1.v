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

    assign spr_valid = spr_cs & (spr_addr[10:5] == 6'd0);

    assign rf_addra = (spr_valid & ~spr_write) ? spr_addr[4:0] : addra;
    assign rf_addrw = (spr_valid & spr_write) ? spr_addr[4:0] : addrw;
    assign rf_dataw = (spr_valid & spr_write) ? spr_dat_i : dataw;

    assign rf_we = ((spr_valid & spr_write) | (we & ~wb_freeze)) & rf_we_allow & (supv | (|rf_addrw));

    assign rf_ena = (rda & ~id_freeze) | spr_valid;
    assign rf_enb = (rdb & ~id_freeze) | spr_valid;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_we_allow <= 1'b1;
        end else begin
            if (~wb_freeze)
                rf_we_allow <= ~flushpipe;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dataa_saved <= 33'd0;
        end else begin
            if (~id_freeze)
                dataa_saved <= 33'd0;
            else if (id_freeze & ~dataa_saved[32])
                dataa_saved <= {1'b1, from_rfa};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            datab_saved <= 33'd0;
        end else begin
            if (~id_freeze)
                datab_saved <= 33'd0;
            else if (id_freeze & ~datab_saved[32])
                datab_saved <= {1'b1, from_rfb};
        end
    end

    assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
    assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;
    assign spr_dat_o = from_rfa;

`ifdef OR1200_RFRAM_TWOPORT
    or1200_tpram_32x32 tpram_a (
        .clk(clk),
        .rst(rst),
        .addr(rf_addra),
        .dout(from_rfa),
        .en(rf_ena),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
    or1200_tpram_32x32 tpram_b (
        .clk(clk),
        .rst(rst),
        .addr(addrb),
        .dout(from_rfb),
        .en(rf_enb),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
`elsif OR1200_RFRAM_DUALPORT
    or1200_dpram_32x32 dpram_a (
        .clk(clk),
        .rst(rst),
        .addr(rf_addra),
        .dout(from_rfa),
        .en(rf_ena),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
    or1200_dpram_32x32 dpram_b (
        .clk(clk),
        .rst(rst),
        .addr(addrb),
        .dout(from_rfb),
        .en(rf_enb),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
`elsif OR1200_RFRAM_GENERIC
    or1200_rfram_generic rfg (
        .clk(clk),
        .rst(rst),
        .addra(rf_addra),
        .ena(rf_ena),
        .douta(from_rfa),
        .addrb(addrb),
        .enb(rf_enb),
        .doutb(from_rfb),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
`elsif OR1200_RAM_MODELS_VIRTEX
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_addra_reg <= 5'd0;
            rf_addrb_reg <= 5'd0;
        end else begin
            rf_addra_reg <= rf_addra;
            rf_addrb_reg <= addrb;
        end
    end

    rf_sub rf_a (
        .clk(clk),
        .rst(rst),
        .addr(rf_addra),
        .dout(from_rfa_int),
        .en(rf_ena),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );
    rf_sub rf_b (
        .clk(clk),
        .rst(rst),
        .addr(addrb),
        .dout(from_rfb_int),
        .en(rf_enb),
        .waddr(rf_addrw),
        .din(rf_dataw),
        .we(rf_we)
    );

    assign from_rfa = (rf_addra_reg == 5'd0) ? 32'd0 : from_rfa_int;
    assign from_rfb = (rf_addrb_reg == 5'd0) ? 32'd0 : from_rfb_int;
`else
    initial begin
        $display("Define RFRAM type.");
        $finish;
    end
`endif

endmodule
