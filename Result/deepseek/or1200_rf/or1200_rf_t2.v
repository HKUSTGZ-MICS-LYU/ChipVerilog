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

    localparam OR1200_SPR_RF = 6'h10;

    wire [31:0] from_rfa;
    wire [31:0] from_rfb;
    reg  [32:0] dataa_saved;
    reg  [32:0] datab_saved;
    wire [4:0]  rf_addra;
    wire [4:0]  rf_addrw;
    wire [31:0] rf_dataw;
    wire        rf_we;
    wire        spr_valid;
    wire        rf_ena;
    wire        rf_enb;
    reg         rf_we_allow;
    wire [31:0] from_rfa_int;
    wire [31:0] from_rfb_int;
    reg  [4:0]  rf_addra_reg;
    reg  [4:0]  rf_addrb_reg;

    assign spr_valid = spr_cs && (spr_addr[10:5] == OR1200_SPR_RF);

    assign rf_addrw = (spr_valid && spr_write) ? spr_addr[4:0] : addrw;
    assign rf_dataw = (spr_valid && spr_write) ? spr_dat_i    : dataw;

    assign rf_addra = (spr_valid && !spr_write) ? spr_addr[4:0] : addra;

    assign rf_we = ((spr_valid && spr_write) || (we && !wb_freeze)) &&
                   rf_we_allow &&
                   (supv || (|rf_addrw));

    assign rf_ena = (rda && !id_freeze) || spr_valid;
    assign rf_enb = (rdb && !id_freeze) || spr_valid;

    assign spr_dat_o = from_rfa;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_we_allow <= 1'b1;
        end else begin
            if (!wb_freeze) begin
                rf_we_allow <= ~flushpipe;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dataa_saved <= 33'd0;
        end else if (!id_freeze) begin
            dataa_saved <= 33'd0;
        end else if (id_freeze && !dataa_saved[32]) begin
            dataa_saved <= {1'b1, from_rfa};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            datab_saved <= 33'd0;
        end else if (!id_freeze) begin
            datab_saved <= 33'd0;
        end else if (id_freeze && !datab_saved[32]) begin
            datab_saved <= {1'b1, from_rfb};
        end
    end

    assign dataa = dataa_saved[32] ? dataa_saved[31:0] : from_rfa;
    assign datab = datab_saved[32] ? datab_saved[31:0] : from_rfb;

`ifdef OR1200_RFRAM_TWOPORT

    or1200_tpram_32x32 u_tpa (
        .clk   (clk),
        .rst   (rst),
        .ce_a  (rf_ena),
        .addr_a(rf_addra),
        .do_a  (from_rfa),
        .ce_b  (rf_enb),
        .addr_b(addrb),
        .do_b  (from_rfb),
        .we    (rf_we),
        .addr_w(rf_addrw),
        .di_w  (rf_dataw)
    );

`elsif OR1200_RFRAM_DUALPORT

    or1200_dpram_32x32 u_dpa (
        .clk   (clk),
        .rst   (rst),
        .ce_a  (rf_ena),
        .addr_a(rf_addra),
        .do_a  (from_rfa),
        .ce_b  (rf_enb),
        .addr_b(addrb),
        .do_b  (from_rfb),
        .we    (rf_we),
        .addr_w(rf_addrw),
        .di_w  (rf_dataw)
    );

`elsif OR1200_RFRAM_GENERIC

    or1200_rfram_generic u_gen (
        .clk   (clk),
        .rst   (rst),
        .ce_a  (rf_ena),
        .addr_a(rf_addra),
        .do_a  (from_rfa),
        .ce_b  (rf_enb),
        .addr_b(addrb),
        .do_b  (from_rfb),
        .we    (rf_we),
        .addr_w(rf_addrw),
        .di_w  (rf_dataw)
    );

`elsif OR1200_RAM_MODELS_VIRTEX

    wire [31:0] rf_sub_a_out;
    wire [31:0] rf_sub_b_out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf_addra_reg <= 5'd0;
            rf_addrb_reg <= 5'd0;
        end else begin
            if (rf_ena) rf_addra_reg <= rf_addra;
            if (rf_enb) rf_addrb_reg <= addrb;
        end
    end

    assign from_rfa_int = (rf_addra_reg == 5'd0) ? 32'd0 : rf_sub_a_out;
    assign from_rfb_int = (rf_addrb_reg == 5'd0) ? 32'd0 : rf_sub_b_out;

    assign from_rfa = from_rfa_int;
    assign from_rfb = from_rfb_int;

    rf_sub u_rf_sub_a (
        .clk   (clk),
        .rst   (rst),
        .ce    (rf_ena),
        .addr  (rf_addra),
        .do    (rf_sub_a_out),
        .we    (rf_we),
        .addr_w(rf_addrw),
        .di_w  (rf_dataw)
    );

    rf_sub u_rf_sub_b (
        .clk   (clk),
        .rst   (rst),
        .ce    (rf_enb),
        .addr  (addrb),
        .do    (rf_sub_b_out),
        .we    (rf_we),
        .addr_w(rf_addrw),
        .di_w  (rf_dataw)
    );

`else

    initial begin
        $display("Define RFRAM type.");
        $finish;
    end

    assign from_rfa = 32'd0;
    assign from_rfb = 32'd0;

`endif

endmodule
